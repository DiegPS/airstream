import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

class Client {
  Client(this.socket) {
    sub = socket.listen((raw) {
      frames.add(jsonDecode(raw as String) as Map);
    });
  }
  final WebSocket socket;
  late StreamSubscription<dynamic> sub;
  final frames = <Map>[];
  void send(Map value) => socket.add(jsonEncode(value));
  Future<Map> next(String type) async {
    for (var i = 0; i < 150; i++) {
      final found = frames.where((v) => v['type'] == type);
      if (found.isNotEmpty) {
        final v = found.first;
        frames.remove(v);
        return v;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('Missing $type: $frames');
  }

  Future<void> close() async {
    await socket.close();
    await sub.cancel();
  }
}

void main() {
  late Directory root;
  late TemplateLibrary library;
  late OverlayServer server;
  final clients = <Client>[];
  Future<Client> connect(String view, [String? id]) async {
    final c =
        Client(await WebSocket.connect('ws://127.0.0.1:${server.port}/ws'));
    clients.add(c);
    c.send({'type': 'register', 'view': view, if (id != null) 'template': id});
    await c.next('registered');
    return c;
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('airstream-server-');
    library = TemplateLibrary(root);
    for (final id in ['one', 'two']) {
      await Directory('${root.path}/$id').create();
      await File('${root.path}/$id/index.html').writeAsString('hello');
      await File('${root.path}/$id/template.json').writeAsString(
          '{"fields":[{"key":"title","type":"text","default":"Default"}]}');
    }
    server = OverlayServer(
        templateLibrary: library,
        featuredAcknowledgementTimeout: const Duration(milliseconds: 350));
    await server.start(
        messages: const Stream<ChatMessage>.empty(),
        settings: const SettingsModel(),
        port: 0);
  });
  tearDown(() async {
    for (final c in clients) {
      await c.close();
    }
    clients.clear();
    await server.dispose();
    await root.delete(recursive: true);
  });
  test('rule trigger envelope reaches only custom templates', () async {
    final custom = await connect('custom', 'one');
    final alerts = await connect('alerts');
    final poll = await connect('poll');
    expect(
        server.broadcastRuleTrigger(
            name: 'celebrate', data: '<plain>', rule: 'My rule'),
        true);
    expect((await custom.next('trigger'))['data'],
        {'name': 'celebrate', 'data': '<plain>', 'rule': 'My rule'});
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(alerts.frames.where((f) => f['type'] == 'trigger'), isEmpty);
    expect(poll.frames.where((f) => f['type'] == 'trigger'), isEmpty);
  });
  test('stopping the HTTP server keeps the shared library watcher alive',
      () async {
    final library = await server.templateLibrary;
    await server.stop();
    final changed = library.changes.firstWhere((e) => e.id == 'one');
    await library.writeTemplateFile('one', 'style.css', 'body { color: red; }');
    expect((await changed.timeout(const Duration(seconds: 5))).id, 'one');
  });
  test('clearing a template error emits updated snapshot', () async {
    final c = await connect('custom', 'one');
    final error =
        server.templateErrorsStream.firstWhere((v) => v.containsKey('one'));
    c.send({
      'type': 'templateError',
      'message': 'Oops',
      'source': 'script.js',
      'line': 7
    });
    expect((await error)['one']!.message, 'Oops');
    final cleared =
        server.templateErrorsStream.firstWhere((v) => !v.containsKey('one'));
    server.clearTemplateError('one');
    expect(await cleared, isEmpty);
    expect(server.templateErrors, isEmpty);
  });
  test('registration fields, counts and poll replay', () async {
    server.broadcastPoll({'question': 'Question'});
    final c = await connect('custom', 'one');
    expect(await c.next('fields'), containsPair('replay', true));
    expect((await c.next('poll'))['replay'], true);
    final d = await connect('custom', 'one');
    await d.next('fields');
    final e = await connect('custom', 'two');
    await e.next('fields');
    expect(server.viewCounts['custom'], 3);
    expect(server.templateViewCounts, {'one': 2, 'two': 1});
    expect(await server.templateViewCountsStream.first, {'one': 2, 'two': 1});
  });
  test('values and files reach only the matching template', () async {
    final a = await connect('custom', 'one'),
        b = await connect('custom', 'two'),
        alerts = await connect('alerts');
    await a.next('fields');
    await b.next('fields');
    await library.writeValues('one', {'title': 'Changed'});
    final fields = await a.next('fields');
    expect(fields['data'], {'title': 'Changed'});
    expect(fields.containsKey('replay'), false);
    await File('${root.path}/one/style.css').writeAsString('body{}');
    await a.next('reload');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (final c in [b, alerts]) {
      expect(c.frames.where((v) => ['fields', 'reload'].contains(v['type'])),
          isEmpty);
    }
    expect(a.frames.where((v) => v['type'] == 'reload'), isEmpty);
  });
  test(
      'featured copy has no delivery id and custom cannot acknowledge or reregister',
      () async {
    final custom = await connect('custom', 'one'),
        alerts = await connect('alerts');
    await custom.next('fields');
    final msg = ChatMessage(
        platform: Platform.youtube,
        id: 'featured',
        author: const ChatAuthor(name: 'Viewer', channelId: 'v'),
        items: const [MessageItem.text('Hello')],
        timestamp: DateTime.now());
    final delivery = server.broadcastFeaturedMessage(msg);
    final copy = await custom.next('featured');
    final real = await alerts.next('alert');
    expect(copy['data'], isNot(contains('deliveryId')));
    expect(real['data']['deliveryId'], delivery.id);
    custom.send({'type': 'register', 'view': 'alerts'});
    custom.send({'type': 'featuredRendered', 'deliveryId': delivery.id});
    expect(await delivery.completed, FeaturedMessageStatus.sent);
    expect(server.viewCounts['alerts'], 1);
    final next = server.broadcastFeaturedMessage(msg);
    await alerts.next('alert');
    alerts.send({'type': 'featuredRendered', 'deliveryId': next.id});
    expect(await next.completed, FeaturedMessageStatus.rendered);
  });
  test('template errors are bounded sanitized and rate limited per template',
      () async {
    final c = await connect('custom', 'one');
    await c.next('fields');
    c.send({
      'type': 'templateError',
      'message': 'bad\n\u0000${'x' * 310}',
      'source': r'C:\secret\folder\script.js?private=1',
      'line': 'bad'
    });
    for (var i = 0; i < 100 && server.templateErrors.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final error = server.templateErrors['one']!;
    expect(error.message.length, 300);
    expect(error.message, startsWith('badxxx'));
    expect(error.source, 'script.js');
    expect(error.line, null);
    c.send({
      'type': 'templateError',
      'message': 'ignored',
      'source': 'other.js',
      'line': 2
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(identical(server.templateErrors['one'], error), true);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    c.send({'type': 'templateError', 'message': 'next', 'line': 42});
    final errors = await server.templateErrorsStream
        .firstWhere((m) => m['one']?.message == 'next')
        .timeout(const Duration(seconds: 3));
    expect(errors['one']!.line, 42);
  });
  test('test events are custom-only and localized', () async {
    final a = await connect('custom', 'one'), b = await connect('alerts');
    await a.next('fields');
    server.setSettings(const SettingsModel(appLanguageCode: 'es'));
    expect(server.broadcastTemplateTest(), true);
    final msg = await a.next('message'), alert = await a.next('alert');
    expect(msg['test'], true);
    expect(alert['test'], true);
    expect(msg['data']['author'], 'Espectador de prueba');
    expect(alert['data']['alertType'], 'raid');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
        b.frames.where((v) => v['type'] == 'alert' || v['type'] == 'message'),
        isEmpty);
  });
}

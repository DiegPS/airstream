import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:shelf/shelf.dart';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test(
      'custom index redirects with its query and injects the SDK at the target',
      () async {
    final root = await Directory.systemTemp.createTemp('custom-index-');
    addTearDown(() => root.delete(recursive: true));
    final dir = await Directory('${root.path}/sample').create();
    await File('${dir.path}/index.html').writeAsString('<h1>Sample</h1>');
    final library = TemplateLibrary(root);
    addTearDown(library.dispose);
    final route = buildOverlayRoutes((_) => Response.notFound(''),
        templates: () async => library);
    Future<Response> get(String path) async =>
        await route(Request('GET', Uri.parse('http://localhost$path')));
    const query = '?demo=1&name=a%2Bb';
    final response = await get('/custom/sample/index.html$query');
    expect(response.statusCode, 302);
    expect(response.headers['location'], '/custom/sample/$query');
    expect(await (await get(response.headers['location']!)).readAsString(),
        contains('<script src="/sdk/v1.js"></script>'));
    final gallery = await get('/gallery/credits/index.html$query');
    expect(gallery.statusCode, 200);
    expect(await gallery.readAsString(),
        contains('<script src="/sdk/v1.js"></script>'));
  });

  test(
      'fresh server replays empty poll, giveaway, goals, timer and queue snapshots',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final poll = _Socket(server)..register('poll');
    final giveaway = _Socket(server)..register('giveaway');
    final goals = _Socket(server)..register('goals');
    final timer = _Socket(server)..register('timer');
    final clock = _Socket(server)..register('clock');
    final widget = _Socket(server)..register('gallery', template: 'poll');
    final queue = _Socket(server)..register('gallery', template: 'queue-list');

    expect(poll.snapshot('poll')['data'], isNull);
    expect(giveaway.snapshot('giveaway')['data'], isNull);
    expect(goals.snapshot('goals')['data'], isEmpty);
    expect(timer.snapshot('timer')['data'], containsPair('phase', 'idle'));
    expect(clock.snapshot('clock')['data'], isA<Map>());
    expect(widget.snapshot('poll')['data'], isNull);
    expect(queue.snapshot('queue')['data'], containsPair('entries', isEmpty));
  });

  test(
      'template registration and session updates explicitly clear stale session state',
      () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    Map<String, Object?>? current = {'startedAt': '2026-11-18'};
    server.sessionState = () => current;
    final first = _Socket(server)..register('gallery', template: 'credits');
    expect(first.snapshot('session')['data'], current);

    current = null;
    final cleared = first.sink.nextFrame('session');
    server.sessionChanged();
    expect(await cleared, {'type': 'session', 'data': null, 'replay': false});

    final reconnected = _Socket(server)
      ..register('gallery', template: 'credits');
    expect(reconnected.snapshot('session')['data'], isNull);
    expect(reconnected.snapshot('counters')['data'], isEmpty);
    expect(reconnected.snapshot('queue')['data'],
        containsPair('entries', isEmpty));
    expect(reconnected.snapshot('poll')['data'], isNull);
  });

  test('stopping while template startup waits prevents a server bind',
      () async {
    final root = await Directory.systemTemp.createTemp('cancel-overlay-start-');
    addTearDown(() => root.delete(recursive: true));
    final library = _SlowTemplateLibrary(root);
    final server = OverlayServer(templateLibrary: library);
    addTearDown(server.dispose);
    var subscribed = false;
    final messages = StreamController<ChatMessage>.broadcast(
      onListen: () => subscribed = true,
    );
    addTearDown(messages.close);
    final starting = server.start(
        messages: messages.stream, settings: const SettingsModel(), port: 0);
    await library.enteredWatch.future;
    final stopping = server.stop();
    library.finishWatch.complete();
    await Future.wait([starting, stopping]);
    expect(server.port, 0);
    expect(subscribed, isFalse);
  });

  test('a template-only featured delivery counts as sent', () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final page = _Socket(server)..register('gallery', template: 'credits');
    final delivery = server.broadcastFeaturedMessage(ChatMessage(
      platform: Platform.twitch,
      id: 'featured',
      author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
      items: const [MessageItem.text('Featured text')],
      timestamp: DateTime.utc(2026),
    ));
    final frame =
        page.sink.frames.singleWhere((frame) => frame['type'] == 'featured');
    expect(frame['data'], containsPair('message', 'Featured text'));
    expect(delivery.status, FeaturedMessageStatus.sent);
    expect(await delivery.completed, FeaturedMessageStatus.sent);
  });

  test('a redacted support alert publishes no chat message', () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    server.broadcastChatSupport(ChatMessage(
      platform: Platform.twitch,
      id: 'bits',
      author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
      items: const [],
      timestamp: DateTime.utc(2026),
      superChat: const SuperChat(amount: '500 Bits', color: '#fff'),
    ));
    final frames = alerts.sink.frames;
    expect(frames.where((frame) => frame['type'] == 'message'), isEmpty);
    final alert = frames.singleWhere((frame) => frame['type'] == 'alert');
    expect(alert['data'], containsPair('message', ''));
    expect(alert['data'], containsPair('amount', '500 Bits'));
  });

  test(
      'test and replay require successful delivery to a registered alerts page',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final chat = _Socket(server)..register('chat');
    final unregistered = _Socket(server);
    server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.utc(2026),
        authorName: 'Viewer',
        count: 42));
    final recent = server.recentAlertsSnapshot.single;
    chat.sink.frames.clear();
    unregistered.sink.frames.clear();

    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    final alerts = _Socket(server)..register('alerts');
    expect(server.broadcastTestAlert('bits'), isTrue);
    expect(server.replayRecentAlert('raid'), isTrue);
    final received =
        alerts.sink.frames.where((frame) => frame['type'] == 'alert').toList();
    expect(received, hasLength(2));
    expect(received.first['data']['id'], startsWith('test-bits-'));
    expect(received.last['data']['id'], 'raid');
    expect(received.last['data'], recent);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    alerts.sink.fail = true;
    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
  });
}

class _SlowTemplateLibrary extends TemplateLibrary {
  _SlowTemplateLibrary(super.root);

  final enteredWatch = Completer<void>();
  final finishWatch = Completer<void>();

  @override
  Future<bool> exists() async => false;

  @override
  Future<void> watch() {
    enteredWatch.complete();
    return finishWatch.future;
  }
}

class _Socket implements WebSocketChannel {
  _Socket(OverlayServer server) {
    server.attachClient(this);
    addTearDown(_incoming.close);
  }

  final _incoming = StreamController<String>(sync: true);

  @override
  final _Sink sink = _Sink();

  @override
  Stream<String> get stream => _incoming.stream;

  void register(String view, {String? template}) {
    _incoming.add(jsonEncode({
      'type': 'register',
      'view': view,
      if (template != null) 'template': template,
    }));
    expect(sink.frames.singleWhere((frame) => frame['type'] == 'registered'),
        {'type': 'registered', 'view': view});
  }

  Map<String, dynamic> snapshot(String type) {
    final frame = sink.frames.singleWhere((frame) => frame['type'] == type);
    expect(frame['replay'], isTrue);
    return frame;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  final frames = <Map<String, dynamic>>[];
  bool fail = false;
  final _waiters = <String, Completer<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> nextFrame(String type) =>
      (_waiters[type] = Completer<Map<String, dynamic>>())
          .future
          .timeout(const Duration(seconds: 3));

  @override
  void add(dynamic event) {
    if (fail) throw StateError('Closed socket');
    final frame = jsonDecode(event as String) as Map<String, dynamic>;
    frames.add(frame);
    _waiters.remove(frame['type'])?.complete(frame);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

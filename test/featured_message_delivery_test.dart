import 'support/empty_template_library.dart';
import 'dart:async';
import 'dart:convert';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late OverlayServer server;
  late StreamController<ChatMessage> messages;
  final connections = <_OverlayConnection>[];
  final message = ChatMessage(
    platform: Platform.kick,
    id: 'featured-1',
    author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
    items: const [MessageItem.text('Which game next?')],
    timestamp: DateTime.utc(2026, 11, 15),
  );

  Future<_OverlayConnection> connect(String? view) async {
    final socket = IOWebSocketChannel.connect(
      'ws://127.0.0.1:${server.port}/ws',
    );
    await socket.ready;
    final connection = _OverlayConnection(socket);
    connections.add(connection);
    expect((await connection.next())['type'], 'settings');
    if (view != null) {
      socket.sink.add(jsonEncode({'type': 'register', 'view': view}));
      expect((await connection.next())['type'], 'registered');
      if (view == 'poll') {
        expect(await connection.next(), {
          'type': 'poll',
          'data': null,
          'replay': true,
        });
      }
      if (view == 'alerts') {
        expect(await connection.next(), {
          'type': 'alertControl',
          'op': server.alertQueueStatus.paused ? 'pause' : 'resume',
        });
      }
    }
    return connection;
  }

  setUp(() async {
    messages = StreamController<ChatMessage>.broadcast();
    server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    await server.start(
      messages: messages.stream,
      settings: const SettingsModel(),
      port: 0,
    );
  });

  tearDown(() async {
    for (final connection in connections) {
      await connection.close();
    }
    connections.clear();
    await server.dispose();
    await messages.close();
  });

  test(
      'custom alerts target alerts only, repeat independently, and never enter provider history',
      () async {
    final poll = await connect('poll');
    expect(
        server.broadcastRuleAlert(
            title: '<b>Title</b>', text: '<script>text</script>', seconds: 3),
        false);
    final alerts = await connect('alerts');
    for (var i = 0; i < 2; i++) {
      expect(
          server.broadcastRuleAlert(
              title: '<b>Title</b>', text: '<script>text</script>', seconds: 3),
          true);
      final envelope = await alerts.next();
      expect(envelope['data'], {
        'kind': 'custom',
        'title': '<b>Title</b>',
        'message': '<script>text</script>',
        'seconds': 3
      });
    }
    expect(server.recentAlertsSnapshot, isEmpty);
    final received = poll.events.moveNext();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await poll.socket.sink.close();
    expect(await received, false);
  });

  test('poll, captions, chat and legacy clients cannot receive highlights',
      () async {
    expect(server.broadcastFeaturedMessage(message).status,
        FeaturedMessageStatus.noReceiver);
    for (final view in ['poll', 'captions', 'chat', null]) {
      await connect(view);
      expect(server.broadcastFeaturedMessage(message).status,
          FeaturedMessageStatus.noReceiver);
    }
  });

  test('waits for the recipient to render, ignoring wrong and duplicate ACKs',
      () async {
    final poll = await connect('poll');
    final alerts = await connect('alerts');
    final delivery = server.broadcastFeaturedMessage(message);
    expect(delivery.status, FeaturedMessageStatus.sent);
    final envelope = await alerts.next();
    expect(envelope['type'], 'alert');
    final data = envelope['data'] as Map;
    expect(data['kind'], 'featured');
    expect(data['platform'], 'kick');
    expect(data['message'], 'Which game next?');
    expect(data['deliveryId'], delivery.id);
    var completed = false;
    unawaited(delivery.completed.then((_) => completed = true));
    void acknowledge(_OverlayConnection client, Object? id) {
      client.socket.sink.add(jsonEncode({
        'type': 'featuredRendered',
        'deliveryId': id,
      }));
    }

    acknowledge(poll, delivery.id);
    acknowledge(alerts, 'unknown');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(completed, isFalse, reason: 'a queued card is only sent');
    acknowledge(alerts, delivery.id);
    expect(await delivery.completed, FeaturedMessageStatus.rendered);
    acknowledge(alerts, delivery.id);

    // Poll did not receive the featured alert.
    server.broadcastCaption('marker');
    expect((await poll.next())['type'], 'caption');
  });

  test('disconnect before rendering resolves without claiming display',
      () async {
    final alerts = await connect('alerts');
    final delivery = server.broadcastFeaturedMessage(message);
    await alerts.next();
    await alerts.close();
    expect(await delivery.completed, FeaturedMessageStatus.disconnected);
    await connect('alerts');
    expect(server.clientCount, 1);
  });

  test('queue controls target alerts and report the largest connected queue',
      () async {
    final first = await connect('alerts');
    final otherView = await connect('featured');
    server.controlAlertQueue(AlertQueueOperation.pause);
    expect(await first.next(), {'type': 'alertControl', 'op': 'pause'});
    final second = await connect('alerts');
    expect(server.alertQueueStatus.pages, 2);
    expect(server.alertQueueStatus.paused, isTrue);

    Future<AlertQueueStatus> statusWhere(
            bool Function(AlertQueueStatus) match) =>
        server.alertQueueStatusStream
            .firstWhere(match)
            .timeout(const Duration(seconds: 3));
    void report(_OverlayConnection client, int pending, {bool active = false}) {
      client.socket.sink.add(jsonEncode({
        'type': 'alertQueue',
        'paused': false,
        'pending': pending,
        'active': active,
      }));
    }

    report(otherView, 20);
    report(first, 4, active: true);
    expect(await statusWhere((s) => s.pending == 4),
        (paused: true, pending: 4, active: true, pages: 2));
    report(second, 7);
    expect(await statusWhere((s) => s.pending == 7),
        (paused: true, pending: 7, active: true, pages: 2));
    await second.close();
    expect(await statusWhere((s) => s.pages == 1),
        (paused: true, pending: 4, active: true, pages: 1));

    for (final op in [
      AlertQueueOperation.skip,
      AlertQueueOperation.clear,
      AlertQueueOperation.resume
    ]) {
      server.controlAlertQueue(op);
      expect(await first.next(), {'type': 'alertControl', 'op': op.name});
    }
    expect(server.alertQueueStatus.paused, isFalse);
    server.broadcastCaption('barrier');
    expect((await otherView.next())['type'], 'caption');
  });

  test('dedicated featured page is preferred, acknowledges and hides',
      () async {
    final alerts = await connect('alerts');
    final featured = await connect('featured');
    expect(server.viewCounts['featured'], 1);
    final delivery = server.broadcastFeaturedMessage(message);
    final data = (await featured.next())['data'] as Map;
    expect(data['deliveryId'], delivery.id);
    expect(data['items'], [
      {'kind': 'text', 'text': 'Which game next?'}
    ]);

    void ack(_OverlayConnection connection, String? id) {
      connection.socket.sink.add(jsonEncode({
        'type': 'featuredRendered',
        'deliveryId': id,
      }));
    }

    ack(alerts, delivery.id);
    var completed = false;
    unawaited(delivery.completed.then((_) => completed = true));
    server.broadcastCaption('barrier');
    expect((await alerts.next())['type'], 'caption');
    expect((await featured.next())['type'], 'caption');
    expect(completed, isFalse);
    ack(featured, delivery.id);
    expect(await delivery.completed, FeaturedMessageStatus.rendered);

    final removed = server.broadcastFeaturedMessage(message);
    await featured.next();
    server.removeFeaturedMessage();
    expect(await alerts.next(), {'type': 'featuredHide'});
    expect(await featured.next(), {'type': 'featuredHide'});
    expect(await removed.completed, FeaturedMessageStatus.removed);

    final disconnected =
        server.viewCountsStream.firstWhere((c) => c['featured'] == 0);
    await featured.close();
    await disconnected.timeout(const Duration(seconds: 3));
    final fallback = server.broadcastFeaturedMessage(message);
    expect((await alerts.next())['data']['deliveryId'], fallback.id);
    ack(alerts, fallback.id);
    expect(await fallback.completed, FeaturedMessageStatus.rendered);
  });

  test('missing render receipt expires as sent, never as rendered', () async {
    await server.dispose();
    server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
      featuredAcknowledgementTimeout: const Duration(milliseconds: 100),
    );
    await server.start(
      messages: messages.stream,
      settings: const SettingsModel(),
      port: 0,
    );
    final alerts = await connect('alerts');
    final delivery = server.broadcastFeaturedMessage(message);
    await alerts.next();
    expect(await delivery.completed, FeaturedMessageStatus.sent);
  });

  test('one of several recipients can confirm, with independent delivery IDs',
      () async {
    final first = await connect('alerts');
    final second = await connect('alerts');
    final a = server.broadcastFeaturedMessage(message);
    final b = server.broadcastFeaturedMessage(message);
    expect(a.id, isNot(b.id));
    await first.next();
    await first.next();
    await second.next();
    await second.next();
    await first.close();
    second.socket.sink.add(jsonEncode({
      'type': 'featuredRendered',
      'deliveryId': b.id,
    }));
    expect(await b.completed, FeaturedMessageStatus.rendered);
    await server.stop();
    expect(await a.completed, FeaturedMessageStatus.disconnected);
  });
}

class _OverlayConnection {
  _OverlayConnection(this.socket) : events = StreamIterator(socket.stream);

  final IOWebSocketChannel socket;
  final StreamIterator<dynamic> events;
  bool closed = false;

  Future<Map<String, dynamic>> next() async {
    expect(await events.moveNext().timeout(const Duration(seconds: 3)), isTrue);
    return jsonDecode(events.current as String) as Map<String, dynamic>;
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    await events.cancel();
    await socket.sink.close();
  }
}

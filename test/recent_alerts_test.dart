import 'support/empty_template_library.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'dart:async';
import 'dart:convert';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

const window = Duration(milliseconds: 100);

ChatMessage message(
  Platform platform, {
  String id = 'first',
  String name = 'Ana',
  String channelId = 'ana',
  MembershipEventKind? membership,
  int? months,
  int? gifts,
  SuperChat? payment,
}) =>
    ChatMessage(
      platform: platform,
      id: id,
      author: ChatAuthor(
        name: name,
        channelId: channelId,
        avatarUrl: 'https://example.com/avatar.png',
        badge: const AuthorBadge(imageUrl: 'badge.png', label: 'Member'),
      ),
      items: const [MessageItem.text(' Hello! ')],
      superChat: payment,
      isMembershipEvent: membership != null,
      membershipEventKind: membership,
      membershipMonths: months,
      membershipGiftCount: gifts,
      timestamp: DateTime.utc(2026, 11, 15),
    );

void main() {
  late _Connection connection;
  setUp(() async {
    connection = _Connection();
    addTearDown(connection.close);
    await connection.start();
  });

  test('records exact automatic payloads newest first, including flushed gifts',
      () async {
    for (final msg in [
      message(Platform.youtube,
          id: 'paid',
          payment: const SuperChat(amount: r'$5', color: '#ffffff')),
      message(Platform.twitch,
          id: 'bits',
          payment: const SuperChat(amount: '100 Bits', color: '#9146FF')),
      message(Platform.youtube,
          id: 'member', membership: MembershipEventKind.subscription),
      message(Platform.kick,
          id: 'sub', membership: MembershipEventKind.resubscription, months: 6),
      message(Platform.twitch,
          id: 'gift', membership: MembershipEventKind.gift),
    ]) {
      final next = connection.nextAlert();
      await connection.send(msg);
      final payload = await next;
      expect(connection.server.recentAlertsSnapshot.first, payload);
    }
    for (final (platform, kind) in [
      (Platform.twitch, ChatProviderEventKind.raid),
      (Platform.kick, ChatProviderEventKind.host),
      (Platform.kick, ChatProviderEventKind.support),
    ]) {
      final next = connection.nextAlert();
      connection.server.broadcastProviderEvent(ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: kind.name,
        timestamp: DateTime.now(),
        authorName: 'Ana',
        count: 42,
      ));
      expect(connection.server.recentAlertsSnapshot.first, await next);
    }
    expect(connection.server.recentAlertsSnapshot,
        connection.alerts.reversed.toList());
    expect(() => connection.server.recentAlertsSnapshot.clear(),
        throwsUnsupportedError);
    expect(
        () =>
            connection.server.recentAlertsSnapshot.first['author'] = 'changed',
        throwsUnsupportedError);
  });

  test(
      'excludes tests, featured messages, disabled alerts and provider repeats',
      () async {
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered;
    var next = connection.nextAlert();
    connection.server.broadcastTestAlert('bits');
    await next;
    next = connection.nextAlert();
    connection.server.broadcastFeaturedMessage(message(Platform.youtube));
    await next;
    connection.server.setSettings(
        const SettingsModel(alertDisabledTypes: ['bits', 'gift', 'raid']));
    await connection.send(message(Platform.twitch,
        payment: const SuperChat(amount: '10 Bits', color: '#ffffff')));
    await connection
        .send(message(Platform.twitch, membership: MembershipEventKind.gift));
    final raid = ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.now());
    connection.server.broadcastProviderEvent(raid);
    expect(connection.server.recentAlertsSnapshot, isEmpty);
    connection.server.setSettings(const SettingsModel());
    next = connection.nextAlert();
    connection.server.broadcastProviderEvent(raid);
    await next;
    connection.server.broadcastProviderEvent(raid);
    await Future<void>.delayed(window * 2);
    expect(connection.server.recentAlertsSnapshot, hasLength(1));
    expect(connection.alerts, hasLength(3));
  });

  test('keeps only the latest 30 and gives every listener the current list',
      () async {
    expect(connection.server.recentAlerts.isBroadcast, isTrue);
    final changes = <List<Map<String, Object?>>>[];
    final subscription = connection.server.recentAlerts.listen(changes.add);
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 31; i++) {
      final next = connection.nextAlert();
      await connection.send(message(Platform.youtube,
          id: '$i', payment: const SuperChat(amount: r'$5', color: '#ffffff')));
      await next;
    }
    final snapshot = connection.server.recentAlertsSnapshot;
    expect(snapshot, hasLength(30));
    expect(snapshot.first['id'], '30');
    expect(snapshot.last['id'], '1');
    expect(await connection.server.recentAlerts.first, snapshot);
    expect(await connection.server.recentAlerts.first, snapshot);
    expect(changes, hasLength(32));
    expect(changes[1], hasLength(1));
    expect(() => changes.last.clear(), throwsUnsupportedError);
    await subscription.cancel();
  });

  test('replay bypasses disabled types with exact payload and no new history',
      () async {
    final next = connection.nextAlert();
    await connection.send(message(Platform.twitch,
        id: 'bits',
        payment: const SuperChat(amount: '10 Bits', color: '#ffffff')));
    final payload = await next;
    connection.server
        .setSettings(const SettingsModel(alertDisabledTypes: ['bits']));
    final replay = connection.nextAlert();
    expect(connection.server.replayRecentAlert('bits'), isTrue);
    expect(await replay, payload);
    expect(connection.server.recentAlertsSnapshot, [payload]);
    expect(connection.server.replayRecentAlert('unknown'), isFalse);
    final disconnected =
        connection.server.clientCountStream.firstWhere((count) => count == 0);
    await connection.socket!.sink.close();
    await disconnected;
    expect(connection.server.replayRecentAlert('bits'), isFalse);
    expect(connection.server.recentAlertsSnapshot, [payload]);
  });

  test('clear and stop empty history and notify listeners', () async {
    for (final stop in [false, true]) {
      final next = connection.nextAlert();
      await connection.send(message(Platform.youtube,
          payment: const SuperChat(amount: r'$5', color: '#ffffff')));
      await next;
      final empty =
          connection.server.recentAlerts.firstWhere((alerts) => alerts.isEmpty);
      if (stop) {
        await connection.server.stop();
      } else {
        connection.server.clearRecentAlerts();
      }
      expect(await empty, isEmpty);
      expect(connection.server.recentAlertsSnapshot, isEmpty);
    }
  });

  test('messages deduplicated by the chat pipeline never enter history twice',
      () async {
    final source = StreamController<ChatMessage>();
    final pipeline = MessagePipeline(const SettingsModel());
    pipeline.addSource(source.stream);
    final bridge = pipeline.stream.listen(connection.messages.add);
    final next = connection.nextAlert();
    final msg = message(Platform.youtube,
        payment: const SuperChat(amount: r'$5', color: '#ffffff'));
    source.add(msg);
    await next;
    source.add(msg);
    await Future<void>.delayed(window);
    expect(connection.alerts, hasLength(1));
    expect(connection.server.recentAlertsSnapshot, connection.alerts);
    await bridge.cancel();
    pipeline.dispose();
    await source.close();
  });

  test('automatic events without clients are not recorded', () async {
    final disconnected =
        connection.server.clientCountStream.firstWhere((count) => count == 0);
    await connection.socket!.sink.close();
    await disconnected;
    connection.messages.add(message(Platform.youtube,
        payment: const SuperChat(amount: r'$5', color: '#ffffff')));
    connection.server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.kick,
        kind: ChatProviderEventKind.support,
        id: 'kicks',
        timestamp: DateTime.now()));
    await Future<void>.delayed(window);
    expect(connection.server.recentAlertsSnapshot, isEmpty);
  });
}

class _Connection {
  OverlayServer server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(), giftGroupingWindow: window);
  final messages = StreamController<ChatMessage>.broadcast();
  final envelopes = StreamController<Map<String, dynamic>>.broadcast();
  final alerts = <Map<String, dynamic>>[];
  IOWebSocketChannel? socket;
  StreamSubscription<dynamic>? subscription;
  bool disposed = false;

  Future<void> start() async {
    await server.start(
        messages: messages.stream, settings: const SettingsModel(), port: 0);
    socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
    await socket!.ready;
    final first = Completer<Map<String, dynamic>>();
    subscription = socket!.stream.listen((raw) {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      if (!first.isCompleted) first.complete(envelope);
      if (envelope['type'] == 'alert') {
        alerts.add(envelope['data'] as Map<String, dynamic>);
      }
      envelopes.add(envelope);
    });
    expect((await first.future)['type'], 'settings');
  }

  Future<void> reconnect(Duration groupingWindow) async {
    await subscription?.cancel();
    await socket?.sink.close();
    await server.dispose();
    server = OverlayServer(
        templateLibrary: emptyTemplateLibrary(),
        giftGroupingWindow: groupingWindow);
    await start();
  }

  Future<void> send(ChatMessage msg) async {
    final delivered =
        envelopes.stream.firstWhere((e) => e['type'] == 'message');
    messages.add(msg);
    await delivered.timeout(const Duration(seconds: 2));
  }

  Future<Map<String, dynamic>> nextAlert(
      [Duration timeout = const Duration(seconds: 2)]) async {
    final event = await envelopes.stream
        .where((e) => e['type'] == 'alert')
        .timeout(timeout)
        .first;
    return event['data'] as Map<String, dynamic>;
  }

  Future<void> close() async {
    await subscription?.cancel();
    await socket?.sink.close();
    if (!disposed) await server.dispose();
    await messages.close();
    await envelopes.close();
  }
}

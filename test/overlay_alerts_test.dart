import 'dart:async';
import 'dart:convert';

import 'package:airstream/models/chat_message.dart';
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

  test('Twitch Bits produces a bits alert', () async {
    final alert = connection.nextAlert();
    await connection.send(message(Platform.twitch,
        payment: const SuperChat(amount: '100 Bits', color: '#9146FF')));
    expect(await alert, containsPair('kind', 'bits'));
    expect(connection.alerts.single, containsPair('platform', 'twitch'));
    expect(connection.alerts.single, containsPair('amount', '100 Bits'));
    expect(connection.alerts.single['membershipKind'], isNull);
    expect(connection.alerts.single['months'], isNull);
    expect(connection.alerts.single['giftCount'], isNull);
  });

  test('Kick subscriptions carry their kind and months', () async {
    for (final (kind, months) in [
      (MembershipEventKind.subscription, 1),
      (MembershipEventKind.resubscription, 6),
    ]) {
      final alert = connection.nextAlert();
      await connection
          .send(message(Platform.kick, membership: kind, months: months));
      expect(
          await alert,
          allOf(
            containsPair('kind', 'membership'),
            containsPair('membershipKind', kind.name),
            containsPair('months', months),
          ));
    }
  });

  test('Kick gift batches are delivered immediately', () async {
    // Longer than the receive timeout: this event must bypass grouping.
    await connection.server.stop();
    await connection.reconnect(const Duration(seconds: 1));
    final alert = connection.nextAlert(const Duration(milliseconds: 300));
    await connection.send(
        message(Platform.kick, membership: MembershipEventKind.gift, gifts: 5));
    expect(
        await alert,
        allOf(
          containsPair('kind', 'membership'),
          containsPair('membershipKind', 'gift'),
          containsPair('giftCount', 5),
        ));
    expect(connection.alerts, hasLength(1));
  });

  test('Twitch gifts restart each gifter window and preserve the first card',
      () async {
    await connection
        .send(message(Platform.twitch, membership: MembershipEventKind.gift));
    await expectLater(
      connection.nextAlert(const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
    final alerts = connection.envelopes.stream
        .where((e) => e['type'] == 'alert')
        .take(2)
        .toList();
    final elapsed = Stopwatch()..start();
    await connection.send(message(Platform.twitch,
        id: 'second', membership: MembershipEventKind.gift));
    await connection.send(message(Platform.twitch,
        id: 'third', membership: MembershipEventKind.gift));
    await connection.send(message(Platform.twitch,
        name: 'Bob', channelId: '', membership: MembershipEventKind.gift));
    final received = await alerts.timeout(const Duration(seconds: 2));
    expect(elapsed.elapsed, greaterThanOrEqualTo(window));
    final data = received.map((e) => e['data'] as Map).toList();
    expect(data.map((a) => a['giftCount']), [3, 1]);
    expect(data.map((a) => a['author']), ['Ana', 'Bob']);
    expect(data.first['id'], 'first');
    expect(data.first['authorAvatarUrl'], 'https://example.com/avatar.png');
    expect(
        data.every((a) =>
            a['membershipKind'] == 'gift' &&
            a['kind'] == 'membership' &&
            a['message'] == ''),
        isTrue);
    await expectLater(connection.nextAlert(const Duration(milliseconds: 130)),
        throwsA(isA<TimeoutException>()));
    expect(connection.alerts, hasLength(2));
  });

  test('YouTube Super Chat preserves every existing payload value', () async {
    final alert = connection.nextAlert();
    await connection.send(message(Platform.youtube,
        payment: const SuperChat(
            amount: r'$10', color: '#FFD600', stickerUrl: 'sticker.png')));
    expect(await alert, {
      'platform': 'youtube',
      'kind': 'superchat',
      'id': 'first',
      'author': 'Ana',
      'authorAvatarUrl': 'https://example.com/avatar.png',
      'authorChannelId': 'ana',
      'badgeImageUrl': 'badge.png',
      'badgeLabel': 'Member',
      'message': 'Hello!',
      'amount': r'$10',
      'color': '#FFD600',
      'stickerUrl': 'sticker.png',
      'timestamp': '2026-11-15T00:00:00.000Z',
      'membershipKind': null,
      'months': null,
      'giftCount': null,
    });
  });

  test('ordinary Twitch and Kick chat never produces alerts', () async {
    await connection.send(message(Platform.twitch));
    await connection.send(message(Platform.kick));
    await expectLater(connection.nextAlert(const Duration(milliseconds: 130)),
        throwsA(isA<TimeoutException>()));
    expect(connection.alerts, isEmpty);
  });

  test('disposing discards pending Twitch gifts without sending or throwing',
      () async {
    await connection
        .send(message(Platform.twitch, membership: MembershipEventKind.gift));
    await connection.server.dispose();
    connection.disposed = true;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(connection.alerts, isEmpty);
  });
}

class _Connection {
  OverlayServer server = OverlayServer(giftGroupingWindow: window);
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
    server = OverlayServer(giftGroupingWindow: groupingWindow);
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

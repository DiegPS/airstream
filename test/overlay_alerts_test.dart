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
      'alertType': 'superchat',
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

  ChatProviderEvent providerEvent(Platform platform, ChatProviderEventKind kind,
          {String id = 'provider', int? count, String text = ''}) =>
      ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: id,
        timestamp: DateTime.utc(2026, 11, 15),
        authorName: 'Ana',
        count: count,
        text: text,
      );

  Future<List<Map<String, dynamic>>> sendProviders(
      List<ChatProviderEvent> events) async {
    // WebSocket ordering makes the caption a barrier for all preceding events.
    final received = connection.envelopes.stream
        .takeWhile((e) => e['type'] != 'caption')
        .toList();
    for (final event in events) {
      connection.server.broadcastProviderEvent(event);
    }
    connection.server.broadcastCaption('barrier');
    return received.timeout(const Duration(seconds: 2));
  }

  test('Twitch raid preserves the provider event and adds a raid alert',
      () async {
    final received = await sendProviders([
      providerEvent(Platform.twitch, ChatProviderEventKind.raid,
          count: 42, text: 'System message'),
    ]);
    expect(received.map((e) => e['type']), ['providerEvent', 'alert']);
    expect(received.first['data'], containsPair('text', 'System message'));
    expect(received.last['data'], {
      'alertType': 'raid',
      'platform': 'twitch',
      'kind': 'raid',
      'id': 'provider',
      'author': 'Ana',
      'authorAvatarUrl': null,
      'authorChannelId': '',
      'badgeImageUrl': null,
      'badgeLabel': null,
      'message': '',
      'amount': null,
      'color': null,
      'stickerUrl': null,
      'timestamp': '2026-11-15T00:00:00.000Z',
      'membershipKind': null,
      'months': null,
      'giftCount': null,
      'count': 42,
    });
  });

  test('Kick host allows a missing viewer count and hides the channel text',
      () async {
    final received = await sendProviders([
      providerEvent(Platform.kick, ChatProviderEventKind.host, text: 'Channel'),
    ]);
    expect(received.map((e) => e['type']), ['providerEvent', 'alert']);
    expect(
        received.last['data'],
        allOf(
          containsPair('kind', 'host'),
          containsPair('count', null),
          containsPair('message', ''),
        ));
  });

  test('Kick support carries Kicks and the gift message', () async {
    final received = await sendProviders([
      providerEvent(Platform.kick, ChatProviderEventKind.support,
          count: 100, text: 'Rocket · gg'),
    ]);
    expect(received.map((e) => e['type']), ['providerEvent', 'alert']);
    expect(
        received.last['data'],
        allOf(
          containsPair('kind', 'kicks'),
          containsPair('count', 100),
          containsPair('message', 'Rocket · gg'),
        ));
  });

  test('duplicate support keeps both provider events but only one alert',
      () async {
    final event = providerEvent(Platform.kick, ChatProviderEventKind.support);
    final received = await sendProviders([event, event]);
    expect(received.map((e) => e['type']),
        ['providerEvent', 'alert', 'providerEvent']);
    expect(connection.alerts, hasLength(1));
  });

  test('rewards, goals and Kick raids remain provider events only', () async {
    final received = await sendProviders([
      providerEvent(Platform.twitch, ChatProviderEventKind.reward),
      providerEvent(Platform.kick, ChatProviderEventKind.goal),
      providerEvent(Platform.kick, ChatProviderEventKind.raid),
    ]);
    expect(received.map((e) => e['type']),
        ['providerEvent', 'providerEvent', 'providerEvent']);
    expect(connection.alerts, isEmpty);
  });

  test('stop and start clear provider alert ids on the same server', () async {
    final event = providerEvent(Platform.kick, ChatProviderEventKind.support);
    await sendProviders([event]);
    final server = connection.server;
    await connection.subscription?.cancel();
    await connection.socket?.sink.close();
    await server.stop();
    await connection.start();
    expect(identical(connection.server, server), isTrue);
    final received = await sendProviders([event]);
    expect(received.map((e) => e['type']), ['providerEvent', 'alert']);
    expect(connection.alerts, hasLength(2));
  });

  test('provider alert ids retain only the last 200 per platform', () async {
    await sendProviders([
      for (var i = 0; i < 201; i++)
        providerEvent(Platform.kick, ChatProviderEventKind.support, id: '$i'),
    ]);
    final received = await sendProviders([
      providerEvent(Platform.kick, ChatProviderEventKind.support, id: '200'),
      providerEvent(Platform.twitch, ChatProviderEventKind.raid, id: '200'),
      providerEvent(Platform.kick, ChatProviderEventKind.support, id: '0'),
    ]);
    expect(received.map((e) => e['type']),
        ['providerEvent', 'providerEvent', 'alert', 'providerEvent', 'alert']);
  });

  test('default settings deliver every automatic alert type unchanged',
      () async {
    for (final msg in [
      message(Platform.youtube,
          payment: const SuperChat(amount: r'$5', color: '#FFD600')),
      message(Platform.youtube, membership: MembershipEventKind.subscription),
      message(Platform.twitch,
          payment: const SuperChat(amount: '100 Bits', color: '#9146FF')),
      message(Platform.kick,
          membership: MembershipEventKind.resubscription, months: 6),
      message(Platform.twitch, membership: MembershipEventKind.gift),
    ]) {
      final alert = connection.nextAlert();
      await connection.send(msg);
      await alert;
    }
    await sendProviders([
      providerEvent(Platform.twitch, ChatProviderEventKind.raid, count: 42),
      providerEvent(Platform.kick, ChatProviderEventKind.support, count: 100),
    ]);
    expect(connection.alerts.map((a) => a['kind']), [
      'superchat',
      'membership',
      'bits',
      'membership',
      'membership',
      'raid',
      'kicks'
    ]);
    expect(connection.alerts[3]['membershipKind'], 'resubscription');
    expect(connection.alerts[4]['membershipKind'], 'gift');
    expect(connection.alerts[4]['giftCount'], 1);
  });

  test('disabled bits still allow Kick subscriptions', () async {
    connection.server
        .setSettings(const SettingsModel(alertDisabledTypes: ['bits']));
    await connection.send(message(Platform.twitch,
        payment: const SuperChat(amount: '100 Bits', color: '#9146FF')));
    final alert = connection.nextAlert();
    await connection.send(
        message(Platform.kick, membership: MembershipEventKind.subscription));
    expect(await alert, containsPair('membershipKind', 'subscription'));
    expect(connection.alerts, hasLength(1));
  });

  test('disabled gifts create no Twitch group and suppress every platform',
      () async {
    connection.server
        .setSettings(const SettingsModel(alertDisabledTypes: ['gift']));
    for (final platform in Platform.values) {
      await connection.send(
          message(platform, membership: MembershipEventKind.gift, gifts: 5));
    }
    // Re-enable before the grouping window: an incorrectly created timer would fire.
    connection.server.setSettings(const SettingsModel());
    await expectLater(connection.nextAlert(const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()));
    await connection.server.dispose();
    connection.disposed = true;
    expect(connection.alerts, isEmpty);
  });

  test('disabled raids preserve provider envelopes and allow Kicks', () async {
    final settingsReceived =
        connection.envelopes.stream.firstWhere((e) => e['type'] == 'settings');
    connection.server
        .setSettings(const SettingsModel(alertDisabledTypes: ['raid']));
    await settingsReceived.timeout(const Duration(seconds: 2));
    final received = await sendProviders([
      providerEvent(Platform.twitch, ChatProviderEventKind.raid),
      providerEvent(Platform.kick, ChatProviderEventKind.host),
      providerEvent(Platform.kick, ChatProviderEventKind.support, id: 'kicks'),
    ]);
    expect(received.map((e) => e['type']),
        ['providerEvent', 'providerEvent', 'providerEvent', 'alert']);
    expect(connection.alerts.single['kind'], 'kicks');
  });

  test('featured cards bypass all disabled types for an alerts client',
      () async {
    connection.server.setSettings(const SettingsModel(alertDisabledTypes: [
      'superchat',
      'membership',
      'bits',
      'subscription',
      'gift',
      'raid',
      'kicks'
    ]));
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered.timeout(const Duration(seconds: 2));
    final alert = connection.nextAlert();
    connection.server.broadcastFeaturedMessage(message(Platform.twitch));
    expect(await alert, containsPair('kind', 'featured'));
  });

  test('new test alerts match real payload shapes even when disabled',
      () async {
    for (final language in ['en', 'es']) {
      connection.server.setSettings(SettingsModel(
          appLanguageCode: language,
          alertDisabledTypes: const [
            'bits',
            'subscription',
            'gift',
            'raid',
            'kicks'
          ]));
      for (final (testKind, kind, platform, membership, count) in [
        ('bits', 'bits', 'twitch', null, null),
        ('subscription', 'membership', 'kick', 'resubscription', null),
        ('gift', 'membership', 'twitch', 'gift', null),
        ('raid', 'raid', 'twitch', null, 42),
        ('kicks', 'kicks', 'kick', null, 100),
      ]) {
        final next = connection.nextAlert();
        expect(connection.server.broadcastTestAlert(testKind), isTrue);
        final alert = await next;
        expect(alert['kind'], kind);
        expect(alert['platform'], platform);
        expect(alert['membershipKind'], membership);
        expect(alert['count'], count);
        expect(alert['author'],
            language == 'es' ? 'Espectador de prueba' : 'Test viewer');
        expect(alert.keys.toSet(), {
          'alertType',
          'platform',
          'kind',
          'id',
          'author',
          'authorAvatarUrl',
          'authorChannelId',
          'badgeImageUrl',
          'badgeLabel',
          'message',
          'amount',
          'color',
          'stickerUrl',
          'timestamp',
          'membershipKind',
          'months',
          'giftCount',
          if (count != null) 'count',
        });
        if (testKind == 'bits') expect(alert['amount'], '100 Bits');
        if (testKind == 'subscription') expect(alert['months'], 6);
        if (testKind == 'gift') expect(alert['giftCount'], 5);
        if (testKind == 'kicks') expect(alert['message'], isNotEmpty);
      }
    }
  });
  test('automatic cards and grouped gifts carry their type and original fields',
      () async {
    for (final (msg, type) in [
      (
        message(Platform.youtube,
            payment: const SuperChat(amount: r'$5', color: '#FFD600')),
        'superchat'
      ),
      (
        message(Platform.youtube, membership: MembershipEventKind.subscription),
        'membership'
      ),
      (
        message(Platform.twitch,
            payment: const SuperChat(amount: '100 Bits', color: '#9146FF')),
        'bits'
      ),
      (
        message(Platform.twitch, membership: MembershipEventKind.subscription),
        'subscription'
      ),
      (
        message(Platform.kick,
            membership: MembershipEventKind.resubscription, months: 6),
        'subscription'
      ),
      (
        message(Platform.youtube,
            membership: MembershipEventKind.gift, gifts: 5),
        'gift'
      ),
      (
        message(Platform.kick, membership: MembershipEventKind.gift, gifts: 5),
        'gift'
      ),
      (message(Platform.twitch, membership: MembershipEventKind.gift), 'gift'),
    ]) {
      final next = connection.nextAlert();
      await connection.send(msg);
      final alert = await next;
      expect(alert['alertType'], type);
      expect(alert['id'], msg.id);
      expect(alert['platform'], msg.platform.name);
      expect(alert['author'], msg.author.name);
      expect(alert['amount'], msg.superChat?.amount);
      expect(alert['membershipKind'], msg.membershipEventKind?.name);
      expect(alert['months'], msg.membershipMonths);
      expect(
          alert['giftCount'],
          msg.platform == Platform.twitch && type == 'gift'
              ? 1
              : msg.membershipGiftCount);
      expect(alert['message'],
          msg.platform == Platform.twitch && type == 'gift' ? '' : 'Hello!');
    }
    for (final (platform, kind, type) in [
      (Platform.twitch, ChatProviderEventKind.raid, 'raid'),
      (Platform.kick, ChatProviderEventKind.host, 'raid'),
      (Platform.kick, ChatProviderEventKind.support, 'kicks'),
    ]) {
      final received = await sendProviders(
          [providerEvent(platform, kind, id: kind.name, count: 42)]);
      final alert = received.last['data'] as Map;
      expect(alert['alertType'], type);
      expect(alert['count'], 42);
      expect(alert['kind'],
          kind == ChatProviderEventKind.support ? 'kicks' : kind.name);
    }
  });

  test('all eight test cards have types and featured has null', () async {
    for (final kind in [
      'superchat',
      'superchat-empty',
      'membership',
      'bits',
      'subscription',
      'gift',
      'raid',
      'kicks'
    ]) {
      final next = connection.nextAlert();
      connection.server.broadcastTestAlert(kind);
      expect((await next)['alertType'],
          kind == 'superchat-empty' ? 'superchat' : kind);
    }
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered;
    final next = connection.nextAlert();
    final delivery =
        connection.server.broadcastFeaturedMessage(message(Platform.youtube));
    final alert = await next;
    expect(alert.containsKey('alertType'), isTrue);
    expect(alert['alertType'], isNull);
    expect(alert['deliveryId'], delivery.id);
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

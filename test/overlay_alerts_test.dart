import 'support/empty_template_library.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/rules/rule_actions.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/preview/sample_messages.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

import 'application/coordinator_fakes.dart';

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

  test('moderates viewer rule alerts in the queue, recent alerts and replays',
      () async {
    final server = connection.server;
    await connection.registerAcknowledgingAlerts();
    server.controlAlertQueue(AlertQueueOperation.pause);
    final audio =
        AudioCoordinator(tts: FakeTtsClient(), captions: FakeCaptionsClient());
    final obs = ObsCoordinator(obs: FakeObsClient());
    final queue = ChatQueueController();
    final giveaway = ChatGiveawayController();
    addTearDown(audio.dispose);
    addTearDown(obs.dispose);
    addTearDown(queue.dispose);
    addTearDown(giveaway.dispose);
    final actions = RuleActions(
      settings: () => const SettingsModel(),
      writeSettings: (_, depth) async {},
      obs: obs,
      audio: audio,
      giveaway: giveaway,
      queue: queue,
      server: () => server,
      feature: server.broadcastFeaturedMessage,
      draw: (_, depth) {},
    );
    final source = message(Platform.youtube, id: 'source-message');
    Future<void> emitAlert(String title, String text) async {
      final result = await actions.execute(
          {
            'type': 'alert.show',
            'title': title,
            'text': text,
            'mediaId': '',
            'seconds': 3,
          },
          RuleRun(
            id: 'test',
            rule: {},
            event: RuleEvent(type: 'chat.message', message: source),
            startedAt: source.timestamp,
            generation: 0,
          ));
      expect(result.status, 'done');
    }

    final next =
        connection.envelopes.stream.firstWhere((e) => e['type'] == 'alert');
    await emitAlert('From ${source.author.name}', source.plainText);
    final frame = await next;
    final data = frame['data'] as Map<String, dynamic>;
    expect(data['message'], source.plainText);
    final deliveryId = frame['alertDeliveryId'];
    expect(deliveryId, isA<int>());
    expect(data['sourceMessageId'], source.id);

    final moderation = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'moderation');
    server.broadcastModeration(ChatModerationEvent.message(
        platform: source.platform, messageId: source.id));
    final deleted = (await moderation)['data'];

    final recent = server.recentAlerts.skip(1).first;
    connection.socket!.sink
        .add(jsonEncode({'type': 'alertRendered', 'deliveryId': deliveryId}));
    final stored = (await recent).single;
    expect(stored['message'], isEmpty);
    expect(stored['title'], isEmpty);
    final replay = connection.nextAlert();
    expect(server.replayRecentAlert(stored['id'] as String), isTrue);
    expect((await replay)['message'], isEmpty);

    final rendered = connection.nextAlert(acknowledge: true);
    await emitAlert('Hello from chat', 'Welcome');
    final renderedId = (await rendered)['id'] as String;
    expect(renderedId, isNot(stored['id']));
    server.setSettings(const SettingsModel(blockedWords: ['hello']));
    expect(server.recentAlertsSnapshot.first['title'], isEmpty);
    expect(server.recentAlertsSnapshot.first['message'], isEmpty);
    final filteredReplay = connection.nextAlert();
    expect(server.replayRecentAlert(renderedId), isTrue);
    expect((await filteredReplay)['title'], isEmpty);

    final temp = await Directory.systemTemp.createTemp('alert-moderation-');
    addTearDown(() => temp.delete(recursive: true));
    final script = File('${temp.path}/test.js');
    final page = alertsOverlayHtml()
        .split('<script>')
        .last
        .split('applySettings(DEFAULT_SETTINGS);')
        .first;
    final checks = '''
  queue.push(${jsonEncode(data)});
  redactModeratedAlerts(${jsonEncode(deleted)});
  assert.equal(queue[0].message, '');
  assert.equal(queue[0].title, '');
  queue[0] = ${jsonEncode(data)};
  applyAlertFilters({users: [], words: ['hello']});
  assert.equal(queue[0].message, '');
  assert.equal(queue[0].title, '');
''';
    await script.writeAsString('''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const node = {appendChild() {}};
vm.runInNewContext(${jsonEncode('$page\n$checks')}, {
  assert,
  window: {addEventListener() {}},
  document: {getElementById: () => node, createElement: () => ({})},
});
''');
    final nodeResult = await Process.run('node', [script.path]);
    expect(nodeResult.exitCode, 0,
        reason: '${nodeResult.stdout}\n${nodeResult.stderr}');
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
    final alert =
        connection.nextAlert(timeout: const Duration(milliseconds: 300));
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
      connection.nextAlert(timeout: const Duration(milliseconds: 30)),
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
    await expectLater(
        connection.nextAlert(timeout: const Duration(milliseconds: 130)),
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
    await expectLater(
        connection.nextAlert(timeout: const Duration(milliseconds: 130)),
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
          {String id = 'provider',
          String authorChannelId = '',
          int? count,
          String text = ''}) =>
      ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: id,
        timestamp: DateTime.utc(2026, 11, 15),
        authorName: 'Ana',
        authorChannelId: authorChannelId,
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
          authorChannelId: 'ana', count: 42, text: 'System message'),
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
      'authorChannelId': 'ana',
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

  test('style preview samples never become support alerts', () async {
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered;
    // The chat style preview's Super Chat sample.
    await connection.send(message(Platform.youtube,
        id: '${previewMessagePrefix}5',
        payment: const SuperChat(amount: r'$5.00', color: '#1DE9B6')));
    expect(connection.alerts, isEmpty);
    expect(connection.server.recentAlertsSnapshot, isEmpty);
    // A real one still goes out.
    final real = connection.nextAlert();
    await connection.send(message(Platform.youtube,
        id: 'real', payment: const SuperChat(amount: r'$5', color: '#FFD600')));
    expect(await real, containsPair('kind', 'superchat'));
  });

  test('platform filtering blocks automatic history and delivery only',
      () async {
    await connection.registerAcknowledgingAlerts();
    final automatic = connection.nextAlert(acknowledge: true);
    await connection.send(message(Platform.youtube,
        payment: const SuperChat(amount: r'$5', color: '#FFD600')));
    final recent = await automatic;

    connection.server.setSettings(const SettingsModel(alertPlatforms: {}));
    await connection.send(message(Platform.youtube,
        id: 'blocked',
        payment: const SuperChat(amount: r'$5', color: '#FFD600')));
    await connection
        .send(message(Platform.twitch, membership: MembershipEventKind.gift));
    final received = await sendProviders([
      providerEvent(Platform.kick, ChatProviderEventKind.support, count: 100),
    ]);
    expect(received.where((e) => e['type'] == 'alert'), isEmpty);
    expect(connection.server.recentAlertsSnapshot, [recent]);
    expect(connection.alerts, [recent]);

    final rule = connection.nextAlert();
    expect(
        connection.server
            .broadcastRuleAlert(title: 'Rule', text: 'Hello', seconds: 3),
        isTrue);
    expect(await rule, containsPair('kind', 'custom'));
    final testAlert = connection.nextAlert();
    expect(connection.server.broadcastTestAlert('superchat'), isTrue);
    expect(await testAlert, containsPair('kind', 'superchat'));
    final replay = connection.nextAlert();
    expect(connection.server.replayRecentAlert(recent['id'] as String), isTrue);
    expect(await replay, recent);
    expect(connection.server.recentAlertsSnapshot, [recent]);
  });

  test(
      'server resolves currency units, counts and grouped gifts into alert data',
      () async {
    await connection.registerAcknowledgingAlerts();
    connection.server.setSettings(const SettingsModel(alertTypeOptions: {
      'superchat': {
        'sound': 'coin',
        'tiers': [
          {'from': 5.5, 'animation': 'zoom'}
        ],
      },
      'bits': {
        'tiers': [
          {'from': 100, 'seconds': 12}
        ]
      },
      'kicks': {
        'tiers': [
          {'from': 25, 'animation': 'fade'}
        ]
      },
      'gift': {
        'tiers': [
          {'from': 2, 'animation': 'pop'}
        ]
      },
    }));
    for (final (msg, option) in [
      (
        message(Platform.youtube,
            payment: const SuperChat(amount: 'EUR 5,50', color: '#FFD600')),
        {'sound': 'coin', 'animation': 'zoom'}
      ),
      (
        message(Platform.twitch,
            payment: const SuperChat(amount: '100 Bits', color: '#9146FF')),
        {'seconds': 12}
      ),
    ]) {
      final next = connection.nextAlert();
      await connection.send(msg);
      expect((await next)['option'], option);
    }
    final nextGift = connection.nextAlert(acknowledge: true);
    await connection.send(message(Platform.twitch,
        id: 'gift1', membership: MembershipEventKind.gift));
    await connection.send(message(Platform.twitch,
        id: 'gift2', membership: MembershipEventKind.gift));
    final gift = await nextGift;
    expect(gift['giftCount'], 2);
    expect(gift['option'], {'animation': 'pop'});
    final kicks = await sendProviders([
      providerEvent(Platform.kick, ChatProviderEventKind.support, count: 25),
    ]);
    expect(kicks.last['data']['option'], {'animation': 'fade'});
    final replay = connection.nextAlert();
    connection.server.setSettings(const SettingsModel());
    expect(connection.server.replayRecentAlert(gift['id'] as String), isTrue);
    expect((await replay)['option'], gift['option']);
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
    await expectLater(
        connection.nextAlert(timeout: const Duration(milliseconds: 150)),
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
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered;
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
    final registered = connection.envelopes.stream
        .firstWhere((e) => e['type'] == 'registered');
    connection.socket!.sink
        .add(jsonEncode({'type': 'register', 'view': 'alerts'}));
    await registered;
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
    final next = connection.nextAlert();
    final delivery =
        connection.server.broadcastFeaturedMessage(message(Platform.youtube));
    final alert = await next;
    expect(alert.containsKey('alertType'), isTrue);
    expect(alert['alertType'], isNull);
    expect(alert['deliveryId'], delivery.id);
  });
  test('sound settings never expose local paths and keys change with paths',
      () async {
    Future<Map<String, dynamic>> update(String path) async {
      final next = connection.envelopes.stream
          .firstWhere((e) => e['type'] == 'settings');
      connection.server.setSettings(SettingsModel(alertTypeOptions: {
        'raid': {'sound': 'custom', 'soundPath': path},
        'bits': {'sound': 'coin', 'soundPath': 'ignored-private.mp3'},
      }));
      return (await next)['data'] as Map<String, dynamic>;
    }

    final first = await update('private-a.wav');
    final second = await update('private-b.wav');
    expect(jsonEncode(first), isNot(contains('soundPath')));
    expect(jsonEncode(first), isNot(contains('private-a.wav')));
    expect(first['alertSoundVolume'], 70);
    expect(first['alertTypeOptions']['bits'], {'sound': 'coin'});
    expect(first['alertTypeOptions']['raid']['soundKey'], isA<String>());
    expect(first['alertTypeOptions']['raid']['soundKey'],
        isNot(second['alertTypeOptions']['raid']['soundKey']));
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

  Future<void> registerAcknowledgingAlerts() async {
    final registered =
        envelopes.stream.firstWhere((e) => e['type'] == 'registered');
    socket!.sink.add(jsonEncode({
      'type': 'register',
      'view': 'alerts',
      'alertDisplayAck': true,
    }));
    await registered;
  }

  Future<Map<String, dynamic>> nextAlert({
    Duration timeout = const Duration(seconds: 2),
    bool acknowledge = false,
  }) async {
    final event = await envelopes.stream
        .where((e) => e['type'] == 'alert')
        .timeout(timeout)
        .first;
    if (acknowledge) {
      final id = event['alertDeliveryId'];
      expect(id, isA<int>());
      final recorded = server.recentAlerts.skip(1).first;
      socket!.sink.add(jsonEncode({'type': 'alertRendered', 'deliveryId': id}));
      await recorded.timeout(timeout);
    }
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

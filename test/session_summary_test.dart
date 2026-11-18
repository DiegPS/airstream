import 'package:airstream/application/session_summary.dart';
import 'package:airstream/l10n/generated/app_localizations_en.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/support_alert.dart';
import 'package:airstream/ui/widgets/session_summary_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

var _next = 0;

ChatMessage _chat(
  String author, {
  Platform platform = Platform.twitch,
  bool owner = false,
  SuperChat? superChat,
  bool membership = false,
  MembershipEventKind? kind,
  int? months,
  int? gifts,
  DateTime? at,
}) =>
    ChatMessage(
      platform: platform,
      id: 'm${_next++}',
      author: ChatAuthor(name: author, channelId: author.toLowerCase()),
      items: const [MessageItem.text('hola')],
      isOwner: owner,
      superChat: superChat,
      isMembershipEvent: membership,
      membershipEventKind: kind,
      membershipMonths: months,
      membershipGiftCount: gifts,
      timestamp: at ?? DateTime.utc(2026, 11, 15),
    );

void main() {
  test('counts messages, viewers and the most active between start and stop',
      () {
    var now = DateTime.utc(2026, 11, 15, 20);
    final collector = SessionSummaryCollector(clock: () => now);
    collector.handleMessage(_chat('Before')); // Not started yet.
    collector.start();
    for (var i = 0; i < 3; i++) {
      collector.handleMessage(_chat('Ana'));
    }
    collector
      ..handleMessage(_chat('Beto'))
      ..handleMessage(_chat('Ana', platform: Platform.kick))
      ..handleMessage(_chat('Streamer', owner: true));
    now = now.add(const Duration(hours: 1, minutes: 23));
    collector.stop();
    collector.handleMessage(_chat('After')); // Stopped.

    final summary = collector.summary;
    expect(summary.messages, 5);
    expect(summary.messagesByPlatform, {Platform.twitch: 4, Platform.kick: 1});
    expect(summary.chatters, 3);
    expect(summary.topChatters.first.name, 'Ana');
    expect(summary.topChatters.first.messages, 3);
    expect(summary.duration(now.add(const Duration(hours: 5))),
        const Duration(hours: 1, minutes: 23),
        reason: 'the summary freezes when the chat stops');
  });

  test('lists every kind of support once', () {
    final collector = SessionSummaryCollector()..start();
    collector
      ..handleMessage(_chat('Donador',
          platform: Platform.youtube,
          superChat: const SuperChat(amount: r'$5.00', color: '#1DE9B6')))
      ..handleMessage(_chat('Miembro',
          platform: Platform.youtube,
          membership: true,
          kind: MembershipEventKind.subscription))
      ..handleMessage(_chat('Fiel',
          membership: true,
          kind: MembershipEventKind.resubscription,
          months: 12))
      ..handleMessage(_chat('Generoso',
          platform: Platform.kick,
          membership: true,
          kind: MembershipEventKind.gift,
          gifts: 5))
      ..handleMessage(_chat('Regalona',
          platform: Platform.youtube,
          membership: true,
          kind: MembershipEventKind.gift,
          gifts: 3))
      // Bits are paid messages too, but not Super Chats.
      ..handleMessage(_chat('Animador',
          platform: Platform.twitch,
          superChat: const SuperChat(amount: '100 Bits', color: '#9146FF')));
    final raid = ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.raid,
      id: 'raid-1',
      timestamp: DateTime.utc(2026, 11, 15),
      authorName: 'Amigo',
      count: 40,
    );
    collector
      ..handleProviderEvent(raid)
      ..handleProviderEvent(raid) // Delivered twice.
      ..handleProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.poll,
        id: 'poll',
        timestamp: DateTime.utc(2026, 11, 15),
        authorName: 'x',
      ));

    final l = AppLocalizationsEn();
    expect(
      collector.summary.supporters.map((s) => sessionSupporterText(l, s)),
      [
        r'Donador sent a Super Chat of $5.00',
        'Miembro became a member',
        'Fiel: 12 months subscribed',
        'Generoso gifted 5 subscriptions',
        'Regalona gifted 3 memberships',
        'Animador cheered 100 Bits',
        'Amigo raided with 40 viewers',
      ],
    );
    expect(collector.summary.messages, 2,
        reason: 'membership events are support; the Bits message is chat');
  });

  test('uses alert types, support values and session-wide reconnect dedupe',
      () {
    final collector = SessionSummaryCollector()..start();
    final messages = [
      (
        'superchat',
        _chat('Donor',
            platform: Platform.youtube,
            superChat: const SuperChat(amount: r'MX$1.234,50', color: ''))
      ),
      (
        'membership',
        _chat('Member',
            platform: Platform.youtube, membership: true, months: 12)
      ),
      (
        'bits',
        _chat('Cheerer',
            superChat: const SuperChat(amount: '250 Bits', color: ''))
      ),
      (
        'subscription',
        _chat('Subscriber',
            platform: Platform.kick,
            membership: true,
            kind: MembershipEventKind.resubscription)
      ),
      (
        'gift',
        _chat('Gifter',
            membership: true, kind: MembershipEventKind.gift, gifts: 5)
      ),
    ];
    for (final (type, msg) in messages) {
      expect(
          supportAlertType(
              messageAlertKind(msg)!, msg.platform, msg.membershipEventKind),
          type);
      expect(collector.handleMessage(msg), true);
      expect(collector.handleMessage(msg), false);
    }
    final events = [
      (
        'raid',
        _provider(Platform.twitch, ChatProviderEventKind.raid, 'Raider', 120)
      ),
      (
        'raid',
        _provider(Platform.kick, ChatProviderEventKind.host, 'Host', 40)
      ),
      (
        'kicks',
        _provider(Platform.kick, ChatProviderEventKind.support, 'Kicker', 95)
      ),
    ];
    for (final (type, event) in events) {
      expect(supportAlertType(providerAlertKind(event)!, event.platform, null),
          type);
      expect(collector.handleProviderEvent(event), true);
      expect(collector.handleProviderEvent(event), false);
    }
    collector.handleMessage(_chat('Owner', owner: true));
    final state = collector.templateState(live: true)!;
    expect(state['messages'], 2);
    expect(state['chatters'], 2);
    expect(state['supporterCount'], 8);
    expect(state['superchatCounts'], {r'MX$': 1});
    expect(state['topChatters'], [
      {'platform': 'youtube', 'name': 'Donor', 'messages': 1},
      {'platform': 'twitch', 'name': 'Cheerer', 'messages': 1},
    ]);
    final supporters = (state['supporters'] as List).cast<Map>();
    expect(supporters.map((s) => s['id']).toSet(), hasLength(8));
    expect(supporters.map((s) => s['type']), [
      ...events.reversed.map((e) => e.$1),
      ...messages.reversed.map((e) => e.$1)
    ]);
    expect(supporters.map((s) => s['value']),
        [95, 40, 120, null, null, 250, null, 1234.5]);
    final latest = state['latest'] as Map;
    expect(latest['superchat'], containsPair('currency', r'MX$'));
    expect(latest['superchat'], containsPair('amount', r'MX$1.234,50'));
    expect(latest['membership'], containsPair('months', 12));
    expect(latest['gift'], containsPair('count', 5));
    expect(latest['raid'], containsPair('count', 40));
    expect(latest['kicks'], containsPair('count', 95));
    expect(latest['superchat'], containsPair('at', '2026-11-15T00:00:00.000Z'));
    expect(
        collector.summary.supporters.where((s) => s.name == 'Host'), isEmpty);
    collector.stop();
    expect(collector.templateState(live: false), {
      ...state,
      'live': false,
      'endedAt': collector.summary.endedAt!.toUtc().toIso8601String(),
    });
    collector.start();
    expect(collector.templateState(live: false)!['supporters'], isEmpty);
  });

  test('ranks all support separately and breaks ties by earliest timestamp',
      () {
    final collector = SessionSummaryCollector()..start();
    final early = DateTime.utc(2026, 11, 15);
    final late = early.add(const Duration(minutes: 1));
    for (final (person, time, units) in [
      ('Later', late, 5),
      ('Earlier', early, 2),
      ('Earlier', late, 3)
    ]) {
      collector
        ..handleMessage(_chat(person,
            at: time,
            membership: true,
            kind: MembershipEventKind.gift,
            gifts: units))
        ..handleMessage(_chat(person,
            at: time, superChat: SuperChat(amount: '$units Bits', color: '')))
        ..handleMessage(_chat(person,
            at: time,
            platform: Platform.youtube,
            superChat: SuperChat(amount: '\$$units.00', color: '')))
        ..handleProviderEvent(_provider(
            Platform.kick, ChatProviderEventKind.support, person, units,
            at: time));
    }
    collector.handleMessage(_chat('Later',
        at: early,
        platform: Platform.youtube,
        superChat: const SuperChat(amount: r'MX$900.00', color: '')));
    for (var i = 0; i < 10; i++) {
      collector.handleMessage(_chat('Cheerer $i',
          superChat: const SuperChat(amount: '1 Bits', color: '')));
    }
    final state = collector.templateState(live: true)!;
    final top = state['top'] as Map;
    List<Map<String, Object>> tie(String platform) => [
          {'platform': platform, 'name': 'Earlier', 'value': 5},
          {'platform': platform, 'name': 'Later', 'value': 5},
        ];
    expect((top['bits'] as List).take(2), tie('twitch'));
    expect(top['bits'], hasLength(5));
    expect(top['gift'], tie('twitch'));
    expect(top['kicks'], tie('kick'));
    expect(top['superchat'], {
      r'$': tie('youtube'),
      r'MX$': [
        {'platform': 'youtube', 'name': 'Later', 'value': 900}
      ],
    });
    expect(state['topChatters'], hasLength(10));
  });

  test('keeps the newest fifty while latest includes older support', () {
    final collector = SessionSummaryCollector()..start();
    final oldest = _provider(
        Platform.twitch, ChatProviderEventKind.raid, 'Raider', 10,
        at: DateTime.utc(2026, 11, 14));
    collector.handleProviderEvent(oldest);
    for (var i = 0; i < 55; i++) {
      collector.handleMessage(_chat('Viewer $i',
          membership: true, kind: MembershipEventKind.subscription));
    }
    final state = collector.templateState(live: true)!;
    final supporters = (state['supporters'] as List).cast<Map>();
    expect(supporters.map((s) => s['name']),
        List.generate(50, (i) => 'Viewer ${54 - i}'));
    expect(state['supporterCount'], 56);
    expect((state['latest'] as Map)['raid'], containsPair('name', 'Raider'));
    expect((state['latest'] as Map)['kicks'], isNull);
  });

  test('starting again begins a new summary', () {
    final collector = SessionSummaryCollector()..start();
    collector.handleMessage(_chat('Ana'));
    collector.stop();
    collector.start();
    expect(collector.summary.isEmpty, isTrue);
  });

  test('template state freezes the end time until the next start', () {
    var now = DateTime.utc(2026, 11, 17, 16);
    final collector = SessionSummaryCollector(clock: () => now)..start();
    expect(collector.templateState(live: true)!['endedAt'], isNull);
    expect(collector.templateState(live: false)!['endedAt'], isNull);

    now = now.add(const Duration(minutes: 30));
    collector.stop();
    now = now.add(const Duration(minutes: 5));
    collector.stop();
    expect(collector.templateState(live: false)!['endedAt'],
        '2026-11-17T16:30:00.000Z');

    collector.start();
    final next = collector.templateState(live: true)!;
    expect(next['startedAt'], '2026-11-17T16:35:00.000Z');
    expect(next['endedAt'], isNull);
  });

  test('the copied summary reads as plain text', () {
    final start = DateTime.utc(2026, 11, 15, 20);
    final collector = SessionSummaryCollector(clock: () => start)..start();
    collector
      ..handleMessage(_chat('Ana'))
      ..handleMessage(_chat('Ana'))
      ..handleMessage(_chat('Beto', platform: Platform.youtube));
    final text = sessionSummaryText(
      AppLocalizationsEn(),
      collector.summary,
      start.add(const Duration(minutes: 42)),
    );
    expect(text, contains('42 min · 3 messages · 2 viewers wrote'));
    expect(text, contains('1. Ana (Twitch) — 2 messages'));
    expect(text, isNot(contains('Support')));
  });
}

ChatProviderEvent _provider(
        Platform platform, ChatProviderEventKind kind, String name, int count,
        {DateTime? at}) =>
    ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: 'e${_next++}',
        timestamp: at ?? DateTime.utc(2026, 11, 15),
        authorName: name,
        count: count);

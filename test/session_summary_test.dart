import 'package:airstream/application/session_summary.dart';
import 'package:airstream/l10n/generated/app_localizations_en.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
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
      timestamp: DateTime.utc(2026, 11, 15),
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
          gifts: 5));
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
        'Amigo raided with 40 viewers',
      ],
    );
    expect(collector.summary.messages, 1,
        reason: 'membership events are support, not chat messages');
  });

  test('starting again begins a new summary', () {
    final collector = SessionSummaryCollector()..start();
    collector.handleMessage(_chat('Ana'));
    collector.stop();
    collector.start();
    expect(collector.summary.isEmpty, isTrue);
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

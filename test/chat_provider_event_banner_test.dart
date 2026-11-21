import 'dart:async';

import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/ui/widgets/chat_provider_event_banner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a disabled event kind keeps the banner showing the enabled one', () {
    ChatProviderEvent event(ChatProviderEventKind kind) => ChatProviderEvent(
        platform: Platform.kick,
        kind: kind,
        id: kind.name,
        timestamp: DateTime.utc(2026, 11, 20));
    final poll = event(ChatProviderEventKind.poll);
    final support = event(ChatProviderEventKind.support);
    const kinds = ['poll'];
    expect(bannerProviderEvent(poll, null, kinds), same(poll));
    // A Kicks gift (support banners off) must not unmount the poll banner.
    expect(bannerProviderEvent(support, poll, kinds), same(poll));
    expect(bannerProviderEvent(support, null, kinds), isNull);
    // Turning poll banners off drops the poll event.
    expect(bannerProviderEvent(support, poll, const ['raid']), isNull);
  });

  testWidgets('shows localized provider event details without raw payload keys',
      (tester) async {
    final event = ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.roomState,
      id: 'roomstate:1',
      timestamp: DateTime.utc(2026, 9, 7),
      data: const {
        'emoteOnly': true,
        'followersOnlyMinutes': 10,
        'slowModeSeconds': 5,
      },
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChatProviderEventBanner(event: event)),
    ));

    expect(
      find.textContaining('Configuración del chat actualizada'),
      findsOneWidget,
    );
    expect(find.textContaining('Solo emotes'), findsOneWidget);
    expect(find.textContaining('Seguidores 10 min'), findsOneWidget);
    expect(find.textContaining('Modo lento 5 s'), findsOneWidget);
    expect(find.textContaining('followersOnlyMinutes'), findsNothing);
  });

  testWidgets('truncates long event detail instead of overflowing',
      (tester) async {
    final event = ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.notice,
      id: 'notice',
      timestamp: DateTime.utc(2026, 9, 7),
      text: 'A' * 500,
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 240,
          child: ChatProviderEventBanner(event: event),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(
      find.byKey(const Key('chat-provider-event-kick')),
    );
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('renders Kick poll choices and goal progress', (tester) async {
    final poll = ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.poll,
      id: 'poll',
      timestamp: DateTime.utc(2026),
      text: 'Choose one',
      data: const {
        'options': [
          {'label': 'One', 'votes': 3},
          {'label': 'Two', 'votes': 5},
        ],
      },
    );
    await tester.pumpWidget(_app(ChatProviderEventBanner(event: poll)));
    expect(find.textContaining('Choose one'), findsOneWidget);
    expect(find.textContaining('One (3)'), findsOneWidget);
    expect(find.textContaining('Two (5)'), findsOneWidget);

    final goal = ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.goal,
      id: 'goal',
      timestamp: DateTime.utc(2026),
      text: 'Subscriptions',
      data: const {'current': 8, 'target': 10},
    );
    await tester.pumpWidget(_app(ChatProviderEventBanner(event: goal)));
    expect(find.textContaining('8 / 10'), findsOneWidget);
  });

  testWidgets('labels KICK gifts as support instead of rewards',
      (tester) async {
    final event = ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.support,
      id: 'gift',
      timestamp: DateTime.utc(2026),
      authorName: 'supporter',
      text: 'Hell Yeah',
      count: 3,
    );
    await tester.pumpWidget(_app(ChatProviderEventBanner(event: event)));

    expect(find.textContaining('Apoyo'), findsOneWidget);
    expect(find.textContaining('supporter · Hell Yeah · 3'), findsOneWidget);
  });

  testWidgets('labels watch streaks and hides them after their lifetime',
      (tester) async {
    final event = ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.watchStreak,
      id: 'streak',
      timestamp: DateTime.utc(2026),
      authorName: 'Viewer',
      count: 7,
    );

    await tester.pumpWidget(
      _app(
        TransientChatProviderEventBanner(
          event: event,
          visibleDuration: const Duration(seconds: 2),
        ),
      ),
    );
    expect(find.textContaining('Racha de visualización'), findsOneWidget);
    expect(find.textContaining('Viewer · 7'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ChatProviderEventBanner), findsNothing);
  });

  testWidgets('does not duplicate an event already rendered as a message',
      (tester) async {
    final event = ChatProviderEvent(
      platform: Platform.twitch,
      kind: ChatProviderEventKind.notice,
      id: 'resub',
      timestamp: DateTime.utc(2026),
      data: const {'duplicatesMessage': true},
    );

    await tester.pumpWidget(
      _app(TransientChatProviderEventBanner(event: event)),
    );

    expect(find.byType(ChatProviderEventBanner), findsNothing);
  });

  testWidgets('a burst of events shows each one in turn', (tester) async {
    ChatProviderEvent event(String id, String author) => ChatProviderEvent(
          platform: Platform.twitch,
          kind: ChatProviderEventKind.raid,
          id: id,
          timestamp: DateTime.utc(2026),
          authorName: author,
          count: 10,
        );
    Widget banner(ChatProviderEvent e) => _app(
          TransientChatProviderEventBanner(
            event: e,
            visibleDuration: const Duration(seconds: 2),
          ),
        );

    await tester.pumpWidget(banner(event('raid-1', 'FirstRaider')));
    await tester.pumpWidget(banner(event('raid-2', 'SecondRaider')));
    await tester.pumpAndSettle();
    expect(find.textContaining('FirstRaider'), findsOneWidget);
    expect(find.textContaining('SecondRaider'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('FirstRaider'), findsNothing);
    expect(find.textContaining('SecondRaider'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ChatProviderEventBanner), findsNothing);
  });

  testWidgets('turning a banner kind off drops its waiting events',
      (tester) async {
    final raid = ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.utc(2026),
        authorName: 'Raider',
        count: 10);
    final poll = ChatProviderEvent(
        platform: Platform.kick,
        kind: ChatProviderEventKind.poll,
        id: 'poll',
        timestamp: DateTime.utc(2026),
        text: 'Waiting poll');
    final host = ChatProviderEvent(
        platform: Platform.kick,
        kind: ChatProviderEventKind.host,
        id: 'host',
        timestamp: DateTime.utc(2026),
        authorName: 'Hoster');
    Widget banner(ChatProviderEvent e, List<String> kinds) =>
        _app(TransientChatProviderEventBanner(
          event: e,
          settings: SettingsModel(providerEventBannerKinds: kinds),
          visibleDuration: const Duration(seconds: 2),
        ));
    const all = ['raid', 'poll', 'host'];
    await tester.pumpWidget(banner(raid, all));
    await tester.pumpWidget(banner(poll, all));
    await tester.pumpWidget(banner(host, all));
    // Poll banners turned off while the poll waits behind the raid.
    await tester.pumpWidget(banner(host, const ['raid', 'host']));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Waiting poll'), findsNothing);
    expect(find.textContaining('Hoster'), findsOneWidget);
  });

  testWidgets('Kick poll updates replace and deletions remove the same poll',
      (tester) async {
    ChatProviderEvent poll(String id, int votes, {bool deleted = false}) =>
        ChatProviderEvent(
          platform: Platform.kick,
          kind: ChatProviderEventKind.poll,
          id: id,
          timestamp: DateTime.utc(2026),
          data: deleted
              ? const {'deleted': true}
              : {
                  'options': [
                    {'label': 'Yes', 'votes': votes},
                  ],
                },
        );
    Future<void> show(ChatProviderEvent e) =>
        tester.pumpWidget(_app(TransientChatProviderEventBanner(
          event: e,
          visibleDuration: const Duration(seconds: 2),
        )));

    await show(poll('poll-1', 1));
    expect(find.textContaining('Yes (1)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await show(poll('poll-1', 5));
    await tester.pump();
    expect(find.textContaining('Yes (5)'), findsOneWidget);
    expect(find.textContaining('Yes (1)'), findsNothing);
    // The update keeps the card's remaining time instead of restarting it.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(ChatProviderEventBanner), findsNothing);

    // A queued poll takes its newest counts, and a deletion removes it.
    await show(poll('poll-2', 1));
    await show(poll('poll-3', 2));
    await show(poll('poll-3', 9));
    await show(poll('poll-2', 0, deleted: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yes (9)'), findsOneWidget);
    await show(poll('poll-3', 0, deleted: true));
    await tester.pumpAndSettle();
    expect(find.byType(ChatProviderEventBanner), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deleted, banned and unpinned pins leave the banner',
      (tester) async {
    final moderation = StreamController<ChatModerationEvent>.broadcast();
    addTearDown(moderation.close);
    ChatProviderEvent pin(String id, String text,
            {Platform platform = Platform.kick}) =>
        ChatProviderEvent(
          platform: platform,
          kind: ChatProviderEventKind.pinnedMessage,
          id: id,
          timestamp: DateTime.utc(2026),
          authorName: 'Writer $id',
          authorChannelId: 'writer-$id',
          text: text,
        );
    final raid = ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.utc(2026),
        authorName: 'Raider');
    Future<void> show(ChatProviderEvent e, [List<String>? kinds]) =>
        tester.pumpWidget(_app(TransientChatProviderEventBanner(
          event: e,
          settings: kinds == null
              ? const SettingsModel()
              : SettingsModel(providerEventBannerKinds: kinds),
          moderationEvents: moderation.stream,
          visibleDuration: const Duration(seconds: 2),
        )));
    Future<void> expire() async {
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    // A pin waiting behind a raid is deleted before it comes up.
    await show(raid);
    await show(pin('deleted', 'Deleted pin'));
    moderation.add(const ChatModerationEvent.message(
        platform: Platform.kick, messageId: 'deleted'));
    await tester.pump();
    await expire();
    expect(find.textContaining('Deleted pin'), findsNothing);
    expect(find.byType(ChatProviderEventBanner), findsNothing);

    // A visible pin leaves when its author is banned.
    await show(pin('banned', 'Banned pin'));
    expect(find.textContaining('Banned pin'), findsOneWidget);
    moderation.add(const ChatModerationEvent.author(
        platform: Platform.kick, authorChannelId: 'writer-banned'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('Banned pin'), findsNothing);

    // An unpin takes the old Kick pin away even with unpin banners off.
    await show(pin('old', 'Old pin'));
    expect(find.textContaining('Old pin'), findsOneWidget);
    await show(
        ChatProviderEvent(
            platform: Platform.kick,
            kind: ChatProviderEventKind.unpinnedMessage,
            id: 'old',
            timestamp: DateTime.utc(2026)),
        const ['pinnedMessage', 'raid']);
    await tester.pumpAndSettle();
    expect(find.textContaining('Old pin'), findsNothing);
    expect(find.byType(ChatProviderEventBanner), findsNothing);

    // A new Kick pin replaces a waiting older one.
    await show(raid);
    await show(pin('first', 'First pin'));
    await show(pin('second', 'Second pin'));
    await expire();
    expect(find.textContaining('First pin'), findsNothing);
    expect(find.textContaining('Second pin'), findsOneWidget);
    await expire();
    expect(
        bannerProviderEvent(
            ChatProviderEvent(
                platform: Platform.kick,
                kind: ChatProviderEventKind.unpinnedMessage,
                id: 'x',
                timestamp: DateTime.utc(2026)),
            null,
            const ['raid'])?.kind,
        ChatProviderEventKind.unpinnedMessage);
  });

  testWidgets('block changes remove visible and queued provider events',
      (tester) async {
    ChatProviderEvent event(String author, String text) => ChatProviderEvent(
          platform: Platform.kick,
          kind: ChatProviderEventKind.reward,
          id: author,
          timestamp: DateTime.utc(2026),
          authorName: author,
          text: text,
        );
    Future<void> show(ChatProviderEvent value,
            [SettingsModel settings = const SettingsModel()]) =>
        tester.pumpWidget(_app(TransientChatProviderEventBanner(
          event: value,
          settings: settings,
          visibleDuration: const Duration(seconds: 2),
        )));

    final allowed = event('AllowedViewer', 'Hello');
    await show(event('BlockedViewer', 'Goodbye'));
    await show(event('OtherViewer', 'hidden phrase'));
    await show(allowed);
    expect(find.textContaining('BlockedViewer'), findsOneWidget);

    await show(
      allowed,
      const SettingsModel(
        blockedUsers: ['@BlockedViewer'],
        blockedWords: ['hidden phrase'],
      ),
    );
    expect(find.textContaining('BlockedViewer'), findsNothing);
    expect(find.textContaining('hidden phrase'), findsNothing);
    expect(find.textContaining('AllowedViewer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ChatProviderEventBanner), findsNothing);
  });
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

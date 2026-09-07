import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/ui/widgets/chat_provider_event_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

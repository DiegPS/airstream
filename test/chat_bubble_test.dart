import 'package:airstream/models/chat_message.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/chat_alignment.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps chat position to horizontal alignment', () {
    expect(chatHorizontalAlignment('left'), Alignment.centerLeft);
    expect(chatHorizontalAlignment('center'), Alignment.center);
    expect(chatHorizontalAlignment('right'), Alignment.centerRight);
  });

  testWidgets(
      'uses available chat width, aligns right, and does not duplicate emojis',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(
        chatTextAlign: 'right',
        chatMaxMessageWidth: 0.5,
        chatTextStroke: 2,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: ChatBubble(message: _message()),
            ),
          ),
        ),
      ),
    );

    final bubbleConstraint = tester
        .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .map((widget) => widget.constraints.maxWidth)
        .where((width) => width.isFinite)
        .singleWhere((width) => width == 250);
    expect(bubbleConstraint, 250);

    expect(
      tester.widgetList<Align>(find.byType(Align)).any(
            (widget) => widget.alignment == Alignment.centerRight,
          ),
      isTrue,
    );
    expect(find.text(':wave:'), findsOneWidget);
  });

  testWidgets('localizes built-in badges and membership events to Spanish',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(showBadges: true),
    );
    final message = ChatMessage(
      platform: Platform.youtube,
      id: 'membership',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: const [],
      isOwner: true,
      isMembership: true,
      isMembershipEvent: true,
      timestamp: DateTime.utc(2026, 6, 10),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: message)),
        ),
      ),
    );

    expect(find.text('DUEÑO'), findsOneWidget);
    expect(find.text('Actualización de membresía'), findsOneWidget);
    expect(find.text('OWNER'), findsNothing);
    expect(find.text('Membership update'), findsNothing);
  });
}

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(SettingsModel settings) {
    state = settings;
  }
}

ChatMessage _message() {
  return ChatMessage(
    platform: Platform.youtube,
    id: 'message',
    author: const ChatAuthor(
      name: 'Tester',
      channelId: 'tester',
    ),
    items: const [
      MessageItem.text('Hello '),
      MessageItem.emoji(EmojiItem(url: '', alt: ':wave:')),
    ],
    timestamp: DateTime.utc(2026, 6, 10),
  );
}

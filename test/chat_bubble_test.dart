import 'package:airstream/models/chat_message.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/chat_alignment.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
import 'package:airstream/ui/widgets/author_avatar.dart';
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
    final avatar = tester.element(find.byType(AuthorAvatar));
    final messageRow = avatar.findAncestorWidgetOfExactType<Row>()!;
    expect(messageRow.children.last, isA<AuthorAvatar>());
    expect(find.text(':wave:'), findsOneWidget);
  });

  testWidgets('keeps the avatar before content when alignment is left',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(chatTextAlign: 'left'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: _message())),
        ),
      ),
    );

    final avatar = tester.element(find.byType(AuthorAvatar));
    final messageRow = avatar.findAncestorWidgetOfExactType<Row>()!;
    expect(messageRow.children.first, isA<AuthorAvatar>());
  });

  testWidgets('keeps the avatar before content when alignment is centered',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(chatTextAlign: 'center'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: _message())),
        ),
      ),
    );

    final avatar = tester.element(find.byType(AuthorAvatar));
    final messageRow = avatar.findAncestorWidgetOfExactType<Row>()!;
    expect(messageRow.children.first, isA<AuthorAvatar>());
  });

  testWidgets('right alignment renders no avatar spacing when avatars are off',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(
        chatTextAlign: 'right',
        showAvatars: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: _message())),
        ),
      ),
    );

    expect(find.byType(AuthorAvatar), findsNothing);
    expect(find.text('Tester'), findsOneWidget);
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
      isVerified: true,
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
    expect(find.text('VERIFICADO'), findsOneWidget);
    expect(find.text('Actualización de membresía'), findsOneWidget);
    expect(find.text('OWNER'), findsNothing);
    expect(find.text('Membership update'), findsNothing);
  });

  testWidgets('renders Twitch VIP, real badges and localized resubscriptions',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(showBadges: true),
    );
    final message = ChatMessage(
      platform: Platform.twitch,
      id: 'resub',
      author: const ChatAuthor(
        name: 'Ana',
        channelId: 'ana',
        badges: [AuthorBadge(label: 'Bits 1000', kind: 'bits')],
      ),
      items: const [MessageItem.text('¡Un año!')],
      isMembership: true,
      isMembershipEvent: true,
      isVip: true,
      membershipEventKind: MembershipEventKind.resubscription,
      membershipMonths: 12,
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

    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Bits 1000'), findsOneWidget);
    expect(find.text('Se resuscribió por 12 meses'), findsOneWidget);
  });

  testWidgets('labels messages from the configured YouTube stream',
      (tester) async {
    final notifier = _TestSettingsNotifier(
      const SettingsModel(
        showBadges: true,
        showYoutubeStreamBadges: true,
      ),
    );
    final message = ChatMessage(
      platform: Platform.youtube,
      id: 'vertical',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: const [MessageItem.text('Hola')],
      youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
      timestamp: DateTime.utc(2026, 8, 26),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: message)),
        ),
      ),
    );

    expect(find.text('VERTICAL'), findsOneWidget);
  });

  testWidgets('shows preserved reply context without changing the message',
      (tester) async {
    final notifier = _TestSettingsNotifier(const SettingsModel());
    final message = ChatMessage(
      platform: Platform.twitch,
      id: 'reply',
      author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
      items: const [MessageItem.text('My answer')],
      reply: const ChatReplyContext(
        messageId: 'parent',
        authorName: 'Bob',
        text: 'Original message',
      ),
      timestamp: DateTime.utc(2026, 9, 7),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ChatBubble(message: message)),
        ),
      ),
    );

    expect(find.text('↪ Bob: Original message'), findsOneWidget);
    expect(find.text('My answer'), findsOneWidget);
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

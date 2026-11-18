import 'dart:async';
import 'dart:convert';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/application/session_summary.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/main.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/session_summary_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'application/coordinator_fakes.dart';

class _MemorySettings extends SettingsNotifier {
  _MemorySettings(String language) : super(systemLanguageCode: () => '') {
    state = SettingsModel(
      appLanguageCode: language,
      ttsEnabled: true,
      overlayEnabled: false,
    );
  }

  SettingsModel get current => state;

  @override
  Future<void> update(SettingsModel settings) async => state = settings;
}

void main() {
  for (final language in ['en', 'es']) {
    final locale = Locale(language);
    final l = lookupAppLocalizations(locale);

    testWidgets('voice reader filters work at 360 px in $language',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 840);
      addTearDown(tester.view.reset);
      final settings = _MemorySettings(language);
      final controller = AppController(
        audioCoordinator: AudioCoordinator(
            tts: FakeTtsClient(), captions: FakeCaptionsClient()),
        chatCoordinator: ChatCoordinator(
          youtube: FakeYouTubeChatClient(),
          youtubeHorizontal: FakeYouTubeChatClient(),
          youtubeVertical: FakeYouTubeChatClient(),
          twitch: FakeChannelChatClient(),
          kick: FakeChannelChatClient(),
        ),
        overlayCoordinator: OverlayCoordinator(overlay: FakeOverlayClient()),
        obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => settings),
          appControllerProvider.overrideWithValue(controller),
        ],
        child: const AirstreamApp(),
      ));
      await tester.tap(find.byTooltip(language == 'en'
          ? 'Show sidebar (Ctrl+B)'
          : 'Mostrar menú lateral (Ctrl+B)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l.ttsAndVoice));
      await tester.pumpAndSettle();

      Future<void> tapVisible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(find.text(language == 'en' ? 'What to read' : 'Qué leer'),
          findsOneWidget);
      await tapVisible(find.byKey(const Key('tts-role-member')));
      await tapVisible(find.byKey(const Key('tts-role-vip')));
      expect(settings.current.ttsRoles, {TtsRole.member, TtsRole.vip});
      await tapVisible(find.byKey(const Key('tts-platform-kick')));
      expect(
          settings.current.ttsPlatforms, {Platform.youtube, Platform.twitch});
      final links = find.descendant(
        of: find.byKey(const Key('tts-links')),
        matching: find.byType(DropdownButton<String>),
      );
      await tapVisible(links);
      await tester.tap(find.text(l.ttsLinksSay).last);
      await tester.pumpAndSettle();
      expect(settings.current.ttsLinks, TtsLinks.sayLink);
      expect(find.text(l.ttsAlwaysReadSupport), findsOneWidget);
      expect(find.text(l.ttsSkipEmoteOnly), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(controller.dispose());
      await tester.pump();
    });

    testWidgets('session export buttons work at 360 px in $language',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);
      final chat = [
        ChatMessage(
          platform: Platform.twitch,
          id: '1',
          author: const ChatAuthor(name: 'Ángela', channelId: 'id'),
          items: const [MessageItem.text('¡Qué tal!')],
          timestamp: DateTime.utc(2026),
        ),
      ];
      final collector = SessionSummaryCollector()..start();
      collector.handleMessage(chat.single);
      final saved = <String, String>{};
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SessionSummaryDialog(
                        summary: collector.summary,
                        chat: chat,
                        listSeparator: () async => ',',
                        saveCsv: (name, bytes) async {
                          expect(bytes.take(3), [0xef, 0xbb, 0xbf]);
                          saved[name] = utf8.decode(bytes);
                        },
                      ),
                    ),
                    child: const Text('Open'),
                  )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(l.sessionExportChatScope(1)), findsOneWidget);
      await tester.tap(find.text(
          language == 'en' ? 'Export chat (CSV)' : 'Exportar chat (CSV)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'en'
          ? 'Export participants (CSV)'
          : 'Exportar participantes (CSV)'));
      await tester.pumpAndSettle();
      expect(saved['airstream-chat.csv'], contains('Ángela,id,,¡Qué tal!'));
      expect(saved['airstream-participants.csv'],
          contains('Ángela,twitch,id,1,0,'));
      expect(tester.takeException(), isNull);
    });
  }
}

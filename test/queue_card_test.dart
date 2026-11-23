import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/queue_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_queue_test.dart' show queueMessage;

void main() {
  for (final language in ['en', 'es']) {
    testWidgets('queue card fits 50 players at 360 px in $language', (t) async {
      SharedPreferences.setMockInitialValues({});
      final l = lookupAppLocalizations(Locale(language));
      final queue = ChatQueueController();
      final command = language == 'es' ? '!quierojugarconelstreamer' : '!join';
      queue.configure(QueueOptions(command: command), language);
      queue.setStatus(QueueStatus.open);
      for (var i = 0; i < 50; i++) {
        queue.handleMessage(queueMessage(
          'Viewer $i with a very long display name 🎮',
          '$command ${'Note ' * 6}',
        ));
      }
      final first = queue.current.entries.first;
      await t.pumpWidget(ProviderScope(
        overrides: [
          chatQueueProvider.overrideWithValue(queue),
          settingsProvider.overrideWith(
            (_) => _FailingSettings(language, command),
          ),
        ],
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: appLocalizationsDelegates,
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: SingleChildScrollView(child: QueueCard()),
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle(const Duration(milliseconds: 250));
      expect(find.byKey(const Key('queue-card')), findsOneWidget);
      final hint = find.text(l.queueJoinHint(command));
      expect(hint, findsOneWidget);
      expect(t.widget<Text>(hint).maxLines, isNull);
      expect(find.text('50 / 50'), findsOneWidget);
      expect(find.byKey(Key('queue-remove-${first.id}')), findsOneWidget);
      expect(t.takeException(), isNull);

      Future<void> click(Finder finder) async {
        await t.ensureVisible(finder);
        await t.tap(finder);
        await t.pumpAndSettle(const Duration(milliseconds: 250));
      }

      await click(find.byKey(const Key('queue-next')));
      expect(queue.current.playing.single.id, first.id);
      expect(find.text(l.queuePlaying), findsOneWidget);
      expect(find.byKey(Key('queue-done-${first.id}')), findsOneWidget);

      // Ten players playing: Next waits until someone is marked Done.
      queue.next(9);
      await t.pumpAndSettle(const Duration(milliseconds: 250));
      ElevatedButton next() =>
          t.widget<ElevatedButton>(find.byKey(const Key('queue-next')));
      expect(next().onPressed, isNull);
      expect(find.text(l.queuePlayingFull), findsOneWidget);
      expect(t.takeException(), isNull);
      await click(find.byKey(Key('queue-done-${first.id}')));
      expect(next().onPressed, isNotNull);
      expect(find.text(l.queuePlayingFull), findsNothing);
      for (final player in [...queue.current.playing]) {
        queue.done(player.id);
      }
      await t.pumpAndSettle(const Duration(milliseconds: 250));
      queue.next(1);
      await t.pumpAndSettle(const Duration(milliseconds: 250));

      await click(find.text(l.queueSettings));
      expect(find.text(l.queueCommand), findsOneWidget);
      final commandField = find.byType(TextFormField);
      await t.ensureVisible(commandField);
      await t.enterText(commandField, '!play');
      await t.pump();
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.text(l.liveSaveFailed), findsOneWidget);
      expect(t.takeException(), isNull);

      await click(find.byKey(const Key('queue-clear')));
      expect(find.text(l.queueClearConfirm), findsOneWidget);
      expect(queue.current.entries, hasLength(39));
      await click(find.text(l.cancel));
      expect(queue.current.playing, hasLength(1));
      await click(find.byKey(const Key('queue-clear')));
      await click(find.byKey(const Key('queue-clear-confirm')));
      expect(queue.current.entries, isEmpty);
      expect(queue.current.playing, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await queue.dispose();
    });
  }
}

class _FailingSettings extends SettingsNotifier {
  _FailingSettings(String language, String command)
      : super(systemLanguageCode: () => '') {
    state = SettingsModel(
      appLanguageCode: language,
      queueOptions: QueueOptions(command: command),
    );
  }

  @override
  Future<void> update(SettingsModel settings) async {
    throw StateError('Disk unavailable');
  }
}

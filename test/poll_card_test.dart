import 'dart:async';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/ui/widgets/poll_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'chat_queue_test.dart' show queueMessage;

class _PollApp implements AppController {
  final polls = ChatPollController();

  @override
  Stream<ChatPoll?> get pollStream => polls.states;

  @override
  void startPoll({
    required String question,
    List<String> options = const [],
    Duration? duration,
    PollMode mode = PollMode.numbered,
    bool hideResults = false,
    QueueRole allowed = QueueRole.everyone,
    bool allowChange = true,
    String command = ChatPoll.defaultCommand,
    String? language,
  }) =>
      polls.start(
        question: question,
        options: options,
        duration: duration,
        mode: mode,
        hideResults: hideResults,
        allowed: allowed,
        allowChange: allowChange,
        command: command,
        language: language ?? 'en',
      );

  @override
  void launchSavedPoll(SavedPoll setup, {required String language}) =>
      startPoll(
        question: setup.question,
        options: setup.options,
        duration:
            setup.minutes == null ? null : Duration(minutes: setup.minutes!),
        mode: setup.mode,
        hideResults: setup.hideResults,
        allowed: setup.allowed,
        allowChange: setup.allowChange,
        command: setup.command,
        language: language,
      );

  @override
  void endPoll() => polls.end();

  @override
  void clearPoll() => polls.clear();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final language in ['en', 'es']) {
    testWidgets('all poll modes fit 360 px in $language', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final l = lookupAppLocalizations(Locale(language));
      final app = _PollApp();
      try {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            appControllerProvider.overrideWithValue(app),
            settingsProvider.overrideWith(
                (_) => SettingsNotifier(systemLanguageCode: () => language)),
            overlayServerStateProvider
                .overrideWith((_) => const Stream.empty()),
            overlayUrlProvider.overrideWithValue(null),
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
                  child: SingleChildScrollView(child: PollCard()),
                ),
              ),
            ),
          ),
        ));
        Future<void> click(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final modePicker = find.byKey(const Key('poll-mode'));
        final question = find.byKey(const Key('poll-question'));
        final first = find.byKey(const Key('poll-option-0'));
        final second = find.byKey(const Key('poll-option-1'));
        final start = find.byKey(const Key('poll-start'));
        final command = find.byKey(const Key('poll-command'));
        final error = find.byKey(const Key('poll-error'));
        final settings = find.text(l.pollOptions);
        for (final (mode, label, vote) in [
          (PollMode.numbered, l.pollModeNumbered, '!1'),
          (PollMode.word, l.pollModeWord, 'Azul'),
          (PollMode.yesNo, l.pollModeYesNo, 'yes'),
          (PollMode.rating, l.pollModeRating, '9'),
          (PollMode.freeAnswer, l.pollModeFreeAnswer, '!r Mi respuesta'),
        ]) {
          await click(modePicker);
          await click(find.text(label).last);
          expect(
              tester.widget<DropdownButton<PollMode>>(modePicker).value, mode);
          expect(tester.getSize(find.byType(PollCard)).width, 360);
          expect(tester.takeException(), isNull);

          await tester.enterText(question, '¿Qué opción prefieres?');
          if (mode == PollMode.numbered || mode == PollMode.word) {
            expect(first, findsOneWidget);
            expect(second, findsOneWidget);
            await tester.enterText(first, 'Azul');
            await tester.enterText(
                second, mode == PollMode.word ? ' ÁZUL ' : 'Rojo');
            await tester.pump();
            if (mode == PollMode.word) {
              await click(start);
              expect(error, findsOneWidget);
              expect(find.text(l.pollAmbiguousOptions), findsOneWidget);
              await tester.enterText(second, 'Rojo');
              await tester.pump();
              expect(error, findsNothing);
            }
          } else {
            expect(first, findsNothing);
            expect(second, findsNothing);
          }
          if (mode == PollMode.freeAnswer) {
            expect(tester.widget<TextField>(command).controller!.text, '!r');
          } else {
            expect(command, findsNothing);
          }
          if (mode == PollMode.numbered) {
            await click(settings);
            expect(find.text(l.pollAllowed), findsOneWidget);
            await click(find.text(l.pollHideResults));
            expect(
              tester
                  .widget<SwitchListTile>(
                    find.widgetWithText(SwitchListTile, l.pollHideResults),
                  )
                  .value,
              isTrue,
            );
            await click(settings);
            expect(tester.takeException(), isNull);
          }

          await click(start);
          expect(app.polls.current?.mode, mode);
          expect(app.polls.current?.hideResults, isTrue);
          app.polls.handleMessage(queueMessage('Viewer', vote));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(l.pollResultsHiddenOnPages), findsOneWidget);
          if (mode == PollMode.rating) {
            expect(find.byKey(const Key('poll-average')), findsOneWidget);
            expect(
                find.text(language == 'es' ? 'Promedio: 9,0' : 'Average: 9.0'),
                findsOneWidget);
          } else if (mode == PollMode.freeAnswer) {
            expect(find.text('Mi respuesta'), findsOneWidget);
          } else {
            final count =
                tester.widget<Text>(find.byKey(const Key('poll-count-0')));
            expect(count.data, '100% · 1');
            if (mode == PollMode.yesNo) {
              expect(find.text(l.pollYes), findsOneWidget);
            }
          }
          expect(tester.takeException(), isNull);
          await click(find.byKey(const Key('poll-end')));
          expect(find.text(l.pollResultsHiddenOnPages), findsNothing);
          await click(find.byKey(const Key('poll-new')));
        }

        await click(find.text(l.pollSavedSetups));
        await click(find.widgetWithText(TextButton, l.pollSaveSetup));
        await tester.enterText(
            find.byKey(const Key('poll-setup-name')), 'Saved setup');
        await tester.pumpAndSettle();
        await click(find.widgetWithText(ElevatedButton, l.ruleLabel('ksave')));
        expect(find.text('Saved setup'), findsOneWidget);
        await click(find.byTooltip(l.pollRenameSetup));
        await tester.enterText(
            find.byKey(const Key('poll-setup-name')), 'Renamed setup');
        await tester.pumpAndSettle();
        await click(find.widgetWithText(ElevatedButton, l.ruleLabel('ksave')));
        expect(find.text('Renamed setup'), findsOneWidget);
        await click(find.widgetWithText(TextButton, l.pollStart));
        expect(app.polls.current?.mode, PollMode.freeAnswer);
        expect(app.polls.current?.command, '!r');
        // While that poll is open, a saved poll cannot replace it (and its
        // votes) by accident.
        expect(
            tester
                .widget<TextButton>(
                    find.widgetWithText(TextButton, l.pollStart))
                .onPressed,
            isNull);
        await click(find.byTooltip(l.pollDeleteSetup));
        expect(find.text('Renamed setup'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        unawaited(app.polls.dispose());
        await tester.pump();
      }
    });
  }
}

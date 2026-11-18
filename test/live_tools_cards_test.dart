import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/ui/widgets/clock_card.dart';
import 'package:airstream/ui/widgets/giveaway_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_giveaway_test.dart' show message;

class _LiveApp implements AppController {
  _LiveApp(this.settings);
  final _Settings settings;
  late final giveaway = ChatGiveawayController(onHistoryChanged: (history) {
    settings.update(settings.current.copyWith(giveawayHistory: history));
  });

  @override
  Stream<ChatGiveaway?> get giveawayStream => giveaway.states;
  @override
  void startGiveaway({required String keyword, required bool membersOnly}) =>
      giveaway.start(keyword: keyword, membersOnly: membersOnly);
  @override
  void closeGiveaway() => giveaway.close();
  @override
  void clearGiveaway() => giveaway.clear();
  @override
  void clearGiveawayHistory() => giveaway.clearHistory();
  @override
  List<GiveawayEntrant> drawGiveaways(int count, {int depth = 0}) =>
      giveaway.drawMany(count);
  @override
  Future<void> operateClock(String op, {int seconds = 0, int depth = 0}) {
    final current = settings.current;
    final next = current.clock
        .perform(op, DateTime.now().millisecondsSinceEpoch, seconds: seconds);
    return settings.update(current.copyWith(clock: next));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings extends SettingsNotifier {
  _Settings(String language) : super(systemLanguageCode: () => language);

  // Expose the current snapshot to the fake app without a provider listener.
  SettingsModel get current => state;
}

void main() {
  for (final language in ['en', 'es']) {
    testWidgets('Timer and Giveaway fit 360 px in $language', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final l = lookupAppLocalizations(Locale(language));
      final settings = _Settings(language);
      final app = _LiveApp(settings);
      Future<void> mount(Widget card) => tester.pumpWidget(ProviderScope(
            overrides: [
              appControllerProvider.overrideWithValue(app),
              settingsProvider.overrideWith((_) => settings),
              overlayUrlProvider.overrideWithValue(null),
              overlayServerStateProvider
                  .overrideWith((_) => const Stream.empty()),
            ],
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: appLocalizationsDelegates,
              theme: ThemeData.dark(),
              home: Scaffold(
                  body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                    width: 360, child: SingleChildScrollView(child: card)),
              )),
            ),
          ));

      Future<void> click(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      // Keep the scope mounted while changing the card.
      await mount(const ClockCard());
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ClockCard)).width, 360);
      await tester.enterText(find.byKey(const Key('clock-duration')), '90');
      await tester.pumpAndSettle();
      expect(find.text('1:30'), findsOneWidget);
      await click(find.byKey(const Key('clock-toggle')));
      expect(find.text(l.clockPause), findsOneWidget);
      await click(find.byKey(const Key('clock-toggle')));
      await click(find.text(l.clockPlusMinute));
      expect(find.text('2:30'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await mount(const GiveawayCard());
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(GiveawayCard)).width, 360);
      await tester.enterText(find.byKey(const Key('giveaway-keyword')), 'go');
      await tester.pumpAndSettle();
      await click(find.byKey(const Key('giveaway-start')));
      app.giveaway.handleMessage(message('Ana', 'go', platform: Platform.kick));
      app.giveaway.handleMessage(message('Beto', 'go'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await click(find.byKey(const Key('giveaway-draw-count')));
      await click(find.text('2').last);
      await click(find.text(l.giveawayDrawMany(2)));
      expect(app.giveaway.current!.winners, hasLength(2));
      await click(find.text(l.giveawayHistory));
      expect(find.textContaining('Ana (kick)'), findsOneWidget);
      expect(find.textContaining('Beto (twitch)'), findsOneWidget);
      await click(find.text(l.giveawayClearHistory));
      expect(find.text(l.giveawayHistoryEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await app.giveaway.dispose();
    });
  }
}

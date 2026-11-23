import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/live_clock.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/clock_card.dart';
import 'package:airstream/ui/widgets/goals_card.dart';
import 'package:airstream/ui/widgets/subathon_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Spanish timer errors and goal editor fit a 360 × 600 window',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const locale = Locale('es');
    final l = lookupAppLocalizations(locale);
    final settings = _TestSettings();
    Future<void> show(Widget card) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          settingsProvider.overrideWith((_) => settings),
          overlayUrlProvider.overrideWithValue(null),
          overlayServerStateProvider.overrideWith((_) => const Stream.empty()),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show(const ClockCard());
    expect(find.text(l.clockPaused), findsOneWidget);
    expect(find.text(l.subathonResume), findsOneWidget);
    await tester.enterText(find.byKey(const Key('clock-duration')), '99999');
    await tester.pump();
    expect(find.text(l.liveNumberRange(1, 86400)), findsOneWidget);
    expect(settings.current.clock.durationSeconds, 300);
    final reset = find.text(l.clockReset);
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text(l.clockResetConfirm), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(l.clockResetConfirm), findsNothing);
    expect(settings.current.clock.phase, ClockPhase.paused);

    await show(const SubathonCard());
    final addTime = find.byKey(const Key('subathon-add-5'));
    expect(tester.widget<OutlinedButton>(addTime).onPressed, isNull);
    expect(find.text(l.subathonAdjustHint), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();
    expect(find.text(l.liveNumberRange(1, 10080)), findsOneWidget);
    expect(settings.current.subathonStartMinutes, 60);

    await show(const GoalsCard());
    await tester.tap(find.byKey(const Key('goals-add')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text(l.goalsInvalid), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-save')), findsNothing);
  });
}

class _TestSettings extends SettingsNotifier {
  _TestSettings() : super(systemLanguageCode: () => '') {
    state = const SettingsModel(
      clock: LiveClock(phase: ClockPhase.paused, valueMs: 120000),
    );
  }

  SettingsModel get current => state;
}

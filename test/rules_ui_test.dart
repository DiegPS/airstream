import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/l10n/app_localization_delegates.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/rules_card.dart';
import 'package:airstream/ui/widgets/rule_editor_dialog.dart';
import 'package:airstream/ui/widgets/sidebar_tab_bar.dart';
import 'rules_test_target.dart';

class MemoryRulesSettings extends SettingsNotifier {
  MemoryRulesSettings(SettingsModel model) {
    state = model;
  }
  @override
  Future<void> update(SettingsModel next) async {
    state = next;
  }
}

Future<void> visible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
}

void main() {
  late RulesTestTarget target;
  late RuleEngine engine;
  late MemoryRulesSettings settings;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
    target = RulesTestTarget();
    engine = RuleEngine(target: target);
    settings = MemoryRulesSettings(const SettingsModel(overlayEnabled: false));
  });
  tearDown(() async {
    await engine.dispose();
  });
  Future<void> mount(WidgetTester t,
      {String language = 'en', Widget? child}) async {
    await t.pumpWidget(ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData.dark(),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                            child: child ?? RulesCard(engine: engine))))))));
    await t.pumpAndSettle();
  }

  testWidgets(
      'empty state, recipe edit save enable, duplicate and confirmed delete',
      (t) async {
    await mount(t);
    expect(find.text('Start with Recipes for an example.'), findsOneWidget);
    await t.tap(find.byKey(const Key('rules-recipes')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('recipe-add-1')));
    await t.pumpAndSettle();
    final scene = find.byKey(const Key('rule-action-0-scene'));
    await visible(t, scene);
    await t.enterText(scene, 'Welcome');
    await t.pump();
    expect(
        t.widget<OutlinedButton>(find.byKey(const Key('rule-run'))).onPressed,
        isNull);
    await t.tap(find.byKey(const Key('rule-save')));
    await t.pumpAndSettle();
    expect(
        t.widget<OutlinedButton>(find.byKey(const Key('rule-run'))).onPressed,
        isNotNull);
    expect((settings.state.rules.single['actions'] as List).first['scene'],
        'Welcome');
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    final id = settings.state.rules.single['id'];
    final enabled = find.byKey(Key('rule-enabled-$id'));
    await visible(t, enabled);
    await t.tap(enabled);
    await t.pumpAndSettle();
    expect(settings.state.rules.single['enabled'], true);
    expect(find.textContaining('When Raid → 3'), findsOneWidget);
    await t.tap(find.byKey(Key('rule-menu-$id')));
    await t.pumpAndSettle();
    await t.tap(find.text('Duplicate'));
    await t.pumpAndSettle();
    expect(settings.state.rules.length, 2);
    expect(settings.state.rules.last['enabled'], false);
    final copy = settings.state.rules.last['id'];
    await visible(t, find.byKey(Key('rule-menu-$copy')));
    await t.tap(find.byKey(Key('rule-menu-$copy')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(settings.state.rules.length, 2);
    await t.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await t.pumpAndSettle();
    expect(settings.state.rules.length, 1);
  });
  testWidgets(
      'chat OBS warning and invalid command disables save; simulation has no effects',
      (t) async {
    final r = {
      ...RuleSchema.newRule('chat.command', id: 'r'),
      'actions': [
        {'id': 'a', 'type': 'obs.scene', 'scene': 'Raid'}
      ]
    };
    settings = MemoryRulesSettings(
        SettingsModel(rules: RuleSchema.sanitize([r]), overlayEnabled: false));
    await mount(t);
    expect(find.text('Anyone in chat can change OBS with this rule'),
        findsOneWidget);
    await t.tap(find.byKey(const Key('rule-menu-r')));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    final command = find.byKey(const Key('rule-trigger-command'));
    await visible(t, command);
    await t.enterText(command, 'invalid');
    await t.pump();
    expect(
        t.widget<ElevatedButton>(find.byKey(const Key('rule-save'))).onPressed,
        isNull);
    await t.enterText(command, '!hello');
    await t.pump();
    await t.tap(find.byKey(const Key('rule-test')));
    await t.pumpAndSettle();
    await visible(t, find.byKey(const Key('rule-test-result')));
    expect(find.text('Matched'), findsOneWidget);
    await visible(t, find.byKey(const Key('rule-sample-text')));
    await t.enterText(find.byKey(const Key('rule-sample-text')), '!different');
    await t.tap(find.byKey(const Key('rule-test')));
    await t.pumpAndSettle();
    await visible(t, find.byKey(const Key('rule-test-result')));
    expect(find.text('Text does not match'), findsOneWidget);
    expect(target.calls, isEmpty);
    expect(engine.history, isEmpty);
  });
  testWidgets('closing an edited rule asks before discarding', (t) async {
    await mount(t);
    await t.tap(find.byKey(const Key('rules-new')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('rule-name')), 'Changed');
    await t.pump();
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rule-editor')), findsOneWidget);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    await t.tap(find.text('Discard'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rule-editor')), findsNothing);
    expect(settings.state.rules, isEmpty);
  });
  for (final language in ['en', 'es']) {
    testWidgets('eight tabs and editor fit 360 panel and 900x700 in $language',
        (t) async {
      t.view.physicalSize = const Size(900, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t,
          language: language,
          child: Column(children: [
            SidebarTabBar(
                selectedIndex: 5,
                onTabSelected: (_) {},
                tabs: List.generate(
                    8,
                    (i) => SidebarTabItem(
                        icon: Icons.rule_rounded, label: 'Tab $i'))),
            RulesCard(engine: engine)
          ]));
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('rules-new')));
      await t.pumpAndSettle();
      expect(find.byType(RuleEditorDialog), findsOneWidget);
      expect(t.takeException(), isNull);
      t.view.physicalSize = const Size(360, 700);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('breaker resumes and history displays every action status',
      (t) async {
    final r = {...RuleSchema.newRule('manual', id: 'r'), 'enabled': true};
    engine.updateSettings(enabled: true, rules: [r]);
    for (var i = 0; i < 31; i++) {
      engine.runNow('r', engine.sampleEvent('manual'));
      await t.pump(const Duration(milliseconds: 1));
    }
    await mount(t);
    expect(find.byKey(const Key('rules-tripped')), findsOneWidget);
    await visible(t, find.byKey(const Key('rules-resume')));
    await t.tap(find.byKey(const Key('rules-resume')));
    await t.pumpAndSettle();
    expect(engine.tripped, isNull);
    final run = engine.history.first;
    run.results.addAll([
      const RuleActionResult('done'),
      const RuleActionResult('skipped', 'notConnected'),
      const RuleActionResult('failed'),
      const RuleActionResult('uncertain'),
      const RuleActionResult('cancelled')
    ]);
    await mount(t, child: RuleHistoryCard(engine: engine));
    expect(find.textContaining('Done ✓'), findsWidgets);
    expect(find.textContaining('OBS is disconnected'), findsWidgets);
    for (final status in ['Failed', 'Uncertain', 'Cancelled']) {
      expect(find.textContaining(status), findsWidgets);
    }
  });
}

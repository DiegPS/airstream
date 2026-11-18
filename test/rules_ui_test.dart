import 'package:airstream/ui/widgets/rules_webhook_card.dart';
import 'package:airstream/ui/widgets/rules_sharing.dart';
import 'package:airstream/application/rules/rule_sharing.dart';
import 'package:airstream/ui/widgets/rule_buttons_card.dart';
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
      'webhook URLs are opt in and limited to enabled named manual rules; regeneration confirms',
      (t) async {
    Map<String, dynamic> manual(String id, bool enabled, String webhook) => {
          ...RuleSchema.newRule('manual', id: id),
          'enabled': enabled,
          'trigger': {'type': 'manual', 'webhook': webhook}
        };
    final rules = [
      manual('yes', true, 'run'),
      manual('off', false, 'off'),
      manual('unnamed', true, ''),
      {...RuleSchema.newRule('chat.firstMessage', id: 'chat'), 'enabled': true}
    ];
    await settings.update(
        settings.state.copyWith(rules: rules, rulesWebhookToken: 'a' * 64));
    await mount(t, child: const RulesWebhookCard());
    expect(find.byKey(const Key('rule-webhook-copy-yes')), findsNothing);
    await settings.update(settings.state.copyWith(rulesWebhookEnabled: true));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rule-webhook-copy-yes')), findsOneWidget);
    for (final id in ['off', 'unnamed', 'chat']) {
      expect(find.byKey(Key('rule-webhook-copy-$id')), findsNothing);
    }
    expect(find.text('a' * 64), findsNothing);
    await visible(t, find.byKey(const Key('rules-webhook-regenerate')));
    await t.tap(find.byKey(const Key('rules-webhook-regenerate')));
    await t.pumpAndSettle();
    expect(find.text('Regenerate token? Existing buttons will stop working.'),
        findsOneWidget);
    expect(settings.state.rulesWebhookToken, 'a' * 64);
    await t.tap(find.widgetWithText(OutlinedButton, 'Regenerate'));
    await t.pumpAndSettle();
    expect(settings.state.rulesWebhookToken, isNot('a' * 64));
  });

  testWidgets('import review shows external warnings and saves disabled rules',
      (t) async {
    final rule = {
      ...RuleSchema.newRule('manual', id: 'incoming'),
      'enabled': true,
      'actions': [
        {'id': 'a', 'type': 'obs.scene', 'scene': 'Studio'},
        {
          'id': 'b',
          'type': 'alert.show',
          'title': 'Hello',
          'text': '',
          'seconds': 5,
          'mediaId': '0123456789abcdef'
        },
        {
          'id': 'http',
          'type': 'http.request',
          'method': 'post',
          'url': 'https://example.invalid/private',
          'contentType': 'json',
          'body': '{}',
        }
      ]
    };
    final review = RuleSharing.import(RuleSharing.export([rule]), existing: []);
    await mount(t,
        child: Builder(
            builder: (c) => TextButton(
                onPressed: () => showDialog<void>(
                    context: c,
                    builder: (_) => RulesImportDialog(review: review)),
                child: const Text('Open import'))));
    await t.tap(find.text('Open import'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rules-import-dialog')), findsOneWidget);
    expect(find.textContaining('Check these names exist in your OBS: Studio'),
        findsOneWidget);
    expect(find.textContaining('0123456789abcdef'), findsOneWidget);
    expect(
        find.textContaining('Set the URL again in: New rule'), findsOneWidget);
    expect(settings.state.rules, isEmpty);
    await t.tap(find.byKey(const Key('rules-import-confirm')));
    await t.pumpAndSettle();
    expect(settings.state.rules.single['enabled'], false);
    expect(settings.state.rules.single['id'], isNot('incoming'));
    expect(settings.state.rules.single['actions'].last['url'], '');
  });

  testWidgets('manual buttons include enabled rules only and explain cooldown',
      (t) async {
    final rules = [
      {
        ...RuleSchema.newRule('manual', id: 'button'),
        'enabled': true,
        'name': 'Celebrate',
        'cooldownSeconds': 30
      },
      {...RuleSchema.newRule('manual', id: 'disabled'), 'name': 'Disabled'},
      {
        ...RuleSchema.newRule('poll.ended', id: 'poll'),
        'enabled': true,
        'name': 'Poll'
      },
    ];
    settings.state = settings.state.copyWith(rules: rules);
    engine.updateSettings(enabled: true, rules: rules);
    await mount(t, child: RuleButtonsCard(engine: engine));
    expect(find.text('Rule buttons'), findsOneWidget);
    expect(find.byKey(const Key('rule-button-disabled')), findsNothing);
    expect(find.byKey(const Key('rule-button-poll')), findsNothing);
    await t.tap(find.byKey(const Key('rule-button-button')));
    await t.pumpAndSettle();
    expect(engine.history.length, 1);
    await t.tap(find.byKey(const Key('rule-button-button')));
    await t.pump();
    expect(find.text('Rule is cooling down'), findsOneWidget);
    settings.state = settings.state.copyWith(rules: []);
    await t.pump();
    expect(find.text('Rule buttons'), findsNothing);
  });

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
  testWidgets('changing triggers clears hidden filters from the draft',
      (t) async {
    final rule = {
      ...RuleSchema.newRule('chat.message', id: 'r'),
      'trigger': {
        'type': 'chat.message',
        'text': 'old text',
        'match': 'contains'
      },
      'conditions': {
        'platforms': ['twitch'],
        'roles': ['vip']
      },
      'actions': [
        {
          'id': 'notice',
          'type': 'template.trigger',
          'name': 'notice',
          'data': 'hi'
        }
      ],
    };
    settings = MemoryRulesSettings(SettingsModel(
        rules: RuleSchema.sanitize([rule]), overlayEnabled: false));
    await mount(t);
    await t.tap(find.byKey(const Key('rule-menu-r')));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    final trigger = find.byKey(const Key('rule-trigger'));
    final dropdown = find.descendant(
        of: trigger, matching: find.byType(DropdownButton<String>));
    t.widget<DropdownButton<String>>(dropdown).onChanged!('poll.ended');
    await t.pump();
    expect(find.byKey(const Key('rule-trigger-text')), findsNothing);
    t.widget<DropdownButton<String>>(dropdown).onChanged!('chat.message');
    await t.pump();
    expect(
        t
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Twitch'))
            .selected,
        isFalse);
    expect(
        t.widget<FilterChip>(find.widgetWithText(FilterChip, 'VIPs')).selected,
        isFalse);
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

    testWidgets('OBS fields and live chat warning fit 360 px in $language',
        (t) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t, language: language);
      await t.tap(find.byKey(const Key('rules-new')));
      await t.pumpAndSettle();
      final spanish = language == 'es';
      final dialog = find.byType(RuleEditorDialog);
      final addAction = find.byKey(const Key('rule-add-action'));
      final warning = find.descendant(
        of: dialog,
        matching: find.text(spanish
            ? 'Lo que escriba el chat saldrá en tu directo'
            : 'Chat text will appear on your stream'),
      );

      Future<void> add(String label) async {
        await visible(t, addAction);
        await t.tap(addAction);
        await t.pumpAndSettle();
        final item = find.widgetWithText(PopupMenuItem<String>, label);
        await visible(t, item);
        await t.tap(item);
        await t.pumpAndSettle();
      }

      final source = spanish ? 'Fuente' : 'Source';
      void field(int action, String key, String label, String value) {
        final widget =
            t.widget<TextField>(find.byKey(Key('rule-action-$action-$key')));
        expect(widget.decoration?.labelText, label);
        expect(widget.controller?.text, value);
      }

      await add(spanish ? 'Cambiar texto' : 'Set text');
      field(0, 'source', source, 'Text');
      field(0, 'text', spanish ? 'Texto' : 'Text', '{counter.count}');
      expect(warning, findsNothing);
      final textField = find.byKey(const Key('rule-action-0-text'));
      await visible(t, textField);
      await t.enterText(textField, 'On stream: {args}');
      await t.pumpAndSettle();
      await visible(t, warning);
      expect(warning.hitTestable(), findsOneWidget);

      await add(
          spanish ? 'Activar / desactivar filtro' : 'Turn filter on / off');
      field(1, 'source', source, 'Camera');
      field(1, 'filter', spanish ? 'Filtro' : 'Filter', 'Filter');
      final state = find.byKey(const Key('rule-action-1-state'));
      await visible(t, state);
      expect(
          find.descendant(
              of: state, matching: find.text(spanish ? 'Estado' : 'State')),
          findsOneWidget);
      await t.tap(state);
      await t.pumpAndSettle();
      for (final label in spanish
          ? ['Activar', 'Desactivar', 'Alternar']
          : ['Turn on', 'Turn off', 'Toggle']) {
        expect(
            find.widgetWithText(DropdownMenuItem<String>, label), findsWidgets);
      }
      await t.tap(find.text(spanish ? 'Desactivar' : 'Turn off').last);
      await t.pumpAndSettle();

      final moderators = find.widgetWithText(
          FilterChip, spanish ? 'Moderadores' : 'Moderators');
      await visible(t, moderators);
      await t.tap(moderators);
      await t.pumpAndSettle();
      expect(warning, findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('phase 11 actions fit 360 px and validate in $language',
        (t) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t, language: language);
      await t.tap(find.byKey(const Key('rules-new')));
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(find.byType(RuleEditorDialog)))!;
      final addAction = find.byKey(const Key('rule-add-action'));
      Finder field(int action, String name) =>
          find.byKey(Key('rule-action-$action-$name'));
      Future<void> add(String type, List<String> fields, int action) async {
        await visible(t, addAction);
        await t.tap(addAction);
        await t.pumpAndSettle();
        final item =
            find.widgetWithText(PopupMenuItem<String>, ruleText(l, type));
        await visible(t, item);
        await t.tap(item);
        await t.pumpAndSettle();
        for (final name in fields) {
          final input = field(action, name);
          await visible(t, input);
          expect(input.hitTestable(), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      }

      await add('obs.stream', ['state'], 0);
      final streamError = find.text(ruleText(l, 'publicStreamControl'));
      expect(streamError.hitTestable(), findsOneWidget);
      final moderators =
          find.widgetWithText(FilterChip, ruleText(l, 'moderator'));
      await visible(t, moderators);
      await t.tap(moderators);
      await t.pumpAndSettle();
      expect(streamError, findsNothing);

      await add('obs.replay', ['op'], 1);
      await add('obs.media', ['source', 'op'], 2);
      await add('obs.volume', ['input', 'mode', 'db'], 3);
      final db = field(3, 'db');
      expect(t.widget<TextField>(db).decoration?.labelText, 'dB (-100–26)');
      final mode = field(3, 'mode');
      await visible(t, mode);
      await t.tap(mode);
      await t.pumpAndSettle();
      await t.tap(find.text(ruleText(l, 'change')).last);
      await t.pumpAndSettle();
      expect(t.widget<TextField>(db).decoration?.labelText, 'dB (-100–100)');

      await add('obs.refresh', ['source'], 4);
      await add('http.request', ['method', 'url', 'contentType', 'body'], 5);
      final url = field(5, 'url');
      final urlError = find.text(ruleText(l, 'invalidHttpUrl'));
      await visible(t, url);
      expect(urlError.hitTestable(), findsOneWidget);
      await t.enterText(url, 'https://example.invalid/announce');
      await t.pumpAndSettle();
      expect(urlError, findsNothing);
      expect(t.widget<TextField>(field(5, 'body')).maxLines, 3);
      expect(t.takeException(), isNull);
    });

    testWidgets('Discord recipe opens with the URL field error in $language',
        (t) async {
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await mount(t, language: language);
      final l = AppLocalizations.of(t.element(find.byType(RulesCard)))!;
      final recipes = find.text(ruleText(l, 'recipes'));
      await visible(t, recipes);
      await t.tap(recipes);
      await t.pumpAndSettle();
      final add = find.byKey(const Key('recipe-add-8'));
      await visible(t, add);
      expect(find.text(ruleText(l, 'recipe8')), findsOneWidget);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.byType(RuleEditorDialog), findsOneWidget);
      expect(find.text(ruleText(l, 'invalidHttpUrl')), findsOneWidget);
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

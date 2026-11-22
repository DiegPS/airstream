import 'rules_sharing.dart';
import 'rules_webhook_card.dart';
import 'dart:async';
import 'package:airstream/settings/settings_notifier.dart';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_recipes.dart';
import 'package:airstream/application/rules/rule_validation.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'settings_controls.dart';
import 'ui_card.dart';
import 'rule_editor_dialog.dart';

String ruleText(AppLocalizations l, String code) => l.ruleLabel(
    'k${code == 'tripped' ? 'trippedReason' : code.replaceAll('.', '_')}');
String freshRuleId() => 'r_${DateTime.now().microsecondsSinceEpoch}';
String ruleSummary(AppLocalizations l, Map<String, dynamic> rule) {
  final t = rule['trigger'] as Map;
  return l.ruleSummary(
      t['type'] == 'chat.command'
          ? t['command'] as String
          : ruleText(l, t['type'] as String),
      (rule['actions'] as List).length);
}

Future<bool> ruleConfirm(BuildContext context, String title,
    {String action = 'delete'}) async {
  final l = AppLocalizations.of(context)!;
  return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(title: Text(title), actions: [
                OutlinedButton(
                    style: dialogSecondaryStyle(),
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(ruleText(l, 'cancel'))),
                OutlinedButton(
                    style: dialogSecondaryStyle(destructive: true),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(ruleText(l, action))),
              ])) ??
      false;
}

class RulesCard extends ConsumerWidget {
  const RulesCard({super.key, this.engine});
  final RuleEngine? engine;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(settingsProvider);
    final e = engine ?? ref.read(appControllerProvider).rules;
    Future<void> write(List<Map<String, dynamic>> rules) =>
        ref.read(settingsProvider.notifier).update(ref
            .read(settingsProvider)
            .copyWith(rules: RuleSchema.sanitize(rules)));
    Future<void> edit(Map<String, dynamic> rule, {bool saved = true}) =>
        showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) =>
                RuleEditorDialog(rule: rule, engine: e, saved: saved));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      UiCard(
          title: ruleText(l, 'rules'),
          icon: Icons.rule_rounded,
          description: ruleText(l, 'description'),
          children: [
            Material(
                color: Colors.transparent,
                child: SwitchListTile(
                    key: const Key('rules-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(ruleText(l, 'automation')),
                    value: s.rulesEnabled,
                    onChanged: (v) => ref
                        .read(settingsProvider.notifier)
                        .update(s.copyWith(rulesEnabled: v)))),
            StreamBuilder<String?>(
                stream: e.trippedStream,
                builder: (context, _) => e.tripped == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: const Key('rules-tripped'),
                        padding: const EdgeInsets.all(10),
                        child: Column(children: [
                          Text(l.ruleLabel('ktripped'),
                              style: const TextStyle(color: Color(0xFFFFB15C))),
                          OutlinedButton(
                              key: const Key('rules-resume'),
                              style: secondarySettingsStyle(),
                              onPressed: e.resetBreaker,
                              child: Text(ruleText(l, 'resume')))
                        ]))),
            ElevatedButton(
                key: const Key('rules-new'),
                style: primarySettingsStyle(),
                onPressed: s.rules.length >= RuleSchema.maxRules
                    ? null
                    : () => edit({
                          ...e.newRule('chat.command', id: freshRuleId()),
                          'name': ruleText(l, 'new')
                        }, saved: false),
                child: Text(ruleText(l, 'new'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                key: const Key('rules-recipes'),
                style: secondarySettingsStyle(),
                onPressed: s.rules.length >= RuleSchema.maxRules
                    ? null
                    : () async {
                        final recipes = RuleRecipes.all;
                        final recipe = await showDialog<int>(
                            context: context,
                            builder: (c) => AlertDialog(
                                    key: const Key('rules-recipes-dialog'),
                                    title: Text(ruleText(l, 'recipes')),
                                    content: SizedBox(
                                        width: 580,
                                        child: SingleChildScrollView(
                                            padding: const EdgeInsets.only(
                                                right: 14),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (var n = 1;
                                                      n <= recipes.length;
                                                      n++)
                                                    ListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Text(ruleText(
                                                            l, 'recipe$n')),
                                                        subtitle: Text(ruleText(
                                                            l, 'recipeDesc$n')),
                                                        trailing: OutlinedButton(
                                                            key: Key(
                                                                'recipe-add-$n'),
                                                            style:
                                                                secondarySettingsStyle(),
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    c, n),
                                                            child: Text(
                                                                ruleText(
                                                                    l, 'add'))))
                                                ]))),
                                    actions: [
                                      OutlinedButton(
                                          style: dialogSecondaryStyle(),
                                          onPressed: () => Navigator.pop(c),
                                          child: Text(ruleText(l, 'close')))
                                    ]));
                        if (recipe == null) return;
                        final rule = {
                          ...recipes[recipe - 1],
                          'id': freshRuleId(),
                          'name': ruleText(l, 'recipe$recipe')
                        };
                        // The settings state updates at once; the editor
                        // must not wait for (or depend on) the disk write.
                        unawaited(
                            write([...ref.read(settingsProvider).rules, rule]));
                        if (context.mounted) await edit(rule);
                      },
                child: Text(ruleText(l, 'recipes')),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      style: secondarySettingsStyle(),
                      onPressed: () => importRules(context, ref),
                      child: Text(ruleText(l, 'importRules')))),
            ]),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: () => exportRules(context, s.rules),
                    child: Text(ruleText(l, 'exportRules')))),
            if (s.rules.isEmpty) ...[
              const SizedBox(height: 4),
              Text(ruleText(l, 'empty'), style: settingsHintStyle),
              Text(ruleText(l, 'empty2'), style: settingsHintStyle),
            ],
            for (final r in s.rules)
              Builder(builder: (context) {
                final id = r['id'] as String,
                    chat = (r['trigger'] as Map)['type']
                        .toString()
                        .startsWith('chat.');
                return Padding(
                    key: Key('rule-$id'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Switch(
                                key: Key('rule-enabled-$id'),
                                value: r['enabled'] == true,
                                onChanged: r['invalid'] == true
                                    ? null
                                    : (v) => write([
                                          for (final old in s.rules)
                                            if (old['id'] == id)
                                              {...old, 'enabled': v}
                                            else
                                              old
                                        ])),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(r['name'] as String,
                                    style: settingsItemTitleStyle)),
                            PopupMenuButton<String>(
                                key: Key('rule-menu-$id'),
                                onSelected: (v) async {
                                  if (v == 'exportRules') {
                                    await exportRules(context, [r]);
                                  }
                                  if (v == 'edit') {
                                    await edit(r);
                                  }
                                  if (v == 'duplicate') {
                                    await write([
                                      ...s.rules,
                                      {
                                        ...jsonDecode(jsonEncode(r))
                                            as Map<String, dynamic>,
                                        'id': freshRuleId(),
                                        'name':
                                            '${r['name']} (${ruleText(l, 'copy')})',
                                        'enabled': false,
                                        'trigger': {
                                          ...r['trigger'] as Map,
                                          if (r['trigger']['type'] == 'manual')
                                            'webhook': ''
                                        }
                                      }
                                    ]);
                                  }
                                  if (v == 'delete' &&
                                      context.mounted &&
                                      await ruleConfirm(context,
                                          ruleText(l, 'confirmDelete'))) {
                                    await write(s.rules
                                        .where((x) => x['id'] != id)
                                        .toList());
                                  }
                                },
                                itemBuilder: (_) => [
                                      for (final v in [
                                        'edit',
                                        'exportRules',
                                        'duplicate',
                                        'delete'
                                      ])
                                        PopupMenuItem(
                                            value: v,
                                            enabled: v != 'duplicate' ||
                                                s.rules.length <
                                                    RuleSchema.maxRules,
                                            child: Text(ruleText(l, v)))
                                    ])
                          ]),
                          Text(ruleSummary(l, r),
                              style: settingsHintStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          for (final warning in [
                            if (r['invalid'] == true) 'invalid',
                            if (isPublicChatRule(r) &&
                                (r['actions'] as List).any((a) =>
                                    a['type'].toString().startsWith('obs.')))
                              'publicObs',
                            if (showsPublicChatText(r)) 'publicChatText',
                            if (chat && r['cooldownSeconds'] == 0) 'noCooldown'
                          ])
                            Text(ruleText(l, warning),
                                style: const TextStyle(
                                    color: Color(0xFFFFB15C),
                                    fontSize: 11,
                                    height: 1.3)),
                        ]));
              }),
          ]),
      RulesWebhookCard(
          baseUrl: engine == null ? ref.watch(overlayUrlProvider) : null),
      RuleHistoryCard(engine: e),
    ]);
  }
}

class RuleHistoryCard extends StatefulWidget {
  const RuleHistoryCard({super.key, required this.engine});
  final RuleEngine engine;
  @override
  State<RuleHistoryCard> createState() => _RuleHistoryCardState();
}

class _RuleHistoryCardState extends State<RuleHistoryCard> {
  final hidden = <String>{};
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<List<RuleRun>>(
        stream: widget.engine.historyStream,
        initialData: widget.engine.history,
        builder: (context, snapshot) {
          final runs = (snapshot.data ?? [])
              .where((r) => !hidden.contains(r.id))
              .take(50)
              .toList();
          return UiCard(
              key: const Key('rules-history'),
              title: ruleText(l, 'history'),
              icon: Icons.history_rounded,
              trailing: TextButton(
                  onPressed: () => setState(() =>
                      hidden.addAll(widget.engine.history.map((r) => r.id))),
                  child: Text(ruleText(l, 'clear'))),
              children: [
                if (runs.isEmpty)
                  Text(ruleText(l, 'noHistory'), style: settingsHintStyle),
                for (final r in runs)
                  Material(
                      color: Colors.transparent,
                      child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(r.ruleName),
                          subtitle: Text(
                              '${TimeOfDay.fromDateTime(r.startedAt).format(context)} · ${ruleText(l, r.triggerSummary)}\n${r.results.map((a) => '${ruleText(l, a.status)}${a.reason == null ? '' : ': ${ruleText(l, a.reason!)}'}').join(' · ')}'),
                          children: [
                            for (var i = 0;
                                i < (r.rule['actions'] as List).length;
                                i++)
                              ListTile(
                                  title: Text(ruleText(
                                      l,
                                      (r.rule['actions'] as List)[i]['type']
                                          as String)),
                                  subtitle: Text(i < r.results.length
                                      ? '${ruleText(l, r.results[i].status)} ${r.results[i].reason == null ? '' : ruleText(l, r.results[i].reason!)}'
                                      : ruleText(l, 'pending')))
                          ]))
              ]);
        });
  }
}

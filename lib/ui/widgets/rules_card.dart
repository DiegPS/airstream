import 'rules_sharing.dart';
import 'rules_webhook_card.dart';
import 'dart:convert';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_model.dart';
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

void ruleFeedback(BuildContext context, String code) {
  final l = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(ruleText(l, code))));
}

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
          builder: (c) =>
              AlertDialog(scrollable: true, title: Text(title), actions: [
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

class RulesCard extends ConsumerStatefulWidget {
  const RulesCard({super.key, this.engine});
  final RuleEngine? engine;
  @override
  ConsumerState<RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends ConsumerState<RulesCard> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ready = ref.watch(settingsProvider.notifier).ready;
    final baseUrl =
        widget.engine == null ? ref.watch(overlayUrlProvider) : null;
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        final l = AppLocalizations.of(context)!;
        if (snapshot.hasError) {
          return Text(ruleText(l, 'loadFailed'),
              style:
                  settingsBodyStyle.copyWith(color: const Color(0xFFFF6B6B)));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Text(ruleText(l, 'loading'), style: settingsBodyStyle);
        }
        return _buildSettings(context, s, baseUrl);
      },
    );
  }

  Widget _buildSettings(
      BuildContext context, SettingsModel s, String? baseUrl) {
    final l = AppLocalizations.of(context)!;
    final e = widget.engine ?? ref.read(appControllerProvider).rules;
    final atLimit = s.rules.length >= RuleSchema.maxRules;
    final notifier = ref.read(settingsProvider.notifier);

    Future<bool> write(
        List<Map<String, dynamic>> Function(List<Map<String, dynamic>>)
            change) async {
      var changed = false;
      try {
        await notifier.updateLatest((current) {
          final rules = change(current.rules);
          changed = !identical(rules, current.rules);
          return changed
              ? current.copyWith(rules: RuleSchema.sanitize(rules))
              : current;
        });
        return changed;
      } catch (_) {
        if (context.mounted) ruleFeedback(context, 'saveFailed');
        return false;
      }
    }

    Future<bool> addRule(Map<String, dynamic> rule) => write((rules) {
          if (rules.length < RuleSchema.maxRules) return [...rules, rule];
          if (context.mounted) ruleFeedback(context, 'rulesLimit');
          return rules;
        });

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
                    title: Text(ruleText(l, 'automation'),
                        style: settingsBodyStyle),
                    value: s.rulesEnabled,
                    onChanged: (v) async {
                      try {
                        await notifier.updateLatest(
                            (current) => current.copyWith(rulesEnabled: v));
                      } catch (_) {
                        if (context.mounted) {
                          ruleFeedback(context, 'saveSettingsFailed');
                        }
                      }
                    })),
            StreamBuilder<String?>(
                stream: e.trippedStream,
                builder: (context, _) => e.tripped == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: const Key('rules-tripped'),
                        padding: const EdgeInsets.all(10),
                        child: Column(children: [
                          Text(l.ruleLabel('ktripped'),
                              style: settingsBodyStyle.copyWith(
                                  color: const Color(0xFFFFB15C))),
                          OutlinedButton(
                              key: const Key('rules-resume'),
                              style: secondarySettingsStyle(),
                              onPressed: e.resetBreaker,
                              child: Text(ruleText(l, 'resume')))
                        ]))),
            ElevatedButton(
                key: const Key('rules-new'),
                style: primarySettingsStyle(),
                onPressed: atLimit
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
                onPressed: atLimit
                    ? null
                    : () async {
                        final recipes = RuleRecipes.all;
                        final recipe = await showDialog<int>(
                            context: context,
                            builder: (c) => AlertDialog(
                                    key: const Key('rules-recipes-dialog'),
                                    insetPadding: const EdgeInsets.all(16),
                                    contentPadding: const EdgeInsets.all(16),
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
                        if (recipe == null || !context.mounted) return;
                        final rule = {
                          ...recipes[recipe - 1],
                          'id': freshRuleId(),
                          'name': ruleText(l, 'recipe$recipe')
                        };
                        if (await addRule(rule) && context.mounted) {
                          await edit(rule);
                        }
                      },
                child: Text(ruleText(l, 'recipes')),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton(
                      style: secondarySettingsStyle(),
                      onPressed: _importing
                          ? null
                          : () async {
                              setState(() => _importing = true);
                              try {
                                await importRules(context, ref);
                              } finally {
                                if (mounted) setState(() => _importing = false);
                              }
                            },
                      child: Text(ruleText(
                          l, _importing ? 'importing' : 'importRules')))),
            ]),
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: () => exportRules(context, s.rules),
                    child: Text(ruleText(l, 'exportRules')))),
            if (atLimit)
              Text(ruleText(l, 'rulesLimit'), style: settingsHintStyle),
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
                                    : (v) => write((rules) => [
                                          for (final old in rules)
                                            if (old['id'] == id)
                                              {...old, 'enabled': v}
                                            else
                                              old
                                        ])),
                            const SizedBox(width: 6),
                            // Summary under the name, not under the switch.
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(r['name'] as String,
                                      style: settingsItemTitleStyle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  Text(ruleSummary(l, r),
                                      style: settingsHintStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ])),
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
                                    // Deep copy: the duplicate must not share
                                    // its actions or trigger maps with r.
                                    await addRule({
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
                                    });
                                  }
                                  if (v == 'delete' &&
                                      context.mounted &&
                                      await ruleConfirm(context,
                                          ruleText(l, 'confirmDelete'))) {
                                    await write((rules) => rules
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
                                            child: Text(ruleText(l, v),
                                                style: v == 'delete'
                                                    ? const TextStyle(
                                                        color:
                                                            Color(0xFFFF6B6B))
                                                    : null))
                                    ])
                          ]),
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
                                style: settingsHintStyle.copyWith(
                                    color: const Color(0xFFFFB15C))),
                        ]));
              }),
          ]),
      RulesWebhookCard(baseUrl: baseUrl),
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
          final history = snapshot.data ?? const <RuleRun>[];
          if (hidden.isNotEmpty) hidden.retainAll(history.map((run) => run.id));
          final runs = history.where((r) => !hidden.contains(r.id));
          return UiCard(
              key: const Key('rules-history'),
              title: ruleText(l, 'history'),
              icon: Icons.history_rounded,
              trailing: TextButton(
                  onPressed: runs.isEmpty
                      ? null
                      : () => setState(() => hidden
                          .addAll(widget.engine.history.map((r) => r.id))),
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

import 'dart:async';
import 'package:airstream/settings/settings_notifier.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:airstream/application/rules/rule_engine.dart';

import 'package:airstream/application/rules/rule_events.dart';

import 'package:airstream/application/rules/rule_model.dart';

import 'package:airstream/application/rules/rule_validation.dart';

import 'package:airstream/l10n/generated/app_localizations.dart';

import 'settings_controls.dart';

import 'rules_card.dart';

class RuleEditorDialog extends ConsumerStatefulWidget {
  const RuleEditorDialog(
      {super.key, required this.rule, required this.engine, this.saved = true});

  final Map<String, dynamic> rule;

  final RuleEngine engine;

  final bool saved;

  @override
  ConsumerState<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<RuleEditorDialog> {
  late Map<String, dynamic> draft;

  late String baseline;

  late bool saved;
  final _resultKey = GlobalKey();

  final controllers = <String, TextEditingController>{};

  String? sampleText, sampleAmount, notice;

  RuleSimulation? simulation;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    draft = jsonDecode(jsonEncode(widget.rule)) as Map<String, dynamic>;

    if (draft['trigger']['type'] == 'manual' &&
        (draft['trigger']['webhook'] as String? ?? '').isEmpty) {
      draft['trigger']['webhook'] = suggestWebhook(draft['name'] as String);
    }
    baseline = jsonEncode(draft);

    saved = widget.saved;
  }

  Map<String, String> get problems {
    final result = ruleProblems(draft);
    final t = draft['trigger'] as Map;
    final name = t['webhook'];
    if (t['type'] == 'manual' &&
        name is String &&
        name.isNotEmpty &&
        ref.read(settingsProvider).rules.any((r) =>
            r['id'] != draft['id'] &&
            r['trigger']['type'] == 'manual' &&
            r['trigger']['webhook'] == name)) {
      result['trigger-webhook'] = 'webhookConflict';
    }
    return result;
  }

  String suggestWebhook(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.substring(0, slug.length.clamp(0, 40));
  }

  bool get dirty => baseline != jsonEncode(draft);

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  void change(VoidCallback mutation) => setState(() {
        mutation();
        simulation = null;
        notice = null;
      });

  Future<void> close() async {
    if (dirty || !saved) {
      final l = AppLocalizations.of(context)!;
      if (!await ruleConfirm(context, ruleText(l, 'discard'),
          action: 'discardAction')) {
        return;
      }
    }

    if (mounted) Navigator.pop(context);
  }

  String group(String type, {bool action = false}) {
    if (type.startsWith('obs.')) return 'obs';

    if (type.startsWith('chat.')) return 'chat';

    if (type.startsWith('support.')) return 'support';

    if (type == 'interval') return 'time';

    if (type == 'manual') return 'manual';

    if (type == 'wait') return 'flow';

    if (type == 'tts.say') return 'voice';

    if (type == 'sound.play') return 'sound';

    if (['alert.show', 'featured', 'template.trigger'].contains(type)) {
      return 'pages';
    }

    return 'live';
  }

  List<DropdownMenuItem<String>> types(Iterable<String> values) {
    final l = AppLocalizations.of(context)!;

    return [
      for (final g in [
        'chat',
        'support',
        'live',
        'obs',
        'time',
        'manual',
        'flow',
        'voice',
        'sound',
        'pages'
      ])
        if (values.any((t) => group(t) == g)) ...[
          DropdownMenuItem(
              value: 'group_$g',
              enabled: false,
              child: Text(ruleText(l, g),
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          for (final t in values.where((t) => group(t) == g))
            DropdownMenuItem(
                value: t,
                child: Text(ruleText(l, t), overflow: TextOverflow.ellipsis)),
        ]
    ];
  }

  Widget input(
      String path, String label, Object? value, void Function(Object) update,
      {RuleField? field,
      List<String> placeholders = const [],
      Map<String, String>? options,
      String? hint}) {
    final l = AppLocalizations.of(context)!;

    final problem = problems[path];

    final decoration = settingsInput(
            hint: hint, error: problem == null ? null : ruleText(l, problem))
        .copyWith(labelText: label);

    Widget child;

    if (options != null || field?.choices != null) {
      final choices =
          options ?? {for (final v in field!.choices!) v: ruleText(l, v)};
      // Preserve references to removed goals or media so users can repair them.
      final selected = value?.toString() ?? '';
      final items = {
        ...choices,
        if (!choices.containsKey(selected)) selected: selected
      };
      child = DropdownButtonFormField<String>(
          key: Key('rule-$path'),
          initialValue: selected,
          isExpanded: true,
          decoration: decoration,
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (v) {
            if (v != null) change(() => update(v));
          });
    } else if (field?.fallback is bool) {
      child = SwitchListTile(
          key: Key('rule-$path'),
          title: Text(label),
          value: value == true,
          onChanged: (v) => change(() => update(v)));
    } else {
      final c = controllers.putIfAbsent(
          path, () => TextEditingController(text: '$value'));
      if (c.text != '$value') {
        c.value = TextEditingValue(
            text: '$value',
            selection: TextSelection.collapsed(offset: '$value'.length));
      }
      child = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
            key: Key('rule-$path'),
            controller: c,
            decoration: decoration,
            keyboardType: field?.numeric == true
                ? const TextInputType.numberWithOptions(
                    signed: true, decimal: true)
                : TextInputType.text,
            onChanged: (v) => change(() =>
                update(field?.numeric == true ? num.tryParse(v) ?? v : v))),
        if (placeholders.isNotEmpty)
          Wrap(spacing: 4, children: [
            for (final p in placeholders)
              ActionChip(
                  label: Text('{$p}', style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    final selection = c.selection;
                    final start =
                            selection.isValid ? selection.start : c.text.length,
                        end = selection.isValid ? selection.end : c.text.length;
                    c.value = TextEditingValue(
                        text: c.text.replaceRange(start, end, '{$p}'),
                        selection: TextSelection.collapsed(
                            offset: start + p.length + 2));
                    change(() => update(c.text));
                  })
          ]),
      ]);
    }

    return Padding(padding: const EdgeInsets.only(top: 14), child: child);
  }

  RuleEvent event() {
    final e =
        widget.engine.sampleEvent((draft['trigger'] as Map)['type'] as String);

    return RuleEvent(
        type: e.type,
        platform: e.platform,
        author: e.author,
        text: sampleText ?? e.text,
        amount: sampleAmount == null ? e.amount : num.tryParse(sampleAmount!),
        currency: e.currency,
        presentationAmount: sampleAmount ?? e.presentationAmount,
        count: e.count,
        note: e.note,
        position: e.position,
        winner: e.winner,
        total: e.total,
        months: e.months,
        scene: e.scene,
        goalId: e.goalId,
        message: e.message);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        settings = ref.watch(settingsProvider);

    final t = draft['trigger'] as Map<String, dynamic>,
        type = t['type'] as String;

    final actions = draft['actions'] as List,
        conditions = draft['conditions'] as Map;

    final meaningful = type.startsWith('chat.') || type.startsWith('support.');

    final placeholders = [
      'platform',
      if (meaningful) ...['user', 'message'],
      if (type == 'queue.joined') ...['user', 'note', 'position'],
      if (type == 'queue.next') ...['user', 'count'],
      if (type == 'poll.ended') ...['winner', 'total'],
      if (type == 'chat.command') ...[
        'args',
        for (var i = 1; i <= 9; i++) 'arg$i'
      ],
      if (type == 'support.superchat') 'amount',
      if (type.startsWith('support.')) ...['count', 'months'],
      if (type.startsWith('obs.')) 'scene',
      for (final c in settings.ruleCounters.keys) 'counter.$c',
      if (actions.any((a) => a['type'] == 'counter'))
        for (final a in actions.where((a) => a['type'] == 'counter'))
          'counter.${a['name']}'
    ];

    Widget section(String name) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 4),
        child: Text(ruleText(l, name),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)));

    List<Widget> params(Map<String, dynamic> map, Map<String, RuleField> schema,
            String prefix) =>
        [
          for (final e in schema.entries)
            input(
                '$prefix-${e.key}',
                '${ruleText(l, e.key)}${e.value.numeric ? ' (${e.value.min}–${e.value.max})' : ''}',
                map[e.key] ?? (e.key == 'webhook' ? '' : null),
                (v) => map[e.key] = v,
                field: e.value,
                hint: e.key == 'scene' &&
                        widget.engine.target.currentScene.isNotEmpty
                    ? widget.engine.target.currentScene
                    : null,
                placeholders: !e.value.numeric &&
                        e.value.choices == null &&
                        ['text', 'title', 'data'].contains(e.key)
                    ? placeholders.toSet().toList()
                    : const [],
                options: e.key == 'goalId'
                    ? {
                        '': '—',
                        for (final g in settings.goals.entries)
                          g.key: g.value['title']?.toString() ?? g.key
                      }
                    : e.key == 'mediaId'
                        ? {
                            '': '—',
                            for (final m in settings.mediaLibrary.entries.where(
                                (m) => map['type'] == 'sound.play'
                                    ? m.value['kind'] == 'audio'
                                    : ['image', 'video']
                                        .contains(m.value['kind'])))
                              m.key: m.value['name'].toString()
                          }
                        : null)
        ];

    final valid = problems.isEmpty;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: Dialog(
            key: const Key('rule-editor'),
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
                width: 820,
                height: MediaQuery.sizeOf(context).height * .88,
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    saved &&
                                            (draft['name'] as String? ?? '')
                                                .isNotEmpty
                                        ? draft['name'] as String
                                        : ruleText(l, 'new'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 20))),
                            IconButton(
                                tooltip: ruleText(l, 'close'),
                                onPressed: close,
                                icon: const Icon(Icons.close))
                          ]),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                input('name', ruleText(l, 'name'),
                                    draft['name'], (v) => draft['name'] = v),
                                section('when'),
                                DropdownButtonFormField<String>(
                                    key: const Key('rule-trigger'),
                                    initialValue: type,
                                    isExpanded: true,
                                    decoration: settingsInput(),
                                    items: [
                                      if (!RuleSchema.triggers
                                          .containsKey(type))
                                        DropdownMenuItem(
                                            value: type,
                                            child:
                                                Text(ruleText(l, 'invalid'))),
                                      ...types(RuleSchema.triggers.keys)
                                    ],
                                    onChanged: (v) {
                                      if (v == null) return;
                                      change(() {
                                        final fresh = widget.engine.newRule(v,
                                            id: draft['id'] as String);
                                        draft['trigger'] = fresh['trigger'];
                                        if (v == 'manual') {
                                          draft['trigger']['webhook'] =
                                              suggestWebhook(
                                                  draft['name'] as String);
                                        }
                                        if (!saved) {
                                          draft['cooldownSeconds'] =
                                              fresh['cooldownSeconds'];
                                        }
                                        sampleText = null;
                                        sampleAmount = null;
                                      });
                                    }),
                                ...params(t, RuleSchema.triggers[type] ?? {},
                                    'trigger'),
                                section('if'),
                                if (meaningful ||
                                    type.startsWith('queue.')) ...[
                                  Wrap(spacing: 6, children: [
                                    for (final p in RuleSchema.platforms)
                                      FilterChip(
                                          label: Text({
                                            'youtube': 'YouTube',
                                            'twitch': 'Twitch',
                                            'kick': 'Kick'
                                          }[p]!),
                                          selected:
                                              (conditions['platforms'] as List)
                                                  .contains(p),
                                          onSelected: (v) => change(() {
                                                final list =
                                                    conditions['platforms']
                                                        as List;
                                                v
                                                    ? list.add(p)
                                                    : list.remove(p);
                                              }))
                                  ]),
                                  Wrap(spacing: 6, children: [
                                    for (final r in RuleSchema.roles)
                                      FilterChip(
                                          label: Text(ruleText(l, r)),
                                          // No role filter means everyone.
                                          selected: (conditions['roles']
                                                      as List)
                                                  .contains(r) ||
                                              (r == 'everyone' &&
                                                  (conditions['roles'] as List)
                                                      .isEmpty),
                                          onSelected: (v) => change(() {
                                                final list =
                                                    conditions['roles'] as List;
                                                if (r == 'everyone') {
                                                  list.clear();
                                                  if (v) list.add(r);
                                                } else {
                                                  list.remove('everyone');
                                                  v
                                                      ? list.add(r)
                                                      : list.remove(r);
                                                }
                                              }))
                                  ])
                                ],
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title:
                                        Text(ruleText(l, 'onlyWhileStreaming')),
                                    value: conditions['onlyWhileStreaming'] ==
                                        true,
                                    onChanged: (v) => change(() =>
                                        conditions['onlyWhileStreaming'] = v)),
                                section('do'),
                                if (showsPublicChatText(draft))
                                  Text(ruleText(l, 'publicChatText'),
                                      style: const TextStyle(
                                          color: Color(0xFFFFB15C))),
                                for (var i = 0; i < actions.length; i++)
                                  Container(
                                      key: ValueKey(actions[i]['id']),
                                      margin: const EdgeInsets.only(top: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E),
                                          border: Border.all(
                                              color: const Color(0xFF2E2E2E)),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Text(
                                                '${i + 1}. ${ruleText(l, actions[i]['type'] as String)}'),
                                            Wrap(children: [
                                              IconButton(
                                                  tooltip: ruleText(l, 'up'),
                                                  onPressed: i == 0
                                                      ? null
                                                      : () => change(() {
                                                            final a = actions
                                                                .removeAt(i);
                                                            actions.insert(
                                                                i - 1, a);
                                                          }),
                                                  icon: const Icon(
                                                      Icons.arrow_upward)),
                                              IconButton(
                                                  tooltip: ruleText(l, 'down'),
                                                  onPressed: i ==
                                                          actions.length - 1
                                                      ? null
                                                      : () => change(() {
                                                            final a = actions
                                                                .removeAt(i);
                                                            actions.insert(
                                                                i + 1, a);
                                                          }),
                                                  icon: const Icon(
                                                      Icons.arrow_downward)),
                                              IconButton(
                                                  tooltip:
                                                      ruleText(l, 'delete'),
                                                  color:
                                                      const Color(0xFFFF6B6B),
                                                  onPressed: () => change(() {
                                                        actions.removeAt(i);
                                                      }),
                                                  icon: const Icon(
                                                      Icons.delete_outline))
                                            ]),
                                            ...params(
                                                actions[i]
                                                    as Map<String, dynamic>,
                                                RuleSchema.actions[actions[i]
                                                        ['type']] ??
                                                    {},
                                                'action-$i')
                                          ])),
                                PopupMenuButton<String>(
                                    key: const Key('rule-add-action'),
                                    enabled:
                                        actions.length < RuleSchema.maxActions,
                                    onSelected: (v) =>
                                        change(() => actions.add({
                                              'id': freshRuleId(),
                                              'type': v,
                                              for (final f in RuleSchema
                                                  .actions[v]!.entries)
                                                f.key: f.value.fallback
                                            })),
                                    itemBuilder: (_) => [
                                          for (final g in [
                                            'flow',
                                            'obs',
                                            'voice',
                                            'sound',
                                            'pages',
                                            'live'
                                          ]) ...[
                                            PopupMenuItem<String>(
                                                enabled: false,
                                                child: Text(ruleText(l, g))),
                                            for (final a in RuleSchema
                                                .actions.keys
                                                .where((a) => group(a) == g))
                                              PopupMenuItem(
                                                  value: a,
                                                  child: Text(ruleText(l, a)))
                                          ]
                                        ],
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                            '+ ${ruleText(l, 'addAction')}'))),
                                section('limits'),
                                for (final k in [
                                  'cooldownSeconds',
                                  'userCooldownSeconds'
                                ])
                                  input(k, ruleText(l, k), draft[k],
                                      (v) => draft[k] = v,
                                      field: const RuleField.number(0, 3600)),
                                input(
                                    'overlap',
                                    ruleText(l, 'overlap'),
                                    draft['overlap'],
                                    (v) => draft['overlap'] = v,
                                    field: const RuleField.choice(
                                        ['queue', 'skip'], 'queue')),
                                section('testWith'),
                                TextField(
                                    key: const Key('rule-sample-text'),
                                    decoration:
                                        settingsInput(hint: event().text)
                                            .copyWith(
                                                labelText: ruleText(l, 'text')),
                                    onChanged: (v) => setState(() {
                                          sampleText = v;
                                          simulation = null;
                                        })),
                                if (type == 'support.superchat')
                                  TextField(
                                      key: const Key('rule-sample-amount'),
                                      decoration: settingsInput(hint: '5')
                                          .copyWith(
                                              labelText:
                                                  ruleText(l, 'minAmount')),
                                      onChanged: (v) => setState(() {
                                            sampleAmount = v;
                                            simulation = null;
                                          })),
                                if (simulation != null)
                                  KeyedSubtree(
                                      key: _resultKey,
                                      child: Container(
                                          key: const Key('rule-test-result'),
                                          margin: const EdgeInsets.only(top: 8),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E1E),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: simulation!.matched
                                                      ? const Color(0xFF53FC18)
                                                      : const Color(
                                                          0xFFFFB15C))),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(ruleText(
                                                    l,
                                                    simulation!.reason ??
                                                        'matched')),
                                                for (var i = 0;
                                                    i <
                                                        simulation!
                                                            .actions.length;
                                                    i++)
                                                  Text(
                                                      '${ruleText(l, simulation!.actions[i]['type'] as String)}${[
                                                    for (final v in simulation!
                                                        .actions[i].entries
                                                        .where((e) => ![
                                                              'type',
                                                              'id'
                                                            ].contains(e.key))
                                                        .map((e) =>
                                                            '${e.value}'))
                                                      if (v.isNotEmpty) v
                                                  ].map((v) => ' · $v').join()}\n${ruleText(l, simulation!.results[i].status == 'skipped' ? 'wouldSkip' : simulation!.results[i].status)}${simulation!.results[i].reason == null ? '' : ': ${ruleText(l, simulation!.results[i].reason!)}'}')
                                              ]))),
                                if (notice != null) Text(ruleText(l, notice!)),
                                if (!valid)
                                  Text(ruleText(l, 'invalid'),
                                      style: const TextStyle(
                                          color: Color(0xFFFFB15C))),
                              ]))),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton(
                                    key: const Key('rule-test'),
                                    style: secondarySettingsStyle(),
                                    onPressed: valid
                                        ? () {
                                            setState(() => simulation =
                                                    widget.engine.simulate({
                                                  ...draft,
                                                  'invalid': false,
                                                  'enabled': true
                                                }, event()));
                                            // The result sits under the
                                            // actions: bring it into view.
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                              final target =
                                                  _resultKey.currentContext;
                                              if (target != null &&
                                                  target.mounted) {
                                                unawaited(
                                                    Scrollable.ensureVisible(
                                                        target,
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    200)));
                                              }
                                            });
                                          }
                                        : null,
                                    child: Text(ruleText(l, 'test'))),
                                OutlinedButton(
                                    key: const Key('rule-run'),
                                    style: secondarySettingsStyle(),
                                    onPressed: saved && !dirty && valid
                                        ? () => setState(() => notice =
                                            widget.engine.runNow(
                                                    draft['id'] as String,
                                                    event()) ??
                                                'accepted')
                                        : null,
                                    child: Text(ruleText(l, 'run'))),
                                ElevatedButton(
                                    key: const Key('rule-save'),
                                    style: primarySettingsStyle().copyWith(
                                        minimumSize:
                                            const WidgetStatePropertyAll(
                                                Size(100, 40))),
                                    onPressed: valid && !saving
                                        ? () async {
                                            setState(() => saving = true);
                                            final clean = RuleSchema.sanitize([
                                              {...draft, 'invalid': false}
                                            ]).single;
                                            final current =
                                                ref.read(settingsProvider);
                                            await ref
                                                .read(settingsProvider.notifier)
                                                .update(current.copyWith(
                                                    rules: RuleSchema.sanitize([
                                                  for (final r in current.rules)
                                                    if (r['id'] == clean['id'])
                                                      clean
                                                    else
                                                      r,
                                                  if (!current.rules.any((r) =>
                                                      r['id'] == clean['id']))
                                                    clean
                                                ])));
                                            if (mounted) {
                                              setState(() {
                                                draft = clean;
                                                baseline = jsonEncode(clean);
                                                saved = true;
                                                saving = false;
                                              });
                                            }
                                          }
                                        : null,
                                    child: Text(ruleText(l, 'save')))
                              ]),
                        ])))));
  }
}

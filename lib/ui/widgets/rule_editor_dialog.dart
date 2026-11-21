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
import 'ui_card.dart';

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

  Future<void> _save() async {
    setState(() {
      saving = true;
      notice = null;
    });
    try {
      final clean = RuleSchema.sanitize([
        {...draft, 'invalid': false}
      ]).single;
      final current = ref.read(settingsProvider);
      final id = clean['id'];
      final rules = [
        for (final rule in current.rules) rule['id'] == id ? clean : rule,
        if (!current.rules.any((rule) => rule['id'] == id)) clean,
      ];
      await ref
          .read(settingsProvider.notifier)
          .update(current.copyWith(rules: RuleSchema.sanitize(rules)));
      if (mounted) {
        setState(() {
          draft = clean;
          baseline = jsonEncode(clean);
          saved = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => notice = 'saveFailed');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

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
      String? hint,
      bool multiline = false}) {
    final l = AppLocalizations.of(context)!;

    final problem = problems[path];

    // The label sits above the field, as everywhere else in the app.
    final decoration = settingsInput(
            hint: hint, error: problem == null ? null : ruleText(l, problem))
        .copyWith(errorMaxLines: problem == 'publicStreamControl' ? 3 : null);

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
          dropdownColor: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          style: const TextStyle(color: Colors.white, fontSize: 13),
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
            maxLines: multiline ? 3 : 1,
            keyboardType: field?.numeric == true
                ? const TextInputType.numberWithOptions(
                    signed: true, decimal: true)
                : multiline
                    ? TextInputType.multiline
                    : TextInputType.text,
            onChanged: (v) => change(() =>
                update(field?.numeric == true ? num.tryParse(v) ?? v : v))),
        if (placeholders.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 4, runSpacing: 4, children: [
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
        ],
      ]);
    }

    if (field?.fallback is! bool) {
      child = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KeyedSubtree(key: Key('rule-$path-label'), child: settingsLabel(label)),
        child
      ]);
    }
    return Padding(padding: const EdgeInsets.only(top: 12), child: child);
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

  /// Groups the editor's rows into settings-style cards: each [_Section]
  /// marker starts a card holding the rows after it.
  List<Widget> _cards(List<Widget> rows) {
    final cards = <Widget>[];
    _Section? current;
    var group = <Widget>[];
    void flush() {
      if (current case final section?) {
        cards.add(UiCard(
            title: section.title,
            icon: section.icon,
            margin: const EdgeInsets.only(bottom: 10),
            children: [
              // Switch rows paint their splash on a Material inside the card.
              Material(
                  type: MaterialType.transparency,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: group)),
            ]));
      } else {
        cards.addAll(group);
      }
      group = <Widget>[];
    }

    for (final row in rows) {
      if (row is _Section) {
        flush();
        current = row;
      } else {
        group.add(row);
      }
    }
    flush();
    return cards;
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

    // Each section becomes a card like the settings panel's.
    Widget section(String name) => _Section(
        ruleText(l, name),
        switch (name) {
          'when' => Icons.bolt_rounded,
          'if' => Icons.filter_alt_outlined,
          'do' => Icons.play_arrow_rounded,
          'limits' => Icons.timer_outlined,
          _ => Icons.science_outlined,
        });

    List<Widget> params(Map<String, dynamic> map, Map<String, RuleField> schema,
            String prefix) =>
        [
          for (final e in schema.entries)
            input(
                '$prefix-${e.key}',
                '${ruleText(l, map['type'] == 'giveaway' && e.key == 'count' ? 'winnerCount' : e.key)}${e.value.numeric ? ' (${e.value.min}–${e.value.max})' : ''}',
                map[e.key] ??
                    (e.key == 'webhook'
                        ? ''
                        : map['type'] == 'giveaway' && e.key == 'count'
                            ? e.value.fallback
                            : null), (v) {
              map[e.key] = v;
              if (map['type'] == 'clock' && e.key == 'op' && v == 'add') {
                map.putIfAbsent('seconds', () => 0);
              }
            },
                field: e.value,
                multiline: e.key == 'body',
                hint: e.key == 'scene' &&
                        widget.engine.target.currentScene.isNotEmpty
                    ? widget.engine.target.currentScene
                    : null,
                placeholders: !e.value.numeric &&
                        e.value.choices == null &&
                        ['text', 'title', 'data', 'body'].contains(e.key)
                    ? placeholders.toSet().toList()
                    : const [],
                options: switch ((map['type'], e.key)) {
                  ('obs.stream', 'state') => {
                      'start': ruleText(l, 'streamStart'),
                      'stop': ruleText(l, 'streamStop')
                    },
                  ('obs.replay', 'op') => {
                      'save': ruleText(l, 'replaySave'),
                      'start': ruleText(l, 'start'),
                      'stop': ruleText(l, 'stop')
                    },
                  (_, 'goalId') => {
                      '': '—',
                      for (final g in settings.goals.entries)
                        g.key: g.value['title']?.toString() ?? g.key
                    },
                  (_, 'mediaId') => {
                      '': '—',
                      for (final m in settings.mediaLibrary.entries.where((m) =>
                          map['type'] == 'sound.play'
                              ? m.value['kind'] == 'audio'
                              : ['image', 'video'].contains(m.value['kind'])))
                        m.key: m.value['name'].toString()
                    },
                  _ => null,
                })
        ];

    final valid = problems.isEmpty;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: Dialog(
            key: const Key('rule-editor'),
            // The settings panel's background, so its cards stand out the same.
            backgroundColor: const Color(0xFF141414),
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
                width: 820,
                height: MediaQuery.sizeOf(context).height * .88,
                child: SettingsPanelTheme(
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
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700))),
                                IconButton(
                                    tooltip: ruleText(l, 'close'),
                                    onPressed: close,
                                    color: Colors.white70,
                                    icon: const Icon(Icons.close_rounded,
                                        size: 20))
                              ]),
                              Expanded(
                                  child: SingleChildScrollView(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: _cards([
                                            input(
                                                'name',
                                                ruleText(l, 'name'),
                                                draft['name'],
                                                (v) => draft['name'] = v),
                                            const SizedBox(height: 12),
                                            section('when'),
                                            DropdownButtonFormField<String>(
                                                key: const Key('rule-trigger'),
                                                initialValue: type,
                                                isExpanded: true,
                                                decoration: settingsInput(),
                                                dropdownColor:
                                                    const Color(0xFF1E1E1E),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                menuMaxHeight: 420,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13),
                                                items: [
                                                  if (!RuleSchema.triggers
                                                      .containsKey(type))
                                                    DropdownMenuItem(
                                                        value: type,
                                                        child: Text(ruleText(
                                                            l, 'invalid'))),
                                                  ...types(
                                                      RuleSchema.triggers.keys)
                                                ],
                                                onChanged: (v) {
                                                  if (v == null) return;
                                                  change(() {
                                                    final fresh = widget.engine
                                                        .newRule(v,
                                                            id: draft['id']
                                                                as String);
                                                    draft['trigger'] =
                                                        fresh['trigger'];
                                                    if (!RuleSchema
                                                        .supportsPlatformFilter(
                                                            v)) {
                                                      conditions['platforms'] =
                                                          <String>[];
                                                    }
                                                    if (!RuleSchema
                                                        .supportsRoleFilter(
                                                            v)) {
                                                      conditions['roles'] =
                                                          <String>[];
                                                    }
                                                    if (v == 'manual') {
                                                      draft['trigger']
                                                              ['webhook'] =
                                                          suggestWebhook(
                                                              draft['name']
                                                                  as String);
                                                    }
                                                    if (!saved) {
                                                      draft['cooldownSeconds'] =
                                                          fresh[
                                                              'cooldownSeconds'];
                                                    }
                                                    sampleText = null;
                                                    sampleAmount = null;
                                                  });
                                                }),
                                            ...params(
                                                t,
                                                RuleSchema.triggers[type] ?? {},
                                                'trigger'),
                                            section('if'),
                                            if (RuleSchema
                                                .supportsPlatformFilter(type))
                                              Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    for (final p
                                                        in RuleSchema.platforms)
                                                      FilterChip(
                                                          label: Text({
                                                            'youtube':
                                                                'YouTube',
                                                            'twitch': 'Twitch',
                                                            'kick': 'Kick'
                                                          }[p]!),
                                                          selected: (conditions[
                                                                      'platforms']
                                                                  as List)
                                                              .contains(p),
                                                          onSelected:
                                                              (v) => change(() {
                                                                    final list =
                                                                        conditions['platforms']
                                                                            as List;
                                                                    v
                                                                        ? list.add(
                                                                            p)
                                                                        : list.remove(
                                                                            p);
                                                                  }))
                                                  ]),
                                            if (RuleSchema.supportsRoleFilter(
                                                type)) ...[
                                              const SizedBox(height: 6),
                                              Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    for (final r
                                                        in RuleSchema.roles)
                                                      FilterChip(
                                                          label: Text(
                                                              ruleText(l, r)),
                                                          // No role filter means everyone.
                                                          selected: (conditions[
                                                                          'roles']
                                                                      as List)
                                                                  .contains(
                                                                      r) ||
                                                              (r == 'everyone' &&
                                                                  (conditions['roles']
                                                                          as List)
                                                                      .isEmpty),
                                                          onSelected:
                                                              (v) => change(() {
                                                                    final list =
                                                                        conditions['roles']
                                                                            as List;
                                                                    if (r ==
                                                                        'everyone') {
                                                                      list.clear();
                                                                      if (v) {
                                                                        list.add(
                                                                            r);
                                                                      }
                                                                    } else {
                                                                      list.remove(
                                                                          'everyone');
                                                                      v
                                                                          ? list.add(
                                                                              r)
                                                                          : list
                                                                              .remove(r);
                                                                    }
                                                                  }))
                                                  ]),
                                            ],
                                            SwitchListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(ruleText(
                                                    l, 'onlyWhileStreaming')),
                                                value: conditions[
                                                        'onlyWhileStreaming'] ==
                                                    true,
                                                onChanged: (v) => change(() =>
                                                    conditions[
                                                            'onlyWhileStreaming'] =
                                                        v)),
                                            section('do'),
                                            if (showsPublicChatText(draft))
                                              Text(
                                                  ruleText(l, 'publicChatText'),
                                                  style: const TextStyle(
                                                      color: Color(0xFFFFB15C),
                                                      fontSize: 11,
                                                      height: 1.3)),
                                            for (var i = 0;
                                                i < actions.length;
                                                i++)
                                              Container(
                                                  key: ValueKey(
                                                      actions[i]['id']),
                                                  margin: const EdgeInsets.only(
                                                      top: 12),
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF1E1E1E),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFF2E2E2E)),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .stretch,
                                                      children: [
                                                        Row(children: [
                                                          Expanded(
                                                              child: Text(
                                                                  '${i + 1}. ${ruleText(l, actions[i]['type'] as String)}',
                                                                  style:
                                                                      settingsItemTitleStyle)),
                                                          IconButton(
                                                              tooltip: ruleText(
                                                                  l, 'up'),
                                                              onPressed: i == 0
                                                                  ? null
                                                                  : () =>
                                                                      change(
                                                                          () {
                                                                        final a =
                                                                            actions.removeAt(i);
                                                                        actions.insert(
                                                                            i - 1,
                                                                            a);
                                                                      }),
                                                              iconSize: 18,
                                                              color: Colors
                                                                  .white70,
                                                              icon: const Icon(Icons
                                                                  .arrow_upward_rounded)),
                                                          IconButton(
                                                              tooltip: ruleText(
                                                                  l, 'down'),
                                                              onPressed: i ==
                                                                      actions.length -
                                                                          1
                                                                  ? null
                                                                  : () =>
                                                                      change(
                                                                          () {
                                                                        final a =
                                                                            actions.removeAt(i);
                                                                        actions.insert(
                                                                            i + 1,
                                                                            a);
                                                                      }),
                                                              iconSize: 18,
                                                              color: Colors
                                                                  .white70,
                                                              icon: const Icon(Icons
                                                                  .arrow_downward_rounded)),
                                                          IconButton(
                                                              tooltip: ruleText(
                                                                  l, 'delete'),
                                                              color: const Color(
                                                                  0xFFFF6B6B),
                                                              onPressed: () =>
                                                                  change(() {
                                                                    actions
                                                                        .removeAt(
                                                                            i);
                                                                  }),
                                                              iconSize: 18,
                                                              icon: const Icon(Icons
                                                                  .delete_outline_rounded))
                                                        ]),
                                                        ...params(
                                                            actions[i] as Map<
                                                                String,
                                                                dynamic>,
                                                            RuleSchema
                                                                .actionFields(
                                                                    actions[i]
                                                                        as Map),
                                                            'action-$i')
                                                      ])),
                                            PopupMenuButton<String>(
                                                key: const Key(
                                                    'rule-add-action'),
                                                enabled: actions.length <
                                                    RuleSchema.maxActions,
                                                onSelected: (v) =>
                                                    change(() => actions.add({
                                                          'id': freshRuleId(),
                                                          'type': v,
                                                          for (final f
                                                              in RuleSchema
                                                                  .actions[v]!
                                                                  .entries)
                                                            f.key:
                                                                f.value.fallback
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
                                                            child: Text(
                                                                ruleText(
                                                                    l, g))),
                                                        for (final a
                                                            in RuleSchema
                                                                .actions.keys
                                                                .where((a) =>
                                                                    group(a) ==
                                                                    g))
                                                          PopupMenuItem(
                                                              value: a,
                                                              child: Text(
                                                                  ruleText(
                                                                      l, a)))
                                                      ]
                                                    ],
                                                // Looks like the app's secondary button.
                                                child: Container(
                                                    margin: const EdgeInsets.only(
                                                        top: 12),
                                                    height: 40,
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFF3A3A3A))),
                                                    child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons.add_rounded,
                                                              size: 16,
                                                              color: actions
                                                                          .length <
                                                                      RuleSchema
                                                                          .maxActions
                                                                  ? const Color(
                                                                      0xFF53FC18)
                                                                  : Colors
                                                                      .white30),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                              ruleText(l,
                                                                  'addAction'),
                                                              style: TextStyle(
                                                                  color: actions
                                                                              .length <
                                                                          RuleSchema
                                                                              .maxActions
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .white30,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600)),
                                                        ]))),
                                            section('limits'),
                                            for (final k in [
                                              'cooldownSeconds',
                                              'userCooldownSeconds'
                                            ])
                                              input(k, ruleText(l, k), draft[k],
                                                  (v) => draft[k] = v,
                                                  field: const RuleField.number(
                                                      0, 3600)),
                                            input(
                                                'overlap',
                                                ruleText(l, 'overlap'),
                                                draft['overlap'],
                                                (v) => draft['overlap'] = v,
                                                field: const RuleField.choice(
                                                    ['queue', 'skip'],
                                                    'queue')),
                                            section('testWith'),
                                            settingsLabel(ruleText(l, 'text')),
                                            TextField(
                                                key: const Key(
                                                    'rule-sample-text'),
                                                decoration: settingsInput(
                                                    hint: event().text),
                                                onChanged: (v) => setState(() {
                                                      sampleText = v;
                                                      simulation = null;
                                                    })),
                                            if (type ==
                                                'support.superchat') ...[
                                              const SizedBox(height: 8),
                                              settingsLabel(
                                                  ruleText(l, 'minAmount')),
                                              TextField(
                                                  key: const Key(
                                                      'rule-sample-amount'),
                                                  decoration:
                                                      settingsInput(hint: '5'),
                                                  onChanged: (v) =>
                                                      setState(() {
                                                        sampleAmount = v;
                                                        simulation = null;
                                                      })),
                                            ],
                                            if (simulation != null)
                                              KeyedSubtree(
                                                  key: _resultKey,
                                                  child: Container(
                                                      key: const Key(
                                                          'rule-test-result'),
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 8),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                          color: const Color(
                                                              0xFF1E1E1E),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8),
                                                          border: Border.all(
                                                              color: simulation!
                                                                      .matched
                                                                  ? const Color(
                                                                      0xFF53FC18)
                                                                  : const Color(
                                                                      0xFFFFB15C))),
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment.start,
                                                          children: [
                                                            Text(ruleText(
                                                                l,
                                                                simulation!
                                                                        .reason ??
                                                                    'matched')),
                                                            for (var i = 0;
                                                                i <
                                                                    simulation!
                                                                        .actions
                                                                        .length;
                                                                i++)
                                                              Text(
                                                                  '${ruleText(l, simulation!.actions[i]['type'] as String)}${[
                                                                for (final v in simulation!
                                                                    .actions[i]
                                                                    .entries
                                                                    .where((e) =>
                                                                        ![
                                                                          'type',
                                                                          'id'
                                                                        ].contains(e
                                                                            .key))
                                                                    .map((e) =>
                                                                        '${e.value}'))
                                                                  if (v
                                                                      .isNotEmpty)
                                                                    v
                                                              ].map((v) => ' · $v').join()}\n${ruleText(l, simulation!.results[i].status == 'skipped' ? 'wouldSkip' : simulation!.results[i].status)}${simulation!.results[i].reason == null ? '' : ': ${ruleText(l, simulation!.results[i].reason!)}'}')
                                                          ]))),
                                            if (notice != null)
                                              Text(ruleText(l, notice!)),
                                            if (!valid)
                                              Text(ruleText(l, 'invalid'),
                                                  style: const TextStyle(
                                                      color:
                                                          Color(0xFFFFB15C))),
                                          ])))),
                              const SizedBox(height: 12),
                              Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    OutlinedButton(
                                        key: const Key('rule-test'),
                                        style: secondarySettingsStyle().copyWith(
                                            minimumSize:
                                                const WidgetStatePropertyAll(
                                                    Size(100, 40))),
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
                                                    unawaited(Scrollable
                                                        .ensureVisible(target,
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
                                        style: secondarySettingsStyle().copyWith(
                                            minimumSize:
                                                const WidgetStatePropertyAll(
                                                    Size(100, 40))),
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
                                        onPressed:
                                            valid && !saving ? _save : null,
                                        child: Text(ruleText(l, 'save')))
                                  ]),
                            ]))))));
  }
}

/// Marks where a card starts in the rule editor; never drawn itself.
class _Section extends StatelessWidget {
  const _Section(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

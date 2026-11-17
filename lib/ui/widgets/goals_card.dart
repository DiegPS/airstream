import 'settings_controls.dart';
import 'dart:async';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/goals.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class GoalsCard extends ConsumerWidget {
  const GoalsCard({super.key});
  String _type(AppLocalizations l, String type) => switch (type) {
        'subs' => l.goalsSubs,
        'bits' => l.goalsBits,
        'kicks' => l.goalsKicks,
        _ => l.goalsManual,
      };
  void _change(WidgetRef ref, String id, int? delta) {
    final s = ref.read(settingsProvider);
    final goals = Goals.sanitize(s.goals);
    final goal = goals[id];
    if (goal == null) return;
    goals[id] = {
      ...goal,
      'current': delta == null
          ? 0
          : ((goal['current'] as int) + delta).clamp(0, 10000000)
    };
    unawaited(
        ref.read(settingsProvider.notifier).update(s.copyWith(goals: goals)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final goals = Goals.sanitize(ref.watch(settingsProvider).goals);
    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final page = ready && url != null ? '$url/goals' : null;
    Widget button(String key, String label, VoidCallback action) => key ==
            'goals-add'
        ? SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                key: Key(key),
                style: primarySettingsStyle(),
                onPressed: action,
                child: Text(label)))
        : OutlinedButton(
            key: Key(key),
            style: secondarySettingsStyle(destructive: key.endsWith('-delete')),
            onPressed: action,
            child: Text(label));
    return UiCard(
        title: l.goalsTitle,
        description: l.goalsDescription,
        icon: Icons.flag_rounded,
        children: [
          for (final e in goals.entries) ...[
            Text(e.value['title'] as String,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            Text(_type(l, e.value['type'] as String),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                color: const Color(0xFF53FC18),
                backgroundColor: const Color(0xFF262626),
                value:
                    ((e.value['current'] as int) / (e.value['target'] as int))
                        .clamp(0, 1)),
            Text(
                '${groupDigits(e.value['current'] as int)} / '
                '${groupDigits(e.value['target'] as int)}',
                key: Key('goal-${e.key}-progress'),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            // Quick adjustments share one row; management actions the next.
            Row(children: [
              for (final (key, label, delta) in [
                ('minus', '−1', -1),
                ('plus', '+1', 1),
                ('plus10', '+10', 10),
                if (['bits', 'kicks'].contains(e.value['type']))
                  ('plus100', '+100', 100),
              ]) ...[
                if (key != 'minus') const SizedBox(width: 8),
                Expanded(
                    child: button('goal-${e.key}-$key', label,
                        () => _change(ref, e.key, delta))),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: button('goal-${e.key}-reset', l.goalsReset,
                      () => _change(ref, e.key, null))),
              const SizedBox(width: 8),
              Expanded(
                  child: button('goal-${e.key}-edit', l.goalsEdit,
                      () => _edit(context, ref, e.key))),
              const SizedBox(width: 8),
              Expanded(
                  child: button('goal-${e.key}-delete', l.goalsDelete, () {
                final s = ref.read(settingsProvider);
                unawaited(ref
                    .read(settingsProvider.notifier)
                    .update(s.copyWith(goals: {...s.goals}..remove(e.key))));
              })),
            ]),
            const SizedBox(height: 12),
          ],
          if (goals.length < 3)
            button('goals-add', l.goalsAdd, () => _edit(context, ref, null)),
          const SizedBox(height: 12),
          if (page != null)
            PageUrlRow(
                url: page,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: page));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.goalsUrlCopied)));
                  }
                }),
        ]);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String? id) async {
    final l = AppLocalizations.of(context)!;
    final old = ref.read(settingsProvider).goals[id];
    final title = TextEditingController(text: old?['title'] as String? ?? '');
    final target = TextEditingController(text: '${old?['target'] ?? 100}');
    var type = old?['type'] as String? ?? 'manual';
    var invalid = false;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: Text(id == null ? l.goalsAdd : l.goalsEdit),
                  content: SizedBox(
                      width: 280,
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            settingsLabel(l.goalsName),
                            TextField(
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                key: const Key('goal-title'),
                                controller: title,
                                maxLength: 60,
                                decoration: settingsInput()),
                            settingsLabel(l.goalsType),
                            DropdownButton<String>(
                                value: type,
                                isExpanded: true,
                                items: [
                                  for (final t in goalTypes)
                                    DropdownMenuItem(
                                        value: t, child: Text(_type(l, t)))
                                ],
                                onChanged: (v) => setState(() => type = v!)),
                            settingsLabel(l.goalsTarget),
                            TextField(
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                key: const Key('goal-target'),
                                controller: target,
                                keyboardType: TextInputType.number,
                                decoration: settingsInput()),
                            if (invalid) Text(l.goalsInvalid),
                          ]))),
                  actions: [
                    OutlinedButton(
                        style: secondarySettingsStyle(),
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.cancel)),
                    ElevatedButton(
                        key: const Key('goal-save'),
                        style: primarySettingsStyle(),
                        child: Text(l.goalsSave),
                        onPressed: () {
                          final n = int.tryParse(target.text);
                          if (title.text.trim().isEmpty ||
                              n == null ||
                              n < 1 ||
                              n > 1000000) {
                            setState(() => invalid = true);
                            return;
                          }
                          final s = ref.read(settingsProvider);
                          if (id == null && s.goals.length >= 3) return;
                          if (id != null && !s.goals.containsKey(id)) {
                            Navigator.pop(context);
                            return;
                          }
                          final key = id ??
                              DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toRadixString(36);
                          unawaited(ref
                              .read(settingsProvider.notifier)
                              .update(s.copyWith(
                                  goals: Goals.sanitize({
                                ...s.goals,
                                key: {
                                  'title': title.text,
                                  'type': type,
                                  'target': n,
                                  'current': s.goals[id]?['current'] ?? 0
                                }
                              }))));
                          Navigator.pop(context);
                        })
                  ],
                )));
    // Dialog route keeps its fields alive through the closing animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    title.dispose();
    target.dispose();
  }
}

/// 7420 -> "7 420" with a narrow no-break space, readable in every language
/// and the same grouping the OBS goals page uses.
String groupDigits(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

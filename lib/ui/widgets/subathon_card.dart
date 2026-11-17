import 'dart:async';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SubathonCard extends ConsumerStatefulWidget {
  const SubathonCard({super.key});
  @override
  ConsumerState<SubathonCard> createState() => _SubathonCardState();
}

class _SubathonCardState extends ConsumerState<SubathonCard> {
  late final Timer _refresh;
  @override
  void initState() {
    super.initState();
    _refresh =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _refresh.cancel();
    super.dispose();
  }

  void change(SettingsModel Function(SettingsModel, int) action) {
    final now = DateTime.now().millisecondsSinceEpoch;
    unawaited(ref.read(settingsProvider.notifier).update(
        action(SubathonTimer.normalize(ref.read(settingsProvider), now), now)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(settingsProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final phase = SubathonTimer.normalize(s, now).subathonPhase;
    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final page = ready && url != null ? '$url/timer' : null;
    Widget button(String key, String label,
            SettingsModel Function(SettingsModel, int) action) =>
        ElevatedButton(
            key: Key(key), onPressed: () => change(action), child: Text(label));
    Widget field(String key, String label, int value, int min, int max,
            SettingsModel Function(SettingsModel, int) update) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TimerNumberField(
                key: Key(key),
                label: label,
                value: value,
                minimum: min,
                maximum: max,
                onChanged: (n) => change((s, _) => update(s, n))));
    return UiCard(
        title: l.subathonTitle,
        description: l.subathonDescription,
        icon: Icons.timer_rounded,
        children: [
          Text(SubathonTimer.format(SubathonTimer.remaining(s, now)),
              key: const Key('subathon-remaining'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700)),
          Text(
              switch (phase) {
                'running' => l.subathonRunning,
                'paused' => l.subathonPaused,
                'ended' => l.subathonEnded,
                _ => l.subathonIdle
              },
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          field(
              'subathon-start-minutes',
              l.subathonStartMinutes,
              s.subathonStartMinutes,
              1,
              10080,
              (s, n) => s.copyWith(subathonStartMinutes: n)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            button('subathon-start', l.subathonStart, SubathonTimer.start),
            if (phase == 'running')
              button('subathon-pause', l.subathonPause, SubathonTimer.pause),
            if (phase == 'paused')
              button('subathon-resume', l.subathonResume, SubathonTimer.resume),
            button('subathon-reset', l.subathonReset, SubathonTimer.reset),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (key, label, seconds) in [
              ('sub-5', '−5m', -300),
              ('sub-1', '−1m', -60),
              ('add-1', '+1m', 60),
              ('add-5', '+5m', 300)
            ])
              button('subathon-$key', label,
                  (s, now) => SubathonTimer.addSeconds(s, now, seconds)),
          ]),
          Material(
              color: Colors.transparent,
              child: ExpansionTile(
                  key: const Key('subathon-rules'),
                  title: Text(l.subathonRules,
                      style: const TextStyle(color: Colors.white70)),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    field(
                        'subathon-subs',
                        l.subathonPerSub,
                        s.subathonSecondsPerSub,
                        0,
                        3600,
                        (s, n) => s.copyWith(subathonSecondsPerSub: n)),
                    field(
                        'subathon-bits',
                        l.subathonPerBits,
                        s.subathonSecondsPer100Bits,
                        0,
                        3600,
                        (s, n) => s.copyWith(subathonSecondsPer100Bits: n)),
                    field(
                        'subathon-kicks',
                        l.subathonPerKicks,
                        s.subathonSecondsPer100Kicks,
                        0,
                        3600,
                        (s, n) => s.copyWith(subathonSecondsPer100Kicks: n)),
                    field(
                        'subathon-cap',
                        l.subathonCap,
                        s.subathonMaxRemainingMinutes,
                        0,
                        10080,
                        (s, n) => s.copyWith(subathonMaxRemainingMinutes: n)),
                  ])),
          Row(children: [
            Expanded(
                child: Text(page ?? l.subathonPageOff,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11))),
            if (page != null)
              IconButton(
                  tooltip: l.copyUrl,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: page))),
          ]),
        ]);
  }
}

class _TimerNumberField extends StatefulWidget {
  const _TimerNumberField(
      {super.key,
      required this.label,
      required this.value,
      required this.minimum,
      required this.maximum,
      required this.onChanged});
  final String label;
  final int value, minimum, maximum;
  final ValueChanged<int> onChanged;
  @override
  State<_TimerNumberField> createState() => _TimerNumberFieldState();
}

class _TimerNumberFieldState extends State<_TimerNumberField> {
  late final TextEditingController controller =
      TextEditingController(text: '${widget.value}');
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant _TimerNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focus.hasFocus && int.tryParse(controller.text) != widget.value) {
      controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
            key: PageStorageKey('subathon-input-${widget.label}'),
            controller: controller,
            focusNode: focus,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: '${widget.minimum}–${widget.maximum}', isDense: true),
            onChanged: (text) {
              final n = int.tryParse(text);
              if (n != null) {
                widget.onChanged(n.clamp(widget.minimum, widget.maximum));
              }
            },
            onEditingComplete: () {
              controller.text = '${widget.value}';
              focus.unfocus();
            },
            onTapOutside: (_) {
              controller.text = '${widget.value}';
              focus.unfocus();
            })
      ]);
}

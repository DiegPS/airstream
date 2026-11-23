import 'settings_controls.dart';
import 'dart:async';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SubathonCard extends ConsumerStatefulWidget {
  const SubathonCard({super.key});
  @override
  ConsumerState<SubathonCard> createState() => _SubathonCardState();
}

class _SubathonCardState extends ConsumerState<SubathonCard> {
  Timer? _refresh;

  /// Refreshes the countdown once a second only while it runs and this tab
  /// is on screen (hidden tabs stay built with tickers disabled).
  void _syncRefresh(bool active) {
    if (active && _refresh == null) {
      _refresh =
          Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    } else if (!active) {
      _refresh?.cancel();
      _refresh = null;
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void restart() {
    final notifier = ref.read(settingsProvider.notifier);
    final now = DateTime.now().millisecondsSinceEpoch;
    final s = SubathonTimer.normalize(ref.read(settingsProvider), now);
    // A new run passes through idle, so OBS does not show the difference
    // between the old and new end as support-added time.
    if (s.subathonPhase == 'running' || s.subathonPhase == 'paused') {
      unawaited(saveLiveSettings(
          context, notifier.update(SubathonTimer.reset(s, now))));
    }
    unawaited(saveLiveSettings(
      context,
      notifier.update(SubathonTimer.start(ref.read(settingsProvider), now)),
    ));
  }

  /// Starting over or resetting a running/paused subathon throws away the
  /// time left (and what support added): ask first.
  Future<bool> _confirmLoss(String title, String action) async =>
      await confirmLiveAction(context,
          title: title,
          action: action,
          dialogKey: const Key('subathon-confirm'),
          actionKey: const Key('subathon-confirm-ok')) &&
      mounted;

  void change(SettingsModel Function(SettingsModel, int) action) {
    final now = DateTime.now().millisecondsSinceEpoch;
    unawaited(saveLiveSettings(
      context,
      ref.read(settingsProvider.notifier).update(action(
          SubathonTimer.normalize(ref.read(settingsProvider), now), now)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(settingsProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final phase = SubathonTimer.normalize(s, now).subathonPhase;
    final active = phase == 'running' || phase == 'paused';
    _syncRefresh(phase == 'running' && TickerMode.valuesOf(context).enabled);
    final url = ref.watch(overlayUrlProvider);
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final page = ready && url != null ? '$url/timer' : null;
    Widget button(String key, String label,
            SettingsModel Function(SettingsModel, int) action,
            {bool primary = false,
            bool destructive = false,
            bool enabled = true,
            VoidCallback? onPressed}) =>
        primary
            ? SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    key: Key(key),
                    style: primarySettingsStyle(),
                    onPressed: onPressed ?? () => change(action),
                    child: Text(label)))
            : OutlinedButton(
                key: Key(key),
                style: secondarySettingsStyle(destructive: destructive),
                onPressed: enabled ? onPressed ?? () => change(action) : null,
                child: Text(label));
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
          Row(children: [
            Expanded(
                child: Text(
                    SubathonTimer.format(SubathonTimer.remaining(s, now)),
                    key: const Key('subathon-remaining'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700))),
            settingsStatus(
                switch (phase) {
                  'running' => l.subathonRunning,
                  'paused' => l.subathonPaused,
                  'ended' => l.subathonEnded,
                  _ => l.subathonIdle
                },
                switch (phase) {
                  'running' => const Color(0xFF53FC18),
                  'paused' => const Color(0xFFFFB15C),
                  'ended' => const Color(0xFFFF6B6B),
                  _ => Colors.white54
                },
                key: const Key('subathon-status')),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: field(
                    'subathon-start-minutes',
                    l.subathonStartMinutes,
                    s.subathonStartMinutes,
                    1,
                    10080,
                    (s, n) => s.copyWith(subathonStartMinutes: n))),
            const SizedBox(width: 8),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: button(
                        'subathon-start',
                        active ? l.subathonStartOver : l.subathonStart,
                        SubathonTimer.start,
                        onPressed: active
                            ? () async {
                                if (await _confirmLoss(
                                    l.subathonStartOverConfirm,
                                    l.subathonStartOver)) {
                                  restart();
                                }
                              }
                            : restart,
                        primary: !active,
                        destructive: active))),
          ]),
          if (phase == 'running')
            button('subathon-pause', l.subathonPause, SubathonTimer.pause,
                primary: true),
          if (phase == 'paused')
            button('subathon-resume', l.subathonResume, SubathonTimer.resume,
                primary: true),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child:
                  button('subathon-reset', l.subathonReset, SubathonTimer.reset,
                      destructive: true,
                      enabled: phase != 'idle',
                      onPressed: active
                          ? () async {
                              if (await _confirmLoss(
                                  l.subathonResetConfirm, l.subathonReset)) {
                                change(SubathonTimer.reset);
                              }
                            }
                          : null)),
          const SizedBox(height: 8),
          Row(spacing: 8, children: [
            for (final (key, label, seconds) in [
              ('sub-5', '−5m', -300),
              ('sub-1', '−1m', -60),
              ('add-1', '+1m', 60),
              ('add-5', '+5m', 300)
            ])
              Expanded(
                  child: button('subathon-$key', label,
                      (s, now) => SubathonTimer.addSeconds(s, now, seconds),
                      enabled: active)),
          ]),
          if (!active) Text(l.subathonAdjustHint, style: settingsHintStyle),
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
          if (page != null)
            PageUrlRow(
                url: page,
                onCopy: () =>
                    copyLiveText(context, page, success: l.subathonUrlCopied)),
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
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) {
        controller.text = '${widget.value}';
        if (_invalid) setState(() => _invalid = false);
      }
    });
  }

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
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: settingsInput(
                    error: _invalid
                        ? AppLocalizations.of(context)!
                            .liveNumberRange(widget.minimum, widget.maximum)
                        : null)
                .copyWith(errorMaxLines: 3),
            onChanged: (text) {
              final n = int.tryParse(text);
              final valid =
                  n != null && n >= widget.minimum && n <= widget.maximum;
              if (_invalid == valid) setState(() => _invalid = !valid);
              if (valid) widget.onChanged(n);
            },
            onEditingComplete: () {
              if (_invalid) return;
              focus.unfocus();
            },
            onTapOutside: (_) => focus.unfocus())
      ]);
}

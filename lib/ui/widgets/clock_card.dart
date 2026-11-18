import 'dart:async';

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/live_clock.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_controls.dart';

class ClockCard extends ConsumerStatefulWidget {
  const ClockCard({super.key});

  @override
  ConsumerState<ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends ConsumerState<ClockCard> {
  final _label = TextEditingController();
  final _duration = TextEditingController();
  final _labelFocus = FocusNode();
  final _durationFocus = FocusNode();
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _label.dispose();
    _duration.dispose();
    _labelFocus.dispose();
    _durationFocus.dispose();
    super.dispose();
  }

  void _configure(LiveClock Function(LiveClock) update) {
    final settings = ref.read(settingsProvider);
    unawaited(ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(clock: update(settings.clock))));
  }

  void _operate(String op, [int seconds = 0]) {
    unawaited(
        ref.read(appControllerProvider).operateClock(op, seconds: seconds));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final clock = settings.clock;
    if (clock.needsTick) {
      _ticker ??= Timer.periodic(
          const Duration(milliseconds: 250), (_) => setState(() {}));
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    if (!_labelFocus.hasFocus && _label.text != clock.label) {
      _label.text = clock.label;
    }
    final seconds = clock.durationSeconds.toString();
    if (!_durationFocus.hasFocus && _duration.text != seconds) {
      _duration.text = seconds;
    }
    final now = DateTime.now();
    final current = clock.expire(now.millisecondsSinceEpoch);
    final value = current.shownAt(now.millisecondsSinceEpoch);
    final display = switch (clock.mode) {
      ClockMode.clock => DateFormat.Hms(l.localeName).format(now),
      ClockMode.countdown => SubathonTimer.format(value),
      ClockMode.stopwatch => SubathonTimer.format(value ~/ 1000 * 1000),
    };
    final isCountdown = clock.mode == ClockMode.countdown;
    final running = current.phase == ClockPhase.running;
    final adjustable =
        isCountdown && (running || current.phase == ClockPhase.paused);
    final audio = {
      HighlightSounds.none: l.clockSoundNone,
      'chime': l.alertSoundChime,
      'coin': l.alertSoundCoin,
      'fanfare': l.alertSoundFanfare,
      for (final entry in settings.mediaLibrary.entries)
        if (entry.value['kind'] == 'audio')
          entry.key: entry.value['name'] as String? ?? entry.key,
    };
    final url = ref.watch(overlayUrlProvider);
    return UiCard(
      key: const Key('clock-card'),
      title: l.clockTitle,
      icon: Icons.timer_outlined,
      description: l.clockDescription,
      children: [
        _picker(
          l.clockMode,
          clock.mode,
          {
            ClockMode.countdown: l.clockCountdown,
            ClockMode.stopwatch: l.clockStopwatch,
            ClockMode.clock: l.clockLocalTime,
          },
          (mode) => _configure((clock) => clock.configure(mode: mode)),
        ),
        settingsLabel(l.clockLabel),
        TextField(
          key: const Key('clock-label'),
          controller: _label,
          focusNode: _labelFocus,
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          decoration: settingsInput(),
          onChanged: (label) =>
              _configure((clock) => clock.configure(label: label)),
        ),
        const SizedBox(height: 8),
        if (isCountdown) ...[
          settingsLabel(l.clockDuration),
          TextField(
            key: const Key('clock-duration'),
            controller: _duration,
            focusNode: _durationFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(5)
            ],
            decoration: settingsInput(),
            onChanged: (input) {
              final value = int.tryParse(input);
              if (value != null) {
                _configure((clock) => clock.configure(durationSeconds: value));
              }
            },
            onEditingComplete: () => setState(() => _durationFocus.unfocus()),
          ),
          const SizedBox(height: 8),
          _picker(
            l.clockSound,
            audio.containsKey(clock.sound) ? clock.sound : HighlightSounds.none,
            audio,
            (sound) => _configure((clock) => clock.configure(sound: sound)),
          ),
        ],
        _picker(
          l.clockStyle,
          clock.style,
          {
            ClockStyle.big: l.clockStyleBig,
            ClockStyle.compact: l.clockStyleCompact,
            ClockStyle.ring: l.clockStyleRing,
          },
          (style) => _configure((clock) => clock.configure(style: style)),
        ),
        Text(display,
            key: const Key('clock-value'),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
        if (current.phase == ClockPhase.ended) Text(l.clockEnded),
        if (clock.mode != ClockMode.clock)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const Key('clock-toggle'),
                style: secondarySettingsStyle(),
                onPressed: () => _operate(running ? 'pause' : 'start'),
                child: Text(running ? l.clockPause : l.start),
              ),
              OutlinedButton(
                style: secondarySettingsStyle(),
                onPressed: current.phase == ClockPhase.idle
                    ? null
                    : () => _operate('reset'),
                child: Text(l.clockReset),
              ),
              if (isCountdown) ...[
                OutlinedButton(
                  style: secondarySettingsStyle(),
                  onPressed: adjustable ? () => _operate('add', -60) : null,
                  child: Text(l.clockMinusMinute),
                ),
                OutlinedButton(
                  style: secondarySettingsStyle(),
                  onPressed: adjustable ? () => _operate('add', 60) : null,
                  child: Text(l.clockPlusMinute),
                ),
              ],
            ],
          ),
        if (url != null &&
            ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
                OverlayServerPhase.ready)
          PageUrlRow(url: '$url/clock'),
      ],
    );
  }

  Widget _picker<T>(String label, T value, Map<T, String> options,
          ValueChanged<T> change) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          settingsLabel(label),
          DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) {
              if (value != null) change(value);
            },
          ),
          const SizedBox(height: 8),
        ],
      );
}

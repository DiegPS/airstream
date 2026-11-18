import 'dart:math' as math;

import 'package:airstream/settings/chat_reading_options.dart';

enum ClockMode { countdown, stopwatch, clock }

enum ClockPhase { idle, running, paused, ended }

enum ClockStyle { big, compact, ring }

/// Wall-clock timestamps let a running timer resume after a restart.
class LiveClock {
  const LiveClock({
    this.mode = ClockMode.countdown,
    this.phase = ClockPhase.idle,
    this.label = '',
    this.durationSeconds = 300,
    this.style = ClockStyle.big,
    this.sound = HighlightSounds.none,
    this.anchorMs = 0,
    this.valueMs = 0,
  });

  static const maxSeconds = 86400;
  static const _maxTimestamp = 8640000000000000;
  final ClockMode mode;
  final ClockPhase phase;
  final String label, sound;
  final int durationSeconds, anchorMs, valueMs;
  final ClockStyle style;

  int get durationMs => durationSeconds * 1000;
  bool get needsTick => mode == ClockMode.clock || phase == ClockPhase.running;

  int shownAt(int now) {
    if (phase == ClockPhase.running) {
      return mode == ClockMode.countdown
          ? math.max(0, anchorMs - now)
          : valueMs + math.max(0, now - anchorMs);
    }
    if (phase == ClockPhase.idle && mode == ClockMode.countdown) {
      return durationMs;
    }
    return valueMs;
  }

  LiveClock expire(int now) => mode == ClockMode.countdown &&
          phase == ClockPhase.running &&
          now >= anchorMs
      ? _state(ClockPhase.ended)
      : this;

  LiveClock start(int now) {
    if (mode == ClockMode.clock || phase == ClockPhase.running) return this;
    final value = phase == ClockPhase.paused ? valueMs : durationMs;
    return mode == ClockMode.countdown
        ? _state(ClockPhase.running, anchor: now + value)
        : _state(ClockPhase.running, anchor: now, value: valueMs);
  }

  LiveClock pause(int now) {
    final current = expire(now);
    return current.phase == ClockPhase.running
        ? current._state(ClockPhase.paused, value: shownAt(now))
        : current;
  }

  LiveClock reset() =>
      phase == ClockPhase.idle ? this : _state(ClockPhase.idle);

  LiveClock addSeconds(int now, int seconds) {
    final current = expire(now);
    if (current.mode != ClockMode.countdown ||
        (current.phase != ClockPhase.running &&
            current.phase != ClockPhase.paused)) {
      return current;
    }
    final value = (shownAt(now) + seconds.clamp(-maxSeconds, maxSeconds) * 1000)
        .clamp(0, maxSeconds * 1000);
    if (value == 0) return _state(ClockPhase.ended);
    return phase == ClockPhase.running
        ? _state(phase, anchor: now + value)
        : _state(phase, value: value);
  }

  LiveClock perform(String op, int now, {int seconds = 0}) => switch (op) {
        'start' => expire(now).start(now),
        'pause' => pause(now),
        'reset' => reset(),
        'add' => addSeconds(now, seconds),
        _ => this,
      };

  LiveClock _state(ClockPhase phase, {int anchor = 0, int value = 0}) =>
      LiveClock(
        mode: mode,
        phase: phase,
        label: label,
        durationSeconds: durationSeconds,
        style: style,
        sound: sound,
        anchorMs: anchor,
        valueMs: value,
      );

  LiveClock configure({
    ClockMode? mode,
    String? label,
    int? durationSeconds,
    ClockStyle? style,
    String? sound,
  }) {
    final changedMode = mode != null && mode != this.mode;
    return LiveClock.fromJson({
      ...toJson(),
      if (mode != null) 'mode': mode.name,
      if (label != null) 'label': label,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (style != null) 'style': style.name,
      if (sound != null) 'sound': sound,
      if (changedMode) ...const {'phase': 'idle', 'anchorMs': 0, 'valueMs': 0},
    });
  }

  Map<String, Object?> optionsJson() => {
        'mode': mode.name,
        'label': label,
        'durationSeconds': durationSeconds,
        'style': style.name,
        'sound': sound,
      };

  Map<String, Object?> toJson() => {
        ...optionsJson(),
        'phase': phase.name,
        'anchorMs': anchorMs,
        'valueMs': valueMs,
      };

  Map<String, Object?> payload(int now) => {
        ...expire(now).toJson()..remove('sound'),
        'serverNowMs': now,
      };

  static LiveClock fromJson(Object? raw) {
    if (raw is! Map) return const LiveClock();
    int number(String key, int min, int max, int fallback) {
      final value = raw[key];
      return value is num && value.isFinite
          ? value.round().clamp(min, max)
          : fallback;
    }

    final mode =
        ClockMode.values.asNameMap()[raw['mode']] ?? ClockMode.countdown;
    var phase = ClockPhase.values.asNameMap()[raw['phase']] ?? ClockPhase.idle;
    final anchor = number('anchorMs', 0, _maxTimestamp, 0);
    final value = number('valueMs', 0,
        mode == ClockMode.countdown ? maxSeconds * 1000 : _maxTimestamp, 0);
    if (mode == ClockMode.clock ||
        (mode == ClockMode.stopwatch && phase == ClockPhase.ended) ||
        (phase == ClockPhase.running && anchor == 0) ||
        (mode == ClockMode.countdown &&
            phase == ClockPhase.paused &&
            value == 0)) {
      phase = ClockPhase.idle;
    }
    final label = raw['label'];
    return LiveClock(
      mode: mode,
      phase: phase,
      label: label is String
          ? String.fromCharCodes(label.trim().runes.take(80))
          : '',
      durationSeconds: number('durationSeconds', 1, maxSeconds, 300),
      style: ClockStyle.values.asNameMap()[raw['style']] ?? ClockStyle.big,
      sound: HighlightSounds.sanitizeSource(raw['sound']),
      anchorMs: phase == ClockPhase.running ? anchor : 0,
      valueMs: phase == ClockPhase.paused ||
              (mode == ClockMode.stopwatch && phase == ClockPhase.running)
          ? value
          : 0,
    );
  }
}

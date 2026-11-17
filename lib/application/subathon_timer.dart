import 'dart:math' as math;
import 'package:airstream/settings/settings_model.dart';

abstract final class SubathonTimer {
  static int remaining(SettingsModel s, int now) => switch (s.subathonPhase) {
        'running' => math.max(0, s.subathonEndsAtMs - now),
        'paused' => s.subathonRemainingMs,
        _ => 0,
      };
  static SettingsModel normalize(SettingsModel s, int now) =>
      s.subathonPhase == 'running' && s.subathonEndsAtMs <= now
          ? s.copyWith(
              subathonPhase: 'ended',
              subathonEndsAtMs: 0,
              subathonRemainingMs: 0)
          : s;
  static int _cap(SettingsModel s, int ms) => s.subathonMaxRemainingMinutes > 0
      ? math.min(ms, s.subathonMaxRemainingMinutes * 60000)
      : ms;
  static SettingsModel start(SettingsModel s, int now) {
    s = normalize(s, now);
    return s.copyWith(
        subathonPhase: 'running',
        subathonEndsAtMs: now + _cap(s, s.subathonStartMinutes * 60000),
        subathonRemainingMs: 0);
  }

  static SettingsModel pause(SettingsModel s, int now) {
    s = normalize(s, now);
    return s.subathonPhase == 'running'
        ? s.copyWith(
            subathonPhase: 'paused',
            subathonRemainingMs: remaining(s, now),
            subathonEndsAtMs: 0)
        : s;
  }

  static SettingsModel resume(SettingsModel s, int now) {
    s = normalize(s, now);
    return s.subathonPhase == 'paused'
        ? normalize(
            s.copyWith(
                subathonPhase: 'running',
                subathonEndsAtMs: now + s.subathonRemainingMs,
                subathonRemainingMs: 0),
            now)
        : s;
  }

  static SettingsModel reset(SettingsModel s, int now) =>
      normalize(s, now).copyWith(
          subathonPhase: 'idle', subathonEndsAtMs: 0, subathonRemainingMs: 0);
  static SettingsModel addSeconds(SettingsModel s, int now, int seconds) {
    s = normalize(s, now);
    if (!['running', 'paused'].contains(s.subathonPhase)) return s;
    final ms = _cap(s, math.max(0, remaining(s, now) + seconds * 1000));
    return s.subathonPhase == 'running'
        ? normalize(s.copyWith(subathonEndsAtMs: now + ms), now)
        : s.copyWith(subathonRemainingMs: ms);
  }

  static ({SettingsModel settings, int addedMs}) applyIncrements(
      SettingsModel s, int now, Map<String, int> increments) {
    s = normalize(s, now);
    if (s.subathonPhase != 'running') return (settings: s, addedMs: 0);
    final ms =
        math.max(0, increments['subs'] ?? 0) * s.subathonSecondsPerSub * 1000 +
            math.max(0, increments['bits'] ?? 0) *
                s.subathonSecondsPer100Bits *
                10 +
            math.max(0, increments['kicks'] ?? 0) *
                s.subathonSecondsPer100Kicks *
                10;
    final before = remaining(s, now);
    final after = _cap(s, before + ms);
    return (
      settings: s.copyWith(subathonEndsAtMs: now + after),
      addedMs: math.max(0, after - before)
    );
  }

  static Map<String, Object?> payload(SettingsModel s, int now,
      {int addedMs = 0}) {
    s = normalize(s, now);
    return {
      'phase': s.subathonPhase,
      'endsAtMs': s.subathonEndsAtMs,
      'remainingMs': remaining(s, now),
      'serverNowMs': now,
      'addedMs': addedMs
    };
  }

  static String format(int ms) {
    final seconds = (math.max(0, ms) / 1000).ceil();
    final minutes = seconds ~/ 60;
    final tail = (seconds % 60).toString().padLeft(2, '0');
    return minutes >= 60
        ? '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}:$tail'
        : '$minutes:$tail';
  }
}

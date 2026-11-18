import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = 1000000;
  const defaults = SettingsModel();
  test('remaining in every phase and expired running', () {
    expect(SubathonTimer.remaining(defaults, now), 0);
    expect(
        SubathonTimer.remaining(
            defaults.copyWith(subathonPhase: 'ended', subathonRemainingMs: 123),
            now),
        0);
    expect(
        SubathonTimer.remaining(
            defaults.copyWith(
                subathonPhase: 'paused', subathonRemainingMs: 123),
            now),
        123);
    expect(
        SubathonTimer.remaining(
            defaults.copyWith(
                subathonPhase: 'running', subathonEndsAtMs: now + 123),
            now),
        123);
    expect(
        SubathonTimer.remaining(
            defaults.copyWith(
                subathonPhase: 'running', subathonEndsAtMs: now - 1),
            now),
        0);
  });
  test('start pause resume reset and restart after expiry', () {
    final run = SubathonTimer.start(defaults, now);
    expect(run.subathonEndsAtMs, now + 3600000);
    final pause = SubathonTimer.pause(run, now + 1000);
    expect(pause.subathonPhase, 'paused');
    expect(SubathonTimer.remaining(pause, now + 99999), 3599000);
    final resume = SubathonTimer.resume(pause, now + 2000);
    expect(resume.subathonEndsAtMs, now + 3601000);
    expect(SubathonTimer.reset(resume, now + 3000).subathonPhase, 'idle');
    final ended = SubathonTimer.normalize(run, run.subathonEndsAtMs);
    expect(ended.subathonPhase, 'ended');
    expect(ended.subathonRemainingMs, 0);
    expect(
        SubathonTimer.applyIncrements(ended, now + 9000000, {'subs': 10})
            .addedMs,
        0);
    expect(SubathonTimer.start(ended, now + 9000000).subathonPhase, 'running');
  });
  test('manual floor cap and idle or ended actions', () {
    var s = SubathonTimer.start(
        defaults.copyWith(
            subathonStartMinutes: 1, subathonMaxRemainingMinutes: 2),
        now);
    s = SubathonTimer.addSeconds(s, now, 300);
    expect(SubathonTimer.remaining(s, now), 120000);
    final paused = SubathonTimer.pause(s, now);
    expect(SubathonTimer.addSeconds(paused, now, -999).subathonRemainingMs, 0);
    expect(
        SubathonTimer.addSeconds(paused, now, 999).subathonRemainingMs, 120000);
    expect(SubathonTimer.addSeconds(s, now, -999).subathonPhase, 'ended');
    expect(SubathonTimer.addSeconds(defaults, now, 300).subathonPhase, 'idle');
    expect(SubathonTimer.pause(s, s.subathonEndsAtMs).subathonPhase, 'ended');
    expect(SubathonTimer.resume(s, s.subathonEndsAtMs).subathonPhase, 'ended');
    expect(SubathonTimer.addSeconds(s, s.subathonEndsAtMs, 60).subathonPhase,
        'ended');
  });
  test(
      'manual changes above a lowered cap preserve time or subtract only the request',
      () {
    final lowered = SubathonTimer.start(
      defaults.copyWith(subathonStartMinutes: 3),
      now,
    ).copyWith(subathonMaxRemainingMinutes: 2);
    for (final timer in [lowered, SubathonTimer.pause(lowered, now)]) {
      expect(SubathonTimer.addSeconds(timer, now, 60), same(timer));
      expect(
          SubathonTimer.remaining(
              SubathonTimer.addSeconds(timer, now, -30), now),
          150000);
    }
  });

  test('each rule preserves fractional hundreds in milliseconds', () {
    final s = SubathonTimer.start(
        defaults.copyWith(
            subathonSecondsPerSub: 7,
            subathonSecondsPer100Bits: 3,
            subathonSecondsPer100Kicks: 9),
        now);
    for (final (increments, ms) in [
      ({'subs': 2}, 14000),
      ({'bits': 1}, 30),
      ({'kicks': 1}, 90),
      ({'bits': 50, 'kicks': 25, 'subs': 1}, 10750)
    ]) {
      final r = SubathonTimer.applyIncrements(s, now, increments);
      expect(r.addedMs, ms);
      expect(r.settings.subathonEndsAtMs - s.subathonEndsAtMs, ms);
    }
  });
  test('support never shortens a run that is above a lowered cap', () {
    final s =
        SubathonTimer.start(defaults.copyWith(subathonStartMinutes: 180), now);
    final lowered = s.copyWith(subathonMaxRemainingMinutes: 120);
    final r = SubathonTimer.applyIncrements(lowered, now, {'subs': 1});
    expect(r.addedMs, 0);
    expect(r.settings.subathonEndsAtMs, s.subathonEndsAtMs);
  });

  test(
      'cap returns actual addition then zero and inactive increments do nothing',
      () {
    final s = SubathonTimer.start(
        defaults.copyWith(
            subathonStartMinutes: 1, subathonMaxRemainingMinutes: 2),
        now);
    final r = SubathonTimer.applyIncrements(s, now, {'subs': 3});
    expect(r.addedMs, 60000);
    expect(
        SubathonTimer.applyIncrements(r.settings, now, {'subs': 3}).addedMs, 0);
    for (final phase in ['idle', 'paused', 'ended']) {
      final inactive = s.copyWith(subathonPhase: phase);
      final r = SubathonTimer.applyIncrements(
          inactive, now, {'subs': 1, 'bits': 100, 'kicks': 100});
      expect(r.settings, same(inactive));
      expect(r.addedMs, 0);
    }
    final expired =
        SubathonTimer.applyIncrements(s, s.subathonEndsAtMs, {'subs': 2});
    expect(expired.settings.subathonPhase, 'ended');
    expect(expired.addedMs, 0);
  });
  test(
      'settings sanitize and profiles preserve state even with malicious state keys',
      () {
    final s = SettingsModel.fromJson({
      'subathonSecondsPerSub': -1,
      'subathonSecondsPer100Bits': 9999,
      'subathonSecondsPer100Kicks': 1.5,
      'subathonMaxRemainingMinutes': 99999,
      'subathonStartMinutes': 0,
      'subathonPhase': 'bad',
      'subathonEndsAtMs': -1,
      'subathonRemainingMs': -1
    });
    expect(s.subathonSecondsPerSub, 0);
    expect(s.subathonSecondsPer100Bits, 3600);
    expect(s.subathonSecondsPer100Kicks, 2);
    expect(s.subathonMaxRemainingMinutes, 10080);
    expect(s.subathonStartMinutes, 1);
    expect(s.subathonPhase, 'idle');
    expect(s.subathonEndsAtMs, 0);
    expect(s.subathonRemainingMs, 0);
    final run = SubathonTimer.start(defaults, now);
    final profile = SettingsProfiles.capture(run);
    for (final key in [
      'subathonPhase',
      'subathonEndsAtMs',
      'subathonRemainingMs'
    ]) {
      expect(profile.containsKey(key), false);
    }
    for (final changed in [
      SettingsProfiles.apply(run, {
        'subathonPhase': 'idle',
        'subathonEndsAtMs': 0,
        'subathonRemainingMs': 99,
        'subathonSecondsPerSub': 5
      }),
      SettingsProfiles.resetToDefaults(run)
    ]) {
      expect(changed.subathonPhase, run.subathonPhase);
      expect(changed.subathonEndsAtMs, run.subathonEndsAtMs);
      expect(changed.subathonRemainingMs, run.subathonRemainingMs);
    }
    expect(SettingsProfiles.capture(run)['subathonSecondsPerSub'], 60);
  });
}

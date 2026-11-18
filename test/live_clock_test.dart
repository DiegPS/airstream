import 'package:airstream/application/live_clock.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const now = 100000;

  test('countdown pauses, resumes, adjusts and expires once', () {
    final running = (const LiveClock(durationSeconds: 5)).start(now);
    expect(running.anchorMs, now + 5000);
    final paused = running.pause(now + 500);
    expect(paused.phase, ClockPhase.paused);
    expect(paused.shownAt(now + 20000), 4500);
    final added = paused.addSeconds(now + 30000, 2);
    final resumed = added.start(now + 40000);
    expect(resumed.shownAt(now + 41000), 5500);
    final shortened = resumed.addSeconds(now + 41000, -5);
    expect(shortened.shownAt(now + 41000), 500);
    expect(shortened.expire(now + 41499), same(shortened));
    final ended = shortened.expire(now + 41500);
    expect(ended.phase, ClockPhase.ended);
    expect(ended.shownAt(now + 41500), 0);
    expect(ended.expire(now + 99999), same(ended));
    expect(ended.reset().shownAt(now), 5000);
    expect(paused.addSeconds(now, -60).phase, ClockPhase.ended);
    expect(paused.addSeconds(now, 999999).shownAt(now), 86400000);
  });

  test('running countdown and stopwatch survive a settings restart', () {
    LiveClock reload(LiveClock clock) =>
        SettingsDocumentCodec.decode(SettingsDocumentCodec.encode(
          SettingsModel(clock: clock),
        )).settings.clock;
    final countdown = reload((const LiveClock(durationSeconds: 3)).start(now));
    expect(countdown.shownAt(now + 750), 2250);
    expect(countdown.expire(now + 3000).phase, ClockPhase.ended);
    final watch = (const LiveClock(mode: ClockMode.stopwatch)).start(now);
    final lap = watch.pause(now + 2000);
    final restored = reload(lap.start(now + 3000));
    expect(restored.shownAt(now + 4500), 3500);
    expect(restored.addSeconds(now + 4500, 10), same(restored));
    expect(restored.configure(mode: ClockMode.clock).phase, ClockPhase.idle);
  });

  test('sanitizes settings and profiles capture setup without a deadline', () {
    final clock = LiveClock.fromJson({
      'mode': 'unknown',
      'style': 'unknown',
      'sound': 'relative.mp3',
      'durationSeconds': 90000,
      'phase': 'running',
      'anchorMs': -10,
      'label': '  Break  ',
    });
    expect(clock.mode, ClockMode.countdown);
    expect(clock.style, ClockStyle.big);
    expect(clock.sound, 'none');
    expect(clock.durationSeconds, 86400);
    expect(clock.phase, ClockPhase.idle);
    final settings = SettingsModel(clock: clock.start(now));
    final profile = SettingsProfiles.capture(settings);
    expect(profile['clock'], {
      'mode': 'countdown',
      'style': 'big',
      'durationSeconds': 86400,
      'sound': 'none',
      'label': 'Break'
    });
    expect(SettingsProfiles.apply(const SettingsModel(), profile).clock.phase,
        ClockPhase.idle);
    expect(SettingsProfiles.apply(settings, profile).clock.anchorMs,
        settings.clock.anchorMs);
  });
}

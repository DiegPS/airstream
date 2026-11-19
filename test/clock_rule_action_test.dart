import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/live_clock.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application/coordinator_fakes.dart';

AppController _controller() => AppController(
      audioCoordinator: AudioCoordinator(
          tts: FakeTtsClient(), captions: FakeCaptionsClient()),
      chatCoordinator: ChatCoordinator(
        youtube: FakeYouTubeChatClient(),
        youtubeHorizontal: FakeYouTubeChatClient(),
        youtubeVertical: FakeYouTubeChatClient(),
        twitch: FakeChannelChatClient(),
        kick: FakeChannelChatClient(),
      ),
      overlayCoordinator: OverlayCoordinator(overlay: FakeOverlayClient()),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
    );

Future<(String, String?, int)> _run(LiveClock clock, String op,
    {int seconds = 60}) async {
  final app = _controller();
  addTearDown(app.dispose);
  var writes = 0;
  app.ruleSettingsWriter = (settings) async {
    writes++;
    app.applySettings(settings, connectChats: false);
  };
  app.applySettings(
    SettingsModel(
      overlayEnabled: false,
      rulesEnabled: true,
      clock: clock,
      rules: [
        {
          ...RuleSchema.newRule('manual', id: 'clock'),
          'enabled': true,
          'actions': [
            {'id': 'a', 'type': 'clock', 'op': op, 'seconds': seconds},
          ],
        }
      ],
    ),
    connectChats: false,
  );
  expect(app.rules.runNow('clock', const RuleEvent(type: 'manual')), isNull);
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  final result = app.rules.history.single.results.single;
  return (result.status, result.reason, writes);
}

void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  const idle = LiveClock();
  final running = LiveClock(phase: ClockPhase.running, anchorMs: now + 120000);

  test('a clock rule that changes nothing is skipped, not done', () async {
    expect(await _run(idle, 'add'), ('skipped', 'clockUnchanged', 0));
    expect(await _run(const LiveClock(phase: ClockPhase.ended), 'add'),
        ('skipped', 'clockUnchanged', 0));
    expect(await _run(running, 'start'), ('skipped', 'clockUnchanged', 0));
    expect(await _run(idle, 'pause'), ('skipped', 'clockUnchanged', 0));
    expect(await _run(idle, 'reset'), ('skipped', 'clockUnchanged', 0));
    expect(await _run(const LiveClock(mode: ClockMode.clock), 'start'),
        ('skipped', 'clockUnchanged', 0));
    // Adding 0 seconds, or time to a paused timer already at its cap.
    expect(await _run(running, 'add', seconds: 0),
        ('skipped', 'clockUnchanged', 0));
    expect(
        await _run(
            const LiveClock(
                phase: ClockPhase.paused, valueMs: LiveClock.maxSeconds * 1000),
            'add'),
        ('skipped', 'clockUnchanged', 0));
  });

  test('a clock rule that changes the timer still runs', () async {
    expect(await _run(running, 'add'), ('done', null, 1));
    expect(await _run(idle, 'start'), ('done', null, 1));
    expect(await _run(running, 'pause'), ('done', null, 1));
    expect(await _run(running, 'reset'), ('done', null, 1));
  });
}

import 'package:airstream/services/overlay_server.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:airstream/application/rules/rule_obs_transitions.dart';
import 'package:airstream/application/rules/rule_sound_player.dart';
import 'package:airstream/application/rules/rule_actions.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/settings/settings_model.dart';
import 'application/coordinator_fakes.dart';
import 'rule_engine_test.dart' show Target, rule;

class Playback extends NativeAudioPlaybackService {
  final files = <File>[];
  final volumes = <double?>[];
  int stops = 0;
  @override
  Future<void> playFile(File file,
      {Duration timeout = const Duration(seconds: 20), double? volume}) async {
    files.add(file);
    volumes.add(volume);
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class AlertTarget extends OverlayServer {
  int calls = 0;
  bool connected = true;
  @override
  Map<String, int> get viewCounts => {'alerts': connected ? 1 : 0};
  @override
  bool broadcastRuleAlert(
      {required String title,
      required String text,
      String mediaId = '',
      required int seconds}) {
    calls++;
    expect(title, '<b>hi</b>');
    expect(text, 'Text');
    expect(seconds, 3);
    return connected;
  }
}

class SoundTarget extends RuleSoundPlayer {
  SoundTarget() : super(settings: () => const SettingsModel());
  int calls = 0;
  @override
  Future<bool> play(Map<String, dynamic> action) async {
    calls++;
    return true;
  }
}

void main() {
  test('OBS baseline, real transitions once, reconnect and user scene', () {
    final adapter = RuleObsTransitions();
    var state = const ObsState(
        connected: true,
        connectionGeneration: 1,
        recordingActive: true,
        currentScene: 'Main');
    expect(adapter.observe(state), isEmpty);
    state = state.copyWith(recordingActive: false);
    expect(adapter.observe(state).single.type, 'obs.recordingStopped');
    expect(adapter.observe(state), isEmpty);
    state = state.copyWith(recordingActive: true);
    expect(adapter.observe(state).single.type, 'obs.recordingStarted');
    expect(adapter.observe(state), isEmpty);
    state = state.copyWith(connectionGeneration: 2, recordingActive: false);
    expect(adapter.observe(state), isEmpty);
    state = state.copyWith(currentScene: 'Game');
    final event = adapter.observe(state).single;
    expect(event.type, 'obs.sceneChanged');
    expect(event.scene, 'Game');
    expect(event.chainDepth, 0);
    expect(adapter.observe(state.copyWith(outputActive: true)).single.type,
        'obs.streamStarted');
    expect(adapter.observe(state).single.type, 'obs.streamStopped');
    expect(adapter.observe(state.copyWith(connected: false)), isEmpty);
    expect(adapter.observe(state.copyWith(recordingActive: true)), isEmpty);
  });
  test('rule scene feedback stops two-rule loop at chain limit', () {
    fakeAsync((a) {
      final target = Target(), transitions = RuleObsTransitions();
      var state = const ObsState(connected: true, currentScene: 'Initial');
      transitions.observe(state);
      final engine = RuleEngine(target: target);
      engine.updateSettings(enabled: true, rules: [
        for (final scene in ['A', 'B'])
          {
            ...rule(
                id: scene.toLowerCase(),
                type: 'obs.sceneChanged',
                actions: [
                  {
                    'id': 'a',
                    'type': 'obs.scene',
                    'scene': scene == 'A' ? 'B' : 'A'
                  }
                ]),
            'trigger': {'type': 'obs.sceneChanged', 'scene': scene}
          }
      ]);
      target.onAction = (run) {
        final scene = run.rule['actions'][0]['scene'] as String;
        transitions.expectScene(scene, run.event.chainDepth + 1);
        state = state.copyWith(currentScene: scene);
        for (final e in transitions.observe(state)) {
          engine.handle(e);
        }
      };
      state = state.copyWith(currentScene: 'A');
      engine.handle(transitions.observe(state).single);
      a.elapse(Duration.zero);
      expect(engine.history.map((r) => r.event.chainDepth), [2, 1, 0]);
      expect(target.calls.length, 3);
      engine.dispose();
      a.flushMicrotasks();
    });
  });
  test('one interval scheduler, independent due times, pause and disable', () {
    fakeAsync((a) {
      final target = Target();
      final engine = RuleEngine(
          target: target, clock: () => DateTime.utc(2026).add(a.elapsed));
      expect(engine.intervalTimerActive, false);
      final rules = [
        {
          ...rule(id: 'five', type: 'interval'),
          'trigger': {'type': 'interval', 'minutes': 5}
        },
        {
          ...rule(id: 'ten', type: 'interval'),
          'trigger': {'type': 'interval', 'minutes': 10},
          'conditions': {'onlyWhileStreaming': true}
        }
      ];
      engine.updateSettings(enabled: true, rules: rules);
      expect(engine.intervalTimerActive, false);
      engine.updateEnvironment(chatConnected: true);
      a.elapse(const Duration(minutes: 5));
      expect(engine.history.length, 1);
      a.elapse(const Duration(minutes: 5));
      expect(engine.history.length, 3);
      expect(engine.history.map((r) => r.event.eventId).toSet().length, 3);
      target.streaming = false;
      engine.updateEnvironment();
      a.elapse(const Duration(minutes: 10));
      expect(engine.history.length, 5);
      target.streaming = true;
      engine.updateEnvironment();
      a.elapse(const Duration(minutes: 9));
      expect(engine.history.where((r) => r.ruleId == 'ten').length, 1);
      a.elapse(const Duration(minutes: 1));
      expect(engine.history.where((r) => r.ruleId == 'ten').length, 2);
      engine.updateEnvironment(chatConnected: false);
      expect(engine.intervalTimerActive, false);
      a.elapse(const Duration(minutes: 30));
      final count = engine.history.length;
      engine.updateEnvironment(chatConnected: true);
      a.elapse(const Duration(minutes: 4));
      expect(engine.history.length, count);
      engine.updateSettings(enabled: false, rules: rules);
      expect(engine.intervalTimerActive, false);
      engine.dispose();
      a.flushMicrotasks();
    });
  });
  test(
      'native rule sounds cache builtins, use library, replace and report missing',
      () async {
    final directory = await Directory.systemTemp.createTemp('rule-sounds');
    final playback = Playback();
    var settings = const SettingsModel(alertSoundVolume: 32);
    final player = RuleSoundPlayer(
        settings: () => settings,
        playback: playback,
        cache: () async => directory,
        library: () async =>
            MediaLibrary(directory, () => settings.mediaLibrary));
    for (final name in ['chime', 'coin', 'fanfare', 'chime']) {
      expect(await player.play({'source': 'builtin', 'name': name}), true);
    }
    expect(directory.listSync().length, 3);
    expect(playback.stops, 4);
    expect(playback.volumes, everyElement(.32));
    final metadata = {
      'name': 'clip.wav',
      'kind': 'audio',
      'ext': 'wav',
      'bytes': 50,
      'addedAt': 0
    };
    settings = settings.copyWith(mediaLibrary: {'0123456789abcdef': metadata});
    await File('${directory.path}/0123456789abcdef.wav').writeAsBytes([1, 2]);
    expect(
        await player.play({'source': 'library', 'mediaId': '0123456789abcdef'}),
        true);
    expect(playback.files.last.path, endsWith('0123456789abcdef.wav'));
    expect(
        await player.play({'source': 'library', 'mediaId': 'ffffffffffffffff'}),
        false);
    await player.dispose();
    await directory.delete(recursive: true);
  });
  test(
      'new action preflight and simulation never contact targets; OBS errors classified',
      () async {
    final client = FakeObsClient();
    client.state = const ObsState(connected: true);
    final obs = ObsCoordinator(obs: client);
    final audio =
        AudioCoordinator(tts: FakeTtsClient(), captions: FakeCaptionsClient());
    final giveaway = ChatGiveawayController();
    var settings = const SettingsModel(obsEnabled: true);
    final soundTarget = SoundTarget();
    AlertTarget? alertTarget;
    final actions = RuleActions(
        sounds: soundTarget,
        settings: () => settings,
        writeSettings: (_, depth) async {},
        obs: obs,
        audio: audio,
        giveaway: giveaway,
        server: () => alertTarget,
        feature: (_) {},
        draw: (_) {});
    final engine = RuleEngine(target: actions);
    final definition = rule(actions: [
      {
        'id': 's',
        'type': 'obs.source',
        'scene': '',
        'source': 'Camera',
        'visible': 'toggle'
      },
      {'id': 'm', 'type': 'obs.mute', 'input': 'Mic', 'state': 'toggle'},
      {
        'id': 'p',
        'type': 'sound.play',
        'source': 'builtin',
        'name': 'coin',
        'mediaId': ''
      },
      {
        'id': 'a',
        'type': 'alert.show',
        'title': '<b>hi</b>',
        'text': 'Text',
        'mediaId': '',
        'seconds': 3
      },
    ]);
    final sim = engine.simulate(definition, const RuleEvent(type: 'manual'));
    expect(sim.results.map((r) => r.reason),
        ['willCheckInObs', 'willCheckInObs', null, 'noAlertsPage']);
    expect(client.switchSceneCount, 0);
    expect(client.ruleControls, isEmpty);
    alertTarget = AlertTarget();
    expect(
        engine
            .simulate(definition, const RuleEvent(type: 'manual'))
            .results
            .last
            .status,
        'wouldRun');
    expect(alertTarget.calls, 0);
    alertTarget = null;
    settings = settings.copyWith(obsEnabled: false);
    expect(
        engine
            .simulate(definition, const RuleEvent(type: 'manual'))
            .results
            .first
            .reason,
        'notConnected');
    settings = settings.copyWith(obsEnabled: true);
    final run = RuleRun(
        id: 'test',
        rule: definition,
        event: const RuleEvent(type: 'manual'),
        startedAt: DateTime.now(),
        generation: 0);
    for (final visibility in ['show', 'hide', 'toggle']) {
      expect(
          (await actions.execute({
            'type': 'obs.source',
            'scene': '',
            'source': 'Camera',
            'visible': visibility
          }, run))
              .status,
          'done');
    }
    for (final state in ['mute', 'unmute', 'toggle']) {
      expect(
          (await actions.execute(
                  {'type': 'obs.mute', 'input': 'Mic', 'state': state}, run))
              .status,
          'done');
    }
    client.commandError =
        ObsRequestException(requestType: 'GetSceneItemId', code: 600);
    expect(
        (await actions.execute({
          'type': 'obs.source',
          'scene': '',
          'source': 'Missing',
          'visible': 'show'
        }, run))
            .reason,
        'notFound');
    expect(
        (await actions.execute(
                {'type': 'obs.mute', 'input': 'Missing', 'state': 'mute'}, run))
            .reason,
        'notFound');
    alertTarget = AlertTarget();
    expect(
        (await actions.execute(
                Map<String, dynamic>.from(definition['actions'][3] as Map),
                run))
            .status,
        'done');
    expect(alertTarget.calls, 1);
    alertTarget = null;
    client.commandError = TimeoutException('OBS did not answer');
    engine.updateSettings(enabled: true, rules: [definition]);
    expect(engine.fireManual('r'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(engine.history.single.results.take(2).map((r) => r.status),
        ['uncertain', 'uncertain']);
    expect(engine.history.single.results.take(2).map((r) => r.reason),
        ['timeout', 'timeout']);
    expect(soundTarget.calls, 1);
    await engine.dispose();
    await actions.sounds.dispose();
    await obs.dispose();
    await audio.dispose();
    await giveaway.dispose();
  });
}

import 'dart:async';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/obs_coordinator.dart'
    show ObsCoordinator, ObsServiceAdapter;
import 'package:airstream/application/rules/rule_actions.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/obs/obs_client.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obs_websocket/obs_websocket.dart' show ObsRequestException;

import 'application/coordinator_fakes.dart'
    show FakeTtsClient, FakeCaptionsClient;
import 'rule_engine_test.dart' show rule;

void main() {
  test('missing OBS host is exposed as an actionable state error', () async {
    final service = ObsService();
    addTearDown(service.dispose);

    await service.connect(host: '  ', password: 'not-logged');

    expect(service.currentState.connected, isFalse);
    expect(service.currentState.statusMessage, 'OBS host required');
    expect(service.currentState.error, contains('OBS WebSocket host'));
  });

  test('OBS state carries recording status and metrics', () {
    final state = const ObsState().copyWith(
      recordingActive: true,
      recordingPaused: true,
      recordingDurationMs: 3723000,
      recordingBytes: 1073741824,
    );

    expect(state.recordingActive, isTrue);
    expect(state.recordingPaused, isTrue);
    expect(state.recordingDurationMs, 3723000);
    expect(state.recordingBytes, 1073741824);
  });

  test('a successful OBS operation clears a stale error', () {
    final failed = const ObsState().copyWith(
      connected: true,
      error: 'Could not switch scene',
    );

    final recovered = failed.copyWith(clearError: true);

    expect(recovered.connected, isTrue);
    expect(recovered.error, isNull);
  });

  test('poll failures remain tolerant before marking OBS unstable', () {
    expect(
      ObsService.pollFailureActionFor(1),
      ObsPollFailureAction.preserve,
    );
    expect(
      ObsService.pollFailureActionFor(2),
      ObsPollFailureAction.preserve,
    );
  });

  test('poll failures mark OBS unstable before reconnect threshold', () {
    for (var failures = 3; failures < 8; failures++) {
      expect(
        ObsService.pollFailureActionFor(failures),
        ObsPollFailureAction.unstable,
      );
    }
  });

  test('poll failures reconnect after eight consecutive failures', () {
    expect(
      ObsService.pollFailureActionFor(8),
      ObsPollFailureAction.reconnect,
    );
    expect(
      ObsService.pollFailureActionFor(10),
      ObsPollFailureAction.reconnect,
    );
  });

  test('uses an injected OBS client for connection, polling, and commands',
      () async {
    final client = _FakeObsClient();
    final service = ObsService(
      connector: (
          {required url,
          required password,
          required onDone,
          required onEvent}) async {
        expect(url, 'ws://studio.local:4455');
        expect(password, 'secret');
        return client;
      },
      statsPollInterval: const Duration(milliseconds: 2),
    );
    addTearDown(service.dispose);

    await service.connect(host: 'studio.local:4455', password: 'secret');
    expect(service.currentState.connected, isTrue);
    expect(service.currentState.currentScene, 'Main');
    await service.startRecording();
    await service.pauseRecording();
    await service.resumeRecording();
    await service.stopRecording();
    await service.switchScene('BRB');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(client.commands, ['start', 'pause', 'resume', 'stop', 'scene:BRB']);
    expect(client.statsCalls, greaterThan(1));
    await service.disconnect();
    expect(client.closeCount, 1);
  });

  test('OBS switches to the scene a spoken name refers to', () async {
    final client = _FakeObsClient();
    final service = ObsService(
      connector: ({
        required String url,
        required String? password,
        required void Function() onDone,
        required void Function(dynamic event) onEvent,
      }) async =>
          client,
      statsPollInterval: const Duration(milliseconds: 2),
    );
    addTearDown(service.dispose);
    await service.connect(host: 'localhost:4455', password: '');

    await service.switchScene('escena juego');
    await service.switchScene('charla final');
    await expectLater(
      service.switchScene('inexistente'),
      throwsA(isA<StateError>()),
    );

    expect(client.commands, ['scene:Escena-Juego', 'scene:Charla Final']);
  });

  test('OBS exposes a client connection timeout as state', () async {
    final pending = Completer<ObsClient>();
    final service = ObsService(
      connector: (
              {required url,
              required password,
              required onDone,
              required onEvent}) =>
          pending.future,
      connectionTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);

    await service.connect(host: 'localhost:4455', password: 'secret');

    expect(service.currentState.connected, isFalse);
    expect(service.currentState.statusMessage, 'Connection failed');
    expect(service.currentState.error, contains('TimeoutException'));
  });

  group('OBS text and filter rules', () {
    late _FakeObsClient client;
    late ObsService service;
    late RuleEngine engine;
    late SettingsModel settings;
    const manual = RuleEvent(type: 'manual');
    const textAction = {
      'id': 'text',
      'type': 'obs.text',
      'source': 'Muertes',
      'text': '',
    };
    Map<String, dynamic> filterAction(String state) => {
          'id': state,
          'type': 'obs.filter',
          'source': 'Main',
          'filter': 'Blur',
          'state': state,
        };

    setUp(() async {
      client = _FakeObsClient();
      service = ObsService(
        connector: (
                {required url,
                required password,
                required onDone,
                required onEvent}) async =>
            client,
      );
      final obs = ObsCoordinator(obs: ObsServiceAdapter(service));
      final audio = AudioCoordinator(
          tts: FakeTtsClient(), captions: FakeCaptionsClient());
      final giveaway = ChatGiveawayController();
      final queue = ChatQueueController();
      settings =
          const SettingsModel(obsEnabled: true, ruleCounters: {'muertes': 4});
      final actions = RuleActions(
        settings: () => settings,
        writeSettings: (next, _) async => settings = next,
        obs: obs,
        audio: audio,
        giveaway: giveaway,
        queue: queue,
        server: () => null,
        feature: (_) {},
        draw: (_) {},
      );
      engine = RuleEngine(target: actions);
      addTearDown(() async {
        await engine.dispose();
        await actions.sounds.dispose();
        await obs.dispose();
        await audio.dispose();
        await giveaway.dispose();
        await queue.dispose();
      });
      await service.connect(host: 'studio.local:4455', password: '');
      expect(service.currentState.connected, isTrue);
    });

    Future<List<(String, String?)>> run(
        Map<String, dynamic> definition, RuleEvent event) async {
      engine.updateSettings(enabled: true, rules: [definition]);
      final finished =
          engine.historyStream.firstWhere((history) => history.first.completed);
      expect(engine.handle(event)['r'], isNull);
      final results = (await finished).first.results;
      return [for (final result in results) (result.status, result.reason)];
    }

    test('merges only resolved text using the updated counter, then clears it',
        () async {
      final definition = rule(type: 'chat.command', actions: [
        {
          'id': 'counter',
          'type': 'counter',
          'name': 'muertes',
          'op': 'add',
          'value': 1
        },
        {...textAction, 'text': 'Muertes: {counter.muertes} ({arg1})'},
        {...textAction, 'id': 'clear'},
      ]);
      const event = RuleEvent(type: 'chat.command', text: '!hello Alex');
      expect(await run(definition, event),
          [('done', null), ('done', null), ('done', null)]);
      expect(settings.ruleCounters, {'muertes': 5});
      expect(client.commands,
          ['kind:Muertes', 'set:Muertes', 'kind:Muertes', 'set:Muertes']);
      expect(
          client.inputWrites.map((write) => [write.$1, write.$2, write.$3]), [
        [
          'Muertes',
          {'text': 'Muertes: 5 (Alex)'},
          true
        ],
        [
          'Muertes',
          {'text': ''},
          true
        ],
      ]);
    });

    test('rejects non-text input kinds and reports the OBS control error',
        () async {
      client.kind = 'browser_source';
      expect(await run(rule(actions: [textAction]), manual),
          [('failed', 'notTextSource')]);
      expect(client.commands, ['kind:Muertes']);
      expect(client.inputWrites, isEmpty);
      expect(service.currentState.error, contains('Not a text source'));
    });

    test('enables and disables directly and reads the state for each toggle',
        () async {
      expect(
          await run(
              rule(actions: [
                filterAction('enable'),
                filterAction('disable'),
                filterAction('toggle'),
                {...filterAction('toggle'), 'id': 'toggle_again'},
              ]),
              manual),
          List.filled(4, ('done', null)));
      expect(client.commands, [
        'filter:Main:Blur:true',
        'filter:Main:Blur:false',
        'read-filter:Main:Blur',
        'filter:Main:Blur:true',
        'read-filter:Main:Blur',
        'filter:Main:Blur:false',
      ]);
    });

    for (final (request, code, action) in [
      ('GetInputSettings', 600, textAction),
      ('SetInputSettings', 601, textAction),
      ('SetSourceFilterEnabled', 600, filterAction('enable')),
      ('GetSourceFilter', 601, filterAction('toggle')),
    ]) {
      test('$request reports OBS error $code as notFound', () async {
        client.requestError =
            ObsRequestException(requestType: request, code: code);
        expect(await run(rule(actions: [action]), manual),
            [('failed', 'notFound')]);
        expect(service.currentState.error, contains('code $code'));
        expect(client.inputWrites, isEmpty);
        expect(
            client.commands.where((command) => command.startsWith('filter:')),
            isEmpty);
      });
    }

    test('simulates both actions without requests and skips both offline',
        () async {
      final definition = rule(actions: [textAction, filterAction('toggle')]);
      final preview = engine.simulate(definition, manual);
      expect(preview.matched, isTrue);
      expect(preview.results.map((r) => (r.status, r.reason)),
          List.filled(2, ('wouldRun', 'willCheckInObs')));
      expect(client.commands, isEmpty);
      await service.disconnect();
      expect(await run(definition, manual),
          List.filled(2, ('skipped', 'notConnected')));
      expect(client.commands, isEmpty);
    });
  });
}

class _FakeObsClient implements ObsClient {
  @override
  Future<void> source(String scene, String source, String visibility) async =>
      commands.add('source:$scene:$source:$visibility');
  @override
  Future<void> mute(String input, String state) async =>
      commands.add('mute:$input:$state');
  final commands = <String>[];
  final inputWrites = <(String, Map<String, dynamic>, bool)>[];
  String kind = 'text_gdiplus_v3';
  bool filterIsEnabled = false;
  ObsRequestException? requestError;
  int statsCalls = 0;
  int closeCount = 0;

  void failRequest(String request) {
    final error = requestError;
    if (error != null && error.requestType == request) throw error;
  }

  @override
  Future<String> inputKind(String input) async {
    commands.add('kind:$input');
    failRequest('GetInputSettings');
    return kind;
  }

  @override
  Future<void> setInputSettings(String input, Map<String, dynamic> settings,
      {required bool overlay}) async {
    failRequest('SetInputSettings');
    commands.add('set:$input');
    inputWrites.add((input, settings, overlay));
  }

  @override
  Future<bool> filterEnabled(String source, String filter) async {
    commands.add('read-filter:$source:$filter');
    failRequest('GetSourceFilter');
    return filterIsEnabled;
  }

  @override
  Future<void> setFilterEnabled(
      String source, String filter, bool enabled) async {
    failRequest('SetSourceFilterEnabled');
    commands.add('filter:$source:$filter:$enabled');
    filterIsEnabled = enabled;
  }

  @override
  Future<void> subscribeOutputsAndScenes() async {}
  @override
  Future<String> currentProgramScene() async => 'Main';
  @override
  Future<ObsStreamSnapshot> streamStatus() async => const ObsStreamSnapshot(
        outputActive: true,
        outputReconnecting: false,
        outputBytes: 1000,
        outputDuration: 1000,
        outputSkippedFrames: 0,
        outputTotalFrames: 60,
      );
  @override
  Future<ObsRecordSnapshot> recordStatus() async => const ObsRecordSnapshot(
        outputActive: false,
        outputPaused: false,
        outputDuration: 0,
        outputBytes: 0,
      );
  @override
  Future<ObsStatsSnapshot> stats() async {
    statsCalls++;
    return const ObsStatsSnapshot(activeFps: 60);
  }

  @override
  Future<void> startRecording() async => commands.add('start');
  @override
  Future<void> stopRecording() async => commands.add('stop');
  @override
  Future<void> pauseRecording() async => commands.add('pause');
  @override
  Future<void> resumeRecording() async => commands.add('resume');
  @override
  Future<void> switchScene(String sceneName) async =>
      commands.add('scene:$sceneName');
  List<String> scenes = const ['Main', 'BRB', 'Escena-Juego', 'Charla Final'];
  @override
  Future<List<String>> sceneNames() async => scenes;
  @override
  Future<void> close() async => closeCount++;
}

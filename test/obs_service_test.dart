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
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:obs_websocket/obs_websocket.dart' as websocket
    show
        ObsRequestException,
        ObsWebSocket,
        Request,
        RequestResponse,
        RequestStatus;
import 'package:obs_websocket/request.dart' as requests;

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

  test('OBS adapter sends the exact phase 11 request payloads', () async {
    final socket = _RecordingSocket();
    final client = ObsWebSocketClient(socket);
    await client.stream(true);
    await client.stream(false);
    for (final op in ['save', 'start', 'stop']) {
      await client.replay(op);
    }
    for (final op in ['play', 'pause', 'restart', 'stop']) {
      await client.media('Clip', op);
    }
    expect(await client.inputVolumeDb('Mic'), -18.5);
    await client.setInputVolumeDb('Mic', 2.5);
    expect(await client.inputKind('Browser'), 'browser_source');
    await client.pressInputButton('Browser', 'refreshnocache');
    expect(socket.sent.map((r) => [r.requestType, r.requestData]), [
      ['StartStream', null],
      ['StopStream', null],
      ['SaveReplayBuffer', null],
      ['StartReplayBuffer', null],
      ['StopReplayBuffer', null],
      for (final op in ['PLAY', 'PAUSE', 'RESTART', 'STOP'])
        [
          'TriggerMediaInputAction',
          {
            'inputName': 'Clip',
            'inputUuid': null,
            'mediaAction': 'OBS_WEBSOCKET_MEDIA_INPUT_ACTION_$op'
          }
        ],
      [
        'GetInputVolume',
        {'inputName': 'Mic', 'inputUuid': null}
      ],
      [
        'SetInputVolume',
        {'inputName': 'Mic', 'inputVolumeDb': 2.5}
      ],
      [
        'GetInputSettings',
        {'inputName': 'Browser', 'inputUuid': null}
      ],
      [
        'PressInputPropertiesButton',
        {
          'inputName': 'Browser',
          'inputUuid': null,
          'propertyName': 'refreshnocache'
        }
      ],
    ]);
  });

  group('OBS rules', () {
    late _FakeObsClient client;
    late ObsService service;
    late RuleEngine engine;
    late RuleActions actions;
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
      actions = RuleActions(
        settings: () => settings,
        writeSettings: (next, _) async => settings = next,
        obs: obs,
        audio: audio,
        giveaway: giveaway,
        queue: queue,
        server: () => null,
        feature: (_) => FeaturedMessageDelivery.noReceiver(),
        draw: (count, depth) {},
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
            websocket.ObsRequestException(requestType: request, code: code);
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

    Map<String, dynamic> stream(String state) =>
        {'id': state, 'type': 'obs.stream', 'state': state};
    Map<String, dynamic> replay(String op) =>
        {'id': op, 'type': 'obs.replay', 'op': op};
    const refresh = {
      'id': 'refresh',
      'type': 'obs.refresh',
      'source': 'Browser'
    };
    const volume = {
      'id': 'volume',
      'type': 'obs.volume',
      'input': 'Mic',
      'mode': 'set',
      'db': -6
    };
    const media = {
      'id': 'media',
      'type': 'obs.media',
      'source': 'Video',
      'op': 'restart'
    };

    test('skips redundant stream state and sends start and stop when needed',
        () async {
      final definition = rule(actions: [stream('start'), stream('stop')]);
      expect(await run(definition, manual),
          [('skipped', 'streamAlready'), ('done', null)]);
      expect(client.commands, ['StopStream']);
      await service.disconnect();
      client.streaming = false;
      await service.connect(host: 'studio.local:4455', password: '');
      expect(
          await run(rule(actions: [stream('stop'), stream('start')]), manual),
          [('skipped', 'streamAlready'), ('done', null)]);
      expect(client.commands, ['StopStream', 'StartStream']);
    });

    test('blocks public chat stream control in the engine and action target',
        () async {
      final definition = rule(type: 'chat.command', actions: [stream('stop')]);
      const event = RuleEvent(type: 'chat.command', text: '!hello');
      expect(engine.simulate(definition, event).results.single.reason,
          'publicStreamControl');
      expect(
          await run(definition, event), [('skipped', 'publicStreamControl')]);
      final direct =
          await actions.execute(stream('stop'), engine.history.single);
      expect(
          (direct.status, direct.reason), ('skipped', 'publicStreamControl'));
      expect(client.commands, isEmpty);
    });

    test('sends all replay and media operations', () async {
      final definition = rule(actions: [
        for (final op in ['save', 'start', 'stop']) replay(op),
        for (final op in ['play', 'pause', 'restart', 'stop'])
          {...media, 'id': 'media_$op', 'op': op},
      ]);
      expect(await run(definition, manual), List.filled(7, ('done', null)));
      expect(client.commands, [
        'SaveReplayBuffer',
        'StartReplayBuffer',
        'StopReplayBuffer',
        'media:Video:play',
        'media:Video:pause',
        'media:Video:restart',
        'media:Video:stop',
      ]);
    });

    for (final (op, request, code, status, reason) in [
      ('save', 'SaveReplayBuffer', 501, 'failed', 'replayOff'),
      ('start', 'StartReplayBuffer', 500, 'skipped', 'replayAlready'),
      ('stop', 'StopReplayBuffer', 501, 'skipped', 'replayAlready'),
    ]) {
      test('maps $request error $code to $reason', () async {
        client.requestError =
            websocket.ObsRequestException(requestType: request, code: code);
        expect(
            await run(rule(actions: [replay(op)]), manual), [(status, reason)]);
      });
    }

    test('sets dB directly and reads and clamps each relative change',
        () async {
      final definition = rule(actions: [
        volume,
        {...volume, 'id': 'up', 'mode': 'change', 'db': 100},
        {...volume, 'id': 'down', 'mode': 'change', 'db': -100},
        {...volume, 'id': 'clamp', 'mode': 'change', 'db': -100},
      ]);
      expect(await run(definition, manual), List.filled(4, ('done', null)));
      expect(client.commands, [
        'set-volume:Mic:-6.0',
        'read-volume:Mic',
        'set-volume:Mic:26.0',
        'read-volume:Mic',
        'set-volume:Mic:-74.0',
        'read-volume:Mic',
        'set-volume:Mic:-100.0',
      ]);
    });

    test('refresh only presses refreshnocache for browser sources', () async {
      final definition = rule(actions: [refresh]);
      expect(await run(definition, manual), [('failed', 'notBrowserSource')]);
      expect(client.commands, ['kind:Browser']);
      client.kind = 'browser_source';
      expect(await run(definition, manual), [('done', null)]);
      expect(client.commands,
          ['kind:Browser', 'kind:Browser', 'press:Browser:refreshnocache']);
    });

    for (final (request, code, action) in [
      ('TriggerMediaInputAction', 600, media),
      ('GetInputVolume', 601, {...volume, 'mode': 'change'}),
      ('GetInputSettings', 600, refresh),
    ]) {
      test('$request maps error $code to notFound', () async {
        client.requestError =
            websocket.ObsRequestException(requestType: request, code: code);
        expect(await run(rule(actions: [action]), manual),
            [('failed', 'notFound')]);
        expect(
            client.commands.where((command) =>
                command.startsWith('set-volume:') ||
                command.startsWith('press:')),
            isEmpty);
      });
    }

    test('simulates all new OBS actions and skips them when disconnected',
        () async {
      final definition = rule(actions: [
        stream('stop'),
        replay('save'),
        media,
        volume,
        refresh,
      ]);
      expect(engine.simulate(definition, manual).results.map((r) => r.reason),
          List.filled(5, 'willCheckInObs'));
      expect(client.commands, isEmpty);
      await service.disconnect();
      expect(await run(definition, manual),
          List.filled(5, ('skipped', 'notConnected')));
      expect(client.commands, isEmpty);
    });
  });
}

class _RecordingSocket implements websocket.ObsWebSocket {
  final sent = <websocket.Request>[];

  @override
  late final requests.Inputs inputs = requests.Inputs(this);
  @override
  late final requests.MediaInputs mediaInputs = requests.MediaInputs(this);
  @override
  late final requests.Outputs outputs = requests.Outputs(this);
  @override
  late final requests.Stream stream = requests.Stream(this);

  @override
  Future<websocket.RequestResponse?> sendRequest(
      websocket.Request request) async {
    sent.add(request);
    return websocket.RequestResponse(
      requestType: request.requestType,
      requestId: request.requestId,
      requestStatus:
          websocket.RequestStatus(result: true, code: 100, comment: null),
      responseData: switch (request.requestType) {
        'GetInputVolume' => {'inputVolumeDb': -18.5, 'inputVolumeMul': 0.12},
        'GetInputSettings' => {
            'inputKind': 'browser_source',
            'inputSettings': <String, dynamic>{}
          },
        _ => null,
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
  websocket.ObsRequestException? requestError;
  bool streaming = true;
  double volumeDb = -10;
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
  Future<void> stream(bool start) async =>
      commands.add(start ? 'StartStream' : 'StopStream');

  @override
  Future<void> replay(String operation) async {
    final request = switch (operation) {
      'start' => 'StartReplayBuffer',
      'stop' => 'StopReplayBuffer',
      _ => 'SaveReplayBuffer',
    };
    commands.add(request);
    failRequest(request);
  }

  @override
  Future<void> media(String source, String operation) async {
    failRequest('TriggerMediaInputAction');
    commands.add('media:$source:$operation');
  }

  @override
  Future<double> inputVolumeDb(String input) async {
    commands.add('read-volume:$input');
    failRequest('GetInputVolume');
    return volumeDb;
  }

  @override
  Future<void> setInputVolumeDb(String input, double db) async {
    commands.add('set-volume:$input:$db');
    volumeDb = db;
  }

  @override
  Future<void> pressInputButton(String input, String property) async =>
      commands.add('press:$input:$property');

  @override
  Future<void> subscribeOutputsAndScenes() async {}
  @override
  Future<String> currentProgramScene() async => 'Main';
  @override
  Future<ObsStreamSnapshot> streamStatus() async => ObsStreamSnapshot(
        outputActive: streaming,
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

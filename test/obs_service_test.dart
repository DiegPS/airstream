import 'dart:async';

import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/obs/obs_client.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

class _FakeObsClient implements ObsClient {
  final commands = <String>[];
  int statsCalls = 0;
  int closeCount = 0;

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
  @override
  Future<void> close() async => closeCount++;
}

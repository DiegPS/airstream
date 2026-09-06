import 'package:obs_websocket/obs_websocket.dart';

class ObsStreamSnapshot {
  const ObsStreamSnapshot({
    required this.outputActive,
    required this.outputReconnecting,
    required this.outputBytes,
    required this.outputDuration,
    required this.outputSkippedFrames,
    required this.outputTotalFrames,
  });
  final bool outputActive;
  final bool outputReconnecting;
  final int outputBytes;
  final int outputDuration;
  final int outputSkippedFrames;
  final int outputTotalFrames;
}

class ObsRecordSnapshot {
  const ObsRecordSnapshot({
    required this.outputActive,
    required this.outputPaused,
    required this.outputDuration,
    required this.outputBytes,
  });
  final bool outputActive;
  final bool outputPaused;
  final int outputDuration;
  final int outputBytes;
}

class ObsStatsSnapshot {
  const ObsStatsSnapshot({required this.activeFps});
  final double activeFps;
}

abstract interface class ObsClient {
  Future<void> subscribeOutputsAndScenes();
  Future<String> currentProgramScene();
  Future<ObsStreamSnapshot> streamStatus();
  Future<ObsRecordSnapshot> recordStatus();
  Future<ObsStatsSnapshot> stats();
  Future<void> startRecording();
  Future<void> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<void> switchScene(String sceneName);
  Future<void> close();
}

typedef ObsClientConnector = Future<ObsClient> Function({
  required String url,
  required String? password,
  required void Function() onDone,
  required void Function(dynamic event) onEvent,
});

class ObsWebSocketClient implements ObsClient {
  ObsWebSocketClient._(this._socket);
  final ObsWebSocket _socket;

  static Future<ObsClient> connect({
    required String url,
    required String? password,
    required void Function() onDone,
    required void Function(dynamic event) onEvent,
  }) async {
    final socket = await ObsWebSocket.connect(
      url,
      password: password,
      onDone: onDone,
      fallbackEventHandler: onEvent,
    );
    return ObsWebSocketClient._(socket);
  }

  @override
  Future<void> subscribeOutputsAndScenes() => _socket.subscribe(
        EventSubscription.scenes | EventSubscription.outputs,
      );
  @override
  Future<String> currentProgramScene() =>
      _socket.scenes.getCurrentProgramScene();
  @override
  Future<ObsStreamSnapshot> streamStatus() async {
    final value = await _socket.stream.getStreamStatus();
    return ObsStreamSnapshot(
      outputActive: value.outputActive,
      outputReconnecting: value.outputReconnecting,
      outputBytes: value.outputBytes,
      outputDuration: value.outputDuration,
      outputSkippedFrames: value.outputSkippedFrames,
      outputTotalFrames: value.outputTotalFrames,
    );
  }

  @override
  Future<ObsRecordSnapshot> recordStatus() async {
    final value = await _socket.record.getRecordStatus();
    return ObsRecordSnapshot(
      outputActive: value.outputActive,
      outputPaused: value.outputPaused,
      outputDuration: value.outputDuration,
      outputBytes: value.outputBytes,
    );
  }

  @override
  Future<ObsStatsSnapshot> stats() async {
    final value = await _socket.general.getStats();
    return ObsStatsSnapshot(activeFps: value.activeFps.toDouble());
  }

  @override
  Future<void> startRecording() => _socket.record.startRecord();
  @override
  Future<void> stopRecording() async => _socket.record.stopRecord();
  @override
  Future<void> pauseRecording() => _socket.record.pauseRecord();
  @override
  Future<void> resumeRecording() => _socket.record.resumeRecord();
  @override
  Future<void> switchScene(String sceneName) =>
      _socket.scenes.setCurrentProgramScene(sceneName);
  @override
  Future<void> close() => _socket.close();
}

import 'dart:async';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/log_sanitizer.dart';
import 'package:airstream/services/obs/obs_client.dart';
import 'package:flutter/foundation.dart';

enum ObsDropTrend { normal, steady, rising }

enum ObsPollFailureAction { preserve, unstable, reconnect }

@immutable
class ObsState {
  final bool connected;
  final bool connecting;
  final bool outputActive;
  final bool recordingActive;
  final bool recordingPaused;
  final bool reconnecting;
  final double bitrateKbps;
  final double fps;
  final int droppedFrames;
  final double dropPercentage;
  final String currentScene;
  final int recordingDurationMs;
  final int recordingBytes;
  final String statusMessage;
  final String? error;
  final String host;
  final ObsDropTrend? _dropTrend;
  ObsDropTrend get dropTrend => _dropTrend ?? ObsDropTrend.normal;

  const ObsState({
    this.connected = false,
    this.connecting = false,
    this.outputActive = false,
    this.recordingActive = false,
    this.recordingPaused = false,
    this.reconnecting = false,
    this.bitrateKbps = 0,
    this.fps = 0,
    this.droppedFrames = 0,
    this.dropPercentage = 0,
    this.currentScene = '',
    this.recordingDurationMs = 0,
    this.recordingBytes = 0,
    this.statusMessage = 'Ready to connect',
    this.error,
    this.host = '',
    ObsDropTrend? dropTrend,
  }) : _dropTrend = dropTrend ?? ObsDropTrend.normal;

  ObsState copyWith({
    bool? connected,
    bool? connecting,
    bool? outputActive,
    bool? recordingActive,
    bool? recordingPaused,
    bool? reconnecting,
    double? bitrateKbps,
    double? fps,
    int? droppedFrames,
    double? dropPercentage,
    String? currentScene,
    int? recordingDurationMs,
    int? recordingBytes,
    String? statusMessage,
    String? error,
    bool clearError = false,
    String? host,
    ObsDropTrend? dropTrend,
  }) =>
      ObsState(
        connected: connected ?? this.connected,
        connecting: connecting ?? this.connecting,
        outputActive: outputActive ?? this.outputActive,
        recordingActive: recordingActive ?? this.recordingActive,
        recordingPaused: recordingPaused ?? this.recordingPaused,
        reconnecting: reconnecting ?? this.reconnecting,
        bitrateKbps: bitrateKbps ?? this.bitrateKbps,
        fps: fps ?? this.fps,
        droppedFrames: droppedFrames ?? this.droppedFrames,
        dropPercentage: dropPercentage ?? this.dropPercentage,
        currentScene: currentScene ?? this.currentScene,
        recordingDurationMs: recordingDurationMs ?? this.recordingDurationMs,
        recordingBytes: recordingBytes ?? this.recordingBytes,
        statusMessage: statusMessage ?? this.statusMessage,
        error: clearError ? null : (error ?? this.error),
        host: host ?? this.host,
        dropTrend: dropTrend ?? this.dropTrend,
      );
}

class ObsService {
  ObsService({
    ObsClientConnector? connector,
    Duration statsPollInterval = const Duration(seconds: 1),
    Duration connectionTimeout = const Duration(seconds: 15),
  })  : _connector = connector ?? ObsWebSocketClient.connect,
        _statsPollInterval = statsPollInterval,
        _connectionTimeout = connectionTimeout;

  final ObsClientConnector _connector;
  final Duration _statsPollInterval;
  final Duration _connectionTimeout;
  static const _dropRecoveryWindow = Duration(seconds: 10);
  static const _unstablePollFailureThreshold = 3;
  static const _reconnectPollFailureThreshold = 8;

  ObsClient? _obs;
  final _stateController =
      // ignore: close_sinks
      StreamController<ObsState>.broadcast();

  ObsState _state = const ObsState();
  int _generation = 0;
  Timer? _statsTimer;
  _ObsMetricsSample? _lastMetricsSample;
  DateTime? _lastObservedDropAt;
  bool _statsPollInFlight = false;
  int _consecutivePollFailures = 0;
  String _connectionPassword = '';

  ObsState get currentState => _state;

  Stream<ObsState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
  }

  Future<void> startRecording() => _runControl(
        'start recording',
        (obs) => obs.startRecording(),
      );

  Future<void> stopRecording() => _runControl(
        'stop recording',
        (obs) => obs.stopRecording(),
      );

  Future<void> pauseRecording() => _runControl(
        'pause recording',
        (obs) => obs.pauseRecording(),
      );

  Future<void> resumeRecording() => _runControl(
        'resume recording',
        (obs) => obs.resumeRecording(),
      );

  Future<void> switchScene(String sceneName) => _runControl(
        'switch scene',
        (obs) => obs.switchScene(sceneName),
      );

  Future<void> _runControl(
    String label,
    Future<void> Function(ObsClient obs) action,
  ) async {
    final obs = _obs;
    if (obs == null || !_state.connected) {
      throw StateError('OBS must be connected to $label.');
    }
    try {
      await action(obs);
      _emit(_state.copyWith(clearError: true));
    } catch (error, stack) {
      AppLogger.error(
        'OBS control failed: $label',
        error: error,
        stackTrace: stack,
      );
      _emit(_state.copyWith(error: 'Could not $label: $error'));
      rethrow;
    }
  }

  @visibleForTesting
  static ObsPollFailureAction pollFailureActionFor(int consecutiveFailures) {
    if (consecutiveFailures >= _reconnectPollFailureThreshold) {
      return ObsPollFailureAction.reconnect;
    }
    if (consecutiveFailures >= _unstablePollFailureThreshold) {
      return ObsPollFailureAction.unstable;
    }
    return ObsPollFailureAction.preserve;
  }

  Future<void> connect({
    required String host,
    required String password,
  }) async {
    final trimmedHost = host.trim();
    if (trimmedHost.isEmpty) {
      _emit(
        _state.copyWith(
          connected: false,
          connecting: false,
          outputActive: false,
          reconnecting: false,
          statusMessage: 'OBS host required',
          error: 'Enter the OBS WebSocket host first.',
          host: '',
        ),
      );
      return;
    }

    final generation = ++_generation;
    LogSanitizer.forgetSecret(_connectionPassword);
    _connectionPassword = password;
    AppLogger.registerSecret(password);
    await _closeCurrentSocket();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: true,
        outputActive: false,
        reconnecting: false,
        statusMessage: 'Connecting...',
        clearError: true,
        host: trimmedHost,
      ),
    );

    ObsClient? connectingObs;
    try {
      connectingObs = await _connector(
        url: _normalizeConnectUrl(trimmedHost),
        password: password.trim().isEmpty ? null : password,
        onDone: () => _handleSocketDone(generation, connectingObs),
        onEvent: (event) => _handleFallbackEvent(event, generation),
      ).timeout(_connectionTimeout);
      final obs = connectingObs;

      if (generation != _generation) {
        await obs.close();
        return;
      }

      _obs = obs;
      await obs.subscribeOutputsAndScenes();

      final currentScene = await obs.currentProgramScene();
      final streamStatus = await obs.streamStatus();
      final recordStatus = await obs.recordStatus();
      final stats = await obs.stats();

      if (generation != _generation) {
        await obs.close();
        return;
      }

      final metrics = _computeMetrics(
        streamStatus: streamStatus,
        stats: stats,
      );
      _lastMetricsSample = metrics.sample;
      _consecutivePollFailures = 0;
      final dropTrend = _rememberDropTrend(metrics.recentDroppedFrames > 0);
      _emit(
        _state.copyWith(
          connected: true,
          connecting: false,
          currentScene: currentScene,
          outputActive: streamStatus.outputActive,
          recordingActive: recordStatus.outputActive,
          recordingPaused: recordStatus.outputPaused,
          recordingDurationMs: recordStatus.outputDuration,
          recordingBytes: recordStatus.outputBytes,
          reconnecting: streamStatus.outputReconnecting,
          bitrateKbps: metrics.bitrateKbps,
          fps: metrics.fps,
          droppedFrames: metrics.droppedFrames,
          dropPercentage: metrics.dropPercentage,
          dropTrend: dropTrend,
          statusMessage: _streamStatusLabel(
            outputActive: streamStatus.outputActive,
            reconnecting: streamStatus.outputReconnecting,
          ),
          clearError: true,
          host: trimmedHost,
        ),
      );
      _startStatsPolling(generation);
    } catch (e, stack) {
      final failedObs = connectingObs;
      if (identical(_obs, failedObs)) {
        _obs = null;
      }
      await _closeSocket(failedObs);
      if (generation != _generation) return;
      AppLogger.error(
        'OBS connection failed for $trimmedHost',
        error: e,
        stackTrace: stack,
      );
      _stopStatsPolling();
      _emit(
        _state.copyWith(
          connected: false,
          connecting: false,
          outputActive: false,
          recordingActive: false,
          recordingPaused: false,
          reconnecting: false,
          bitrateKbps: 0,
          fps: 0,
          droppedFrames: 0,
          dropPercentage: 0,
          dropTrend: ObsDropTrend.normal,
          recordingDurationMs: 0,
          recordingBytes: 0,
          statusMessage: 'Connection failed',
          error: _formatError(e),
          host: trimmedHost,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    LogSanitizer.forgetSecret(_connectionPassword);
    _connectionPassword = '';
    _stopStatsPolling();
    await _closeCurrentSocket();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        recordingActive: false,
        recordingPaused: false,
        reconnecting: false,
        bitrateKbps: 0,
        fps: 0,
        droppedFrames: 0,
        dropPercentage: 0,
        dropTrend: ObsDropTrend.normal,
        recordingDurationMs: 0,
        recordingBytes: 0,
        currentScene: '',
        statusMessage: 'Disconnected',
        clearError: true,
      ),
    );
  }

  Future<void> _closeCurrentSocket() async {
    final obs = _obs;
    _obs = null;
    _lastMetricsSample = null;
    _lastObservedDropAt = null;
    _consecutivePollFailures = 0;
    await _closeSocket(obs);
  }

  Future<void> _closeSocket(ObsClient? obs) async {
    if (obs == null) return;
    try {
      await obs.close();
    } catch (_) {
      // Best-effort cleanup: the socket is already detached from app state.
    }
  }

  void _handleSocketDone(int generation, ObsClient? obs) {
    if (generation != _generation || obs == null || !identical(_obs, obs)) {
      return;
    }
    _obs = null;
    _stopStatsPolling();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        recordingActive: false,
        recordingPaused: false,
        reconnecting: false,
        bitrateKbps: 0,
        fps: 0,
        droppedFrames: 0,
        dropPercentage: 0,
        dropTrend: ObsDropTrend.normal,
        recordingDurationMs: 0,
        recordingBytes: 0,
        currentScene: '',
        statusMessage: 'Disconnected',
      ),
    );
  }

  void _handleFallbackEvent(dynamic event, int generation) {
    if (generation != _generation) return;

    final eventType = event.eventType?.toString() ?? '';
    final rawData = event.eventData;
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};

    switch (eventType) {
      case 'CurrentProgramSceneChanged':
        final sceneName = (data['sceneName'] ??
                data['currentProgramSceneName'] ??
                data['currentProgramScene'])
            ?.toString();
        if (sceneName == null || sceneName.isEmpty) return;
        _emit(_state.copyWith(currentScene: sceneName));
        break;
      case 'StreamStateChanged':
        final outputActive = data['outputActive'] == true;
        final reconnecting = data['outputReconnecting'] == true;
        _emit(
          _state.copyWith(
            outputActive: outputActive,
            reconnecting: reconnecting,
            statusMessage: _streamStatusLabel(
              outputActive: outputActive,
              reconnecting: reconnecting,
            ),
          ),
        );
        unawaited(_pollStatsOnce(generation));
        break;
      case 'RecordStateChanged':
        _emit(
          _state.copyWith(
            recordingActive: data['outputActive'] == true,
          ),
        );
        unawaited(_pollStatsOnce(generation));
        break;
      default:
        break;
    }
  }

  void _startStatsPolling(int generation) {
    _stopStatsPolling();
    _statsTimer = Timer.periodic(_statsPollInterval, (_) {
      unawaited(_pollStatsOnce(generation));
    });
  }

  void _stopStatsPolling() {
    _statsTimer?.cancel();
    _statsTimer = null;
    _statsPollInFlight = false;
    _lastMetricsSample = null;
    _lastObservedDropAt = null;
  }

  Future<void> _pollStatsOnce(int generation) async {
    if (_statsPollInFlight || generation != _generation) return;
    final obs = _obs;
    if (obs == null) return;

    _statsPollInFlight = true;
    try {
      final streamStatus = await obs.streamStatus();
      final recordStatus = await obs.recordStatus();
      final stats = await obs.stats();
      if (generation != _generation) return;

      final metrics = _computeMetrics(
        streamStatus: streamStatus,
        stats: stats,
      );
      _lastMetricsSample = metrics.sample;
      _consecutivePollFailures = 0;
      final dropTrend = _rememberDropTrend(metrics.recentDroppedFrames > 0);
      _emit(
        _state.copyWith(
          outputActive: streamStatus.outputActive,
          recordingActive: recordStatus.outputActive,
          recordingPaused: recordStatus.outputPaused,
          recordingDurationMs: recordStatus.outputDuration,
          recordingBytes: recordStatus.outputBytes,
          reconnecting: streamStatus.outputReconnecting,
          bitrateKbps: metrics.bitrateKbps,
          fps: metrics.fps,
          droppedFrames: metrics.droppedFrames,
          dropPercentage: metrics.dropPercentage,
          dropTrend: dropTrend,
          statusMessage: _streamStatusLabel(
            outputActive: streamStatus.outputActive,
            reconnecting: streamStatus.outputReconnecting,
          ),
        ),
      );
    } catch (error, stack) {
      if (generation != _generation) return;

      _consecutivePollFailures++;
      switch (pollFailureActionFor(_consecutivePollFailures)) {
        case ObsPollFailureAction.preserve:
          break;
        case ObsPollFailureAction.unstable:
          _emit(
            _state.copyWith(
              statusMessage:
                  'OBS connection unstable ($_consecutivePollFailures/$_reconnectPollFailureThreshold)',
            ),
          );
          break;
        case ObsPollFailureAction.reconnect:
          AppLogger.warning(
            'OBS statistics polling failed repeatedly; reconnecting',
            error: error,
            stackTrace: stack,
          );
          final host = _state.host;
          final password = _connectionPassword;
          _emit(
            _state.copyWith(
              connected: false,
              connecting: true,
              outputActive: false,
              recordingActive: false,
              recordingPaused: false,
              reconnecting: true,
              statusMessage: 'Reconnecting to OBS...',
            ),
          );
          await connect(host: host, password: password);
          break;
      }
    } finally {
      _statsPollInFlight = false;
    }
  }

  _ObsMetrics _computeMetrics({
    required ObsStreamSnapshot streamStatus,
    required ObsStatsSnapshot stats,
  }) {
    final previous = _lastMetricsSample;
    final sample = _ObsMetricsSample(
      outputBytes: streamStatus.outputBytes,
      outputDurationMs: streamStatus.outputDuration,
      droppedFrames: streamStatus.outputSkippedFrames,
    );

    double bitrateKbps = 0;
    if (previous != null) {
      final bytesDelta = streamStatus.outputBytes - previous.outputBytes;
      final durationDeltaMs =
          streamStatus.outputDuration - previous.outputDurationMs;
      if (bytesDelta > 0 && durationDeltaMs > 0) {
        bitrateKbps = (bytesDelta * 8) / durationDeltaMs;
      }
    }

    if (bitrateKbps <= 0 && streamStatus.outputDuration > 0) {
      bitrateKbps =
          (streamStatus.outputBytes * 8) / streamStatus.outputDuration;
    }

    final totalFrames = streamStatus.outputTotalFrames;
    final droppedFrames = streamStatus.outputSkippedFrames;
    final dropPercentage =
        totalFrames > 0 ? (droppedFrames / totalFrames) * 100 : 0.0;

    return _ObsMetrics(
      sample: sample,
      bitrateKbps: bitrateKbps,
      fps: stats.activeFps.toDouble(),
      droppedFrames: droppedFrames,
      dropPercentage: dropPercentage,
      recentDroppedFrames: previous == null
          ? 0
          : (droppedFrames - previous.droppedFrames).clamp(0, droppedFrames),
    );
  }

  String _normalizeConnectUrl(String host) {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
      return trimmed;
    }

    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring('http://'.length)}';
    }

    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring('https://'.length)}';
    }

    return 'ws://$trimmed';
  }

  String _streamStatusLabel({
    required bool outputActive,
    required bool reconnecting,
  }) {
    if (reconnecting) return 'Stream reconnecting';
    if (outputActive) return 'Live';
    return 'Connected';
  }

  ObsDropTrend _rememberDropTrend(bool hasActiveDrop) {
    final now = DateTime.now().toUtc();
    if (hasActiveDrop) {
      _lastObservedDropAt = now;
      return ObsDropTrend.rising;
    }

    final lastObservedDropAt = _lastObservedDropAt;
    if (lastObservedDropAt != null &&
        now.difference(lastObservedDropAt) < _dropRecoveryWindow) {
      return ObsDropTrend.steady;
    }

    return ObsDropTrend.normal;
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length).trim();
    }
    return message;
  }

  void _emit(ObsState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  Future<void> dispose() async {
    _stopStatsPolling();
    await _closeCurrentSocket();
    await _stateController.close();
  }
}

class _ObsMetrics {
  const _ObsMetrics({
    required this.sample,
    required this.bitrateKbps,
    required this.fps,
    required this.droppedFrames,
    required this.dropPercentage,
    required this.recentDroppedFrames,
  });

  final _ObsMetricsSample sample;
  final double bitrateKbps;
  final double fps;
  final int droppedFrames;
  final double dropPercentage;
  final int recentDroppedFrames;
}

class _ObsMetricsSample {
  const _ObsMetricsSample({
    required this.outputBytes,
    required this.outputDurationMs,
    required this.droppedFrames,
  });

  final int outputBytes;
  final int outputDurationMs;
  final int droppedFrames;
}

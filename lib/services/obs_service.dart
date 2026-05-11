import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:obs_websocket/obs_websocket.dart';

enum ObsDropTrend { normal, steady, rising }

@immutable
class ObsState {
  final bool connected;
  final bool connecting;
  final bool outputActive;
  final bool reconnecting;
  final double bitrateKbps;
  final double fps;
  final int droppedFrames;
  final double dropPercentage;
  final String currentScene;
  final String statusMessage;
  final String? error;
  final String host;
  final ObsDropTrend? _dropTrend;
  ObsDropTrend get dropTrend => _dropTrend ?? ObsDropTrend.normal;

  const ObsState({
    this.connected = false,
    this.connecting = false,
    this.outputActive = false,
    this.reconnecting = false,
    this.bitrateKbps = 0,
    this.fps = 0,
    this.droppedFrames = 0,
    this.dropPercentage = 0,
    this.currentScene = '',
    this.statusMessage = 'Ready to connect',
    this.error,
    this.host = '',
    ObsDropTrend? dropTrend,
  }) : _dropTrend = dropTrend ?? ObsDropTrend.normal;

  ObsState copyWith({
    bool? connected,
    bool? connecting,
    bool? outputActive,
    bool? reconnecting,
    double? bitrateKbps,
    double? fps,
    int? droppedFrames,
    double? dropPercentage,
    String? currentScene,
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
        reconnecting: reconnecting ?? this.reconnecting,
        bitrateKbps: bitrateKbps ?? this.bitrateKbps,
        fps: fps ?? this.fps,
        droppedFrames: droppedFrames ?? this.droppedFrames,
        dropPercentage: dropPercentage ?? this.dropPercentage,
        currentScene: currentScene ?? this.currentScene,
        statusMessage: statusMessage ?? this.statusMessage,
        error: clearError ? null : (error ?? this.error),
        host: host ?? this.host,
        dropTrend: dropTrend ?? this.dropTrend,
      );
}

class ObsService {
  static const _statsPollInterval = Duration(seconds: 1);
  static const _dropTrendWindow = Duration(seconds: 3);
  static const _dropTrendTolerance = 0.01;

  ObsWebSocket? _obs;
  final _stateController =
      // ignore: close_sinks
      StreamController<ObsState>.broadcast();

  ObsState _state = const ObsState();
  int _generation = 0;
  Timer? _statsTimer;
  _ObsMetricsSample? _lastMetricsSample;
  final Queue<_ObsDropSnapshot> _dropHistory = Queue<_ObsDropSnapshot>();
  bool _statsPollInFlight = false;

  ObsState get currentState => _state;

  Stream<ObsState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
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

    try {
      final obs = await ObsWebSocket.connect(
        _normalizeConnectUrl(trimmedHost),
        password: password.trim().isEmpty ? null : password,
        onDone: () => _handleSocketDone(generation),
        fallbackEventHandler: (event) =>
            _handleFallbackEvent(event, generation),
      );

      if (generation != _generation) {
        await obs.close();
        return;
      }

      _obs = obs;
      await obs.subscribe(EventSubscription.scenes | EventSubscription.outputs);

      final currentScene = await obs.scenes.getCurrentProgramScene();
      final streamStatus = await obs.stream.getStreamStatus();
      final stats = await obs.general.getStats();

      if (generation != _generation) {
        await obs.close();
        return;
      }

      final metrics = _computeMetrics(
        streamStatus: streamStatus,
        stats: stats,
      );
      _lastMetricsSample = metrics.sample;
      final dropTrend = _rememberDropTrend(metrics.dropPercentage);
      _emit(
        _state.copyWith(
          connected: true,
          connecting: false,
          currentScene: currentScene,
          outputActive: streamStatus.outputActive,
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
    } catch (e) {
      if (generation != _generation) return;
      _obs = null;
      _stopStatsPolling();
      _emit(
        _state.copyWith(
          connected: false,
          connecting: false,
          outputActive: false,
          reconnecting: false,
          bitrateKbps: 0,
          fps: 0,
          droppedFrames: 0,
          dropPercentage: 0,
          dropTrend: ObsDropTrend.normal,
          statusMessage: 'Connection failed',
          error: _formatError(e),
          host: trimmedHost,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    _stopStatsPolling();
    await _closeCurrentSocket();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        reconnecting: false,
        bitrateKbps: 0,
        fps: 0,
        droppedFrames: 0,
        dropPercentage: 0,
        dropTrend: ObsDropTrend.normal,
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
    _dropHistory.clear();
    if (obs == null) return;
    try {
      await obs.close();
    } catch (_) {}
  }

  void _handleSocketDone(int generation) {
    if (generation != _generation) return;
    _obs = null;
    _stopStatsPolling();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        reconnecting: false,
        bitrateKbps: 0,
        fps: 0,
        droppedFrames: 0,
        dropPercentage: 0,
        dropTrend: ObsDropTrend.normal,
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
    _dropHistory.clear();
  }

  Future<void> _pollStatsOnce(int generation) async {
    if (_statsPollInFlight || generation != _generation) return;
    final obs = _obs;
    if (obs == null) return;

    _statsPollInFlight = true;
    try {
      final streamStatus = await obs.stream.getStreamStatus();
      final stats = await obs.general.getStats();
      if (generation != _generation) return;

      final metrics = _computeMetrics(
        streamStatus: streamStatus,
        stats: stats,
      );
      _lastMetricsSample = metrics.sample;
      final dropTrend = _rememberDropTrend(metrics.dropPercentage);
      _emit(
        _state.copyWith(
          outputActive: streamStatus.outputActive,
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
    } catch (_) {
      // Keep the last known UI state; connection lifecycle will be updated by socket callbacks.
    } finally {
      _statsPollInFlight = false;
    }
  }

  _ObsMetrics _computeMetrics({
    required StreamStatusResponse streamStatus,
    required StatsResponse stats,
  }) {
    final sample = _ObsMetricsSample(
      outputBytes: streamStatus.outputBytes,
      outputDurationMs: streamStatus.outputDuration,
    );

    double bitrateKbps = 0;
    final previous = _lastMetricsSample;
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

  ObsDropTrend _rememberDropTrend(double dropPercentage) {
    final now = DateTime.now().toUtc();
    _dropHistory.addLast(
      _ObsDropSnapshot(
        capturedAt: now,
        dropPercentage: dropPercentage,
      ),
    );

    final maxAge = _dropTrendWindow * 2 + _statsPollInterval;
    while (_dropHistory.isNotEmpty &&
        now.difference(_dropHistory.first.capturedAt) > maxAge) {
      _dropHistory.removeFirst();
    }

    final baselineTime = now.subtract(_dropTrendWindow);
    _ObsDropSnapshot? baseline;
    for (final snapshot in _dropHistory) {
      if (snapshot.capturedAt.isAfter(baselineTime)) break;
      baseline = snapshot;
    }

    baseline ??= _dropHistory.length >= 2
        ? _dropHistory.elementAt(_dropHistory.length - 2)
        : null;

    if (baseline == null) {
      return dropPercentage > _dropTrendTolerance
          ? ObsDropTrend.steady
          : ObsDropTrend.normal;
    }

    final delta = dropPercentage - baseline.dropPercentage;
    if (delta > _dropTrendTolerance) {
      return ObsDropTrend.rising;
    }
    if (dropPercentage > _dropTrendTolerance &&
        delta.abs() <= _dropTrendTolerance) {
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

  void dispose() {
    _stopStatsPolling();
    unawaited(_closeCurrentSocket());
    _stateController.close();
  }
}

class _ObsMetrics {
  const _ObsMetrics({
    required this.sample,
    required this.bitrateKbps,
    required this.fps,
    required this.droppedFrames,
    required this.dropPercentage,
  });

  final _ObsMetricsSample sample;
  final double bitrateKbps;
  final double fps;
  final int droppedFrames;
  final double dropPercentage;
}

class _ObsMetricsSample {
  const _ObsMetricsSample({
    required this.outputBytes,
    required this.outputDurationMs,
  });

  final int outputBytes;
  final int outputDurationMs;
}

class _ObsDropSnapshot {
  const _ObsDropSnapshot({
    required this.capturedAt,
    required this.dropPercentage,
  });

  final DateTime capturedAt;
  final double dropPercentage;
}

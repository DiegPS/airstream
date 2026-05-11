import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obs_websocket/obs_websocket.dart';

@immutable
class ObsState {
  final bool connected;
  final bool connecting;
  final bool outputActive;
  final bool reconnecting;
  final String currentScene;
  final String statusMessage;
  final String? error;
  final String host;

  const ObsState({
    this.connected = false,
    this.connecting = false,
    this.outputActive = false,
    this.reconnecting = false,
    this.currentScene = '',
    this.statusMessage = 'Ready to connect',
    this.error,
    this.host = '',
  });

  ObsState copyWith({
    bool? connected,
    bool? connecting,
    bool? outputActive,
    bool? reconnecting,
    String? currentScene,
    String? statusMessage,
    String? error,
    bool clearError = false,
    String? host,
  }) =>
      ObsState(
        connected: connected ?? this.connected,
        connecting: connecting ?? this.connecting,
        outputActive: outputActive ?? this.outputActive,
        reconnecting: reconnecting ?? this.reconnecting,
        currentScene: currentScene ?? this.currentScene,
        statusMessage: statusMessage ?? this.statusMessage,
        error: clearError ? null : (error ?? this.error),
        host: host ?? this.host,
      );
}

class ObsService {
  ObsWebSocket? _obs;
  final _stateController =
      // ignore: close_sinks
      StreamController<ObsState>.broadcast();

  ObsState _state = const ObsState();
  int _generation = 0;

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

      if (generation != _generation) {
        await obs.close();
        return;
      }

      _emit(
        _state.copyWith(
          connected: true,
          connecting: false,
          currentScene: currentScene,
          outputActive: streamStatus.outputActive,
          reconnecting: streamStatus.outputReconnecting,
          statusMessage: _streamStatusLabel(
            outputActive: streamStatus.outputActive,
            reconnecting: streamStatus.outputReconnecting,
          ),
          clearError: true,
          host: trimmedHost,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      _obs = null;
      _emit(
        _state.copyWith(
          connected: false,
          connecting: false,
          outputActive: false,
          reconnecting: false,
          statusMessage: 'Connection failed',
          error: _formatError(e),
          host: trimmedHost,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    ++_generation;
    await _closeCurrentSocket();
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        reconnecting: false,
        currentScene: '',
        statusMessage: 'Disconnected',
        clearError: true,
      ),
    );
  }

  Future<void> _closeCurrentSocket() async {
    final obs = _obs;
    _obs = null;
    if (obs == null) return;
    try {
      await obs.close();
    } catch (_) {}
  }

  void _handleSocketDone(int generation) {
    if (generation != _generation) return;
    _obs = null;
    _emit(
      _state.copyWith(
        connected: false,
        connecting: false,
        outputActive: false,
        reconnecting: false,
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
        break;
      default:
        break;
    }
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
    unawaited(_closeCurrentSocket());
    _stateController.close();
  }
}

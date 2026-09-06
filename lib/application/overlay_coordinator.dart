import 'dart:async';

import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';

abstract interface class OverlayClient {
  int get port;
  String get overlayUrl;
  Stream<int> get clientCountStream;
  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port,
  });
  void setSettings(SettingsModel settings);
  bool reloadClients();
  bool broadcastTestAlert(String kind);
  void broadcastCaption(String text);
  Future<void> stop();
  Future<void> dispose();
}

class OverlayServerAdapter implements OverlayClient {
  OverlayServerAdapter(this.server);

  final OverlayServer server;

  @override
  int get port => server.port;
  @override
  String get overlayUrl => server.overlayUrl;
  @override
  Stream<int> get clientCountStream => server.clientCountStream;
  @override
  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) =>
      server.start(messages: messages, settings: settings, port: port);
  @override
  void setSettings(SettingsModel settings) => server.setSettings(settings);
  @override
  bool reloadClients() => server.reloadClients();
  @override
  bool broadcastTestAlert(String kind) => server.broadcastTestAlert(kind);
  @override
  void broadcastCaption(String text) => server.broadcastCaption(text);
  @override
  Future<void> stop() => server.stop();
  @override
  Future<void> dispose() => server.dispose();
}

class OverlayCoordinator {
  OverlayCoordinator({required OverlayClient overlay}) : _overlay = overlay;

  final OverlayClient _overlay;
  final _stateController = StreamController<OverlayServerState>.broadcast();
  OverlayServerState _state = const OverlayServerState();
  int _generation = 0;
  bool _disposed = false;

  Stream<int> get clientCountStream => _overlay.clientCountStream;

  Stream<OverlayServerState> get stateStream async* {
    yield _state;
    yield* _stateController.stream;
  }

  String? get url =>
      _state.phase == OverlayServerPhase.ready ? _overlay.overlayUrl : null;

  bool reload() => _overlay.reloadClients();
  bool testAlert(String kind) => _overlay.broadcastTestAlert(kind);
  void broadcastCaption(String text) => _overlay.broadcastCaption(text);

  void applySettings(
    SettingsModel settings, {
    required SettingsModel? previous,
    required Stream<ChatMessage> messages,
  }) {
    if (_disposed) return;
    final changed = previous == null ||
        previous.overlayPort != settings.overlayPort ||
        previous.overlayEnabled != settings.overlayEnabled;
    if (changed) {
      if (settings.overlayEnabled) {
        unawaited(_start(settings, messages));
      } else {
        ++_generation;
        unawaited(_stopSafely());
        _emit(const OverlayServerState());
      }
    }
    if (settings.overlayEnabled) _overlay.setSettings(settings);
  }

  Future<void> _start(
    SettingsModel settings,
    Stream<ChatMessage> messages,
  ) async {
    final generation = ++_generation;
    _emit(
      OverlayServerState(
        phase: OverlayServerPhase.starting,
        port: settings.overlayPort,
      ),
    );
    try {
      await _overlay.start(
        messages: messages,
        settings: settings,
        port: settings.overlayPort,
      );
      if (generation != _generation || _disposed) return;
      _emit(
        OverlayServerState(
          phase: OverlayServerPhase.ready,
          port: _overlay.port,
        ),
      );
    } catch (error, stack) {
      if (generation != _generation || _disposed) return;
      AppLogger.error(
        'Overlay server failed to start on port ${settings.overlayPort}',
        error: error,
        stackTrace: stack,
      );
      _emit(
        OverlayServerState(
          phase: OverlayServerPhase.error,
          port: settings.overlayPort,
          error: error,
        ),
      );
    }
  }

  Future<void> _stopSafely() async {
    try {
      await _overlay.stop();
    } catch (error, stack) {
      AppLogger.warning(
        'Overlay server cleanup failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void _emit(OverlayServerState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    await _overlay.dispose();
    await _stateController.close();
  }
}

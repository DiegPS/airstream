import 'dart:async';

import 'package:airstream/application/coordinator_notice.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/settings/settings_model.dart';

abstract interface class ObsClient {
  ObsState get currentState;
  Stream<ObsState> get stateStream;
  Future<void> connect({required String host, required String password});
  Future<void> disconnect();
  Future<void> startRecording();
  Future<void> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<void> switchScene(String sceneName);
  Future<void> dispose();
}

class ObsServiceAdapter implements ObsClient {
  ObsServiceAdapter(this.service);

  final ObsService service;

  @override
  ObsState get currentState => service.currentState;
  @override
  Stream<ObsState> get stateStream => service.stateStream;
  @override
  Future<void> connect({required String host, required String password}) =>
      service.connect(host: host, password: password);
  @override
  Future<void> disconnect() => service.disconnect();
  @override
  Future<void> startRecording() => service.startRecording();
  @override
  Future<void> stopRecording() => service.stopRecording();
  @override
  Future<void> pauseRecording() => service.pauseRecording();
  @override
  Future<void> resumeRecording() => service.resumeRecording();
  @override
  Future<void> switchScene(String sceneName) => service.switchScene(sceneName);
  @override
  Future<void> dispose() => service.dispose();
}

class ObsCoordinator {
  ObsCoordinator({required ObsClient obs}) : _obs = obs;

  final ObsClient _obs;
  final _noticeController = StreamController<CoordinatorNotice>.broadcast();
  SettingsModel? _settings;
  bool _connectRequested = false;
  bool _disposed = false;

  Stream<ObsState> get stateStream async* {
    yield _obs.currentState;
    yield* _obs.stateStream;
  }

  Stream<CoordinatorNotice> get notices => _noticeController.stream;

  void applySettings(SettingsModel settings,
      {required SettingsModel? previous}) {
    if (_disposed) return;
    _settings = settings;
    final changed = previous == null ||
        previous.obsEnabled != settings.obsEnabled ||
        previous.obsHost != settings.obsHost ||
        previous.obsPassword != settings.obsPassword;
    if (!changed) return;
    if (!settings.obsEnabled) {
      _connectRequested = false;
      unawaited(_disconnectSafely());
    } else if (_connectRequested) {
      unawaited(_connectSafely(settings));
    }
  }

  Future<void> connect() async {
    final settings = _settings;
    if (settings == null || !settings.obsEnabled || _disposed) return;
    _connectRequested = true;
    await _connectSafely(settings);
  }

  Future<void> disconnect() async {
    _connectRequested = false;
    await _disconnectSafely();
  }

  Future<void> executeVoiceCommand(VoiceCommand command) async {
    try {
      switch (command.type) {
        case VoiceCommandType.startRecording:
          await _obs.startRecording();
        case VoiceCommandType.stopRecording:
          await _obs.stopRecording();
        case VoiceCommandType.pauseRecording:
          await _obs.pauseRecording();
        case VoiceCommandType.resumeRecording:
          await _obs.resumeRecording();
        case VoiceCommandType.switchScene:
          await _obs.switchScene(command.argument);
      }
    } catch (error, stack) {
      AppLogger.error(
        'Voice command failed',
        error: error,
        stackTrace: stack,
      );
      if (!_noticeController.isClosed) {
        _noticeController.add(
          const CoordinatorNotice(
            AppNoticeCode.voiceCommandFailed,
            AppNoticeSeverity.error,
          ),
        );
      }
    }
  }

  Future<void> _connectSafely(SettingsModel settings) async {
    try {
      await _obs.connect(
          host: settings.obsHost, password: settings.obsPassword);
    } catch (error, stack) {
      AppLogger.error(
        'OBS connection failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _disconnectSafely() async {
    try {
      await _obs.disconnect();
    } catch (error, stack) {
      AppLogger.warning(
        'OBS disconnection cleanup failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _connectRequested = false;
    await _obs.dispose();
    await _noticeController.close();
  }
}

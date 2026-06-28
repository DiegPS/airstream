import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

class MediaKitAudioPlaybackService {
  Player? _player;
  Completer<void>? _activePlayback;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;

  Future<List<AudioDevice>> getAudioDevices() async {
    final player = _ensurePlayer();
    final current = player.state.audioDevices;
    if (current.isNotEmpty) return current;
    return player.stream.audioDevices.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => current,
    );
  }

  Future<void> setAudioDevice(AudioDevice device) {
    return _ensurePlayer().setAudioDevice(device);
  }

  Future<void> useDefaultAudioDevice() {
    return _ensurePlayer().setAudioDevice(AudioDevice.auto());
  }

  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final player = _ensurePlayer();
    await _completedSub?.cancel();
    _completedSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    await player.stop();
    _completeActivePlayback();

    final playback = Completer<void>();
    _activePlayback = playback;
    _completedSub = player.stream.completed.listen((completed) {
      if (completed && !playback.isCompleted) {
        playback.complete();
      }
    });
    _errorSub = player.stream.error.listen((error) {
      if (!playback.isCompleted) {
        playback.completeError(StateError(error));
      }
    });

    try {
      await player.open(Media(file.absolute.uri.toString()));
      await playback.future.timeout(timeout);
    } on TimeoutException {
      await player.stop();
      rethrow;
    } finally {
      if (identical(_activePlayback, playback)) {
        _activePlayback = null;
      }
      await _completedSub?.cancel();
      _completedSub = null;
      await _errorSub?.cancel();
      _errorSub = null;
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _completeActivePlayback();
    await _completedSub?.cancel();
    _completedSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
  }

  Future<void> dispose() async {
    _completeActivePlayback();
    await _completedSub?.cancel();
    _completedSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    final player = _player;
    _player = null;
    await player?.dispose();
  }

  Player _ensurePlayer() {
    return _player ??= Player();
  }

  void _completeActivePlayback() {
    final playback = _activePlayback;
    _activePlayback = null;
    if (playback != null && !playback.isCompleted) {
      playback.complete();
    }
  }
}

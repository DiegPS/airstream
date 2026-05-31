import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

class MediaKitAudioPlaybackService {
  Player? _player;
  Completer<void>? _activePlayback;
  StreamSubscription<bool>? _completedSub;

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

  Future<void> playFile(File file) async {
    final player = _ensurePlayer();
    await _completedSub?.cancel();
    _completedSub = null;
    await player.stop();
    _completeActivePlayback();

    final playback = Completer<void>();
    _activePlayback = playback;
    _completedSub = player.stream.completed.listen((completed) {
      if (completed && !playback.isCompleted) {
        playback.complete();
      }
    });

    try {
      await player.open(Media(file.absolute.uri.toString()));
      await playback.future;
    } finally {
      if (identical(_activePlayback, playback)) {
        _activePlayback = null;
      }
      await _completedSub?.cancel();
      _completedSub = null;
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _completeActivePlayback();
    await _completedSub?.cancel();
    _completedSub = null;
  }

  Future<void> dispose() async {
    _completeActivePlayback();
    await _completedSub?.cancel();
    _completedSub = null;
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

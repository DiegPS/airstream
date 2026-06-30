import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

class MediaKitAudioPlaybackService {
  static const double _keepAliveVolume = 0.0;

  Player? _player;
  Player? _keepAlivePlayer;
  Completer<void>? _activePlayback;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<String>? _errorSub;
  Future<File>? _keepAliveFileFuture;
  AudioDevice? _audioDevice;
  bool _isDisposed = false;

  Future<List<AudioDevice>> getAudioDevices() async {
    final player = _ensurePlayer();
    final current = player.state.audioDevices;
    if (current.isNotEmpty) return current;
    return player.stream.audioDevices.first.timeout(
      const Duration(seconds: 2),
      onTimeout: () => current,
    );
  }

  Future<void> setAudioDevice(AudioDevice device) async {
    _audioDevice = device;
    await _ensurePlayer().setAudioDevice(device);
    await _keepAlivePlayer?.setAudioDevice(device);
  }

  Future<void> useDefaultAudioDevice() async {
    _audioDevice = null;
    final device = AudioDevice.auto();
    await _ensurePlayer().setAudioDevice(device);
    await _keepAlivePlayer?.setAudioDevice(device);
  }

  Future<void> startKeepAlive() async {
    if (_isDisposed) return;

    final player = _keepAlivePlayer ??= Player();
    final device = _audioDevice;
    if (device != null) {
      await player.setAudioDevice(device);
    }

    final file = await (_keepAliveFileFuture ??= _ensureKeepAliveFile());
    if (_isDisposed) return;

    await player.setVolume(_keepAliveVolume);
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(file.absolute.uri.toString()));
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
    _isDisposed = true;
    _completeActivePlayback();
    await _completedSub?.cancel();
    _completedSub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    final player = _player;
    _player = null;
    final keepAlivePlayer = _keepAlivePlayer;
    _keepAlivePlayer = null;
    await player?.dispose();
    await keepAlivePlayer?.dispose();
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

  Future<File> _ensureKeepAliveFile() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/airstream_audio_keep_alive.wav');
    if (await file.exists()) {
      return file;
    }

    await file.writeAsBytes(_buildKeepAliveWav(), flush: true);
    return file;
  }

  Uint8List _buildKeepAliveWav() {
    const sampleRate = 8000;
    const channels = 1;
    const bitsPerSample = 16;
    const seconds = 1;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    const dataSize = sampleRate * seconds * blockAlign;
    const fileSizeMinus8 = 36 + dataSize;

    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.sublistView(bytes);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    data.setUint32(4, fileSizeMinus8, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, byteRate, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    data.setUint32(40, dataSize, Endian.little);

    var sampleIndex = 0;
    for (var offset = 44; offset < bytes.length; offset += 2) {
      data.setInt16(offset, sampleIndex.isEven ? 1 : -1, Endian.little);
      sampleIndex++;
    }

    return bytes;
  }
}

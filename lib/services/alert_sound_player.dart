import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Plays the short alert tone for highlighted chat messages.
abstract interface class AlertSoundClient {
  Future<void> play();
  Future<void> dispose();
}

/// A two-note chime generated in memory, written once to a temporary WAV.
class ChimeSoundPlayer implements AlertSoundClient {
  ChimeSoundPlayer({NativeAudioPlaybackService? playback})
      : _playback = playback ?? NativeAudioPlaybackService();

  final NativeAudioPlaybackService _playback;
  Future<File>? _file;

  @override
  Future<void> play() async {
    final file = await (_file ??= _writeChime());
    await _playback.playFile(file, timeout: const Duration(seconds: 2));
  }

  @override
  Future<void> dispose() => _playback.dispose();

  static Future<File> _writeChime() async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, 'airstream_highlight_chime.wav'));
    await file.writeAsBytes(chimeWav(), flush: true);
    return file;
  }

  /// 16-bit mono WAV: two soft notes (A5, then E6) of about 110 ms each.
  static Uint8List chimeWav() {
    const sampleRate = 22050;
    const noteSamples = sampleRate * 110 ~/ 1000;
    final samples = Float64List(noteSamples * 2);
    for (final (index, frequency) in [880.0, 1318.5].indexed) {
      for (var i = 0; i < noteSamples; i++) {
        final t = i / sampleRate;
        // Quick attack, gentle decay: a bell-like tone that never clicks.
        final envelope = math.min(1, i / 120) * math.exp(-t * 18);
        samples[index * noteSamples + i] =
            0.35 * envelope * math.sin(2 * math.pi * frequency * t);
      }
    }
    final dataSize = samples.length * 2;
    final bytes = Uint8List(44 + dataSize);
    final view = ByteData.sublistView(bytes);
    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes[offset + i] = value.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    view.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate * 2, Endian.little);
    view.setUint16(32, 2, Endian.little);
    view.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    view.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      view.setInt16(44 + i * 2, (samples[i] * 32767).round(), Endian.little);
    }
    return bytes;
  }
}

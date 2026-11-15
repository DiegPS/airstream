import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:airstream/services/alert_sound_player.dart';

abstract final class AlertSounds {
  static const builtIn = ['chime', 'coin', 'fanfare'];
  static final _cache = <String, Uint8List>{};

  static Uint8List wav(String name) => _cache.putIfAbsent(name, () {
        if (name == 'chime') {
          final bytes = ChimeSoundPlayer.chimeWav();
          final data = ByteData.sublistView(bytes);
          final noteSamples = (bytes.length - 44) ~/ 4;
          // Preserve the existing chime, tapering each note's last 8 ms.
          for (var note = 0; note < 2; note++) {
            for (var i = 0; i < 180; i++) {
              final offset = 44 + ((note + 1) * noteSamples - 1 - i) * 2;
              data.setInt16(
                  offset,
                  (data.getInt16(offset, Endian.little) * i / 180).round(),
                  Endian.little);
            }
          }
          return bytes;
        }
        final notes = switch (name) {
          'coin' => [(987.77, 80), (1318.51, 220)],
          'fanfare' => [
              (523.25, 120),
              (659.25, 120),
              (783.99, 120),
              (1046.5, 320)
            ],
          _ => throw ArgumentError.value(name, 'name'),
        };
        const rate = 22050;
        final count =
            notes.fold<int>(0, (n, note) => n + rate * note.$2 ~/ 1000);
        final bytes = Uint8List(44 + count * 2);
        final data = ByteData.sublistView(bytes);
        void ascii(int offset, String text) =>
            bytes.setRange(offset, offset + text.length, text.codeUnits);
        ascii(0, 'RIFF');
        data.setUint32(4, bytes.length - 8, Endian.little);
        ascii(8, 'WAVE');
        ascii(12, 'fmt ');
        data.setUint32(16, 16, Endian.little);
        data.setUint16(20, 1, Endian.little);
        data.setUint16(22, 1, Endian.little);
        data.setUint32(24, rate, Endian.little);
        data.setUint32(28, rate * 2, Endian.little);
        data.setUint16(32, 2, Endian.little);
        data.setUint16(34, 16, Endian.little);
        ascii(36, 'data');
        data.setUint32(40, count * 2, Endian.little);
        var offset = 44;
        for (final (frequency, ms) in notes) {
          final length = rate * ms ~/ 1000;
          for (var i = 0; i < length; i++) {
            final t = i / rate;
            final envelope = math.min(1.0, i / 100) *
                math.min(1.0, (length - 1 - i) / 180) *
                math.exp(-t * (name == 'coin' ? 14 : 3));
            final phase = 2 * math.pi * frequency * t;
            final wave = name == 'coin'
                ? math.sin(phase)
                : (math.sin(phase) + 0.15 * math.sin(2 * phase)) / 1.15;
            data.setInt16(
                offset, (32767 * 0.3 * envelope * wave).round(), Endian.little);
            offset += 2;
          }
        }
        return bytes;
      });

  static File? customFile(String path) {
    if (path.isEmpty ||
        !RegExp(r'\.(wav|mp3|ogg)$', caseSensitive: false).hasMatch(path)) {
      return null;
    }
    try {
      if (FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      final file = File(path);
      return file.lengthSync() <= 5 * 1024 * 1024 ? file : null;
    } on FileSystemException {
      return null;
    }
  }

  static String contentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/wav';
  }
}

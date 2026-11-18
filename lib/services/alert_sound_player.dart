import 'dart:io';

import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Plays the short alert tone for highlighted chat messages.
abstract interface class AlertSoundClient {
  Future<void> play(
    String source, {
    required Map<String, Map<String, dynamic>> library,
    required bool Function() canStart,
  });
  Future<void> dispose();
}

/// Plays generated tones and audio files from the media library.
class HighlightSoundPlayer implements AlertSoundClient {
  HighlightSoundPlayer({
    NativeAudioPlaybackService? playback,
    Future<Directory> Function()? cache,
    Future<MediaLibrary> Function(Map<String, Map<String, dynamic>> entries)?
        media,
  })  : _playback = playback ?? NativeAudioPlaybackService(),
        _cache = cache ?? getTemporaryDirectory,
        _media = media ?? _openMediaLibrary;

  final Future<Directory> Function() _cache;
  final Future<MediaLibrary> Function(Map<String, Map<String, dynamic>>) _media;

  final NativeAudioPlaybackService _playback;
  final _builtInFiles = <String, Future<File>>{};

  @override
  Future<void> play(
    String source, {
    required Map<String, Map<String, dynamic>> library,
    required bool Function() canStart,
  }) async {
    final builtIn = AlertSounds.builtIn.contains(source);
    final File? file;
    if (builtIn) {
      try {
        file =
            await _builtInFiles.putIfAbsent(source, () => _writeTone(source));
      } catch (_) {
        _builtInFiles.remove(source);
        rethrow;
      }
    } else {
      final entry = library[source];
      if (entry == null || entry['kind'] != 'audio') return;
      final media = await _media(library);
      file = await media.fileFor(MapEntry(source, entry));
    }
    if (file == null || !canStart()) return;
    await _playback.playFile(
      file,
      timeout: builtIn ? const Duration(seconds: 2) : const Duration(hours: 24),
      volume: builtIn ? null : 1,
      canStart: canStart,
    );
  }

  @override
  Future<void> dispose() => _playback.dispose();

  static Future<MediaLibrary> _openMediaLibrary(
    Map<String, Map<String, dynamic>> entries,
  ) async {
    final support = await getApplicationSupportDirectory();
    return MediaLibrary(
        Directory(p.join(support.path, 'media')), () => entries);
  }

  Future<File> _writeTone(String source) async {
    final directory = await _cache();
    final file =
        File(p.join(directory.path, 'airstream_highlight_$source.wav'));
    await file.writeAsBytes(
      source == 'chime'
          ? AlertSounds.highlightChimeWav()
          : AlertSounds.wav(source),
      flush: true,
    );
    return file;
  }
}

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:airstream/settings/settings_model.dart';

/// Separate rule sound channel; replacement invalidates any pending file lookup.
class RuleSoundPlayer {
  RuleSoundPlayer(
      {required this.settings,
      NativeAudioPlaybackService? playback,
      Future<MediaLibrary> Function()? library,
      Future<Directory> Function()? cache})
      : _playback = playback ?? NativeAudioPlaybackService(),
        _library = library,
        _cache = cache ?? getTemporaryDirectory;
  final SettingsModel Function() settings;
  final NativeAudioPlaybackService _playback;
  final Future<MediaLibrary> Function()? _library;
  final Future<Directory> Function() _cache;
  final _files = <String, Future<File>>{};
  int _generation = 0;
  Future<bool> play(Map<String, dynamic> action) async {
    final generation = ++_generation;
    await _playback.stop();
    File? file;
    if (action['source'] == 'builtin') {
      final name = action['name'] as String;
      file = await _files.putIfAbsent(name, () async {
        final directory = await _cache();
        final file = File(p.join(directory.path, 'airstream_rule_$name.wav'));
        await file.writeAsBytes(AlertSounds.wav(name), flush: true);
        return file;
      });
    } else {
      final id = action['mediaId'] as String;
      final entry = settings().mediaLibrary[id];
      if (entry == null || entry['kind'] != 'audio') return false;
      final library = await (_library?.call() ?? _defaultLibrary());
      file = await library.fileFor(MapEntry(id, entry));
    }
    if (file == null) return false;
    if (generation != _generation) return true;
    await _playback.playFile(file,
        volume: settings().alertSoundVolume / 100,
        timeout: const Duration(hours: 24));
    return true;
  }

  Future<MediaLibrary> _defaultLibrary() async => MediaLibrary(
      Directory(p.join((await getApplicationSupportDirectory()).path, 'media')),
      () => settings().mediaLibrary);
  Future<void> dispose() async {
    ++_generation;
    await _playback.dispose();
  }
}

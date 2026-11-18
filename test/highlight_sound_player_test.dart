import 'dart:async';
import 'dart:io';

import 'package:airstream/services/alert_sound_player.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/native_audio_playback_service.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Playback extends NativeAudioPlaybackService {
  final played = <File>[];
  final volumes = <double?>[];

  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
    double? volume,
    bool Function()? canStart,
  }) async {
    if (canStart?.call() == false) return;
    played.add(file);
    volumes.add(volume);
  }
}

void main() {
  test('highlight sounds reuse the legacy chime and load media by ID',
      () async {
    final directory = await Directory.systemTemp.createTemp('highlight-audio-');
    addTearDown(() => directory.delete(recursive: true));
    final playback = _Playback();
    final player = HighlightSoundPlayer(
      playback: playback,
      cache: () async => directory,
      media: (entries) async => MediaLibrary(directory, () => entries),
    );
    addTearDown(player.dispose);
    const id = '1234567890abcdef';
    final wav = AlertSounds.highlightChimeWav();
    await File(p.join(directory.path, '$id.wav')).writeAsBytes(wav);
    final entries = {
      id: {
        'name': 'Tone',
        'kind': 'audio',
        'ext': 'wav',
        'bytes': wav.length,
        'addedAt': 1
      },
    };
    for (final source in ['chime', 'coin', 'fanfare', id, '0000000000000000']) {
      await player.play(source, library: entries, canStart: () => true);
    }
    expect(playback.played.length, 4);
    expect(await playback.played[0].readAsBytes(), wav);
    expect(await playback.played[1].readAsBytes(), AlertSounds.wav('coin'));
    expect(await playback.played[2].readAsBytes(), AlertSounds.wav('fanfare'));
    expect(p.basename(playback.played[3].path), '$id.wav');
    expect(playback.volumes, [null, null, null, 1]);
  });

  test('a voice reader that becomes busy during lookup takes precedence',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('highlight-pending-');
    addTearDown(() => directory.delete(recursive: true));
    final playback = _Playback();
    final cache = Completer<Directory>();
    final player =
        HighlightSoundPlayer(playback: playback, cache: () => cache.future);
    addTearDown(player.dispose);
    var busy = false;
    final pending = player.play('coin', library: {}, canStart: () => !busy);
    busy = true;
    cache.complete(directory);
    await pending;
    expect(playback.played, isEmpty);
  });
}

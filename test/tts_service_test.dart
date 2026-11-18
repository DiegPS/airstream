import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/native_audio_playback_service.dart';

import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/tts/sherpa_tts_engine.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'application/coordinator_fakes.dart' show FakeCaptionsClient;

void main() {
  test('normalizes URLs and caps speech by Unicode code points', () {
    expect(
      TtsService.prepareTextForSpeech('  Hola   https://example.com mundo  '),
      'Hola mundo',
    );
    final longEmojiText = List.filled(300, '🟢').join();
    final prepared = TtsService.prepareTextForSpeech(longEmojiText);
    expect(prepared.runes.length, 261);
    expect(prepared.endsWith('…'), isTrue);
  });

  test('enabled TTS never downloads without an explicit user action', () async {
    final root = await Directory.systemTemp.createTemp('airstream-tts-lazy-');
    var requests = 0;
    final cache = TtsModelCache(
      rootDirectory: root,
      client: MockClient((request) async {
        requests++;
        return http.Response('unexpected request', 500);
      }),
    );
    final service = TtsService(modelCache: cache);
    try {
      await service.updateConfig(
        enabled: true,
        modelId: 'supertonic-3-hybrid',
        voice: 'M1',
        language: 'es',
        speed: 1.05,
        steps: 8,
        referenceAudioPath: '',
        referenceText: '',
      );
      service.speak('Este mensaje no debe iniciar una descarga.');
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(requests, 0);
      expect(service.currentLoadState.phase, TtsLoadPhase.idle);
      expect(service.currentLoadState.message, contains('not downloaded'));
    } finally {
      await service.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });

  for (final stopDuringWrite in [true, false]) {
    test(
      stopDuringWrite
          ? 'disabling TTS during a WAV write prevents native playback'
          : 'disabling TTS before native start cancels the pending playback',
      () async {
        final root =
            await Directory.systemTemp.createTemp('tts-playback-race-');
        addTearDown(() => root.delete(recursive: true));
        final overrides = _WavWriteOverride();
        final player = _GatedPlayback();
        final service = TtsService(
          engine: _ReadySherpaEngine(),
          modelCache: TtsModelCache(rootDirectory: root),
          audioPlayback: player,
          temporaryDirectory: () async => root,
        );
        addTearDown(service.dispose);
        Future<void> disable() => service.updateConfig(
              enabled: false,
              modelId: 'supertonic-3-hybrid',
              voice: 'M1',
              language: 'es',
              speed: 1,
              steps: 8,
              referenceAudioPath: '',
              referenceText: '',
            );

        IOOverrides.runWithIOOverrides(() {
          service.speak('Hello');
        }, overrides);
        final wav = await overrides.opened.future;
        if (stopDuringWrite) {
          await disable();
          player.resume.complete();
          wav.resume.complete();
        } else {
          wav.resume.complete();
          await player.entered.future;
          await disable();
          player.resume.complete();
        }
        await wav.deleted.future;
        expect(player.starts, 0);
        expect(player.entered.isCompleted, !stopDuringWrite);
      },
    );
  }

  test('a dead TTS worker immediately replaces Ready with an error', () async {
    final engine = _ControllableSherpaEngine();
    final service = TtsService(engine: engine);
    try {
      engine.fail(StateError('worker exited'));
      await Future<void>.delayed(Duration.zero);

      expect(service.currentLoadState.phase, TtsLoadPhase.error);
      expect(service.currentLoadState.error, contains('worker exited'));
      expect(service.isBusy, isFalse);
    } finally {
      await service.dispose();
    }
  });

  test(
      'stopping chat interrupts playback and the untagged utterance still plays',
      () async {
    final root =
        await Directory.systemTemp.createTemp('airstream-tts-session-');
    addTearDown(() => root.delete(recursive: true));
    final player = _InterruptiblePlayback();
    final service = TtsService(
      engine: _ReadySherpaEngine(),
      modelCache: TtsModelCache(
        rootDirectory: root,
        client:
            MockClient((_) async => throw StateError('Unexpected download')),
      ),
      audioPlayback: player,
      temporaryDirectory: () async => root,
    );
    final audio = AudioCoordinator(
      tts: TtsServiceAdapter(service),
      captions: FakeCaptionsClient(),
    );
    addTearDown(audio.dispose);
    const settings = SettingsModel(
      ttsEnabled: true,
      twitchEnabled: true,
      twitchChannel: 'channel',
    );
    audio.applySettings(settings, connectChats: true);
    for (final id in ['first', 'second']) {
      audio.handleChatMessage(ChatMessage(
        platform: Platform.twitch,
        id: id,
        author: ChatAuthor(name: id, channelId: id),
        items: [MessageItem.text(id)],
        timestamp: DateTime.now().toUtc(),
      ));
    }
    await player.started.future;
    service.speak('Announcement');
    expect(service.queuedTexts, ['second says: second', 'Announcement']);
    final finished = service.busyStream.firstWhere((busy) => !busy);
    audio.applySettings(settings, connectChats: false);
    expect(player.interrupted.isCompleted, isTrue);
    expect(service.queuedTexts, ['Announcement']);
    await finished;
    expect(player.playCount, 2);
  });

  test('withdraws queued speech whose message was moderated', () async {
    final root = await Directory.systemTemp.createTemp('airstream-tts-cancel-');
    final cache = TtsModelCache(
      rootDirectory: root,
      client: MockClient((request) async => http.Response('', 500)),
    );
    final service = TtsService(modelCache: cache);
    try {
      service.speak('troll says something', tag: 'troll');
      service.speak('viewer says hi', tag: 'viewer');
      service.speak('troll says more', tag: 'troll');

      final cancelled = service.cancelWhere((tag) => tag == 'troll');

      expect(cancelled, 2);
      expect(service.queuedTexts, ['viewer says hi']);
    } finally {
      await service.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });
}

class _ReadySherpaEngine extends SherpaTtsEngine {
  @override
  bool get isReady => true;

  @override
  Future<TtsAudio> synthesize({
    required String text,
    required int speakerId,
    required String language,
    required double speed,
    required int steps,
    String? referenceAudio,
    String referenceText = '',
  }) async =>
      TtsAudio(Float32List.fromList([0, 0.2, 0]), 16000);
}

class _GatedPlayback extends NativeAudioPlaybackService {
  final entered = Completer<void>();
  final resume = Completer<void>();
  int starts = 0;

  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
    double? volume,
    bool Function()? canStart,
  }) async {
    entered.complete();
    await resume.future;
    if (canStart?.call() != false) starts++;
  }
}

class _InterruptiblePlayback extends NativeAudioPlaybackService {
  final started = Completer<void>();
  final interrupted = Completer<void>();
  int playCount = 0;

  @override
  Future<void> playFile(
    File file, {
    Duration timeout = const Duration(seconds: 20),
    double? volume,
    bool Function()? canStart,
  }) async {
    if (++playCount == 1) {
      started.complete();
      await interrupted.future;
    }
  }

  @override
  Future<void> stop() async {
    if (started.isCompleted && !interrupted.isCompleted) interrupted.complete();
  }
}

final class _WavWriteOverride extends IOOverrides {
  final opened = Completer<_GatedWav>();

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    if (!path.endsWith('.wav')) return file;
    final wav = _GatedWav(file);
    opened.complete(wav);
    return wav;
  }
}

class _GatedWav implements File {
  _GatedWav(this.file);

  final File file;
  final resume = Completer<void>();
  final deleted = Completer<void>();

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) async {
    await resume.future;
    return file.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<bool> exists() => file.exists();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final result = await file.delete(recursive: recursive);
    deleted.complete();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableSherpaEngine extends SherpaTtsEngine {
  final _failures = StreamController<Object>.broadcast();

  @override
  Stream<Object> get workerFailures => _failures.stream;

  void fail(Object error) => _failures.add(error);

  @override
  Future<void> dispose() async {
    await _failures.close();
    await super.dispose();
  }
}

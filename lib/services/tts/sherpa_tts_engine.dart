import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:ffi/ffi.dart';

import '../tts_model_cache.dart';
import 'tts_model_catalog.dart';

class TtsAudio {
  final Float32List samples;
  final int sampleRate;
  const TtsAudio(this.samples, this.sampleRate);
  Duration get duration => sampleRate <= 0
      ? Duration.zero
      : Duration(milliseconds: (samples.length * 1000 / sampleRate).ceil());
}

class SherpaTtsEngine {
  Isolate? _isolate;
  SendPort? _commands;
  TtsModelInstallation? _installation;
  Pointer<Uint8>? _cancelFlag;
  Completer<void>? _activeRequest;
  bool _disposed = false;

  bool get isReady => _commands != null;

  Future<void> initialize(TtsModelInstallation installation) async {
    if (_disposed) throw StateError('TTS engine has been disposed.');
    if (_commands != null &&
        _installation?.model.storageKey == installation.model.storageKey) {
      return;
    }
    await unload();
    final ready = ReceivePort();
    final errors = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      <String, Object>{
        'reply': ready.sendPort,
        'model': _modelMessage(installation),
        'nativeLibraryDirectory':
            Platform.environment['AIRSTREAM_SHERPA_LIBRARY_DIR'] ??
                File(Platform.resolvedExecutable).parent.path,
      },
      errorsAreFatal: true,
      onError: errors.sendPort,
    );
    _isolate = isolate;
    final first = await Future.any<Object?>([
      ready.first,
      errors.first
          .then((value) => throw StateError('Sherpa worker failed: $value')),
    ]).timeout(const Duration(minutes: 2));
    ready.close();
    errors.close();
    if (first is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      _isolate = null;
      throw StateError('Sherpa initialization failed: $first');
    }
    _commands = first;
    _installation = installation;
  }

  Future<TtsAudio> synthesize({
    required String text,
    required int speakerId,
    required String language,
    required double speed,
    required int steps,
  }) async {
    final commands = _commands;
    if (commands == null) throw StateError('TTS engine is not ready.');
    final response = ReceivePort();
    final cancelFlag = calloc<Uint8>()..value = 0;
    final activeRequest = Completer<void>();
    _cancelFlag = cancelFlag;
    _activeRequest = activeRequest;
    commands.send(<String, Object>{
      'type': 'synthesize',
      'reply': response.sendPort,
      'text': text,
      'speakerId': speakerId,
      'language': language,
      'speed': speed,
      'steps': steps,
      'cancelAddress': cancelFlag.address,
    });
    try {
      final result = await response.first.timeout(const Duration(seconds: 90));
      if (result is Map && result['error'] != null) {
        throw StateError(result['error'] as String);
      }
      if (result is! Map || result['samples'] is! TransferableTypedData) {
        throw StateError('Sherpa returned an invalid audio response.');
      }
      final bytes = (result['samples'] as TransferableTypedData).materialize();
      return TtsAudio(
        Float32List.view(bytes),
        result['sampleRate'] as int,
      );
    } finally {
      response.close();
      if (identical(_cancelFlag, cancelFlag)) _cancelFlag = null;
      if (identical(_activeRequest, activeRequest)) _activeRequest = null;
      calloc.free(cancelFlag);
      if (!activeRequest.isCompleted) activeRequest.complete();
    }
  }

  /// Stops native generation immediately. The worker is recreated lazily.
  Future<void> cancel() async {
    _cancelFlag?.value = 1;
    final activeRequest = _activeRequest;
    if (activeRequest != null) {
      try {
        await activeRequest.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        _commands = null;
        _installation = null;
        _isolate?.kill(priority: Isolate.immediate);
        _isolate = null;
        return;
      }
    }
    await unload();
  }

  Future<void> unload() async {
    final commands = _commands;
    _commands = null;
    _installation = null;
    final isolate = _isolate;
    _isolate = null;
    if (commands == null) {
      isolate?.kill(priority: Isolate.immediate);
      return;
    }
    final response = ReceivePort();
    commands.send({'type': 'dispose', 'reply': response.sendPort});
    try {
      await response.first.timeout(const Duration(seconds: 3));
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
    } finally {
      response.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await unload();
  }

  static Map<String, Object> _modelMessage(TtsModelInstallation installation) {
    final model = installation.model;
    return {
      'family': model.family.name,
      'directory': installation.directory.path,
      'threads': 2,
    };
  }

  static void _workerMain(Map<String, Object> startup) {
    final owner = startup['reply']! as SendPort;
    final model = startup['model']! as Map;
    if (Platform.isWindows) {
      // Windows searches System32 before the application directory for a DLL's
      // transitive dependencies. Preloading our pinned runtime prevents an old
      // system-wide onnxruntime.dll from being bound to Sherpa.
      final directory = startup['nativeLibraryDirectory']! as String;
      DynamicLibrary.open('$directory\\onnxruntime.dll');
      DynamicLibrary.open('$directory\\sherpa-onnx-c-api.dll');
    }
    sherpa.initBindings();
    sherpa.OfflineTts? tts;
    try {
      final directory = model['directory']! as String;
      final separator = directory.contains('\\') ? '\\' : '/';
      String file(String name) => '$directory$separator$name';
      final family = model['family'] as String;
      final modelConfig = family == TtsModelFamily.supertonic.name
          ? sherpa.OfflineTtsModelConfig(
              supertonic: sherpa.OfflineTtsSupertonicModelConfig(
                durationPredictor: file('duration_predictor.int8.onnx'),
                textEncoder: file('text_encoder.int8.onnx'),
                vectorEstimator: file('vector_estimator.int8.onnx'),
                vocoder: file('vocoder.int8.onnx'),
                ttsJson: file('tts.json'),
                unicodeIndexer: file('unicode_indexer.bin'),
                voiceStyle: file('voice.bin'),
              ),
              numThreads: model['threads'] as int,
              debug: false,
              provider: 'cpu',
            )
          : sherpa.OfflineTtsModelConfig(
              vits: sherpa.OfflineTtsVitsModelConfig(
                model: file('es_ES-sharvard-medium.onnx'),
                tokens: file('tokens.txt'),
                dataDir: file('espeak-ng-data'),
              ),
              numThreads: model['threads'] as int,
              debug: false,
              provider: 'cpu',
            );
      tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      ));
      final commands = ReceivePort();
      owner.send(commands.sendPort);
      commands.listen((dynamic message) {
        if (message is! Map) return;
        if (message['type'] == 'dispose') {
          final reply = message['reply'] as SendPort?;
          tts?.free();
          tts = null;
          reply?.send(true);
          commands.close();
          return;
        }
        if (message['type'] != 'synthesize') return;
        final reply = message['reply'] as SendPort;
        try {
          final audio = tts!.generateWithConfig(
            text: message['text'] as String,
            config: sherpa.OfflineTtsGenerationConfig(
              sid: message['speakerId'] as int,
              speed: message['speed'] as double,
              numSteps: message['steps'] as int,
              extra: family == TtsModelFamily.supertonic.name
                  ? {'lang': message['language'] as String}
                  : const {},
            ),
            onProgress: (_, __) => Pointer<Uint8>.fromAddress(
                      message['cancelAddress'] as int,
                    ).value ==
                    0
                ? 1
                : 0,
          );
          reply.send({
            'samples': TransferableTypedData.fromList([
              audio.samples.buffer.asUint8List(
                audio.samples.offsetInBytes,
                audio.samples.lengthInBytes,
              ),
            ]),
            'sampleRate': audio.sampleRate,
          });
        } catch (error, stack) {
          reply.send({'error': '$error\n$stack'});
        }
      });
    } catch (error, stack) {
      tts?.free();
      owner.send('Unable to load Sherpa model: $error\n$stack');
    }
  }
}

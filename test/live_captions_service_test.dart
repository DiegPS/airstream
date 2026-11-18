import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/speech_model_catalog.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a superseded loading caption worker releases before the next spawns',
      () async {
    final root = await Directory.systemTemp.createTemp('airstream-captions-');
    addTearDown(() => root.delete(recursive: true));
    final service = LiveCaptionsService(
      modelCache: _InstalledCache(root),
      audioCapture: _SilentCapture(),
      workerEntrypoint: _gatedWorker,
    );
    final proceed = File('${root.path}/proceed');
    addTearDown(() async {
      await proceed.create();
      await service.dispose();
    });
    final first = service.updateConfig(
        enabled: true,
        sourceLanguage: 'es',
        targetLanguage: 'es',
        denoise: true);
    final loading = File('${root.path}/loading');
    for (var i = 0; i < 500 && !loading.existsSync(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(loading.existsSync(), isTrue);
    final second = service.updateConfig(
        enabled: true,
        sourceLanguage: 'en',
        targetLanguage: 'en',
        denoise: true);
    // Let an incorrectly concurrent teardown finish while the worker is gated.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await proceed.create();
    await second;
    expect(File('${root.path}/worker-order').readAsStringSync(), 'released');
    await first;
    expect(service.currentState.phase, LiveCaptionsPhase.listening);
  });

  test('language changes wait for stale caption startup to release capture',
      () async {
    final root = await Directory.systemTemp.createTemp('airstream-captions-');
    addTearDown(() => root.delete(recursive: true));
    final capture = _GatedCapture();
    final service = LiveCaptionsService(
      modelCache: _InstalledCache(root),
      audioCapture: capture,
      workerEntrypoint: _releasingWorker,
    );
    addTearDown(service.dispose);
    final first = service.updateConfig(
        enabled: true,
        sourceLanguage: 'es',
        targetLanguage: 'es',
        denoise: true);
    await capture.entered.future;
    expect(service.currentState.phase, LiveCaptionsPhase.loading);
    final second = service.updateConfig(
        enabled: true,
        sourceLanguage: 'en',
        targetLanguage: 'en',
        denoise: true);
    // Give a wrongly concurrent stop a chance to run before startup returns.
    await Future<void>.delayed(Duration.zero);
    capture.release.complete();
    await Future.wait([first, second]);
    expect(capture.calls, ['start', 'started', 'stop', 'start', 'started']);
    expect(service.currentState.phase, LiveCaptionsPhase.listening);
  });

  test('enabling captions never downloads without explicit user action',
      () async {
    final root = await Directory.systemTemp.createTemp('airstream-captions-');
    var requests = 0;
    final service = LiveCaptionsService(
      modelCache: TtsModelCache(
        rootDirectory: root,
        client: MockClient((request) async {
          requests++;
          return http.Response('unexpected', 500);
        }),
      ),
    );
    try {
      await service.updateConfig(
        enabled: true,
        sourceLanguage: 'es',
        targetLanguage: 'en',
        denoise: true,
      );

      expect(requests, 0);
      expect(service.currentState.phase, LiveCaptionsPhase.missingModel);
      expect(service.currentState.totalBytes,
          SpeechModelCatalog.canary.package.downloadBytes);
    } finally {
      await service.dispose();
      if (await root.exists()) await root.delete(recursive: true);
    }
  });

  test('settings changes during a model download keep it running and visible',
      () async {
    final cache = _PendingDownloadCache();
    final service = LiveCaptionsService(modelCache: cache);
    addTearDown(service.dispose);
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'es',
      targetLanguage: 'en',
      denoise: true,
    );
    expect(service.currentState.phase, LiveCaptionsPhase.missingModel);

    final download = service.prepareModel();
    await cache.started.future;
    expect(service.currentState.phase, LiveCaptionsPhase.downloading);

    // An unrelated setting changed: the same caption configuration again.
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'es',
      targetLanguage: 'en',
      denoise: true,
    );
    expect(service.currentState.phase, LiveCaptionsPhase.downloading);

    // The caption language changed while downloading.
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'en',
      targetLanguage: 'es',
      denoise: true,
    );
    expect(cache.cancellation!.isCancelled, isFalse);
    expect(service.currentState.phase, LiveCaptionsPhase.downloading);

    // Disabling captions does cancel it.
    await service.updateConfig(
      enabled: false,
      sourceLanguage: 'en',
      targetLanguage: 'es',
      denoise: true,
    );
    expect(cache.cancellation!.isCancelled, isTrue);
    cache.finish();
    await expectLater(download, throwsA(anything));
  });

  test('caption model package has verified ASR and VAD artifacts', () {
    final model = SpeechModelCatalog.canary;

    expect(model.package.downloads, hasLength(3));
    expect(model.package.downloads.every((item) => item.sha256.length == 64),
        isTrue);
    expect(model.package.requiredFiles, contains('silero_vad.onnx'));
    expect(model.package.requiredFiles, contains('gtcrn_simple.onnx'));
    expect(model.languages.map((item) => item.code),
        containsAll(['es', 'en', 'de', 'fr']));
    expect(model.targetsFor('es').map((item) => item.code), ['es', 'en']);
    expect(model.supportsDirection('es', 'fr'), isFalse);
  });

  test('turning captions off releases the native model before the worker ends',
      () async {
    final root = await Directory.systemTemp.createTemp('airstream-captions-');
    addTearDown(() => root.delete(recursive: true));
    final service = LiveCaptionsService(
      modelCache: _InstalledCache(root),
      audioCapture: _SilentCapture(),
      workerEntrypoint: _releasingWorker,
    );
    addTearDown(service.dispose);
    final listening = service.states
        .firstWhere((state) => state.phase == LiveCaptionsPhase.listening);
    await service.updateConfig(
      enabled: true,
      sourceLanguage: 'es',
      targetLanguage: 'es',
      denoise: false,
    );
    await listening.timeout(const Duration(seconds: 10));

    await service.updateConfig(
      enabled: false,
      sourceLanguage: 'es',
      targetLanguage: 'es',
      denoise: false,
    );

    expect(File('${root.path}/released').existsSync(), isTrue);
  });
}

/// A model cache whose download stays pending until [finish] is called.
class _PendingDownloadCache extends TtsModelCache {
  final started = Completer<void>();
  final _done = Completer<TtsModelInstallation>();
  TtsDownloadCancellation? cancellation;

  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async =>
      null;

  @override
  Future<TtsModelInstallation> ensureAvailable(
    TtsModelDefinition model, {
    void Function(TtsInstallProgress progress)? onProgress,
    TtsDownloadCancellation? cancellation,
  }) {
    this.cancellation = cancellation;
    onProgress?.call(const TtsInstallProgress(
      phase: TtsInstallPhase.downloading,
      message: 'Downloading',
      receivedBytes: 10,
      totalBytes: 100,
    ));
    if (!started.isCompleted) started.complete();
    return _done.future;
  }

  void finish() => _done.completeError(StateError('download stopped'));
}

/// A model cache that reports the caption model as installed in [directory].
class _InstalledCache extends TtsModelCache {
  _InstalledCache(this.directory);

  final Directory directory;

  @override
  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async =>
      TtsModelInstallation(model, directory);
}

class _SilentCapture implements SpeechAudioCapture {
  final _audio = StreamController<Uint8List>();

  @override
  Future<Stream<Uint8List>> start() async => _audio.stream;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _audio.close();
}

class _GatedCapture implements SpeechAudioCapture {
  final entered = Completer<void>();
  final release = Completer<void>();
  final calls = <String>[];

  @override
  Future<Stream<Uint8List>> start() async {
    calls.add('start');
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    calls.add('started');
    return const Stream.empty();
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {}
}

/// Stands in for the native worker: releasing its model takes a moment, and
/// leaves a mark so the test can tell it happened.
void _releasingWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final directory = startup['directory']! as String;
  final commands = ReceivePort();
  owner.send(commands.sendPort);
  commands.listen((dynamic message) {
    if (message is Map && message['type'] == 'dispose') {
      sleep(const Duration(milliseconds: 200));
      File('$directory/released').writeAsStringSync('freed');
      (message['reply'] as SendPort?)?.send(true);
      commands.close();
    }
  });
}

void _gatedWorker(Map<String, Object> startup) {
  final owner = startup['reply']! as SendPort;
  final directory = startup['directory']! as String;
  final old = startup['sourceLanguage'] == 'es';
  final released = File('$directory/old-worker-released');
  final commands = ReceivePort();
  commands.listen((dynamic message) {
    if (message is Map && message['type'] == 'dispose') {
      if (old) released.createSync();
      (message['reply'] as SendPort?)?.send(true);
      commands.close();
    }
  });
  if (old) {
    File('$directory/loading').createSync();
    Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!File('$directory/proceed').existsSync()) return;
      timer.cancel();
      owner.send(commands.sendPort);
    });
  } else {
    File('$directory/worker-order')
        .writeAsStringSync(released.existsSync() ? 'released' : 'overlap');
    owner.send(commands.sendPort);
  }
}

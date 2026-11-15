import 'dart:async';
import 'dart:io';

import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/speech_model_catalog.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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

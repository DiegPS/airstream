import 'dart:io';

import 'package:airstream/services/tts/sherpa_tts_engine.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

class _NativeModelCase {
  const _NativeModelCase({
    required this.environmentKey,
    required this.model,
    required this.text,
    this.language,
  });

  final String environmentKey;
  final TtsModelDefinition model;
  final String text;
  final String? language;
}

void main() {
  final cases = [
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_SUPERTONIC_MODEL_DIR',
      model: TtsModelCatalog.supertonic,
      text: 'Hola, Airstream está listo.',
      language: 'es',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_PIPER_MX_MODEL_DIR',
      model: TtsModelCatalog.piperMexico,
      text: 'Hola, esta es la voz mexicana de Airstream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_PIPER_ES_MODEL_DIR',
      model: TtsModelCatalog.piperSpain,
      text: 'Hola, esta es la voz española de Airstream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_KITTEN_MODEL_DIR',
      model: TtsModelCatalog.kitten,
      text: 'Airstream is ready for your next live stream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_KOKORO_MODEL_DIR',
      model: TtsModelCatalog.kokoro,
      text: 'Airstream is ready for your next live stream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_MATCHA_MODEL_DIR',
      model: TtsModelCatalog.matcha,
      text: 'Airstream is ready for your next live stream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_POCKET_MODEL_DIR',
      model: TtsModelCatalog.pocket,
      text: 'Airstream is ready for your next live stream.',
    ),
    _NativeModelCase(
      environmentKey: 'AIRSTREAM_ZIPVOICE_MODEL_DIR',
      model: TtsModelCatalog.zipVoice,
      text: 'Airstream is ready for your next live stream.',
      language: 'en',
    ),
  ];

  for (final modelCase in cases) {
    final directory = Platform.environment[modelCase.environmentKey];
    test(
      'synthesizes audio with ${modelCase.model.name}',
      () async {
        final model = modelCase.model;
        final voice = model.voices.first;
        final engine = SherpaTtsEngine();
        try {
          await engine.initialize(TtsModelInstallation(
            model,
            Directory(directory!),
          ));
          final audio = await engine.synthesize(
            text: modelCase.text,
            speakerId: voice.speakerId,
            language: modelCase.language ?? model.languages.first.code,
            speed: 1,
            steps: model.defaultSteps,
            referenceAudio: voice.referenceAudio,
            referenceText: voice.referenceText,
          );
          expect(audio.sampleRate, greaterThan(0));
          expect(audio.samples.length, greaterThan(audio.sampleRate ~/ 4));
        } finally {
          await engine.dispose();
        }
      },
      skip: directory == null
          ? 'Set ${modelCase.environmentKey} for this native smoke test.'
          : false,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }

  final piperDirectory = Platform.environment['AIRSTREAM_PIPER_MX_MODEL_DIR'];
  test(
    'cancels native generation and can initialize again',
    () async {
      final engine = SherpaTtsEngine();
      final installation = TtsModelInstallation(
        TtsModelCatalog.piperMexico,
        Directory(piperDirectory!),
      );
      try {
        await engine.initialize(installation);
        final generation = engine.synthesize(
          text: List.filled(
            80,
            'Esta frase hace deliberadamente larga la síntesis.',
          ).join(' '),
          speakerId: 0,
          language: 'es',
          speed: 1,
          steps: 8,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final stopwatch = Stopwatch()..start();
        await engine.cancel();
        await generation;
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));

        await engine.initialize(installation);
        final recovered = await engine.synthesize(
          text: 'El motor se recuperó correctamente.',
          speakerId: 0,
          language: 'es',
          speed: 1,
          steps: 8,
        );
        expect(recovered.samples, isNotEmpty);
      } finally {
        await engine.dispose();
      }
    },
    skip: piperDirectory == null
        ? 'Set AIRSTREAM_PIPER_MX_MODEL_DIR for the native cancellation test.'
        : false,
  );
}

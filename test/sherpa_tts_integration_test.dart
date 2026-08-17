import 'dart:io';

import 'package:airstream/services/tts/sherpa_tts_engine.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final supertonicDirectory =
      Platform.environment['AIRSTREAM_SUPERTONIC_MODEL_DIR'];
  final piperDirectory = Platform.environment['AIRSTREAM_PIPER_MODEL_DIR'];

  test(
    'synthesizes Spanish audio through the native Sherpa runtime',
    () async {
      final engine = SherpaTtsEngine();
      try {
        await engine.initialize(TtsModelInstallation(
          TtsModelCatalog.supertonic,
          Directory(supertonicDirectory!),
        ));
        final audio = await engine.synthesize(
          text: 'Hola, Airstream está listo.',
          speakerId: TtsModelCatalog.supertonic.voice('M1').speakerId,
          language: 'es',
          speed: 1.05,
          steps: 8,
        );
        expect(audio.sampleRate, greaterThan(0));
        expect(audio.samples.length, greaterThan(audio.sampleRate ~/ 2));
      } finally {
        await engine.dispose();
      }
    },
    skip: supertonicDirectory == null
        ? 'Set AIRSTREAM_SUPERTONIC_MODEL_DIR for the native model smoke test.'
        : false,
  );

  test(
    'synthesizes Spanish audio through the native Piper runtime',
    () async {
      final engine = SherpaTtsEngine();
      try {
        await engine.initialize(TtsModelInstallation(
          TtsModelCatalog.piperSpanish,
          Directory(piperDirectory!),
        ));
        final audio = await engine.synthesize(
          text: 'Hola, esta es la voz ligera de Airstream.',
          speakerId: 0,
          language: 'es',
          speed: 1,
          steps: 8,
        );
        expect(audio.sampleRate, 22050);
        expect(audio.samples.length, greaterThan(audio.sampleRate ~/ 2));
      } finally {
        await engine.dispose();
      }
    },
    skip: piperDirectory == null
        ? 'Set AIRSTREAM_PIPER_MODEL_DIR for the native model smoke test.'
        : false,
  );

  test(
    'cancels native generation and can initialize again',
    () async {
      final engine = SherpaTtsEngine();
      final installation = TtsModelInstallation(
        TtsModelCatalog.piperSpanish,
        Directory(piperDirectory!),
      );
      try {
        await engine.initialize(installation);
        final generation = engine.synthesize(
          text: List.filled(
                  80, 'Esta frase hace deliberadamente larga la síntesis.')
              .join(' '),
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
        ? 'Set AIRSTREAM_PIPER_MODEL_DIR for the native cancellation test.'
        : false,
  );
}

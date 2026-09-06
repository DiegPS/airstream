import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'package:airstream/services/speech/speech_model_catalog.dart';

import 'support/sherpa_test_environment.dart';

void main() {
  final nativeDirectory = findSherpaNativeLibraryDirectory();
  final speechDirectory = findSherpaModelDirectory(
    environmentKey: 'AIRSTREAM_CAPTIONS_MODEL_DIR',
    storageKey: SpeechModelCatalog.canary.package.storageKey,
  );
  final vadModel = Platform.environment['AIRSTREAM_SILERO_VAD_MODEL'] ??
      (speechDirectory == null ? null : '$speechDirectory\\silero_vad.onnx');
  final denoiserModel = Platform.environment['AIRSTREAM_GTCRN_MODEL'] ??
      (speechDirectory == null ? null : '$speechDirectory\\gtcrn_simple.onnx');
  final canRun = nativeDirectory != null &&
      vadModel != null &&
      File(vadModel).existsSync() &&
      denoiserModel != null &&
      File(denoiserModel).existsSync();

  test(
    'loads native VAD and streaming noise reduction',
    () {
      DynamicLibrary.open('$nativeDirectory\\onnxruntime.dll');
      DynamicLibrary.open('$nativeDirectory\\sherpa-onnx-c-api.dll');
      sherpa.initBindings();
      final vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(model: vadModel!),
          sampleRate: 16000,
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 10,
      );
      final denoiser = sherpa.OnlineSpeechDenoiser(
        sherpa.OnlineSpeechDenoiserConfig(
          model: sherpa.OfflineSpeechDenoiserModelConfig(
            gtcrn: sherpa.OfflineSpeechDenoiserGtcrnModelConfig(
              model: denoiserModel!,
            ),
            numThreads: 1,
            debug: false,
          ),
        ),
      );
      try {
        final samples = Float32List.fromList(List<double>.generate(
          16000,
          (index) => 0.1 * math.sin(index * 2 * math.pi * 220 / 16000),
        ));
        final enhanced = denoiser.run(samples: samples, sampleRate: 16000);
        expect(enhanced.sampleRate, 16000);
        expect(enhanced.samples, isNotEmpty);

        vad.acceptWaveform(Float32List(16000));
        expect(vad.isDetected(), isFalse);
      } finally {
        denoiser.free();
        vad.free();
      }
    },
    skip: canRun
        ? false
        : 'Set Sherpa library, Silero VAD, and GTCRN model paths.',
  );
}

import 'dart:io';

import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}

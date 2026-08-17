import 'package:airstream/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

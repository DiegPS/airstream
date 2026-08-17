import 'package:airstream/services/speech/voice_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires the configured wake word', () {
    expect(VoiceCommand.parse('inicia grabación'), isNull);
    expect(VoiceCommand.parse('computadora inicia grabación'), isNull);
  });

  test('parses safe OBS recording commands', () {
    expect(
      VoiceCommand.parse('Airstream, inicia grabación')?.type,
      VoiceCommandType.startRecording,
    );
    expect(
      VoiceCommand.parse('Airstream detén grabación')?.type,
      VoiceCommandType.stopRecording,
    );
    expect(
      VoiceCommand.parse('Airstream reanuda grabación')?.type,
      VoiceCommandType.resumeRecording,
    );
  });

  test('extracts an OBS scene name', () {
    final command = VoiceCommand.parse('Airstream cambia a escena cámara');

    expect(command?.type, VoiceCommandType.switchScene);
    expect(command?.argument, 'cámara');
    expect(
      VoiceCommand.parse('Airstream switch to scene camera')?.argument,
      'camera',
    );
  });
}

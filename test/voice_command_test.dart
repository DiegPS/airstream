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
    expect(command?.argument, 'camara');
    expect(
      VoiceCommand.parse('Airstream switch to scene camera')?.argument,
      'camera',
    );
  });

  test('accepts commands transcribed without accents or with punctuation', () {
    expect(
      VoiceCommand.parse('airstream inicia grabacion')?.type,
      VoiceCommandType.startRecording,
    );
    expect(
      VoiceCommand.parse('AIRSTREAM... deten grabacion!')?.type,
      VoiceCommandType.stopRecording,
    );
    expect(
      VoiceCommand.parse('Airstream, continúa grabación.')?.type,
      VoiceCommandType.resumeRecording,
    );
  });

  test('normalizes a custom wake word like the transcript', () {
    expect(
      VoiceCommand.parse('Hey Air Stream, pausa grabación',
              wakeWord: 'Hey, Air-Stream')
          ?.type,
      VoiceCommandType.pauseRecording,
    );
    expect(
      VoiceCommand.parse('Hola Señal inicia grabación', wakeWord: 'hola senal')
          ?.type,
      VoiceCommandType.startRecording,
    );
    expect(VoiceCommand.parse('inicia grabación', wakeWord: '!!!'), isNull);
  });

  test('resolves a spoken scene to the exact OBS scene name', () {
    const scenes = ['Main', 'BRB!', 'Escena-Juego', 'Cámara 2'];

    expect(resolveSceneName('Main', scenes), 'Main');
    expect(resolveSceneName('brb', scenes), 'BRB!');
    expect(resolveSceneName('escena juego', scenes), 'Escena-Juego');
    expect(resolveSceneName('camara 2', scenes), 'Cámara 2');
    expect(resolveSceneName('juego', scenes), isNull);
    expect(resolveSceneName('', scenes), isNull);
  });
}

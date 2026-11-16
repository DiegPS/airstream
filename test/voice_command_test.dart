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

  group('multilingual recording commands', () {
    const forms = [
      (
        VoiceCommandType.startRecording,
        ['inicia', 'iniciar', 'empieza', 'comienza'],
        'la',
        'grabacion'
      ),
      (
        VoiceCommandType.stopRecording,
        ['deten', 'detener', 'para', 'parar', 'termina'],
        'la',
        'grabacion'
      ),
      (VoiceCommandType.pauseRecording, ['pausa', 'pausar'], 'la', 'grabacion'),
      (
        VoiceCommandType.resumeRecording,
        ['continua', 'continuar', 'reanuda', 'reanudar'],
        'la',
        'grabacion'
      ),
      (VoiceCommandType.startRecording, ['start', 'begin'], 'the', 'recording'),
      (VoiceCommandType.stopRecording, ['stop', 'end'], 'the', 'recording'),
      (VoiceCommandType.pauseRecording, ['pause'], 'the', 'recording'),
      (
        VoiceCommandType.resumeRecording,
        ['resume', 'continue'],
        'the',
        'recording'
      ),
      (
        VoiceCommandType.startRecording,
        ['starte', 'starten', 'beginne'],
        'die',
        'aufnahme'
      ),
      (
        VoiceCommandType.stopRecording,
        ['stoppe', 'stopp', 'beende'],
        'die',
        'aufnahme'
      ),
      (VoiceCommandType.pauseRecording, ['pausiere'], 'die', 'aufnahme'),
      (
        VoiceCommandType.startRecording,
        ['demarre', 'demarrer', 'lance', 'lancer', 'commence'],
        'l',
        'enregistrement'
      ),
      (
        VoiceCommandType.stopRecording,
        ['arrete', 'arreter', 'stoppe', 'termine'],
        'l',
        'enregistrement'
      ),
      (
        VoiceCommandType.pauseRecording,
        ['mets en pause', 'mettre en pause', 'pause'],
        'l',
        'enregistrement'
      ),
      (
        VoiceCommandType.resumeRecording,
        ['reprends', 'reprendre'],
        'l',
        'enregistrement'
      ),
    ];
    const endings = [
      '',
      ' por favor',
      ' please',
      ' bitte',
      ' s il te plait',
      ' s il vous plait'
    ];
    for (final (type, verbs, article, noun) in forms) {
      for (final verb in verbs) {
        for (final determiner in ['', '$article ', if (article == 'l') 'le ']) {
          final phrase = '$verb $determiner$noun';
          test('recognizes $phrase with punctuation and polite endings', () {
            for (final ending in endings) {
              for (final transcript in [
                'airstream $phrase$ending',
                'Airstream, $phrase$ending.'
              ]) {
                final command = VoiceCommand.parse(transcript);
                expect(command?.type, type, reason: transcript);
                expect(command?.argument, isEmpty, reason: transcript);
              }
            }
          });
        }
      }
    }

    const alternateForms = {
      'aufnahme starten': VoiceCommandType.startRecording,
      'aufnahme stoppen': VoiceCommandType.stopRecording,
      'aufnahme beenden': VoiceCommandType.stopRecording,
      'aufnahme pausieren': VoiceCommandType.pauseRecording,
      'setze aufnahme fort': VoiceCommandType.resumeRecording,
      'setze die aufnahme fort': VoiceCommandType.resumeRecording,
      'aufnahme fortsetzen': VoiceCommandType.resumeRecording,
      'mets enregistrement en pause': VoiceCommandType.pauseRecording,
      'mets l enregistrement en pause': VoiceCommandType.pauseRecording,
      'mets le enregistrement en pause': VoiceCommandType.pauseRecording,
    };
    for (final entry in alternateForms.entries) {
      test('recognizes ${entry.key} with punctuation and polite endings', () {
        for (final ending in endings) {
          for (final transcript in [
            'airstream ${entry.key}$ending',
            'Airstream, ${entry.key}$ending.'
          ]) {
            expect(VoiceCommand.parse(transcript)?.type, entry.value,
                reason: transcript);
          }
        }
      });
    }
  });

  group('multilingual scene commands', () {
    const prefixes = [
      'cambia escena',
      'cambia a escena',
      'cambia la escena',
      'cambia a la escena',
      'cambiar escena',
      'cambiar a escena',
      'cambiar la escena',
      'cambiar a la escena',
      'switch scene',
      'switch to scene',
      'switch the scene',
      'switch to the scene',
      'change to scene',
      'go to scene',
      'wechsle zu szene',
      'wechsle zur szene',
      'wechsle szene',
      'passe a la scene',
      'passer a la scene',
      'change de scene',
      'va a la scene',
      'passe a scene',
      'passer a scene',
      'va a scene',
      'change de la scene',
    ];
    for (final prefix in prefixes) {
      test('extracts scene after $prefix', () {
        for (final transcript in [
          'airstream $prefix Caméra 2',
          'Airstream, $prefix Caméra 2.',
        ]) {
          final command = VoiceCommand.parse(transcript);
          expect(command?.type, VoiceCommandType.switchScene,
              reason: transcript);
          expect(command?.argument, 'camera 2', reason: transcript);
        }
        expect(VoiceCommand.parse('airstream $prefix'), isNull);
      });
    }
    test('preserves scene names containing polite endings', () {
      expect(
          VoiceCommand.parse('airstream switch scene camera please')?.argument,
          'camera please');
      expect(VoiceCommand.parse('airstream cambia escena por favor')?.argument,
          'por favor');
      expect(VoiceCommand.parse('airstream switch scene please')?.argument,
          'please');
    });
  });

  test('recognizes typical Canary transcripts', () {
    const recordings = {
      'Airstream, starte die Aufnahme.': VoiceCommandType.startRecording,
      "Airstream, démarre l'enregistrement.": VoiceCommandType.startRecording,
      "Airstream, arrête l'enregistrement.": VoiceCommandType.stopRecording,
      "Airstream, mets l'enregistrement en pause.":
          VoiceCommandType.pauseRecording,
      "Airstream, reprends l'enregistrement.": VoiceCommandType.resumeRecording,
      'Airstream, setze die Aufnahme fort.': VoiceCommandType.resumeRecording,
      'Airstream, start the recording please.': VoiceCommandType.startRecording,
    };
    for (final entry in recordings.entries) {
      expect(VoiceCommand.parse(entry.key)?.type, entry.value,
          reason: entry.key);
    }
    for (final (transcript, scene) in [
      ('Airstream, wechsle zur Szene Spiel.', 'spiel'),
      ('Airstream, passe à la scène jeu.', 'jeu'),
    ]) {
      final command = VoiceCommand.parse(transcript);
      expect(command?.type, VoiceCommandType.switchScene);
      expect(command?.argument, scene);
    }
  });

  test('rejects ordinary speech and incomplete or misplaced commands', () {
    for (final transcript in [
      'starte die aufnahme',
      'hallo airstream starte die aufnahme',
      'airstreaming starte die aufnahme',
      'airstream szene spiel',
      'airstream la grabacion',
      'airstream',
      'airstream hoy quiero hablar de la grabacion',
      'airstream we should start the recording later',
      'airstream heute sprechen wir uber die aufnahme',
      'airstream nous parlons de l enregistrement',
      'airstream inicia la grabacion cuando llegue',
      'airstream start the recording tomorrow',
      'airstream starte die aufnahme morgen',
      'airstream demarre l enregistrement demain',
    ]) {
      expect(VoiceCommand.parse(transcript), isNull, reason: transcript);
    }
  });

  test('recognizes new commands only with the configured custom wake word', () {
    for (final (phrase, type) in [
      ('starte die Aufnahme', VoiceCommandType.startRecording),
      ("arrête l'enregistrement", VoiceCommandType.stopRecording),
      ("mets l'enregistrement en pause", VoiceCommandType.pauseRecording),
      ('setze die Aufnahme fort', VoiceCommandType.resumeRecording),
      ('wechsle zur Szene Spiel', VoiceCommandType.switchScene),
      ('passe à la scène jeu', VoiceCommandType.switchScene),
    ]) {
      expect(
          VoiceCommand.parse('Hey, Signal! $phrase.', wakeWord: 'Hey Signal')
              ?.type,
          type);
      expect(VoiceCommand.parse('Airstream, $phrase.', wakeWord: 'Hey Signal'),
          isNull);
    }
  });
}

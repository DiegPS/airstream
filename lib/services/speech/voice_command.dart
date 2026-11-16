enum VoiceCommandType {
  startRecording,
  stopRecording,
  pauseRecording,
  resumeRecording,
  switchScene,
}

const _accentFolding = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

final _nonWordCharacters = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Normalizes spoken or typed text for comparison: lowercase, without accents
/// or punctuation, single spaces. Speech recognition may or may not produce
/// accents and punctuation, so both sides of every comparison use this.
String normalizeVoiceText(String value) {
  final lowered = value.toLowerCase();
  final folded = StringBuffer();
  for (final character in lowered.split('')) {
    folded.write(_accentFolding[character] ?? character);
  }
  return folded
      .toString()
      .replaceAll(_nonWordCharacters, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Finds the OBS scene a spoken name refers to. Scene names are matched
/// exactly first, then ignoring case, accents and punctuation, because a
/// transcript never reproduces "Escena-Juego" or "BRB!" literally.
String? resolveSceneName(String spoken, Iterable<String> sceneNames) {
  final names = sceneNames.toList(growable: false);
  if (names.contains(spoken)) return spoken;
  final target = normalizeVoiceText(spoken);
  if (target.isEmpty) return null;
  for (final name in names) {
    if (normalizeVoiceText(name) == target) return name;
  }
  return null;
}

class VoiceCommand {
  const VoiceCommand(this.type, {this.argument = ''});

  final VoiceCommandType type;
  final String argument;

  // Patterns run only after an exact, leading wake word has been removed.
  // Keep recording commands anchored so ordinary trailing speech is rejected.
  static final _recordingCommands = <RegExp, VoiceCommandType>{
    RegExp(
      r'^(?:(?:inicia|iniciar|empieza|comienza) (?:la )?grabacion|'
      r'(?:start|begin) (?:the )?recording|'
      r'(?:starte|starten|beginne) (?:die )?aufnahme|aufnahme starten|'
      r'(?:demarre|demarrer|lance|lancer|commence) (?:l |le )?enregistrement)$',
    ): VoiceCommandType.startRecording,
    RegExp(
      r'^(?:(?:deten|detener|para|parar|termina) (?:la )?grabacion|'
      r'(?:stop|end) (?:the )?recording|'
      r'(?:stoppe|stopp|beende) (?:die )?aufnahme|aufnahme (?:stoppen|beenden)|'
      r'(?:arrete|arreter|stoppe|termine) (?:l |le )?enregistrement)$',
    ): VoiceCommandType.stopRecording,
    RegExp(
      r'^(?:(?:pausa|pausar) (?:la )?grabacion|pause (?:the )?recording|'
      r'pausiere (?:die )?aufnahme|aufnahme pausieren|'
      r'(?:mets en pause|mettre en pause|pause) (?:l |le )?enregistrement|'
      r'mets (?:l |le )?enregistrement en pause)$',
    ): VoiceCommandType.pauseRecording,
    RegExp(
      r'^(?:(?:continua|continuar|reanuda|reanudar) (?:la )?grabacion|'
      r'(?:resume|continue) (?:the )?recording|'
      r'setze (?:die )?aufnahme fort|aufnahme fortsetzen|'
      r'(?:reprends|reprendre) (?:l |le )?enregistrement)$',
    ): VoiceCommandType.resumeRecording,
  };

  static final _politeEnding = RegExp(
    r' (?:por favor|please|bitte|s il te plait|s il vous plait)$',
  );
  static final _sceneCommands = [
    RegExp(r'^(?:cambia|cambiar) (?:a )?(?:la )?escena (.+)$'),
    RegExp(
        r'^(?:switch (?:to )?(?:the )?|(?:change|go) to (?:the )?)scene (.+)$'),
    RegExp(r'^wechsle (?:(?:zu|zur) )?(?:die )?szene (.+)$'),
    RegExp(r'^(?:(?:passe|passer|va) a|change de) (?:la )?scene (.+)$'),
  ];

  static VoiceCommand? parse(
    String transcript, {
    String wakeWord = 'airstream',
  }) {
    final normalized = normalizeVoiceText(transcript);
    final prefix = normalizeVoiceText(wakeWord);
    if (prefix.isEmpty || !normalized.startsWith('$prefix ')) return null;
    final command = normalized.substring(prefix.length).trim();
    final withoutPoliteEnding = command.replaceFirst(_politeEnding, '');

    for (final entry in _recordingCommands.entries) {
      if (entry.key.hasMatch(withoutPoliteEnding)) {
        return VoiceCommand(entry.value);
      }
    }

    for (final pattern in _sceneCommands) {
      // The entire remainder is the scene name, including words that could
      // also be polite endings. Preserve existing scene-name behavior.
      final scene = pattern.firstMatch(command)?.group(1)?.trim();
      if (scene != null && scene.isNotEmpty) {
        return VoiceCommand(
          VoiceCommandType.switchScene,
          argument: scene,
        );
      }
    }
    return null;
  }
}

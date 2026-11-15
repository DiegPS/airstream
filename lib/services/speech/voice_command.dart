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

  static const _commands = {
    'inicia grabacion': VoiceCommandType.startRecording,
    'iniciar grabacion': VoiceCommandType.startRecording,
    'start recording': VoiceCommandType.startRecording,
    'deten grabacion': VoiceCommandType.stopRecording,
    'detener grabacion': VoiceCommandType.stopRecording,
    'para grabacion': VoiceCommandType.stopRecording,
    'stop recording': VoiceCommandType.stopRecording,
    'pausa grabacion': VoiceCommandType.pauseRecording,
    'pausar grabacion': VoiceCommandType.pauseRecording,
    'pause recording': VoiceCommandType.pauseRecording,
    'continua grabacion': VoiceCommandType.resumeRecording,
    'continuar grabacion': VoiceCommandType.resumeRecording,
    'reanuda grabacion': VoiceCommandType.resumeRecording,
    'resume recording': VoiceCommandType.resumeRecording,
  };

  static final _spanishScene =
      RegExp(r'^(?:cambia|cambiar) (?:a )?(?:la )?escena (.+)$');
  static final _englishScene = RegExp(r'^switch (?:to )?(?:the )?scene (.+)$');

  static VoiceCommand? parse(
    String transcript, {
    String wakeWord = 'airstream',
  }) {
    final normalized = normalizeVoiceText(transcript);
    final prefix = normalizeVoiceText(wakeWord);
    if (prefix.isEmpty || !normalized.startsWith('$prefix ')) return null;
    final command = normalized.substring(prefix.length).trim();

    final type = _commands[command];
    if (type != null) return VoiceCommand(type);

    final scene =
        (_spanishScene.firstMatch(command) ?? _englishScene.firstMatch(command))
            ?.group(1)
            ?.trim();
    if (scene != null && scene.isNotEmpty) {
      return VoiceCommand(VoiceCommandType.switchScene, argument: scene);
    }
    return null;
  }
}

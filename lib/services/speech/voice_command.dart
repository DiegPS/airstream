enum VoiceCommandType {
  startRecording,
  stopRecording,
  pauseRecording,
  resumeRecording,
  switchScene,
}

class VoiceCommand {
  const VoiceCommand(this.type, {this.argument = ''});

  final VoiceCommandType type;
  final String argument;

  static VoiceCommand? parse(String transcript,
      {String wakeWord = 'airstream'}) {
    final normalized = transcript
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-záéíóúüñ0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final prefix = wakeWord.toLowerCase().trim();
    if (prefix.isEmpty || !normalized.startsWith('$prefix ')) return null;
    final command = normalized.substring(prefix.length).trim();
    if (command == 'inicia grabación' ||
        command == 'iniciar grabación' ||
        command == 'start recording') {
      return const VoiceCommand(VoiceCommandType.startRecording);
    }
    if (command == 'detén grabación' ||
        command == 'detener grabación' ||
        command == 'para grabación' ||
        command == 'stop recording') {
      return const VoiceCommand(VoiceCommandType.stopRecording);
    }
    if (command == 'pausa grabación' ||
        command == 'pausar grabación' ||
        command == 'pause recording') {
      return const VoiceCommand(VoiceCommandType.pauseRecording);
    }
    if (command == 'continúa grabación' ||
        command == 'continuar grabación' ||
        command == 'reanuda grabación' ||
        command == 'resume recording') {
      return const VoiceCommand(VoiceCommandType.resumeRecording);
    }
    final scene = RegExp(r'^(?:cambia|cambiar) (?:a )?escena (.+)$')
        .firstMatch(command)
        ?.group(1)
        ?.trim();
    if (scene != null && scene.isNotEmpty) {
      return VoiceCommand(VoiceCommandType.switchScene, argument: scene);
    }
    final englishScene = RegExp(r'^switch (?:to )?scene (.+)$')
        .firstMatch(command)
        ?.group(1)
        ?.trim();
    if (englishScene != null && englishScene.isNotEmpty) {
      return VoiceCommand(
        VoiceCommandType.switchScene,
        argument: englishScene,
      );
    }
    return null;
  }
}

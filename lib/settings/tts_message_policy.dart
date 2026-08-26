import 'package:airstream/models/chat_message.dart';

const ttsSessionMessageTolerance = Duration(seconds: 2);

bool isTtsMessageFresh(
  ChatMessage message,
  DateTime? sessionStartedAt, {
  Duration tolerance = ttsSessionMessageTolerance,
}) {
  if (sessionStartedAt == null) return true;
  final threshold = sessionStartedAt.toUtc().subtract(tolerance);
  return !message.timestamp.toUtc().isBefore(threshold);
}

String sanitizeTtsAuthorName(String rawName) {
  return rawName
      .replaceAll('@', ' ')
      .replaceAll(RegExp(r'\d+'), ' ')
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Returns the text following an exact TTS command, or `null` when [message]
/// is not a command or contains no text to speak.
String? extractTtsCommandText(
  String message, {
  required String prefix,
  required bool ignoreCase,
}) {
  final command = prefix.trim();
  if (command.isEmpty || message.length < command.length) return null;

  final candidate = message.substring(0, command.length);
  final matches = ignoreCase
      ? candidate.toLowerCase() == command.toLowerCase()
      : candidate == command;
  if (!matches) return null;

  final remainder = message.substring(command.length);
  if (remainder.isEmpty || !RegExp(r'^\s').hasMatch(remainder)) return null;

  final body = remainder.trim();
  return body.isEmpty ? null : body;
}

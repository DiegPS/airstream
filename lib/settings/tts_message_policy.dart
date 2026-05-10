import 'package:airchat_flutter/models/chat_message.dart';

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

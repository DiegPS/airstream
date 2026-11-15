import 'package:airstream/models/chat_message.dart';

/// What the chat shows while the viewer has scrolled up to read.
class PausedChatView {
  const PausedChatView({required this.messages, required this.newCount});

  /// The messages that were on screen when reading started, in their latest
  /// version. Moderated or trimmed messages drop out; nothing is added, so
  /// the text being read does not move.
  final List<ChatMessage> messages;

  /// Messages that arrived since reading started.
  final int newCount;
}

PausedChatView pausedChatView(
  List<ChatMessage> snapshot,
  List<ChatMessage> live,
) {
  final liveByKey = {for (final message in live) message.dedupeKey: message};
  final snapshotKeys = {for (final message in snapshot) message.dedupeKey};
  return PausedChatView(
    messages: [
      for (final message in snapshot)
        if (liveByKey[message.dedupeKey] case final current?) current,
    ],
    newCount: live
        .where((message) => !snapshotKeys.contains(message.dedupeKey))
        .length,
  );
}

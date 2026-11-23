import 'package:airstream/models/chat_message.dart';

/// What the chat shows while the viewer has scrolled up to read.
class PausedChatView {
  const PausedChatView({required this.messages, required this.newCount});

  /// The messages that were on screen when reading started, in their latest
  /// version. Moderated messages drop out; messages the buffer trimmed while
  /// reading stay (a fast chat would otherwise empty the view under the
  /// reader); nothing is added, so the text being read does not move.
  final List<ChatMessage> messages;

  /// Messages that arrived since reading started.
  final int newCount;
}

/// [retained] is the whole current buffer (before any view filter) and
/// [bufferFull] says it reached its size limit, the only case in which it
/// trims. Then a message gone from the front of the buffer was trimmed (kept
/// on screen) and one gone from the middle was moderated (removed).
PausedChatView pausedChatView(
  List<ChatMessage> snapshot,
  List<ChatMessage> live, {
  List<ChatMessage>? retained,
  bool bufferFull = false,
}) {
  final liveByKey = {for (final message in live) message.dedupeKey: message};
  final retainedKeys = {
    for (final message in retained ?? live) message.dedupeKey
  };
  final snapshotKeys = {for (final message in snapshot) message.dedupeKey};
  // The buffer drops its oldest messages first: everything in the snapshot
  // before the first message still retained was trimmed, not moderated.
  var trimmedBefore = bufferFull
      ? snapshot.indexWhere((m) => retainedKeys.contains(m.dedupeKey))
      : 0;
  if (trimmedBefore < 0) trimmedBefore = snapshot.length;
  return PausedChatView(
    messages: [
      for (final (index, message) in snapshot.indexed)
        if (liveByKey[message.dedupeKey] case final current?)
          current
        else if (index < trimmedBefore)
          message,
    ],
    newCount: live
        .where((message) => !snapshotKeys.contains(message.dedupeKey))
        .length,
  );
}

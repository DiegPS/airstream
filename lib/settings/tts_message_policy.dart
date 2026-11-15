import 'package:airstream/models/chat_message.dart';

const ttsSessionMessageTolerance = Duration(seconds: 2);

/// Chat history (the YouTube backlog) only arrives right after connecting.
/// Anything received later is live, whatever its timestamp says.
const ttsBacklogWindow = Duration(seconds: 10);

/// Whether a message should be read aloud in the current TTS session.
///
/// Messages stamped before the session started are history and are skipped,
/// but only during [backlogWindow]: platform timestamps come from the
/// provider's clock, so a computer clock running ahead would otherwise mute
/// live chat for as long as the clocks differ.
bool isTtsMessageFresh(
  ChatMessage message,
  DateTime? sessionStartedAt, {
  Duration tolerance = ttsSessionMessageTolerance,
  Duration backlogWindow = ttsBacklogWindow,
  DateTime? now,
}) {
  if (sessionStartedAt == null) return true;
  final started = sessionStartedAt.toUtc();
  final threshold = started.subtract(tolerance);
  if (!message.timestamp.toUtc().isBefore(threshold)) return true;
  final receivedAt = (now ?? DateTime.now()).toUtc();
  return receivedAt.difference(started) >= backlogWindow;
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

/// Shortens [text] to [maxCharacters] characters (Unicode code points),
/// ending it with an ellipsis.
String limitTtsText(String text, int maxCharacters) {
  final runes = text.runes;
  if (runes.length <= maxCharacters) return text;
  return '${String.fromCharCodes(runes.take(maxCharacters)).trim()}…';
}

/// Whether [author] is on the list of users the voice reader skips (bots
/// such as Nightbot, for example). Names match without case or a leading @.
bool isTtsIgnoredAuthor(ChatAuthor author, List<String> ignoredUsers) {
  if (ignoredUsers.isEmpty) return false;
  String key(String value) =>
      value.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
  final ignored = {for (final user in ignoredUsers) key(user)}..remove('');
  return ignored.contains(key(author.name)) ||
      ignored.contains(key(author.channelId));
}

/// Keeps one viewer from taking over the voice reader: after a message of
/// theirs is read, their next ones wait for the cooldown.
class TtsAuthorCooldown {
  final _lastSpoken = <String, DateTime>{};

  /// Whether [authorKey] may be read at [now]; records it when it may.
  bool tryAcquire(String authorKey, DateTime now, Duration cooldown) {
    if (cooldown <= Duration.zero) return true;
    final last = _lastSpoken[authorKey];
    if (last != null && now.difference(last) < cooldown) return false;
    _lastSpoken[authorKey] = now;
    if (_lastSpoken.length > 2000) {
      _lastSpoken.removeWhere((_, time) => now.difference(time) >= cooldown);
    }
    return true;
  }

  void clear() => _lastSpoken.clear();
}

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_model.dart';

final _ttsUrl = RegExp(
  r'''\b(?:https?://|www\.)[^\s<>"']+''',
  caseSensitive: false,
);
final _ttsEmoji = RegExp(
  // The lint checks this pattern without Unicode mode.
  // ignore: valid_regexps
  r'(?:[0-9#*]\uFE0F?\u20E3|\p{Regional_Indicator}{2}|'
  r'\p{Emoji_Presentation}|\p{Extended_Pictographic})'
  r'[\uFE0E\uFE0F]?(?:\p{Emoji_Modifier})?'
  r'(?:[\u{E0020}-\u{E007E}]+\u{E007F})?'
  r'(?:\u200D(?:\p{Extended_Pictographic}|\p{Emoji_Presentation})'
  r'[\uFE0E\uFE0F]?(?:\p{Emoji_Modifier})?)*',
  unicode: true,
);

bool ttsAllows(ChatMessage message, SettingsModel settings) {
  final roles = settings.ttsRoles;
  final allowedRole = roles.contains(TtsRole.everyone) ||
      (message.isMembership && roles.contains(TtsRole.member)) ||
      (message.isModerator && roles.contains(TtsRole.moderator)) ||
      (message.isVip && roles.contains(TtsRole.vip)) ||
      (message.isOwner && roles.contains(TtsRole.owner));
  final support = settings.ttsAlwaysReadSupport &&
      message.superChat?.amount.trim().isNotEmpty == true;
  return (support ||
          (allowedRole && settings.ttsPlatforms.contains(message.platform))) &&
      (settings.ttsLinks != TtsLinks.skip ||
          !_ttsUrl.hasMatch(message.ttsText)) &&
      (!settings.ttsSkipEmoteOnly || !isTtsEmoteOnly(message));
}

bool isTtsEmoteOnly(ChatMessage message) {
  var hasEmote = false;
  for (final item in message.items) {
    if (item.isEmoji) {
      hasEmote = true;
      continue;
    }
    final text = item.text.trim();
    if (text.isEmpty) continue;
    if (text.replaceAll(_ttsEmoji, '').trim().isNotEmpty) return false;
    hasEmote = true;
  }
  return hasEmote;
}

String replaceTtsLinks(String text, String linkWord) =>
    text.replaceAllMapped(_ttsUrl, (match) {
      final url = match[0]!;
      var end = url.length;
      while (end > 0) {
        final last = url[end - 1];
        if ('.!,?;:'.contains(last)) {
          end--;
          continue;
        }
        final open = const {')': '(', ']': '[', '}': '{'}[last];
        if (open != null) {
          final prefix = url.substring(0, end);
          if (last.allMatches(prefix).length > open.allMatches(prefix).length) {
            end--;
            continue;
          }
        }
        break;
      }
      return '$linkWord${url.substring(end)}';
    });

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

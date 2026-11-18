import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/word_matching.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/settings/settings_model.dart';

/// Decides which chat messages stand out for the streamer: mentions of their
/// channels and the words they chose.
class ChatHighlighter {
  ChatHighlighter({
    required Iterable<String> ownNames,
    required Iterable<String> words,
    this.firstMessages = false,
  })  : _ownNames = {
          for (final name in ownNames)
            if (WordMatching.normalize(name) case final normalized
                when normalized.isNotEmpty)
              normalized,
        },
        _words = {
          for (final word in words)
            if (WordMatching.normalize(word) case final normalized
                when normalized.isNotEmpty)
              normalized,
        };

  factory ChatHighlighter.fromSettings(SettingsModel settings) =>
      ChatHighlighter(
        ownNames: settings.highlightMentions ? ownChannelNames(settings) : [],
        words: settings.highlightWords,
        firstMessages: settings.highlightFirstMessages,
      );

  final Set<String> _ownNames;
  final Set<String> _words;
  final bool firstMessages;

  bool get isEnabled => _ownNames.isNotEmpty || _words.isNotEmpty;

  /// The streamer's own channel names, as viewers would mention them.
  static List<String> ownChannelNames(SettingsModel settings) {
    final handle = settings.youtubeHandle.trim();
    return [
      if (settings.twitchChannel.trim().isNotEmpty) settings.twitchChannel,
      if (settings.kickSlug.trim().isNotEmpty) settings.kickSlug,
      // Only a @handle is a name viewers type; IDs and URLs are not.
      if (handle.startsWith('@') && handle.length > 1) handle.substring(1),
    ];
  }

  bool matches(ChatMessage message) {
    if (!isEnabled || message.isOwner || message.isMembershipEvent) {
      return false;
    }
    final kind = highlightKind(message);
    return kind == HighlightKind.mention || kind == HighlightKind.word;
  }

  /// A mention takes precedence over a word, then a first session message.
  HighlightKind? highlightKind(ChatMessage message) {
    if (message.isOwner || message.isMembershipEvent) return null;
    if (isEnabled &&
        !_ownNames.contains(WordMatching.normalize(message.author.name))) {
      final text = WordMatching.prepare(message.plainText);
      if (_ownNames.any((name) => WordMatching.containsPhrase(text, name))) {
        return HighlightKind.mention;
      }
      if (_words.any((word) => WordMatching.containsPhrase(text, word))) {
        return HighlightKind.word;
      }
    }
    return firstMessages && message.isFirstInSession
        ? HighlightKind.firstMessage
        : null;
  }
}

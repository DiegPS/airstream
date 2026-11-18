import 'package:airstream/settings/media_library_entries.dart';

enum TtsRole { everyone, member, moderator, vip, owner }

enum TtsLinks { read, sayLink, skip }

enum HighlightKind { mention, word, firstMessage }

abstract final class HighlightSounds {
  static const none = 'none';
  static const builtIn = ['chime', 'coin', 'fanfare'];

  static const defaults = {
    HighlightKind.mention: none,
    HighlightKind.word: none,
    HighlightKind.firstMessage: none,
  };

  // The legacy tone ran only for mentions and words.
  static const legacyEnabled = {
    HighlightKind.mention: 'chime',
    HighlightKind.word: 'chime',
    HighlightKind.firstMessage: none,
  };

  static Map<HighlightKind, String> fromJson(Object? raw,
      {bool legacy = false}) {
    if (raw is! Map) return legacy ? legacyEnabled : defaults;
    return Map.unmodifiable({
      for (final kind in HighlightKind.values)
        kind: sanitizeSource(raw[kind.name]),
    });
  }

  static String sanitizeSource(Object? source) => source is String &&
          (builtIn.contains(source) ||
              MediaLibraryEntries.idPattern.hasMatch(source))
      ? source
      : none;
}

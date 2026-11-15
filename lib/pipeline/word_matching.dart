/// Whole-word matching shared by chat filters and highlights.
///
/// Letters, combining marks and digits of every script count as word
/// characters, so words in any language (and letters such as ç, ñ or ö) are
/// matched as whole words, and punctuation such as `@` or `!` is ignored.
abstract final class WordMatching {
  static final _nonWordCharacters =
      RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);
  static final _spaces = RegExp(r'\s+');

  /// Lowercase words separated by single spaces.
  static String normalize(String value) {
    final lowered = value.toLowerCase();
    final sanitized = lowered.replaceAll(_nonWordCharacters, ' ');
    return sanitized.replaceAll(_spaces, ' ').trim();
  }

  /// [text] prepared for [containsPhrase]: normalized and padded.
  static String prepare(String text) => ' ${normalize(text)} ';

  /// Whether the normalized [phrase] appears as whole words in [prepared].
  static bool containsPhrase(String prepared, String phrase) =>
      phrase.isNotEmpty && prepared.contains(' $phrase ');
}

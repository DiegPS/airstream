import 'package:dart_youtube_chat/dart_youtube_chat.dart' as youtube;

/// Pure normalization and validation rules for settings text input.
abstract final class SettingsInputNormalizer {
  /// Normalizes a Twitch or Kick channel name or URL to its public slug.
  static String platformChannel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri?.hasScheme == true && uri!.host.isNotEmpty) {
      final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
      final lastPath = parts.isNotEmpty ? parts.last : '';
      return lastPath.replaceFirst(RegExp(r'^@'), '').trim();
    }
    return trimmed.replaceFirst(RegExp(r'^@'), '').trim();
  }

  /// Normalizes a six-digit RGB color or returns [fallback] when invalid.
  static String hexColor(String value, {required String fallback}) {
    final trimmed = value.trim().toUpperCase();
    final normalized = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized)
        ? normalized
        : fallback.toUpperCase();
  }

  /// Parses a case-insensitively deduplicated comma or line-separated list.
  static List<String> filterList(String raw) {
    final seen = <String>{};
    final values = <String>[];
    for (final part in raw.split(RegExp(r'[\r\n,;]+'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) continue;
      values.add(trimmed);
    }
    return values;
  }

  /// Formats filter values for editing in a multiline text field.
  static String formatFilterList(List<String> values) => values.join('\n');

  /// Whether [first] and [second] contain the same values in the same order.
  static bool listsEqual(List<String> first, List<String> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  /// The video ID in an explicit YouTube video URL, or `null`.
  static String? youtubeVideoId(String value) =>
      youtube.YoutubeId.tryParseVideoUrl(value)?.liveId;

  /// Whether both values are distinct explicit YouTube video URLs.
  static bool distinctYoutubeVideoUrls(String first, String second) {
    final firstId = youtubeVideoId(first);
    final secondId = youtubeVideoId(second);
    return firstId != null && secondId != null && firstId != secondId;
  }

  /// The valid TCP port in [value], or [fallback] when invalid.
  static int overlayPort(String value, {required int fallback}) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed >= 1 && parsed <= 65535 ? parsed : fallback;
  }

  /// Whether [value] is a valid TCP port number.
  static bool isValidOverlayPort(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed >= 1 && parsed <= 65535;
  }
}

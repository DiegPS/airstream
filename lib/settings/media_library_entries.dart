import 'package:path/path.dart' as p;

abstract final class MediaLibraryEntries {
  static final idPattern = RegExp(r'^[0-9a-f]{16}$');
  static const types = {
    'png': ('image', 'image/png'),
    'jpg': ('image', 'image/jpeg'),
    'jpeg': ('image', 'image/jpeg'),
    'gif': ('image', 'image/gif'),
    'webp': ('image', 'image/webp'),
    'mp4': ('video', 'video/mp4'),
    'webm': ('video', 'video/webm'),
    'wav': ('audio', 'audio/wav'),
    'mp3': ('audio', 'audio/mpeg'),
    'ogg': ('audio', 'audio/ogg'),
  };
  static int limit(String kind) =>
      (kind == 'video'
          ? 50
          : kind == 'image'
              ? 10
              : 5) *
      1024 *
      1024;

  static String? displayName(String input) {
    final name = input.trim();
    if (name.isEmpty || RegExp(r'[\\/\x00-\x1f\x7f]').hasMatch(name)) {
      return null;
    }
    return String.fromCharCodes(name.runes.take(80));
  }

  static Iterable<MapEntry<String, Map<String, dynamic>>> search(
    Map<String, Map<String, dynamic>> entries,
    String query,
  ) {
    final term = query.trim().toLowerCase();
    return entries.entries.where((entry) =>
        (entry.value['name'] as String).toLowerCase().contains(term));
  }

  static Map<String, Map<String, dynamic>> sanitize(Object? raw) {
    final result = <String, Map<String, dynamic>>{};
    if (raw is! Map) return result;
    for (final e in raw.entries) {
      if (e.key is! String || !idPattern.hasMatch(e.key) || e.value is! Map) {
        continue;
      }
      final v = e.value as Map;
      final name = v['name'],
          kind = v['kind'],
          ext = v['ext'],
          bytes = v['bytes'],
          added = v['addedAt'];
      if (name is! String ||
          name.isEmpty ||
          kind is! String ||
          ext is! String ||
          types[ext]?.$1 != kind ||
          bytes is! int ||
          bytes <= 0 ||
          bytes > limit(kind) ||
          added is! int ||
          added < 0) {
        continue;
      }
      final base = p.basename(name);
      result[e.key as String] = {
        'name': String.fromCharCodes(base.runes.take(80)),
        'kind': kind,
        'ext': ext,
        'bytes': bytes,
        'addedAt': added
      };
    }
    return result;
  }
}

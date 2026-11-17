import 'dart:convert';
import 'dart:math';
import 'rule_model.dart';

class RuleImportReview {
  const RuleImportReview(this.rules, this.warnings, this.skipped);
  final List<Map<String, dynamic>> rules;

  /// Stable codes with a value for localized presentation.
  final Map<String, List<(String, String)>> warnings;
  final int skipped;
}

abstract final class RuleSharing {
  static String export(List<Map<String, dynamic>> rules) => jsonEncode({
        'format': 'airstream-rules',
        'version': 1,
        'rules': RuleSchema.sanitize(rules)
      });
  static RuleImportReview import(
    String source, {
    required List<Map<String, dynamic>> existing,
    Set<String> mediaIds = const {},
  }) {
    if (utf8.encode(source).length > 1024 * 1024) {
      throw const FormatException('fileTooLarge');
    }
    Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw const FormatException('malformedJson');
    }
    if (raw is! Map || raw['format'] != 'airstream-rules') {
      throw const FormatException('unknownFormat');
    }
    if (raw['version'] != 1) throw const FormatException('unknownVersion');
    final items = raw['rules'];
    if (items is! List) throw const FormatException('malformedJson');
    final names = {
      for (final r in existing)
        if (r['trigger']['type'] == 'manual') r['trigger']['webhook']
    };
    final ids = {for (final r in existing) r['id']};
    final random = Random.secure();
    final rules = <Map<String, dynamic>>[];
    final warnings = <String, List<(String, String)>>{};
    for (final item in items.take((50 - existing.length).clamp(0, 50))) {
      String id;
      do {
        id =
            'r_${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join()}';
      } while (!ids.add(id));
      final r = RuleSchema.sanitize([
        {if (item is Map) ...item, 'id': id, 'enabled': false}
      ]).single;
      final ww = <(String, String)>[];
      if (r['invalid'] == true) ww.add(('invalid', ''));
      final t = r['trigger'] as Map;
      final name = t['webhook'];
      if (t['type'] == 'manual' &&
          name is String &&
          name.isNotEmpty &&
          !names.add(name)) {
        t['webhook'] = '';
        ww.add(('webhookCollision', name));
      }
      if (t['type'] == 'obs.sceneChanged' && t['scene'] != '') {
        ww.add(('obsNames', t['scene'] as String));
      }
      for (final a in r['actions'] as List) {
        if (a['type'].toString().startsWith('obs.')) {
          for (final k in ['scene', 'source', 'input']) {
            if (a[k] is String && (a[k] as String).isNotEmpty) {
              ww.add(('obsNames', a[k] as String));
            }
          }
        }
        final media = a['mediaId'];
        if (media is String && media.isNotEmpty && !mediaIds.contains(media)) {
          ww.add(('missingMedia', media));
        }
        if (a['type'] == 'template.trigger') {
          ww.add(('templateName', a['name'] as String));
        }
      }
      rules.add(r);
      warnings[id] = ww;
    }
    return RuleImportReview(rules, warnings, items.length - rules.length);
  }
}

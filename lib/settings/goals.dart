const goalTypes = ['subs', 'bits', 'kicks', 'manual'];

abstract final class Goals {
  static Map<String, Map<String, dynamic>> sanitize(Object? raw) {
    final result = <String, Map<String, dynamic>>{};
    if (raw is! Map) return result;
    for (final entry in raw.entries) {
      if (result.length == 3) break;
      final id = entry.key;
      final v = entry.value;
      if (id is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(id) ||
          v is! Map) {
        continue;
      }
      final title = v['title'],
          type = v['type'],
          target = v['target'],
          current = v['current'];
      if (title is! String ||
          title.trim().isEmpty ||
          !goalTypes.contains(type) ||
          target is! int ||
          target < 1 ||
          target > 1000000 ||
          current is! int ||
          current < 0 ||
          current > 10000000) {
        continue;
      }
      final trimmed = title.trim();
      result[id] = {
        'title': String.fromCharCodes(trimmed.runes.take(60)),
        'type': type,
        'target': target,
        'current': current
      };
    }
    return result;
  }

  static Map<String, Map<String, dynamic>> advance(
          Map<String, Map<String, dynamic>> goals,
          Map<String, int> increments) =>
      {
        for (final e in sanitize(goals).entries)
          e.key: {
            ...e.value,
            'current': ((e.value['current'] as int) +
                    (increments[e.value['type']] ?? 0))
                .clamp(0, 10000000)
          },
      };

  static List<Map<String, Object?>> payload(Object? goals) => [
        for (final e in sanitize(goals).entries)
          {
            'id': e.key,
            ...e.value,
            'percent':
                ((e.value['current'] as int) / (e.value['target'] as int) * 100)
                    .clamp(0, 100),
            'reached': (e.value['current'] as int) >= (e.value['target'] as int)
          },
      ];
}

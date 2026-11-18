import 'rule_model.dart';

bool isPublicChatRule(Map<String, dynamic> rule) {
  final trigger = rule['trigger'] as Map;
  final roles = (rule['conditions'] as Map)['roles'] as List;
  return trigger['type'].toString().startsWith('chat.') &&
      (roles.isEmpty || roles.contains('everyone'));
}

final _chatTextPlaceholder = RegExp(r'\{(?:message|args|arg[1-9])\}');

/// Whether a public chat trigger can put a viewer's message or command text in OBS.
bool showsPublicChatText(Map<String, dynamic> rule) =>
    isPublicChatRule(rule) &&
    (rule['actions'] as List).any((action) {
      final text = action['text'];
      return action['type'] == 'obs.text' &&
          text is String &&
          _chatTextPlaceholder.hasMatch(text);
    });

/// Field paths used by the editor, without changing sanitizer semantics.
Map<String, String> ruleProblems(Map<String, dynamic> rule) {
  final problems = <String, String>{};
  void fields(Map map, Map<String, RuleField>? schema, String prefix) {
    if (schema == null) {
      problems[prefix] = 'invalid';
      return;
    }
    final countCodePoints =
        map['type'] == 'obs.text' || map['type'] == 'obs.filter';
    int length(String value) =>
        countCodePoints ? value.runes.length : value.length;
    for (final entry in schema.entries) {
      final f = entry.value,
          v = map[entry.key] ?? (entry.key == 'webhook' ? '' : null);
      final bad = f.numeric
          ? v is! num || !v.isFinite || v < f.min || v > f.max
          : f.choices != null
              ? !f.choices!.contains(v)
              : f.fallback is bool
                  ? v is! bool
                  : v is! String ||
                      length(v.trim()) < f.min ||
                      length(v.trim()) > f.max ||
                      (v.trim().isNotEmpty &&
                          f.pattern != null &&
                          !RegExp(f.pattern!).hasMatch(v.trim()));
      if (bad) problems['$prefix-${entry.key}'] = 'fieldError';
    }
    if (map['type'] == 'sound.play' &&
        map['source'] == 'library' &&
        map['mediaId'] == '') {
      problems['$prefix-mediaId'] = 'fieldError';
    }
    if (map['type'] == 'giveaway' &&
        map['op'] == 'start' &&
        map['keyword'] == '') {
      problems['$prefix-keyword'] = 'fieldError';
    }
  }

  final t = rule['trigger'] as Map;
  fields(t, RuleSchema.triggers[t['type']], 'trigger');
  final actions = rule['actions'] as List;
  for (var i = 0; i < actions.length; i++) {
    fields(
        actions[i] as Map, RuleSchema.actions[actions[i]['type']], 'action-$i');
  }
  for (final k in ['cooldownSeconds', 'userCooldownSeconds']) {
    final v = rule[k];
    if (v is! int || v < 0 || v > 3600) problems[k] = 'fieldError';
  }
  if ((rule['name'] as String).length > 60) problems['name'] = 'fieldError';
  final clean = RuleSchema.sanitize([
    {...rule, 'invalid': false}
  ]).single;
  if (clean['invalid'] == true && problems.isEmpty) {
    problems['rule'] = 'invalid';
  }
  return problems;
}

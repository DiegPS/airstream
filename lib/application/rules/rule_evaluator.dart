import 'package:airstream/services/speech/voice_command.dart';
import 'rule_events.dart';
import 'rule_model.dart';

class RuleContext {
  const RuleContext(
      {required this.now,
      this.streaming = false,
      this.enabled = true,
      this.cooldowns = const {},
      this.userCooldowns = const {}});
  final DateTime now;
  final bool streaming, enabled;
  final Map<String, DateTime> cooldowns, userCooldowns;
}

/// Null means matched; other results are stable machine-readable reasons.
String? evaluateRule(Map<String, dynamic> rule, RuleEvent event, RuleContext c,
    {bool manual = false}) {
  if (!c.enabled) return 'automationOff';
  if (event.chainDepth >= 3) return 'chainLimit';
  if (rule['invalid'] == true) return 'invalidRule';
  if (!manual && rule['enabled'] != true) return 'ruleDisabled';
  final t = rule['trigger'] as Map;
  if (!RuleSchema.triggers.containsKey(t['type'])) return 'invalidRule';
  if (!manual && t['type'] != event.type) return 'wrongTrigger';
  final conditions = rule['conditions'] as Map;
  final platforms = conditions['platforms'] as List,
      roles = conditions['roles'] as List;
  if (platforms.isNotEmpty && !platforms.contains(event.platform)) {
    return 'platform';
  }
  if (roles.isNotEmpty &&
      !roles.contains('everyone') &&
      !roles.any((r) =>
          event.author.roles.contains(r) ||
          (r == 'moderator' && event.author.roles.contains('owner')))) {
    return 'role';
  }
  if (conditions['onlyWhileStreaming'] == true && !c.streaming) {
    return 'notStreaming';
  }
  if (!manual) {
    final text = normalizeVoiceText(event.text),
        wanted = normalizeVoiceText(t['text'] as String? ?? '');
    if (t['type'] == 'chat.message' &&
        !switch (t['match']) {
          'startsWith' => text.startsWith(wanted),
          'equals' => text == wanted,
          _ => text.contains(wanted)
        }) {
      return 'textMismatch';
    }
    if (t['type'] == 'chat.command' && event.command != t['command']) {
      return 'textMismatch';
    }
    if (t['type'] == 'goal.reached' &&
        t['goalId'] != '' &&
        t['goalId'] != event.goalId) {
      return 'textMismatch';
    }
    if (t['type'] == 'obs.sceneChanged' &&
        t['scene'] != '' &&
        t['scene'] != event.scene) {
      return 'textMismatch';
    }
    if (t['type'] == 'support.superchat') {
      if (event.amount == null) return 'amountUnknown';
      if (t['currency'] != '' && t['currency'] != event.currency) {
        return 'currencyMismatch';
      }
      if (event.amount! < (t['minAmount'] as num)) return 'belowMinimum';
    }
    if (t.containsKey('min') && event.count < (t['min'] as num)) {
      return 'belowMinimum';
    }
    if (t.containsKey('minMonths') && event.months < (t['minMonths'] as num)) {
      return 'belowMinimum';
    }
    final last = c.cooldowns[rule['id']],
        user = c.userCooldowns['${rule['id']}:${event.userKey}'];
    if (last != null &&
        c.now.difference(last).inSeconds < (rule['cooldownSeconds'] as int)) {
      return 'cooldown';
    }
    if (user != null &&
        c.now.difference(user).inSeconds <
            (rule['userCooldownSeconds'] as int)) {
      return 'userCooldown';
    }
  }
  return null;
}

String resolveRuleText(
    String text, RuleEvent e, Map<String, int> counters, int max) {
  final args = e.args.split(RegExp(r'\s+'));
  final values = <String, String>{
    'user': e.author.name,
    'platform': e.platform,
    'message': e.text,
    'amount': e.presentationAmount,
    'count': '${e.count}',
    if (e.note != null) 'note': e.note!,
    if (e.position != null) 'position': '${e.position}',
    'months': '${e.months}',
    'scene': e.scene,
    'args': e.args,
    for (var i = 1; i <= 9; i++) 'arg$i': args.length >= i ? args[i - 1] : '',
    for (final c in counters.entries) 'counter.${c.key}': '${c.value}'
  };
  return String.fromCharCodes(text
      .replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) => values[m[1]] ?? m[0]!)
      .runes
      .take(max));
}

/// Evaluates every rule without allocating or mutating execution state.
Map<String, String?> evaluateRules(List<Map<String, dynamic>> rules,
        RuleEvent event, RuleContext context) =>
    {
      for (final rule in rules)
        rule['id'] as String: evaluateRule(rule, event, context),
    };

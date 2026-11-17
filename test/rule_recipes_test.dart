import 'package:flutter_test/flutter_test.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_recipes.dart';
import 'package:airstream/application/rules/rule_validation.dart';
import 'package:airstream/l10n/generated/app_localizations_en.dart';
import 'package:airstream/l10n/generated/app_localizations_es.dart';
import 'package:airstream/ui/widgets/rules_card.dart';
import 'rules_test_target.dart';

void main() {
  test(
      'recipes sanitize unchanged and match their sample events without effects',
      () async {
    final target = RulesTestTarget();
    final e = RuleEngine(target: target);
    for (final r in RuleRecipes.all) {
      expect(r['invalid'], false);
      expect(RuleSchema.sanitize([r]).single, r);
      final type = (r['trigger'] as Map)['type'] as String;
      final sample = e.sampleEvent(type);
      final event = type == 'chat.command'
          ? RuleEvent(
              type: type,
              platform: sample.platform,
              author: sample.author,
              text: (r['trigger'] as Map)['command'] as String)
          : sample;
      expect(e.simulate({...r, 'enabled': true}, event).matched, true);
    }
    expect(target.calls, isEmpty);
    expect(e.history, isEmpty);
    await e.dispose();
  });
  test('all exported reasons, triggers and actions have both translations', () {
    for (final l in [AppLocalizationsEn(), AppLocalizationsEs()]) {
      for (final code in [
        ...RuleEngine.reasonCodes,
        ...RuleSchema.triggers.keys,
        ...RuleSchema.actions.keys
      ]) {
        expect(ruleText(l, code), isNot('…'), reason: code);
      }
    }
  });
  test('field validation catches bounds, commands and repair clears invalid',
      () {
    final r = RuleSchema.newRule('chat.command', id: 'r');
    expect(ruleProblems(r), isEmpty);
    (r['trigger'] as Map)['command'] = 'bad';
    expect(ruleProblems(r), contains('trigger-command'));
    (r['trigger'] as Map)['command'] = '!fixed';
    r['invalid'] = true;
    expect(ruleProblems(r), isEmpty);
    r['cooldownSeconds'] = 3601;
    expect(ruleProblems(r), contains('cooldownSeconds'));
  });
  test('all declared trigger adapters are active', () {
    for (final t in RuleSchema.triggers.keys) {
      expect(RuleEngine.triggerAdapterActive(t), isTrue);
    }
  });
}

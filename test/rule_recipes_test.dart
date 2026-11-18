import 'package:flutter_test/flutter_test.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_recipes.dart';
import 'package:airstream/application/rules/rule_sharing.dart';
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
  test('counter on screen recipe increments muertes for moderators', () {
    final recipe = RuleRecipes.all.singleWhere((r) => r['id'] == 'recipe_7');
    expect(recipe['trigger'], {'type': 'chat.command', 'command': '!muerte'});
    expect(recipe['conditions']['roles'], ['moderator']);
    expect(recipe['enabled'], isFalse);
    expect(recipe['actions'], [
      {
        'id': 'a_0',
        'type': 'counter',
        'name': 'muertes',
        'op': 'add',
        'value': 1
      },
      {
        'id': 'a_1',
        'type': 'obs.text',
        'source': 'Muertes',
        'text': 'Muertes: {counter.muertes}'
      },
    ]);
    expect(ruleProblems(recipe), isEmpty);
  });

  test('Discord recipe round trips and requires the webhook URL', () {
    final recipe = RuleRecipes.all.singleWhere((r) => r['id'] == 'recipe_8');
    expect(recipe['trigger'], {'type': 'obs.streamStarted'});
    expect(recipe['enabled'], isFalse);
    expect(recipe['actions'], [
      {
        'id': 'a_0',
        'type': 'http.request',
        'method': 'post',
        'url': '',
        'contentType': 'json',
        'body': '{"content":"¡Estoy en directo!"}',
      },
    ]);
    final review =
        RuleSharing.import(RuleSharing.export([recipe]), existing: []);
    expect(review.rules.single, {...recipe, 'id': review.rules.single['id']});
    expect(
        ruleProblems(review.rules.single), {'action-0-url': 'invalidHttpUrl'});
  });

  test('public chat text warning tracks viewer text placeholders only', () {
    bool warns(String trigger, List<String> roles, String text,
        {String actionType = 'obs.text'}) {
      final rule = RuleSchema.newRule(trigger, id: 'r');
      rule['conditions']['roles'] = roles;
      rule['actions'] = [
        {'type': actionType, 'source': 'Text', 'text': text}
      ];
      return showsPublicChatText(rule);
    }

    for (final placeholder in [
      'message',
      'args',
      for (var n = 1; n <= 9; n++) 'arg$n'
    ]) {
      expect(
          warns('chat.command', ['everyone'], 'Text: {$placeholder}'), isTrue);
      expect(warns('chat.command', ['moderator'], '{$placeholder}'), isFalse);
      expect(
          warns('support.superchat', ['everyone'], '{$placeholder}'), isFalse);
    }
    expect(warns('chat.message', [], '{message}'), isTrue);
    expect(
        warns('chat.command', ['everyone'],
            'Counter {counter.count} {arg10} message'),
        isFalse);
    expect(
        warns('chat.command', ['everyone'], '{message}', actionType: 'tts.say'),
        isFalse);
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

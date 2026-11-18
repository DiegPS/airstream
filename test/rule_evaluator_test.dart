import 'package:flutter_test/flutter_test.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_evaluator.dart';

void main() {
  test('stored rules discard only filters their trigger cannot evaluate', () {
    for (final (type, platform, roles) in [
      ('poll.ended', false, false),
      ('clock.ended', false, false),
      ('obs.sceneChanged', false, false),
      ('interval', false, false),
      ('manual', false, false),
      ('giveaway.winner', true, false),
      ('support.raid', true, false),
      ('support.kicks', true, false),
      ('support.bits', true, true),
      ('chat.message', true, true),
      ('queue.joined', true, true),
    ]) {
      final rule = RuleSchema.sanitize([
        {
          ...RuleSchema.newRule(type, id: 'test'),
          'enabled': true,
          'trigger': {
            ...RuleSchema.newRule(type, id: 'test')['trigger'] as Map,
            if (type == 'chat.message') 'text': 'hello' else 'text': 'stale'
          },
          'conditions': {
            'platforms': ['twitch'],
            'roles': ['member'],
            'onlyWhileStreaming': true
          },
        }
      ]).single;
      expect(
          rule['conditions'],
          {
            'platforms': platform ? ['twitch'] : [],
            'roles': roles ? ['member'] : [],
            'onlyWhileStreaming': true,
          },
          reason: type);
      if (!platform) {
        expect((rule['trigger'] as Map).containsKey('text'), isFalse);
        expect(
            evaluateRule(rule, RuleEvent(type: type),
                RuleContext(now: DateTime.utc(2026), streaming: true)),
            isNull,
            reason: type);
      }
    }
  });

  Map<String, dynamic> rule(String type,
          {Map<String, dynamic> params = const {},
          Map<String, dynamic> conditions = const {}}) =>
      RuleSchema.sanitize([
        {
          ...RuleSchema.newRule(type, id: 'r'),
          'enabled': true,
          'cooldownSeconds': 0,
          'trigger': {
            'type': type,
            ...(RuleSchema.newRule(type, id: 'r')['trigger'] as Map),
            ...params
          },
          'conditions': conditions
        }
      ]).single;
  final now = DateTime.utc(2026);
  RuleContext context(
          {bool enabled = true,
          bool streaming = true,
          Map<String, DateTime> cooldowns = const {},
          Map<String, DateTime> users = const {}}) =>
      RuleContext(
          now: now,
          enabled: enabled,
          streaming: streaming,
          cooldowns: cooldowns,
          userCooldowns: users);
  for (final type in RuleSchema.triggers.keys) {
    test('$type matches a representative event and rejects a different trigger',
        () {
      final r = rule(type);
      final e = RuleEvent(
          type: type,
          text: type == 'chat.command' ? '!hello a b' : 'hello',
          amount: 5,
          count: 500,
          months: 12,
          scene: 'Gameplay',
          goalId: 'goal');
      expect(evaluateRule(r, e, context()), null);
      expect(
          evaluateRule(
              r,
              RuleEvent(type: type == 'manual' ? 'chat.message' : 'manual'),
              context()),
          'wrongTrigger');
      if ((r['trigger'] as Map).containsKey('min')) {
        final rr = {
          ...r,
          'trigger': {...(r['trigger'] as Map), 'min': 501}
        };
        expect(evaluateRule(rr, e, context()), 'belowMinimum');
      }
      if (type == 'support.membership') {
        expect(
            evaluateRule({
              ...r,
              'trigger': {'type': type, 'minMonths': 13}
            }, e, context()),
            'belowMinimum');
      }
    });
  }
  test('all evaluator reasons are stable and successful conditions match', () {
    final r =
        rule('chat.message', params: {'text': 'hola mundo', 'match': 'equals'});
    const event = RuleEvent(
        type: 'chat.message',
        text: '¡HÓLA, mundo!',
        platform: 'twitch',
        author: RuleAuthor(id: 'u', roles: ['owner']));
    expect(evaluateRule(r, event, context()), null);
    expect(evaluateRule(r, event, context(enabled: false)), 'automationOff');
    expect(
        evaluateRule({...r, 'invalid': true}, event, context()), 'invalidRule');
    expect(evaluateRule({...r, 'enabled': false}, event, context()),
        'ruleDisabled');
    expect(evaluateRule(r, const RuleEvent(type: 'manual'), context()),
        'wrongTrigger');
    expect(
        evaluateRule(
            r, const RuleEvent(type: 'chat.message', text: 'no'), context()),
        'textMismatch');
    expect(
        evaluateRule(
            r, const RuleEvent(type: 'chat.message', chainDepth: 3), context()),
        'chainLimit');
    for (final condition in [
      {
        'platforms': ['youtube']
      },
      {
        'roles': ['vip']
      },
      {'onlyWhileStreaming': true}
    ]) {
      final rr = {
        ...r,
        'conditions': {...(r['conditions'] as Map), ...condition}
      };
      expect(
          evaluateRule(rr, event, context(streaming: false)),
          condition.containsKey('platforms')
              ? 'platform'
              : condition.containsKey('roles')
                  ? 'role'
                  : 'notStreaming');
    }
    expect(
        evaluateRule({
          ...r,
          'conditions': {
            'platforms': [],
            'roles': ['moderator'],
            'onlyWhileStreaming': false
          }
        }, event, context()),
        null);
    expect(
        evaluateRule({...r, 'cooldownSeconds': 30}, event,
            context(cooldowns: {'r': now})),
        'cooldown');
    expect(
        evaluateRule({...r, 'userCooldownSeconds': 30}, event,
            context(users: {'r:twitch:u': now})),
        'userCooldown');
    final support =
        rule('support.superchat', params: {'minAmount': 5, 'currency': 'USD'});
    expect(
        evaluateRule(
            support, const RuleEvent(type: 'support.superchat'), context()),
        'amountUnknown');
    expect(
        evaluateRule(
            support,
            const RuleEvent(
                type: 'support.superchat', amount: 10, currency: 'EUR'),
            context()),
        'currencyMismatch');
    expect(
        evaluateRule(
            support,
            const RuleEvent(
                type: 'support.superchat', amount: 2, currency: 'USD'),
            context()),
        'belowMinimum');
    expect(
        evaluateRule(
            support,
            const RuleEvent(
                type: 'support.superchat', amount: 5, currency: 'USD'),
            context()),
        null);
    expect(
        evaluateRule(
            rule('support.superchat'),
            const RuleEvent(
                type: 'support.superchat', amount: 5, currency: r'MX$'),
            context()),
        null);
  });
  for (final data in [
    (r'$5.00', 5, r'$'),
    (r'MX$100.00', 100, r'MX$'),
    ('€2,00', 2, '€'),
    ('1.234,50 €', 1234.5, '€'),
    ('¥500', 500, '¥')
  ]) {
    test('parses ${data.$1}', () {
      final v = parseRuleAmount(data.$1);
      expect(v.amount, data.$2);
      expect(v.currency, data.$3);
    });
  }
  test('unparseable money and commands and plain text placeholders', () {
    expect(parseRuleAmount('garbage').amount, null);
    const e = RuleEvent(
        type: 'chat.command',
        text: '!HELLO one two',
        author: RuleAuthor(name: '<Alex>'));
    expect(e.command, '!hello');
    expect(e.args, 'one two');
    expect(evaluateRule(rule('chat.command'), e, context()), null);
    expect(
        resolveRuleText('{user} {args} {arg2} {counter.deaths} {unknown}', e,
            {'deaths': 4}, 200),
        '<Alex> one two two 4 {unknown}');
  });
}

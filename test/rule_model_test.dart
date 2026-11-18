import 'package:flutter_test/flutter_test.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_validation.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';

void main() {
  for (final type in RuleSchema.triggers.keys) {
    test('sanitizes trigger $type and drops unknown keys', () {
      final r = RuleSchema.newRule(type, id: 'test');
      expect(r['invalid'], false);
      final t = r['trigger'] as Map<String, dynamic>;
      t['unknown'] = 'drop';
      expect(
          (RuleSchema.sanitize([r]).single['trigger'] as Map)
              .containsKey('unknown'),
          false);
      for (final field in RuleSchema.triggers[type]!.entries) {
        final bad = {
          ...t,
          field.key: field.value.numeric
              ? double.nan
              : (field.value.min > 0 ? '' : Object())
        };
        final sanitized = RuleSchema.sanitize([
          {...r, 'enabled': true, 'trigger': bad}
        ]).single;
        if (field.value.numeric ||
            field.value.min > 0 ||
            field.value.choices != null) {
          expect(sanitized['invalid'], true, reason: field.key);
        }
      }
    });
  }
  for (final type in RuleSchema.actions.keys) {
    test('sanitizes action $type and validates parameters', () {
      final params = {
        for (final e in RuleSchema.actions[type]!.entries)
          e.key: e.value.fallback
      };
      if (type == 'giveaway') params['keyword'] = 'join';
      final action = {'id': 'a', 'type': type, ...params};
      final r = {
        ...RuleSchema.newRule('manual', id: 'test'),
        'enabled': true,
        'actions': [action]
      };
      final clean = RuleSchema.sanitize([r]).single;
      expect(clean['invalid'], false);
      expect(clean['actions'], [action]);
      for (final field in RuleSchema.actions[type]!.entries) {
        if (!field.value.numeric &&
            field.value.min == 0 &&
            field.value.choices == null) {
          continue;
        }
        final bad = {
          ...action,
          field.key: field.value.numeric ? double.infinity : ''
        };
        expect(
            RuleSchema.sanitize([
              {
                ...r,
                'actions': [bad]
              }
            ]).single['invalid'],
            true,
            reason: field.key);
      }
    });
  }
  test('volume sanitization and editor validation use the mode-specific range',
      () {
    for (final (mode, max) in [('set', 26), ('change', 100)]) {
      final action = {
        'id': 'a',
        'type': 'obs.volume',
        'input': 'Mic',
        'mode': mode,
        'db': 101
      };
      final rule = RuleSchema.newRule('manual', id: 'test')
        ..['actions'] = [action];
      expect(ruleProblems(rule), {'action-0-db': 'fieldError'});
      final clean = RuleSchema.sanitize([rule]).single;
      expect(clean['actions'].single['db'], max);
      expect(ruleProblems(clean), isEmpty);
      action['db'] = -101;
      expect(ruleProblems(rule), {'action-0-db': 'fieldError'});
      expect(RuleSchema.sanitize([rule]).single['actions'].single['db'], -100);
    }
  });

  test('HTTP templates and URL lengths are bounded without requiring a URL',
      () {
    final url = 'https://example.invalid/${'a' * 600}';
    final body = '🎮' * 2001;
    final action = {
      'id': 'a',
      'type': 'http.request',
      'method': 'post',
      'url': url,
      'contentType': 'json',
      'body': body,
    };
    final rule = RuleSchema.newRule('manual', id: 'test')
      ..['actions'] = [action];
    expect(ruleProblems(rule).keys, ['action-0-url', 'action-0-body']);
    final clean = RuleSchema.sanitize([rule]).single;
    expect(clean['actions'].single['url'], url.substring(0, 500));
    expect(clean['actions'].single['body'], '🎮' * 2000);
    expect(clean['invalid'], isFalse);
    for (final invalid in ['', 'ftp://example.invalid', 'https:///missing']) {
      action['url'] = invalid;
      action['body'] = '';
      expect(RuleSchema.sanitize([rule]).single['invalid'], isFalse);
      expect(ruleProblems(rule), {'action-0-url': 'invalidHttpUrl'});
    }
  });

  test('stream control is an editor error only for public chat rules', () {
    for (final (trigger, roles, blocked) in [
      ('chat.command', <String>[], true),
      ('chat.firstMessage', ['everyone', 'moderator'], true),
      ('chat.message', ['moderator'], false),
      ('manual', <String>[], false),
    ]) {
      final rule = RuleSchema.newRule(trigger, id: 'test')
        ..['actions'] = [
          {'id': 'a', 'type': 'obs.stream', 'state': 'start'}
        ];
      rule['conditions']['roles'] = roles;
      expect(ruleProblems(rule),
          blocked ? {'action-0-state': 'publicStreamControl'} : isEmpty);
    }
  });
  test('clamps OBS text and filter fields by Unicode code points', () {
    final source = 'S' * 100;
    final filter = 'F' * 100;
    final text = '\u{1F3AE}' * 500;
    final raw = {
      ...RuleSchema.newRule('manual', id: 'test'),
      'actions': [
        {
          'id': 'a',
          'type': 'obs.text',
          'source': '${source}X',
          'text': '${text}X'
        },
        {'id': 'b', 'type': 'obs.text', 'source': 'Caption', 'text': ''},
        {
          'id': 'c',
          'type': 'obs.filter',
          'source': '${source}X',
          'filter': '${filter}X',
          'state': 'toggle'
        },
      ],
    };
    final sanitized = RuleSchema.sanitize([raw]).single;
    expect(sanitized['invalid'], isFalse);
    expect(sanitized['actions'], [
      {'id': 'a', 'type': 'obs.text', 'source': source, 'text': text},
      {'id': 'b', 'type': 'obs.text', 'source': 'Caption', 'text': ''},
      {
        'id': 'c',
        'type': 'obs.filter',
        'source': source,
        'filter': filter,
        'state': 'toggle'
      },
    ]);
    expect(
        ruleProblems(raw).keys,
        unorderedEquals([
          'action-0-source',
          'action-0-text',
          'action-2-source',
          'action-2-filter'
        ]));
    expect(ruleProblems(sanitized), isEmpty);
  });

  test('saved OBS source and mute actions still round trip unchanged', () {
    final saved = {
      ...RuleSchema.newRule('chat.command', id: 'legacy'),
      'enabled': true,
      'actions': [
        {
          'id': 'a',
          'type': 'obs.source',
          'scene': '',
          'source': 'S' * 150,
          'visible': 'toggle'
        },
        {'id': 'b', 'type': 'obs.mute', 'input': 'M' * 150, 'state': 'unmute'},
      ],
    };
    final settings = SettingsModel(rules: [saved]);
    expect(
        SettingsModel.fromJsonString(settings.toJsonString()).rules, [saved]);
  });

  test('clamps limits, retains invalid definitions, caps rules and actions',
      () {
    final r = {
      ...RuleSchema.newRule('interval', id: 'test'),
      'enabled': true,
      'cooldownSeconds': 9999,
      'userCooldownSeconds': -10,
      'trigger': {'type': 'interval', 'minutes': 999},
      'actions': List.generate(
          25, (i) => {'id': 'a$i', 'type': 'wait', 'seconds': 999})
    };
    final v = RuleSchema.sanitize([r]).single;
    expect(v['cooldownSeconds'], 3600);
    expect(v['userCooldownSeconds'], 0);
    expect((v['trigger'] as Map)['minutes'], 240);
    expect(v['actions'], hasLength(20));
    expect(RuleSchema.sanitize(List.generate(70, (i) => {...r, 'id': 'r$i'})),
        hasLength(50));
    for (final bad in [
      {
        'trigger': {'type': 'future'}
      },
      {
        'actions': [
          {'id': 'x', 'type': 'future'}
        ]
      }
    ]) {
      final v = RuleSchema.sanitize([
        {...r, ...bad}
      ]).single;
      expect(v['enabled'], false);
      expect(v['invalid'], true);
      expect(RuleSchema.sanitize([v]).single['invalid'], true);
    }
  });
  test('round trip, profiles and factory reset preserve automation', () {
    final s = SettingsModel(
        rulesEnabled: false,
        rules: [RuleSchema.newRule('manual', id: 'one')],
        ruleCounters: {'count': 2000000000, 'bad name': 1});
    final loaded = SettingsModel.fromJsonString(s.toJsonString());
    expect(loaded.ruleCounters, {'count': 1000000000});
    expect(SettingsModel.fromJsonString(loaded.toJsonString()).toJson(),
        loaded.toJson());
    final captured = SettingsProfiles.capture(loaded);
    for (final key in ['rules', 'rulesEnabled', 'ruleCounters']) {
      expect(captured.containsKey(key), false);
    }
    final reset = SettingsProfiles.resetToDefaults(loaded);
    expect(reset.rules, loaded.rules);
    expect(reset.rulesEnabled, false);
    expect(reset.ruleCounters, loaded.ruleCounters);
    final applied = SettingsProfiles.apply(
        loaded, {'rules': [], 'rulesEnabled': true, 'ruleCounters': {}});
    expect(applied.rules, loaded.rules);
    expect(applied.rulesEnabled, false);
    expect(applied.ruleCounters, loaded.ruleCounters);
  });
}

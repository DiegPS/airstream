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
      expect(RuleSchema.sanitize([r]).single['invalid'], false);
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

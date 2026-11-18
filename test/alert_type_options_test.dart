import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizes types, durations and entrances without trusting nested data',
      () {
    expect(
        AlertTypeOptions.sanitize({
          'raid': {'seconds': 12.4, 'animation': 'slide-up', 'extra': true},
          'bits': {'seconds': 3, 'animation': 'zoom'},
          'gift': {'seconds': 20, 'animation': 'pop'},
          'unknown': {'seconds': 7},
        }),
        {
          'raid': {'seconds': 12, 'animation': 'slide-up'},
          'bits': {'seconds': 3, 'animation': 'zoom'},
          'gift': {'seconds': 20, 'animation': 'pop'},
        });
    for (final bad in [2, 21, '7', double.nan, double.infinity, null, [], {}]) {
      expect(
          AlertTypeOptions.sanitize({
            'raid': {'seconds': bad, 'animation': 'unknown'},
            'bits': {},
            'membership': [7],
          }),
          isEmpty);
    }
    for (final junk in [
      null,
      [],
      'garbage',
      42,
      {
        'raid': {42: []}
      }
    ]) {
      expect(AlertTypeOptions.sanitize(junk), isEmpty);
      expect(
          SettingsModel.fromJson({'alertTypeOptions': junk}).alertTypeOptions,
          isEmpty);
    }
    for (final animation in ['pop', 'slide-up', 'slide-down', 'fade', 'zoom']) {
      expect(
          AlertTypeOptions.sanitize({
            'raid': {'animation': animation}
          }),
          {
            'raid': {'animation': animation}
          });
    }
  });

  test('updates, keeps and removes overrides and survives codec round trips',
      () {
    var s = const SettingsModel();
    expect(AlertTypeOptions.of(s, 'raid').seconds, 0);
    expect(AlertTypeOptions.of(s, 'raid').animation, '');
    s = AlertTypeOptions.withOption(s, 'raid', seconds: 12, animation: 'fade');
    s = AlertTypeOptions.withOption(s, 'bits', animation: 'zoom');
    s = AlertTypeOptions.withOption(s, 'raid', seconds: 15);
    expect(AlertTypeOptions.of(s, 'raid').animation, 'fade');
    expect(AlertTypeOptions.of(s, 'raid').seconds, 15);
    s = AlertTypeOptions.withOption(s, 'raid', animation: '');
    expect(s.alertTypeOptions['raid'], {'seconds': 15});
    final restored = SettingsModel.fromJsonString(s.toJsonString());
    expect(restored.alertTypeOptions, s.alertTypeOptions);
    s = AlertTypeOptions.withOption(s, 'raid', seconds: 0);
    expect(s.alertTypeOptions.containsKey('raid'), isFalse);
    s = AlertTypeOptions.withOption(s, 'bits', animation: '');
    expect(s.alertTypeOptions, isEmpty);
    expect(
        AlertTypeOptions.withOption(s, 'unknown', seconds: 7).alertTypeOptions,
        isEmpty);
    expect(
        AlertTypeOptions.withOption(s, 'raid', seconds: 21, animation: 'bad')
            .alertTypeOptions,
        isEmpty);
  });
  test('highest reached tier overrides only the fields it sets', () {
    final options = AlertTypeOptions.sanitize({
      'superchat': {
        'seconds': 8,
        'animation': 'pop',
        'sound': 'custom',
        'soundPath': 'private.wav',
        'tiers': [
          {'from': 50, 'seconds': 12, 'mediaAudio': false},
          {'from': 5.5, 'animation': 'fade', 'sound': 'coin'},
          {'from': 50, 'seconds': 20},
        ],
      }
    })['superchat']!;
    final base = {...options}..remove('tiers');
    expect(AlertTypeOptions.resolve(options, null), base);
    expect(AlertTypeOptions.resolve(options, 5.49), base);
    expect(AlertTypeOptions.resolve(options, 5.5),
        {...base, 'animation': 'fade', 'sound': 'coin'});
    expect(AlertTypeOptions.resolve(options, 49.99),
        {...base, 'animation': 'fade', 'sound': 'coin'});
    expect(AlertTypeOptions.resolve(options, 50),
        {...base, 'seconds': 12, 'mediaAudio': false});
    expect(AlertTypeOptions.resolve(options, 100),
        {...base, 'seconds': 12, 'mediaAudio': false});
    expect(options['seconds'], 8);
  });

  test('invalid rows are dropped before limiting tiers to five', () {
    final settings = SettingsModel.fromJson({
      'alertTypeOptions': {
        'bits': {
          'tiers': [
            false,
            {},
            {'from': '9'},
            {'from': 0},
            {'from': -5},
            {'from': double.nan},
            {'from': double.infinity},
            {'from': 1, 'seconds': 30, 'sound': 'unknown'},
            for (var i = 2; i <= 7; i++) {'from': i, 'seconds': 12},
          ],
        },
        'raid': {
          'tiers': [
            {'from': 1}
          ],
        },
      }
    });
    final tiers = AlertTypeOptions.tiers(settings.alertTypeOptions['bits']);
    expect(tiers.map((row) => row['from']), [1, 2, 3, 4, 5]);
    expect(tiers.first, {'from': 1});
    expect(settings.alertTypeOptions.keys, ['bits']);
    expect(
        SettingsModel.fromJsonString(settings.toJsonString()).alertTypeOptions,
        settings.alertTypeOptions);
  });

  test('sound options sanitize paths and preserve existing overrides', () {
    for (final sound in ['chime', 'coin', 'fanfare', 'custom']) {
      final sanitized = AlertTypeOptions.sanitize({
        'raid': {'sound': sound, 'soundPath': 'C:/private.wav', 'seconds': 8},
      })['raid']!;
      expect(sanitized['sound'], sound);
      expect(sanitized.containsKey('soundPath'), sound == 'custom');
    }
    for (final path in ['', 12, 'x' * 1025]) {
      expect(
          AlertTypeOptions.sanitize({
            'raid': {'sound': 'custom', 'soundPath': path}
          })['raid'],
          {'sound': 'custom'});
    }
    expect(
        AlertTypeOptions.sanitize({
          'raid': {'sound': 'unknown', 'soundPath': 'x'}
        }),
        isEmpty);
    var s = AlertTypeOptions.withOption(const SettingsModel(), 'raid',
        seconds: 9, sound: 'custom', soundPath: 'private.wav');
    expect(AlertTypeOptions.of(s, 'raid').soundPath, 'private.wav');
    s = AlertTypeOptions.withOption(s, 'raid', sound: 'coin');
    expect(s.alertTypeOptions['raid'], {'seconds': 9, 'sound': 'coin'});
    s = AlertTypeOptions.withOption(s, 'raid',
        sound: '', soundPath: 'ignored.wav');
    expect(s.alertTypeOptions['raid'], {'seconds': 9});
    expect(AlertTypeOptions.of(s, 'raid').sound, '');
    expect(AlertTypeOptions.of(s, 'raid').soundPath, '');
  });
}

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

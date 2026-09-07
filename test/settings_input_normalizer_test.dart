import 'package:airstream/settings/settings_input_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsInputNormalizer', () {
    test('normalizes plain, mentioned, and URL channel values', () {
      expect(SettingsInputNormalizer.platformChannel(' creator '), 'creator');
      expect(SettingsInputNormalizer.platformChannel('@creator'), 'creator');
      expect(
        SettingsInputNormalizer.platformChannel(
          'https://kick.com/category/creator/',
        ),
        'creator',
      );
      expect(SettingsInputNormalizer.platformChannel(''), '');
    });

    test('normalizes valid colors and preserves the safe fallback', () {
      expect(
        SettingsInputNormalizer.hexColor(' ab12ef ', fallback: '#000000'),
        '#AB12EF',
      );
      expect(
        SettingsInputNormalizer.hexColor('#invalid', fallback: '#aabbcc'),
        '#AABBCC',
      );
    });

    test('parses filters across separators and deduplicates case', () {
      expect(
        SettingsInputNormalizer.filterList(
          ' Alice, bob\nALICE;  Carol \r\n',
        ),
        ['Alice', 'bob', 'Carol'],
      );
      expect(
        SettingsInputNormalizer.formatFilterList(['Alice', 'bob']),
        'Alice\nbob',
      );
    });

    test('compares lists by value and order', () {
      expect(SettingsInputNormalizer.listsEqual(['a'], ['a']), isTrue);
      expect(SettingsInputNormalizer.listsEqual(['a'], ['A']), isFalse);
      expect(
          SettingsInputNormalizer.listsEqual(['a', 'b'], ['b', 'a']), isFalse);
      expect(SettingsInputNormalizer.listsEqual([], []), isTrue);
    });

    test('accepts distinct explicit YouTube video URLs only', () {
      const first = 'https://youtube.com/watch?v=dQw4w9WgXcQ';
      const second = 'https://youtu.be/abcdefghijk';
      expect(SettingsInputNormalizer.youtubeVideoId(first), 'dQw4w9WgXcQ');
      expect(
        SettingsInputNormalizer.distinctYoutubeVideoUrls(first, second),
        isTrue,
      );
      expect(
        SettingsInputNormalizer.distinctYoutubeVideoUrls(first, first),
        isFalse,
      );
      expect(
        SettingsInputNormalizer.distinctYoutubeVideoUrls('@channel', second),
        isFalse,
      );
    });

    test('validates and safely falls back from overlay ports', () {
      expect(SettingsInputNormalizer.isValidOverlayPort('65535'), isTrue);
      expect(SettingsInputNormalizer.isValidOverlayPort('0'), isFalse);
      expect(SettingsInputNormalizer.isValidOverlayPort('65536'), isFalse);
      expect(
        SettingsInputNormalizer.overlayPort('8080', fallback: 7777),
        8080,
      );
      expect(
        SettingsInputNormalizer.overlayPort('invalid', fallback: 7777),
        7777,
      );
    });
  });
}

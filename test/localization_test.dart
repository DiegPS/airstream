import 'dart:convert';
import 'dart:io';

import 'package:airstream/l10n/generated/app_localizations_en.dart';
import 'package:airstream/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Spanish catalogs expose exactly the same messages', () {
    final english = _messages('lib/l10n/app_en.arb');
    final spanish = _messages('lib/l10n/app_es.arb');

    expect(spanish.keys.toSet(), english.keys.toSet());
  });

  test('Spanish UI does not retain known English interface terminology', () {
    final spanish = _messages('lib/l10n/app_es.arb');
    final forbidden = RegExp(
      r'\b(stream|bitrate|assets?|click-through|browser source|payload|overlay|screen share|frames?|padding|slug|handle|chroma key)\b',
      caseSensitive: false,
    );

    for (final entry in spanish.entries) {
      expect(
        entry.value,
        isNot(matches(forbidden)),
        reason: 'Unexpected English UI term in ${entry.key}',
      );
    }
  });

  test('localized language, layout, animation and status labels stay paired',
      () {
    final en = AppLocalizationsEn();
    final es = AppLocalizationsEs();

    expect(en.languageJapanese, 'Japanese');
    expect(es.languageJapanese, 'Japonés');
    expect(en.alignmentLeft, 'Left');
    expect(es.alignmentLeft, 'Izquierda');
    expect(en.animationFadeIn, 'Fade in');
    expect(es.animationFadeIn, 'Aparecer gradualmente');
    expect(en.obsStatusConnected, 'OBS: Connected');
    expect(es.obsStatusConnected, 'OBS: Conectado');
  });
}

Map<String, String> _messages(String path) {
  final decoded =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@')) entry.key: entry.value as String,
  };
}

import 'dart:convert';

import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes a formally versioned settings document', () {
    final encoded = SettingsDocumentCodec.encode(
      const SettingsModel(appLanguageCode: 'es'),
    );
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    expect(json['schemaVersion'], currentSettingsSchemaVersion);
    expect(json['settings'], containsPair('appLanguageCode', 'es'));
  });

  test('migrates the legacy unversioned document', () {
    final decoded = SettingsDocumentCodec.decode(
      jsonEncode({'appLanguageCode': 'es'}),
    );
    expect(decoded.settings.appLanguageCode, 'es');
    expect(decoded.requiresRewrite, isTrue);
  });

  test('refuses settings from an unsupported future schema', () {
    expect(
      () => SettingsDocumentCodec.decode(
        jsonEncode({'schemaVersion': 99, 'settings': {}}),
      ),
      throwsFormatException,
    );
  });
}

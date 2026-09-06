import 'dart:convert';

import 'package:airstream/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps a recoverable backup when committing new settings', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsRepository.settingsKey: jsonEncode({'old': 1}),
    });
    final repository = SharedPreferencesSettingsRepository();

    await repository.write(jsonEncode({'new': 2}));

    expect(jsonDecode((await repository.read())!), {'new': 2});
    expect(jsonDecode((await repository.readBackup())!), {'old': 1});
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(SharedPreferencesSettingsRepository.stagingKey),
      isNull,
    );
  });

  test('recovers an interrupted staged write when primary is absent', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsRepository.stagingKey:
          jsonEncode({'safe': true}),
    });
    final repository = SharedPreferencesSettingsRepository();

    expect(jsonDecode((await repository.read())!), {'safe': true});
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(SharedPreferencesSettingsRepository.settingsKey),
      isNotNull,
    );
  });

  test('refuses to stage malformed JSON', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesSettingsRepository();
    await expectLater(repository.write('{broken'), throwsFormatException);
  });

  test('never copies a legacy plaintext password into the backup', () async {
    SharedPreferences.setMockInitialValues({
      SharedPreferencesSettingsRepository.settingsKey:
          jsonEncode({'obsPassword': 'legacy-secret'}),
    });
    final repository = SharedPreferencesSettingsRepository();

    await repository.write(jsonEncode({'schemaVersion': 1, 'settings': {}}));

    expect(await repository.readBackup(), isNull);
  });
}

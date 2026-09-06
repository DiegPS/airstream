import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsRepository {
  Future<String?> read();

  Future<void> write(String json);
}

abstract interface class RecoverableSettingsRepository
    implements SettingsRepository {
  Future<String?> readBackup();
}

class SharedPreferencesSettingsRepository
    implements RecoverableSettingsRepository {
  static const settingsKey = 'AIRSTREAM_SETTINGS';
  static const backupKey = 'AIRSTREAM_SETTINGS_BACKUP';
  static const stagingKey = 'AIRSTREAM_SETTINGS_STAGING';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final primary = preferences.getString(settingsKey);
    if (primary != null) return primary;
    final staging = preferences.getString(stagingKey);
    if (staging != null) {
      await preferences.setString(settingsKey, staging);
      await preferences.remove(stagingKey);
      return staging;
    }
    return preferences.getString(backupKey);
  }

  @override
  Future<String?> readBackup() async =>
      (await SharedPreferences.getInstance()).getString(backupKey);

  @override
  Future<void> write(String json) async {
    final preferences = await SharedPreferences.getInstance();
    jsonDecode(json); // Never replace a valid document with malformed JSON.
    if (!await preferences.setString(stagingKey, json)) {
      throw StateError('Could not stage settings.');
    }
    final previous = preferences.getString(settingsKey);
    if (previous != null) {
      try {
        final decodedPrevious = jsonDecode(previous);
        if (_containsSensitiveSettings(decodedPrevious)) {
          await preferences.remove(backupKey);
        } else {
          if (!await preferences.setString(backupKey, previous)) {
            throw StateError('Could not back up settings.');
          }
        }
      } on FormatException {
        // Preserve the last known-good backup instead of copying corruption.
      }
    }
    if (!await preferences.setString(settingsKey, json)) {
      throw StateError('Could not commit settings.');
    }
    await preferences.remove(stagingKey);
  }

  bool _containsSensitiveSettings(Object? document) {
    if (document is! Map) return false;
    if (document.containsKey('obsPassword')) return true;
    final settings = document['settings'];
    return settings is Map && settings.containsKey('obsPassword');
  }
}

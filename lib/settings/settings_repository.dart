import 'dart:convert';

import 'package:airstream/services/app_logger.dart';
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
    final previous = {
      for (final key in [settingsKey, backupKey, stagingKey])
        key: preferences.getString(key),
    };
    try {
      if (!await preferences.setString(stagingKey, json)) {
        throw StateError('Could not stage settings.');
      }
      final primary = previous[settingsKey];
      if (primary != null) {
        try {
          final decoded = jsonDecode(primary);
          final saved = _containsSensitiveSettings(decoded)
              ? await preferences.remove(backupKey)
              : await preferences.setString(backupKey, primary);
          if (!saved) {
            throw StateError('Could not back up settings.');
          }
        } on FormatException {
          // Preserve the last known-good backup instead of copying corruption.
        }
      }
      if (!await preferences.setString(settingsKey, json)) {
        throw StateError('Could not commit settings.');
      }
    } catch (_) {
      // SharedPreferences changes its in-memory cache before I/O completes.
      for (final entry in previous.entries) {
        final value = entry.value;
        if (preferences.getString(entry.key) == value) continue;
        try {
          final restored = value == null
              ? await preferences.remove(entry.key)
              : await preferences.setString(entry.key, value);
          if (!restored) {
            AppLogger.warning('Could not roll back a settings key');
          }
        } catch (_) {
          AppLogger.warning('Could not roll back a settings key');
        }
      }
      rethrow;
    }
    // A leftover staging key is harmless once the primary is committed.
    try {
      if (!await preferences.remove(stagingKey)) {
        AppLogger.warning('Could not clear staged settings');
      }
    } catch (_) {
      AppLogger.warning('Could not clear staged settings');
    }
  }

  bool _containsSensitiveSettings(Object? document) {
    if (document is! Map) return false;
    if (document.containsKey('obsPassword')) return true;
    final settings = document['settings'];
    return settings is Map && settings.containsKey('obsPassword');
  }
}

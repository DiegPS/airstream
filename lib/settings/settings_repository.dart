import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsRepository {
  Future<String?> read();

  Future<void> write(String json);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const settingsKey = 'AIRSTREAM_SETTINGS';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(settingsKey);
  }

  @override
  Future<void> write(String json) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(settingsKey, json);
  }
}

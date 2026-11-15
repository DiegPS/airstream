import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';

/// Named setups ("Gaming", "Just chatting") and settings backups.
///
/// A profile holds how Airstream looks and behaves (style, voice reader,
/// overlay, highlights…), never where it connects: channels, OBS, the
/// overlay server and the language stay as they are when switching.
abstract final class SettingsProfiles {
  static const maxProfiles = 20;

  static const _connectionKeys = {
    'appLanguageCode',
    'connectChatOnLaunch',
    'obsEnabled',
    'obsConnectOnLaunch',
    'obsHost',
    'overlayEnabled',
    'overlayPort',
    'profiles',
  };

  static bool _isConnectionKey(String key) =>
      _connectionKeys.contains(key) ||
      key.startsWith('youtube') ||
      key.startsWith('twitch') ||
      key.startsWith('kick') ||
      // Shortcuts belong to the computer, not to a kind of stream.
      key.startsWith('shortcut');

  /// The part of [settings] a profile stores.
  static Map<String, dynamic> capture(SettingsModel settings) => {
        for (final entry in settings.toJson().entries)
          if (!_isConnectionKey(entry.key)) entry.key: entry.value,
      };

  /// [current] with [profile] applied; connections stay unchanged.
  static SettingsModel apply(
    SettingsModel current,
    Map<String, dynamic> profile,
  ) =>
      SettingsModel.fromJson({
        ...current.toJson(),
        for (final entry in profile.entries)
          if (!_isConnectionKey(entry.key)) entry.key: entry.value,
      }).copyWith(obsPassword: current.obsPassword);

  static SettingsModel save(SettingsModel current, String name) {
    final profiles = {...current.profiles, name.trim(): capture(current)};
    return current.copyWith(profiles: profiles);
  }

  static SettingsModel delete(SettingsModel current, String name) =>
      current.copyWith(profiles: {...current.profiles}..remove(name));

  /// Factory settings for everything a profile covers; connections, the
  /// language and saved profiles stay.
  static SettingsModel resetToDefaults(SettingsModel current) =>
      apply(current, capture(const SettingsModel()));

  /// Every setting as a file, without the OBS password (kept in Windows'
  /// secure storage, never in the settings document).
  static String export(SettingsModel settings) =>
      SettingsDocumentCodec.encode(settings);

  /// Settings read from an exported file, keeping the current OBS password.
  static SettingsModel import(String source, SettingsModel current) =>
      SettingsDocumentCodec.decode(source)
          .settings
          .copyWith(obsPassword: current.obsPassword);
}

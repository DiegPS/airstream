import 'package:airstream/application/live_clock.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';

/// Named setups ("Gaming", "Just chatting") and settings backups.
///
/// A profile holds how Airstream looks and behaves (style, voice reader,
/// overlay, highlights…), never where it connects: channels, OBS, the
/// overlay server and the language stay as they are when switching.
abstract final class SettingsProfiles {
  static const maxProfiles = 20;

  static const _readerFilterKeys = {
    'ttsRoles',
    'ttsPlatforms',
    'ttsAlwaysReadSupport',
    'ttsLinks',
    'ttsSkipEmoteOnly',
  };

  static const _connectionKeys = {
    'appLanguageCode',
    'connectChatOnLaunch',
    'obsEnabled',
    'obsConnectOnLaunch',
    'obsHost',
    'overlayEnabled',
    'overlayPort',
    'profiles',
    'goals',
    'queueState',
    'giveawayHistory',
    'rulesEnabled',
    'rulesWebhookEnabled',
    'rulesWebhookToken',
    'rules',
    'ruleCounters',
    'mediaLibrary',
    'subathonPhase',
    'subathonEndsAtMs',
    'subathonRemainingMs',
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
          if (!_isConnectionKey(entry.key) && entry.key != 'clock')
            entry.key: entry.value,
        'clock': settings.clock.optionsJson(),
      };

  /// [current] with [profile] applied; connections stay unchanged.
  static SettingsModel apply(
    SettingsModel current,
    Map<String, dynamic> profile,
  ) =>
      SettingsModel.fromJson({
        for (final entry in current.toJson().entries)
          if (!(_readerFilterKeys.contains(entry.key) &&
                  profile['ttsMembersOnly'] is bool) &&
              !(entry.key == 'highlightSounds' &&
                  profile['highlightSound'] is bool))
            entry.key: entry.value,
        for (final entry in profile.entries)
          if (!_isConnectionKey(entry.key) && entry.key != 'clock')
            entry.key: entry.value,
        if (profile['clock'] is Map)
          'clock':
              _applyClock(current.clock, LiveClock.fromJson(profile['clock']))
                  .toJson(),
      }).copyWith(
          giveawayHistory: current.giveawayHistory,
          obsPassword: current.obsPassword,
          rulesWebhookToken: current.rulesWebhookToken,
          rulesWebhookEnabled: current.rulesWebhookEnabled);

  static LiveClock _applyClock(LiveClock current, LiveClock options) =>
      current.configure(
        mode: options.mode,
        label: options.label,
        durationSeconds: options.durationSeconds,
        style: options.style,
        sound: options.sound,
      );

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

  /// Settings for portable backups, without credentials or the current queue.
  static String export(SettingsModel settings) =>
      SettingsDocumentCodec.encode(settings,
          includeWebhookSecret: false, includeQueueState: false);

  /// Settings read from a backup, keeping local credentials and API opt-in.
  static SettingsModel import(String source, SettingsModel current) =>
      SettingsDocumentCodec.decode(source).settings.copyWith(
          queueState: current.queueState,
          obsPassword: current.obsPassword,
          rulesWebhookToken: current.rulesWebhookToken,
          rulesWebhookEnabled: current.rulesWebhookEnabled);
}

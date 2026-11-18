import 'package:airstream/application/live_clock.dart';
import 'package:airstream/application/rules/rule_model.dart';
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
    // Saved polls and giveaway rounds are the streamer's data, not a look:
    // switching profiles or resetting settings must not erase them.
    'savedPolls',
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
  /// HTTP rule URLs are private too (a Discord webhook URL is a credential).
  static String export(SettingsModel settings) => SettingsDocumentCodec.encode(
      settings.copyWith(rules: [
        for (final rule in settings.rules)
          {
            ...rule,
            'actions': [
              for (final action in rule['actions'] as List? ?? const [])
                if (action is Map<String, dynamic>)
                  RuleSchema.withoutHttpUrl(action)
                else
                  action,
            ],
          },
      ]),
      includeWebhookSecret: false,
      includeQueueState: false);

  /// Settings read from a backup, keeping local credentials, API opt-in and
  /// the HTTP rule URLs this computer already has.
  static SettingsModel import(String source, SettingsModel current) =>
      keepLocalHttpUrls(
          SettingsDocumentCodec.decode(source).settings.copyWith(
              queueState: current.queueState,
              obsPassword: current.obsPassword,
              rulesWebhookToken: current.rulesWebhookToken,
              rulesWebhookEnabled: current.rulesWebhookEnabled),
          current);

  /// Restores each HTTP action's URL from [current] by rule and action id;
  /// an action this computer does not have keeps an empty URL.
  static SettingsModel keepLocalHttpUrls(
      SettingsModel restored, SettingsModel current) {
    final urls = <(String, String), Object?>{
      for (final rule in current.rules)
        for (final action in rule['actions'] as List? ?? const [])
          if (action is Map &&
              action['type'] == 'http.request' &&
              rule['id'] is String &&
              action['id'] is String)
            (rule['id'] as String, action['id'] as String): action['url'],
    };
    return restored.copyWith(rules: [
      for (final rule in restored.rules)
        {
          ...rule,
          'actions': [
            for (final action in rule['actions'] as List? ?? const [])
              if (action is Map<String, dynamic> &&
                  action['type'] == 'http.request')
                {
                  ...action,
                  'url': urls[(rule['id'], action['id'])] ?? '',
                }
              else
                action,
          ],
        },
    ]);
  }
}

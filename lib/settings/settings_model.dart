import 'dart:convert';

/// All persisted settings for the app.
class SettingsModel {
  // Platform connections
  final String youtubeHandle;
  final String youtubeLiveId;
  final String twitchChannel;
  final String kickSlug;

  // Overlay visual
  final double fontSize;
  final double bgOpacity;
  final double messageOpacity;
  final bool showAvatars;
  final bool showPlatformIcons;
  final bool showBadges;
  final bool showTimestamp;

  // Message design
  final bool showBubble;
  final bool showBubbleShadow;
  final double borderRadius;
  final double messageGap;
  final int maxMessages;

  // Filtering
  final List<String> blockedUsers;
  final List<String> blockedWords;

  // TTS
  final bool ttsEnabled;
  final bool ttsMembersOnly;
  final bool ttsCommandMode;
  final String ttsCommandPrefix;
  final String ttsSeparatorText;
  final String ttsVoice;
  final String ttsLanguage;

  // OBS overlay server
  final int overlayPort;
  final bool overlayEnabled;

  // OBS integration
  final bool obsEnabled;
  final String obsHost;
  final String obsPassword;
  final bool obsShowStreamState;
  final bool obsShowCurrentScene;
  final bool obsShowBitrate;
  final bool obsShowFps;
  final bool obsShowDroppedFrames;

  const SettingsModel({
    this.youtubeHandle = '',
    this.youtubeLiveId = '',
    this.twitchChannel = '',
    this.kickSlug = '',
    this.fontSize = 14.0,
    this.bgOpacity = 0.4,
    this.messageOpacity = 1.0,
    this.showAvatars = true,
    this.showPlatformIcons = true,
    this.showBadges = true,
    this.showTimestamp = false,
    this.showBubble = true,
    this.showBubbleShadow = true,
    this.borderRadius = 8.0,
    this.messageGap = 4.0,
    this.maxMessages = 200,
    this.blockedUsers = const [],
    this.blockedWords = const [],
    this.ttsEnabled = false,
    this.ttsMembersOnly = false,
    this.ttsCommandMode = false,
    this.ttsCommandPrefix = '!voz',
    this.ttsSeparatorText = 'dice',
    this.ttsVoice = 'M1',
    this.ttsLanguage = 'es',
    this.overlayPort = 8080,
    this.overlayEnabled = true,
    this.obsEnabled = false,
    this.obsHost = 'localhost:4455',
    this.obsPassword = '',
    this.obsShowStreamState = true,
    this.obsShowCurrentScene = true,
    this.obsShowBitrate = true,
    this.obsShowFps = true,
    this.obsShowDroppedFrames = true,
  });

  SettingsModel copyWith({
    String? youtubeHandle,
    String? youtubeLiveId,
    String? twitchChannel,
    String? kickSlug,
    double? fontSize,
    double? bgOpacity,
    double? messageOpacity,
    bool? showAvatars,
    bool? showPlatformIcons,
    bool? showBadges,
    bool? showTimestamp,
    bool? showBubble,
    bool? showBubbleShadow,
    double? borderRadius,
    double? messageGap,
    int? maxMessages,
    List<String>? blockedUsers,
    List<String>? blockedWords,
    bool? ttsEnabled,
    bool? ttsMembersOnly,
    bool? ttsCommandMode,
    String? ttsCommandPrefix,
    String? ttsSeparatorText,
    String? ttsVoice,
    String? ttsLanguage,
    int? overlayPort,
    bool? overlayEnabled,
    bool? obsEnabled,
    String? obsHost,
    String? obsPassword,
    bool? obsShowStreamState,
    bool? obsShowCurrentScene,
    bool? obsShowBitrate,
    bool? obsShowFps,
    bool? obsShowDroppedFrames,
  }) =>
      SettingsModel(
        youtubeHandle: youtubeHandle ?? this.youtubeHandle,
        youtubeLiveId: youtubeLiveId ?? this.youtubeLiveId,
        twitchChannel: twitchChannel ?? this.twitchChannel,
        kickSlug: kickSlug ?? this.kickSlug,
        fontSize: fontSize ?? this.fontSize,
        bgOpacity: bgOpacity ?? this.bgOpacity,
        messageOpacity: messageOpacity ?? this.messageOpacity,
        showAvatars: showAvatars ?? this.showAvatars,
        showPlatformIcons: showPlatformIcons ?? this.showPlatformIcons,
        showBadges: showBadges ?? this.showBadges,
        showTimestamp: showTimestamp ?? this.showTimestamp,
        showBubble: showBubble ?? this.showBubble,
        showBubbleShadow: showBubbleShadow ?? this.showBubbleShadow,
        borderRadius: borderRadius ?? this.borderRadius,
        messageGap: messageGap ?? this.messageGap,
        maxMessages: maxMessages ?? this.maxMessages,
        blockedUsers: blockedUsers ?? this.blockedUsers,
        blockedWords: blockedWords ?? this.blockedWords,
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        ttsMembersOnly: ttsMembersOnly ?? this.ttsMembersOnly,
        ttsCommandMode: ttsCommandMode ?? this.ttsCommandMode,
        ttsCommandPrefix: ttsCommandPrefix ?? this.ttsCommandPrefix,
        ttsSeparatorText: ttsSeparatorText ?? this.ttsSeparatorText,
        ttsVoice: ttsVoice ?? this.ttsVoice,
        ttsLanguage: ttsLanguage ?? this.ttsLanguage,
        overlayPort: overlayPort ?? this.overlayPort,
        overlayEnabled: overlayEnabled ?? this.overlayEnabled,
        obsEnabled: obsEnabled ?? this.obsEnabled,
        obsHost: obsHost ?? this.obsHost,
        obsPassword: obsPassword ?? this.obsPassword,
        obsShowStreamState: obsShowStreamState ?? this.obsShowStreamState,
        obsShowCurrentScene: obsShowCurrentScene ?? this.obsShowCurrentScene,
        obsShowBitrate: obsShowBitrate ?? this.obsShowBitrate,
        obsShowFps: obsShowFps ?? this.obsShowFps,
        obsShowDroppedFrames: obsShowDroppedFrames ?? this.obsShowDroppedFrames,
      );

  Map<String, dynamic> toJson() => {
        'youtubeHandle': youtubeHandle,
        'youtubeLiveId': youtubeLiveId,
        'twitchChannel': twitchChannel,
        'kickSlug': kickSlug,
        'fontSize': fontSize,
        'bgOpacity': bgOpacity,
        'messageOpacity': messageOpacity,
        'showAvatars': showAvatars,
        'showPlatformIcons': showPlatformIcons,
        'showBadges': showBadges,
        'showTimestamp': showTimestamp,
        'showBubble': showBubble,
        'showBubbleShadow': showBubbleShadow,
        'borderRadius': borderRadius,
        'messageGap': messageGap,
        'maxMessages': maxMessages,
        'blockedUsers': blockedUsers,
        'blockedWords': blockedWords,
        'ttsEnabled': ttsEnabled,
        'ttsMembersOnly': ttsMembersOnly,
        'ttsCommandMode': ttsCommandMode,
        'ttsCommandPrefix': ttsCommandPrefix,
        'ttsSeparatorText': ttsSeparatorText,
        'ttsVoice': ttsVoice,
        'ttsLanguage': ttsLanguage,
        'overlayPort': overlayPort,
        'overlayEnabled': overlayEnabled,
        'obsEnabled': obsEnabled,
        'obsHost': obsHost,
        'obsPassword': obsPassword,
        'obsShowStreamState': obsShowStreamState,
        'obsShowCurrentScene': obsShowCurrentScene,
        'obsShowBitrate': obsShowBitrate,
        'obsShowFps': obsShowFps,
        'obsShowDroppedFrames': obsShowDroppedFrames,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> j) => SettingsModel(
        youtubeHandle: j['youtubeHandle'] as String? ?? '',
        youtubeLiveId: j['youtubeLiveId'] as String? ?? '',
        twitchChannel: j['twitchChannel'] as String? ?? '',
        kickSlug: j['kickSlug'] as String? ?? '',
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14.0,
        bgOpacity: (j['bgOpacity'] as num?)?.toDouble() ?? 0.4,
        messageOpacity: (j['messageOpacity'] as num?)?.toDouble() ?? 1.0,
        showAvatars: j['showAvatars'] as bool? ?? true,
        showPlatformIcons: j['showPlatformIcons'] as bool? ?? true,
        showBadges: j['showBadges'] as bool? ?? true,
        showTimestamp: j['showTimestamp'] as bool? ?? false,
        showBubble: j['showBubble'] as bool? ?? true,
        showBubbleShadow: j['showBubbleShadow'] as bool? ?? true,
        borderRadius: (j['borderRadius'] as num?)?.toDouble() ?? 8.0,
        messageGap: (j['messageGap'] as num?)?.toDouble() ?? 4.0,
        maxMessages: j['maxMessages'] as int? ?? 200,
        blockedUsers: List<String>.from(j['blockedUsers'] as List? ?? []),
        blockedWords: List<String>.from(j['blockedWords'] as List? ?? []),
        ttsEnabled: j['ttsEnabled'] as bool? ?? false,
        ttsMembersOnly: j['ttsMembersOnly'] as bool? ?? false,
        ttsCommandMode: j['ttsCommandMode'] as bool? ?? false,
        ttsCommandPrefix: j['ttsCommandPrefix'] as String? ?? '!voz',
        ttsSeparatorText: j['ttsSeparatorText'] as String? ?? 'dice',
        ttsVoice: j['ttsVoice'] as String? ?? 'M1',
        ttsLanguage: j['ttsLanguage'] as String? ?? 'es',
        overlayPort: j['overlayPort'] as int? ?? 8080,
        overlayEnabled: j['overlayEnabled'] as bool? ?? true,
        obsEnabled: j['obsEnabled'] as bool? ?? false,
        obsHost: j['obsHost'] as String? ?? 'localhost:4455',
        obsPassword: j['obsPassword'] as String? ?? '',
        obsShowStreamState: j['obsShowStreamState'] as bool? ?? true,
        obsShowCurrentScene: j['obsShowCurrentScene'] as bool? ?? true,
        obsShowBitrate: j['obsShowBitrate'] as bool? ?? true,
        obsShowFps: j['obsShowFps'] as bool? ?? true,
        obsShowDroppedFrames: j['obsShowDroppedFrames'] as bool? ?? true,
      );

  factory SettingsModel.fromJsonString(String s) =>
      SettingsModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}

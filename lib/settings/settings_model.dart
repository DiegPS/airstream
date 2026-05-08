import 'dart:convert';

/// All persisted settings for the app.
class SettingsModel {
  // Platform connections
  final String youtubeHandle;
  final String youtubeLiveId;
  final String twitchChannel;
  final String kickSlug;
  final int kickChatroomId; // optional override — bypasses HTTP lookup

  // Overlay visual
  final double fontSize;
  final double bgOpacity;
  final double messageOpacity;
  final bool showAvatars;
  final bool showBadges;
  final bool showTimestamp;

  // Message design
  final bool showBubble;
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

  // Window behaviour (Windows-only)
  final bool clickThrough;
  final bool alwaysOnTop;

  const SettingsModel({
    this.youtubeHandle = '',
    this.youtubeLiveId = '',
    this.twitchChannel = '',
    this.kickSlug = '',
    this.kickChatroomId = 0,
    this.fontSize = 14.0,
    this.bgOpacity = 0.4,
    this.messageOpacity = 1.0,
    this.showAvatars = true,
    this.showBadges = true,
    this.showTimestamp = false,
    this.showBubble = true,
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
    this.clickThrough = false,
    this.alwaysOnTop = false,
  });

  SettingsModel copyWith({
    String? youtubeHandle,
    String? youtubeLiveId,
    String? twitchChannel,
    String? kickSlug,
    int? kickChatroomId,
    double? fontSize,
    double? bgOpacity,
    double? messageOpacity,
    bool? showAvatars,
    bool? showBadges,
    bool? showTimestamp,
    bool? showBubble,
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
    bool? clickThrough,
    bool? alwaysOnTop,
  }) =>
      SettingsModel(
        youtubeHandle: youtubeHandle ?? this.youtubeHandle,
        youtubeLiveId: youtubeLiveId ?? this.youtubeLiveId,
        twitchChannel: twitchChannel ?? this.twitchChannel,
        kickSlug: kickSlug ?? this.kickSlug,
        kickChatroomId: kickChatroomId ?? this.kickChatroomId,
        fontSize: fontSize ?? this.fontSize,
        bgOpacity: bgOpacity ?? this.bgOpacity,
        messageOpacity: messageOpacity ?? this.messageOpacity,
        showAvatars: showAvatars ?? this.showAvatars,
        showBadges: showBadges ?? this.showBadges,
        showTimestamp: showTimestamp ?? this.showTimestamp,
        showBubble: showBubble ?? this.showBubble,
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
        clickThrough: clickThrough ?? this.clickThrough,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      );

  Map<String, dynamic> toJson() => {
        'youtubeHandle': youtubeHandle,
        'youtubeLiveId': youtubeLiveId,
        'twitchChannel': twitchChannel,
        'kickSlug': kickSlug,
        'kickChatroomId': kickChatroomId,
        'fontSize': fontSize,
        'bgOpacity': bgOpacity,
        'messageOpacity': messageOpacity,
        'showAvatars': showAvatars,
        'showBadges': showBadges,
        'showTimestamp': showTimestamp,
        'showBubble': showBubble,
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
        'clickThrough': clickThrough,
        'alwaysOnTop': alwaysOnTop,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> j) => SettingsModel(
        youtubeHandle: j['youtubeHandle'] as String? ?? '',
        youtubeLiveId: j['youtubeLiveId'] as String? ?? '',
        twitchChannel: j['twitchChannel'] as String? ?? '',
        kickSlug: j['kickSlug'] as String? ?? '',
        kickChatroomId: j['kickChatroomId'] as int? ?? 0,
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14.0,
        bgOpacity: (j['bgOpacity'] as num?)?.toDouble() ?? 0.4,
        messageOpacity: (j['messageOpacity'] as num?)?.toDouble() ?? 1.0,
        showAvatars: j['showAvatars'] as bool? ?? true,
        showBadges: j['showBadges'] as bool? ?? true,
        showTimestamp: j['showTimestamp'] as bool? ?? false,
        showBubble: j['showBubble'] as bool? ?? true,
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
        clickThrough: j['clickThrough'] as bool? ?? false,
        alwaysOnTop: j['alwaysOnTop'] as bool? ?? false,
      );

  factory SettingsModel.fromJsonString(String s) =>
      SettingsModel.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}

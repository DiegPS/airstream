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
  final bool overlayChromaMode;
  final String overlayChromaColor;
  final bool overlayShowGrid;
  final bool overlayHideScrollbar;
  final double overlayFontSize;
  final double overlayBgOpacity;
  final double overlayMessageOpacity;
  final bool overlayShowAvatars;
  final bool overlayShowPlatformIcons;
  final bool overlayShowBadges;
  final bool overlayShowTimestamp;
  final double overlayTextStroke;
  final String overlayTextStrokeColor;
  final double overlayLineHeight;
  final double overlayMessageGap;
  final double overlayFontWeight;
  final double overlayBorderRadius;
  final bool overlayTextShadow;
  final bool overlayShowBubble;
  final bool overlaySuperChatBarEnabled;
  final String overlaySuperChatBarColor;
  final double overlaySuperChatBarWidth;
  final int overlayMaxMessages;
  final int overlayMessageTtlSeconds;
  final String overlayAnimation;
  final double overlayAnimationDuration;
  final String overlayTextAlign;
  final bool overlayTwitchBubbleAccent;
  final bool overlayKickBubbleAccent;
  final bool overlayThreeDEnabled;
  final double overlayPerspective;
  final double overlayRotateX;
  final double overlayRotateY;
  final double overlayRotateZ;
  final double overlaySkewX;
  final double overlayScale;
  final double alertFontSize;
  final int alertDisplaySeconds;
  final bool alertShowAvatars;

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
    this.overlayChromaMode = false,
    this.overlayChromaColor = '#00FF00',
    this.overlayShowGrid = false,
    this.overlayHideScrollbar = false,
    this.overlayFontSize = 14.0,
    this.overlayBgOpacity = 0.0,
    this.overlayMessageOpacity = 0.45,
    this.overlayShowAvatars = true,
    this.overlayShowPlatformIcons = true,
    this.overlayShowBadges = true,
    this.overlayShowTimestamp = false,
    this.overlayTextStroke = 0.0,
    this.overlayTextStrokeColor = '#000000',
    this.overlayLineHeight = 1.5,
    this.overlayMessageGap = 15.0,
    this.overlayFontWeight = 400.0,
    this.overlayBorderRadius = 16.0,
    this.overlayTextShadow = false,
    this.overlayShowBubble = true,
    this.overlaySuperChatBarEnabled = true,
    this.overlaySuperChatBarColor = '#1DE9B6',
    this.overlaySuperChatBarWidth = 3.0,
    this.overlayMaxMessages = 100,
    this.overlayMessageTtlSeconds = 20,
    this.overlayAnimation = 'slide-up',
    this.overlayAnimationDuration = 0.4,
    this.overlayTextAlign = 'left',
    this.overlayTwitchBubbleAccent = true,
    this.overlayKickBubbleAccent = true,
    this.overlayThreeDEnabled = false,
    this.overlayPerspective = 1000.0,
    this.overlayRotateX = 0.0,
    this.overlayRotateY = 0.0,
    this.overlayRotateZ = 0.0,
    this.overlaySkewX = 0.0,
    this.overlayScale = 1.0,
    this.alertFontSize = 28.0,
    this.alertDisplaySeconds = 7,
    this.alertShowAvatars = true,
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
    bool? overlayChromaMode,
    String? overlayChromaColor,
    bool? overlayShowGrid,
    bool? overlayHideScrollbar,
    double? overlayFontSize,
    double? overlayBgOpacity,
    double? overlayMessageOpacity,
    bool? overlayShowAvatars,
    bool? overlayShowPlatformIcons,
    bool? overlayShowBadges,
    bool? overlayShowTimestamp,
    double? overlayTextStroke,
    String? overlayTextStrokeColor,
    double? overlayLineHeight,
    double? overlayMessageGap,
    double? overlayFontWeight,
    double? overlayBorderRadius,
    bool? overlayTextShadow,
    bool? overlayShowBubble,
    bool? overlaySuperChatBarEnabled,
    String? overlaySuperChatBarColor,
    double? overlaySuperChatBarWidth,
    int? overlayMaxMessages,
    int? overlayMessageTtlSeconds,
    String? overlayAnimation,
    double? overlayAnimationDuration,
    String? overlayTextAlign,
    bool? overlayTwitchBubbleAccent,
    bool? overlayKickBubbleAccent,
    bool? overlayThreeDEnabled,
    double? overlayPerspective,
    double? overlayRotateX,
    double? overlayRotateY,
    double? overlayRotateZ,
    double? overlaySkewX,
    double? overlayScale,
    double? alertFontSize,
    int? alertDisplaySeconds,
    bool? alertShowAvatars,
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
        overlayChromaMode: overlayChromaMode ?? this.overlayChromaMode,
        overlayChromaColor: overlayChromaColor ?? this.overlayChromaColor,
        overlayShowGrid: overlayShowGrid ?? this.overlayShowGrid,
        overlayHideScrollbar: overlayHideScrollbar ?? this.overlayHideScrollbar,
        overlayFontSize: overlayFontSize ?? this.overlayFontSize,
        overlayBgOpacity: overlayBgOpacity ?? this.overlayBgOpacity,
        overlayMessageOpacity:
            overlayMessageOpacity ?? this.overlayMessageOpacity,
        overlayShowAvatars: overlayShowAvatars ?? this.overlayShowAvatars,
        overlayShowPlatformIcons:
            overlayShowPlatformIcons ?? this.overlayShowPlatformIcons,
        overlayShowBadges: overlayShowBadges ?? this.overlayShowBadges,
        overlayShowTimestamp: overlayShowTimestamp ?? this.overlayShowTimestamp,
        overlayTextStroke: overlayTextStroke ?? this.overlayTextStroke,
        overlayTextStrokeColor:
            overlayTextStrokeColor ?? this.overlayTextStrokeColor,
        overlayLineHeight: overlayLineHeight ?? this.overlayLineHeight,
        overlayMessageGap: overlayMessageGap ?? this.overlayMessageGap,
        overlayFontWeight: overlayFontWeight ?? this.overlayFontWeight,
        overlayBorderRadius: overlayBorderRadius ?? this.overlayBorderRadius,
        overlayTextShadow: overlayTextShadow ?? this.overlayTextShadow,
        overlayShowBubble: overlayShowBubble ?? this.overlayShowBubble,
        overlaySuperChatBarEnabled:
            overlaySuperChatBarEnabled ?? this.overlaySuperChatBarEnabled,
        overlaySuperChatBarColor:
            overlaySuperChatBarColor ?? this.overlaySuperChatBarColor,
        overlaySuperChatBarWidth:
            overlaySuperChatBarWidth ?? this.overlaySuperChatBarWidth,
        overlayMaxMessages: overlayMaxMessages ?? this.overlayMaxMessages,
        overlayMessageTtlSeconds:
            overlayMessageTtlSeconds ?? this.overlayMessageTtlSeconds,
        overlayAnimation: overlayAnimation ?? this.overlayAnimation,
        overlayAnimationDuration:
            overlayAnimationDuration ?? this.overlayAnimationDuration,
        overlayTextAlign: overlayTextAlign ?? this.overlayTextAlign,
        overlayTwitchBubbleAccent:
            overlayTwitchBubbleAccent ?? this.overlayTwitchBubbleAccent,
        overlayKickBubbleAccent:
            overlayKickBubbleAccent ?? this.overlayKickBubbleAccent,
        overlayThreeDEnabled: overlayThreeDEnabled ?? this.overlayThreeDEnabled,
        overlayPerspective: overlayPerspective ?? this.overlayPerspective,
        overlayRotateX: overlayRotateX ?? this.overlayRotateX,
        overlayRotateY: overlayRotateY ?? this.overlayRotateY,
        overlayRotateZ: overlayRotateZ ?? this.overlayRotateZ,
        overlaySkewX: overlaySkewX ?? this.overlaySkewX,
        overlayScale: overlayScale ?? this.overlayScale,
        alertFontSize: alertFontSize ?? this.alertFontSize,
        alertDisplaySeconds: alertDisplaySeconds ?? this.alertDisplaySeconds,
        alertShowAvatars: alertShowAvatars ?? this.alertShowAvatars,
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
        'overlayChromaMode': overlayChromaMode,
        'overlayChromaColor': overlayChromaColor,
        'overlayShowGrid': overlayShowGrid,
        'overlayHideScrollbar': overlayHideScrollbar,
        'overlayFontSize': overlayFontSize,
        'overlayBgOpacity': overlayBgOpacity,
        'overlayMessageOpacity': overlayMessageOpacity,
        'overlayShowAvatars': overlayShowAvatars,
        'overlayShowPlatformIcons': overlayShowPlatformIcons,
        'overlayShowBadges': overlayShowBadges,
        'overlayShowTimestamp': overlayShowTimestamp,
        'overlayTextStroke': overlayTextStroke,
        'overlayTextStrokeColor': overlayTextStrokeColor,
        'overlayLineHeight': overlayLineHeight,
        'overlayMessageGap': overlayMessageGap,
        'overlayFontWeight': overlayFontWeight,
        'overlayBorderRadius': overlayBorderRadius,
        'overlayTextShadow': overlayTextShadow,
        'overlayShowBubble': overlayShowBubble,
        'overlaySuperChatBarEnabled': overlaySuperChatBarEnabled,
        'overlaySuperChatBarColor': overlaySuperChatBarColor,
        'overlaySuperChatBarWidth': overlaySuperChatBarWidth,
        'overlayMaxMessages': overlayMaxMessages,
        'overlayMessageTtlSeconds': overlayMessageTtlSeconds,
        'overlayAnimation': overlayAnimation,
        'overlayAnimationDuration': overlayAnimationDuration,
        'overlayTextAlign': overlayTextAlign,
        'overlayTwitchBubbleAccent': overlayTwitchBubbleAccent,
        'overlayKickBubbleAccent': overlayKickBubbleAccent,
        'overlayThreeDEnabled': overlayThreeDEnabled,
        'overlayPerspective': overlayPerspective,
        'overlayRotateX': overlayRotateX,
        'overlayRotateY': overlayRotateY,
        'overlayRotateZ': overlayRotateZ,
        'overlaySkewX': overlaySkewX,
        'overlayScale': overlayScale,
        'alertFontSize': alertFontSize,
        'alertDisplaySeconds': alertDisplaySeconds,
        'alertShowAvatars': alertShowAvatars,
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
        overlayChromaMode: j['overlayChromaMode'] as bool? ?? false,
        overlayChromaColor: j['overlayChromaColor'] as String? ?? '#00FF00',
        overlayShowGrid: j['overlayShowGrid'] as bool? ?? false,
        overlayHideScrollbar: j['overlayHideScrollbar'] as bool? ?? false,
        overlayFontSize: (j['overlayFontSize'] as num?)?.toDouble() ?? 14.0,
        overlayBgOpacity: (j['overlayBgOpacity'] as num?)?.toDouble() ?? 0.0,
        overlayMessageOpacity:
            (j['overlayMessageOpacity'] as num?)?.toDouble() ?? 0.45,
        overlayShowAvatars: j['overlayShowAvatars'] as bool? ?? true,
        overlayShowPlatformIcons:
            j['overlayShowPlatformIcons'] as bool? ?? true,
        overlayShowBadges: j['overlayShowBadges'] as bool? ?? true,
        overlayShowTimestamp: j['overlayShowTimestamp'] as bool? ?? false,
        overlayTextStroke: (j['overlayTextStroke'] as num?)?.toDouble() ?? 0.0,
        overlayTextStrokeColor:
            j['overlayTextStrokeColor'] as String? ?? '#000000',
        overlayLineHeight: (j['overlayLineHeight'] as num?)?.toDouble() ?? 1.5,
        overlayMessageGap: (j['overlayMessageGap'] as num?)?.toDouble() ?? 15.0,
        overlayFontWeight:
            (j['overlayFontWeight'] as num?)?.toDouble() ?? 400.0,
        overlayBorderRadius:
            (j['overlayBorderRadius'] as num?)?.toDouble() ?? 16.0,
        overlayTextShadow: j['overlayTextShadow'] as bool? ?? false,
        overlayShowBubble: j['overlayShowBubble'] as bool? ?? true,
        overlaySuperChatBarEnabled:
            j['overlaySuperChatBarEnabled'] as bool? ?? true,
        overlaySuperChatBarColor:
            j['overlaySuperChatBarColor'] as String? ?? '#1DE9B6',
        overlaySuperChatBarWidth:
            (j['overlaySuperChatBarWidth'] as num?)?.toDouble() ?? 3.0,
        overlayMaxMessages: j['overlayMaxMessages'] as int? ?? 100,
        overlayMessageTtlSeconds:
            (j['overlayMessageTtlSeconds'] as num?)?.round() ?? 20,
        overlayAnimation: j['overlayAnimation'] as String? ?? 'slide-up',
        overlayAnimationDuration:
            (j['overlayAnimationDuration'] as num?)?.toDouble() ?? 0.4,
        overlayTextAlign: j['overlayTextAlign'] as String? ?? 'left',
        overlayTwitchBubbleAccent:
            j['overlayTwitchBubbleAccent'] as bool? ?? true,
        overlayKickBubbleAccent: j['overlayKickBubbleAccent'] as bool? ?? true,
        overlayThreeDEnabled: j['overlayThreeDEnabled'] as bool? ?? false,
        overlayPerspective:
            (j['overlayPerspective'] as num?)?.toDouble() ?? 1000.0,
        overlayRotateX: (j['overlayRotateX'] as num?)?.toDouble() ?? 0.0,
        overlayRotateY: (j['overlayRotateY'] as num?)?.toDouble() ?? 0.0,
        overlayRotateZ: (j['overlayRotateZ'] as num?)?.toDouble() ?? 0.0,
        overlaySkewX: (j['overlaySkewX'] as num?)?.toDouble() ?? 0.0,
        overlayScale: (j['overlayScale'] as num?)?.toDouble() ?? 1.0,
        alertFontSize: (j['alertFontSize'] as num?)?.toDouble() ?? 28.0,
        alertDisplaySeconds: (j['alertDisplaySeconds'] as num?)?.round() ?? 7,
        alertShowAvatars: j['alertShowAvatars'] as bool? ?? true,
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

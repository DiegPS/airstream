import 'dart:convert';

/// All persisted settings for the app.
class SettingsModel {
  final String appLanguageCode;

  // Platform connections
  final String youtubeHandle;
  final String youtubeLiveId;
  final bool youtubeDualStreamEnabled;
  final String youtubeHorizontalUrl;
  final String youtubeVerticalUrl;
  final String twitchChannel;
  final String kickSlug;
  final bool youtubeEnabled;
  final bool twitchEnabled;
  final bool kickEnabled;

  // Overlay visual
  final double fontSize;
  final double bgOpacity;
  final double messageOpacity;
  final bool showAvatars;
  final bool showPlatformIcons;
  final bool showBadges;
  final bool showYoutubeStreamBadges;
  final bool showTimestamp;

  // Message design
  final bool showBubble;
  final bool showBubbleShadow;
  final double borderRadius;
  final double messageGap;
  final String chatTextAlign;
  final double chatMaxMessageWidth;
  final double chatHorizontalPadding;
  final double chatLineHeight;
  final double chatFontWeight;
  final bool chatTextShadow;
  final double chatTextStroke;
  final int maxMessages;

  // Filtering
  final List<String> blockedUsers;
  final List<String> blockedWords;

  // TTS
  final bool ttsEnabled;
  final bool ttsMembersOnly;
  final bool ttsCommandMode;
  final bool ttsCommandIgnoreCase;
  final String ttsCommandPrefix;
  final String ttsSeparatorText;
  final String ttsModelId;
  final String ttsVoice;
  final String ttsLanguage;
  final double ttsSpeed;
  final int ttsSteps;
  final String ttsReferenceAudioPath;
  final String ttsReferenceText;

  // Local speech tools
  final bool liveCaptionsEnabled;
  final String liveCaptionsModelId;
  final String liveCaptionsSourceLanguage;
  final String liveCaptionsTargetLanguage;
  final bool liveCaptionsOverlayEnabled;
  final bool liveCaptionsDenoiseEnabled;
  final bool voiceCommandsEnabled;
  final String voiceCommandsWakeWord;

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
  final bool overlayShowYoutubeStreamBadges;
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
  final bool obsShowRecordingState;
  final bool obsShowRecordingDuration;
  final bool obsShowRecordingSize;

  const SettingsModel({
    this.appLanguageCode = 'en',
    this.youtubeHandle = '',
    this.youtubeLiveId = '',
    this.youtubeDualStreamEnabled = false,
    this.youtubeHorizontalUrl = '',
    this.youtubeVerticalUrl = '',
    this.twitchChannel = '',
    this.kickSlug = '',
    this.youtubeEnabled = true,
    this.twitchEnabled = true,
    this.kickEnabled = true,
    this.fontSize = 14.0,
    this.bgOpacity = 0.4,
    this.messageOpacity = 1.0,
    this.showAvatars = true,
    this.showPlatformIcons = true,
    this.showBadges = true,
    this.showYoutubeStreamBadges = true,
    this.showTimestamp = false,
    this.showBubble = true,
    this.showBubbleShadow = true,
    this.borderRadius = 8.0,
    this.messageGap = 4.0,
    this.chatTextAlign = 'left',
    this.chatMaxMessageWidth = 0.82,
    this.chatHorizontalPadding = 24.0,
    this.chatLineHeight = 1.5,
    this.chatFontWeight = 400.0,
    this.chatTextShadow = false,
    this.chatTextStroke = 0.0,
    this.maxMessages = 200,
    this.blockedUsers = const [],
    this.blockedWords = const [],
    this.ttsEnabled = false,
    this.ttsMembersOnly = false,
    this.ttsCommandMode = false,
    this.ttsCommandIgnoreCase = true,
    this.ttsCommandPrefix = '!v',
    this.ttsSeparatorText = '',
    this.ttsModelId = 'supertonic-3-hybrid',
    this.ttsVoice = 'M1',
    this.ttsLanguage = 'es',
    this.ttsSpeed = 1.05,
    this.ttsSteps = 8,
    this.ttsReferenceAudioPath = '',
    this.ttsReferenceText = '',
    this.liveCaptionsEnabled = false,
    this.liveCaptionsModelId = 'canary-180m-int8',
    this.liveCaptionsSourceLanguage = 'es',
    this.liveCaptionsTargetLanguage = 'es',
    this.liveCaptionsOverlayEnabled = true,
    this.liveCaptionsDenoiseEnabled = true,
    this.voiceCommandsEnabled = false,
    this.voiceCommandsWakeWord = 'airstream',
    this.overlayPort = 8080,
    this.overlayEnabled = false,
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
    this.overlayShowYoutubeStreamBadges = true,
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
    this.obsShowRecordingState = true,
    this.obsShowRecordingDuration = true,
    this.obsShowRecordingSize = false,
  });

  SettingsModel copyWith({
    String? appLanguageCode,
    String? youtubeHandle,
    String? youtubeLiveId,
    bool? youtubeDualStreamEnabled,
    String? youtubeHorizontalUrl,
    String? youtubeVerticalUrl,
    String? twitchChannel,
    String? kickSlug,
    bool? youtubeEnabled,
    bool? twitchEnabled,
    bool? kickEnabled,
    double? fontSize,
    double? bgOpacity,
    double? messageOpacity,
    bool? showAvatars,
    bool? showPlatformIcons,
    bool? showBadges,
    bool? showYoutubeStreamBadges,
    bool? showTimestamp,
    bool? showBubble,
    bool? showBubbleShadow,
    double? borderRadius,
    double? messageGap,
    String? chatTextAlign,
    double? chatMaxMessageWidth,
    double? chatHorizontalPadding,
    double? chatLineHeight,
    double? chatFontWeight,
    bool? chatTextShadow,
    double? chatTextStroke,
    int? maxMessages,
    List<String>? blockedUsers,
    List<String>? blockedWords,
    bool? ttsEnabled,
    bool? ttsMembersOnly,
    bool? ttsCommandMode,
    bool? ttsCommandIgnoreCase,
    String? ttsCommandPrefix,
    String? ttsSeparatorText,
    String? ttsModelId,
    String? ttsVoice,
    String? ttsLanguage,
    double? ttsSpeed,
    int? ttsSteps,
    String? ttsReferenceAudioPath,
    String? ttsReferenceText,
    bool? liveCaptionsEnabled,
    String? liveCaptionsModelId,
    String? liveCaptionsSourceLanguage,
    String? liveCaptionsTargetLanguage,
    bool? liveCaptionsOverlayEnabled,
    bool? liveCaptionsDenoiseEnabled,
    bool? voiceCommandsEnabled,
    String? voiceCommandsWakeWord,
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
    bool? overlayShowYoutubeStreamBadges,
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
    bool? obsShowRecordingState,
    bool? obsShowRecordingDuration,
    bool? obsShowRecordingSize,
  }) =>
      SettingsModel(
        appLanguageCode: appLanguageCode ?? this.appLanguageCode,
        youtubeHandle: youtubeHandle ?? this.youtubeHandle,
        youtubeLiveId: youtubeLiveId ?? this.youtubeLiveId,
        youtubeDualStreamEnabled:
            youtubeDualStreamEnabled ?? this.youtubeDualStreamEnabled,
        youtubeHorizontalUrl: youtubeHorizontalUrl ?? this.youtubeHorizontalUrl,
        youtubeVerticalUrl: youtubeVerticalUrl ?? this.youtubeVerticalUrl,
        twitchChannel: twitchChannel ?? this.twitchChannel,
        kickSlug: kickSlug ?? this.kickSlug,
        youtubeEnabled: youtubeEnabled ?? this.youtubeEnabled,
        twitchEnabled: twitchEnabled ?? this.twitchEnabled,
        kickEnabled: kickEnabled ?? this.kickEnabled,
        fontSize: fontSize ?? this.fontSize,
        bgOpacity: bgOpacity ?? this.bgOpacity,
        messageOpacity: messageOpacity ?? this.messageOpacity,
        showAvatars: showAvatars ?? this.showAvatars,
        showPlatformIcons: showPlatformIcons ?? this.showPlatformIcons,
        showBadges: showBadges ?? this.showBadges,
        showYoutubeStreamBadges:
            showYoutubeStreamBadges ?? this.showYoutubeStreamBadges,
        showTimestamp: showTimestamp ?? this.showTimestamp,
        showBubble: showBubble ?? this.showBubble,
        showBubbleShadow: showBubbleShadow ?? this.showBubbleShadow,
        borderRadius: borderRadius ?? this.borderRadius,
        messageGap: messageGap ?? this.messageGap,
        chatTextAlign: chatTextAlign ?? this.chatTextAlign,
        chatMaxMessageWidth: chatMaxMessageWidth ?? this.chatMaxMessageWidth,
        chatHorizontalPadding:
            chatHorizontalPadding ?? this.chatHorizontalPadding,
        chatLineHeight: chatLineHeight ?? this.chatLineHeight,
        chatFontWeight: chatFontWeight ?? this.chatFontWeight,
        chatTextShadow: chatTextShadow ?? this.chatTextShadow,
        chatTextStroke: chatTextStroke ?? this.chatTextStroke,
        maxMessages: maxMessages ?? this.maxMessages,
        blockedUsers: blockedUsers ?? this.blockedUsers,
        blockedWords: blockedWords ?? this.blockedWords,
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        ttsMembersOnly: ttsMembersOnly ?? this.ttsMembersOnly,
        ttsCommandMode: ttsCommandMode ?? this.ttsCommandMode,
        ttsCommandIgnoreCase: ttsCommandIgnoreCase ?? this.ttsCommandIgnoreCase,
        ttsCommandPrefix: ttsCommandPrefix ?? this.ttsCommandPrefix,
        ttsSeparatorText: ttsSeparatorText ?? this.ttsSeparatorText,
        ttsModelId: ttsModelId ?? this.ttsModelId,
        ttsVoice: ttsVoice ?? this.ttsVoice,
        ttsLanguage: ttsLanguage ?? this.ttsLanguage,
        ttsSpeed: ttsSpeed ?? this.ttsSpeed,
        ttsSteps: ttsSteps ?? this.ttsSteps,
        ttsReferenceAudioPath:
            ttsReferenceAudioPath ?? this.ttsReferenceAudioPath,
        ttsReferenceText: ttsReferenceText ?? this.ttsReferenceText,
        liveCaptionsEnabled: liveCaptionsEnabled ?? this.liveCaptionsEnabled,
        liveCaptionsModelId: liveCaptionsModelId ?? this.liveCaptionsModelId,
        liveCaptionsSourceLanguage:
            liveCaptionsSourceLanguage ?? this.liveCaptionsSourceLanguage,
        liveCaptionsTargetLanguage:
            liveCaptionsTargetLanguage ?? this.liveCaptionsTargetLanguage,
        liveCaptionsOverlayEnabled:
            liveCaptionsOverlayEnabled ?? this.liveCaptionsOverlayEnabled,
        liveCaptionsDenoiseEnabled:
            liveCaptionsDenoiseEnabled ?? this.liveCaptionsDenoiseEnabled,
        voiceCommandsEnabled: voiceCommandsEnabled ?? this.voiceCommandsEnabled,
        voiceCommandsWakeWord:
            voiceCommandsWakeWord ?? this.voiceCommandsWakeWord,
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
        overlayShowYoutubeStreamBadges: overlayShowYoutubeStreamBadges ??
            this.overlayShowYoutubeStreamBadges,
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
        obsShowRecordingState:
            obsShowRecordingState ?? this.obsShowRecordingState,
        obsShowRecordingDuration:
            obsShowRecordingDuration ?? this.obsShowRecordingDuration,
        obsShowRecordingSize: obsShowRecordingSize ?? this.obsShowRecordingSize,
      );

  Map<String, dynamic> toJson() => {
        'appLanguageCode': appLanguageCode,
        'youtubeHandle': youtubeHandle,
        'youtubeLiveId': youtubeLiveId,
        'youtubeDualStreamEnabled': youtubeDualStreamEnabled,
        'youtubeHorizontalUrl': youtubeHorizontalUrl,
        'youtubeVerticalUrl': youtubeVerticalUrl,
        'twitchChannel': twitchChannel,
        'kickSlug': kickSlug,
        'youtubeEnabled': youtubeEnabled,
        'twitchEnabled': twitchEnabled,
        'kickEnabled': kickEnabled,
        'fontSize': fontSize,
        'bgOpacity': bgOpacity,
        'messageOpacity': messageOpacity,
        'showAvatars': showAvatars,
        'showPlatformIcons': showPlatformIcons,
        'showBadges': showBadges,
        'showYoutubeStreamBadges': showYoutubeStreamBadges,
        'showTimestamp': showTimestamp,
        'showBubble': showBubble,
        'showBubbleShadow': showBubbleShadow,
        'borderRadius': borderRadius,
        'messageGap': messageGap,
        'chatTextAlign': chatTextAlign,
        'chatMaxMessageWidth': chatMaxMessageWidth,
        'chatHorizontalPadding': chatHorizontalPadding,
        'chatLineHeight': chatLineHeight,
        'chatFontWeight': chatFontWeight,
        'chatTextShadow': chatTextShadow,
        'chatTextStroke': chatTextStroke,
        'maxMessages': maxMessages,
        'blockedUsers': blockedUsers,
        'blockedWords': blockedWords,
        'ttsEnabled': ttsEnabled,
        'ttsMembersOnly': ttsMembersOnly,
        'ttsCommandMode': ttsCommandMode,
        'ttsCommandIgnoreCase': ttsCommandIgnoreCase,
        'ttsCommandPrefix': ttsCommandPrefix,
        'ttsSeparatorText': ttsSeparatorText,
        'ttsModelId': ttsModelId,
        'ttsVoice': ttsVoice,
        'ttsLanguage': ttsLanguage,
        'ttsSpeed': ttsSpeed,
        'ttsSteps': ttsSteps,
        'ttsReferenceAudioPath': ttsReferenceAudioPath,
        'ttsReferenceText': ttsReferenceText,
        'liveCaptionsEnabled': liveCaptionsEnabled,
        'liveCaptionsModelId': liveCaptionsModelId,
        'liveCaptionsSourceLanguage': liveCaptionsSourceLanguage,
        'liveCaptionsTargetLanguage': liveCaptionsTargetLanguage,
        'liveCaptionsOverlayEnabled': liveCaptionsOverlayEnabled,
        'liveCaptionsDenoiseEnabled': liveCaptionsDenoiseEnabled,
        'voiceCommandsEnabled': voiceCommandsEnabled,
        'voiceCommandsWakeWord': voiceCommandsWakeWord,
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
        'overlayShowYoutubeStreamBadges': overlayShowYoutubeStreamBadges,
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
        'obsShowStreamState': obsShowStreamState,
        'obsShowCurrentScene': obsShowCurrentScene,
        'obsShowBitrate': obsShowBitrate,
        'obsShowFps': obsShowFps,
        'obsShowDroppedFrames': obsShowDroppedFrames,
        'obsShowRecordingState': obsShowRecordingState,
        'obsShowRecordingDuration': obsShowRecordingDuration,
        'obsShowRecordingSize': obsShowRecordingSize,
      };

  factory SettingsModel.fromJson(Map<String, dynamic> source) =>
      SettingsModel._fromSanitizedJson(_sanitizeJson(source));

  factory SettingsModel._fromSanitizedJson(Map<String, dynamic> j) =>
      SettingsModel(
        appLanguageCode: j['appLanguageCode'] as String? ?? 'en',
        youtubeHandle: j['youtubeHandle'] as String? ?? '',
        youtubeLiveId: j['youtubeLiveId'] as String? ?? '',
        youtubeDualStreamEnabled:
            j['youtubeDualStreamEnabled'] as bool? ?? false,
        youtubeHorizontalUrl: j['youtubeHorizontalUrl'] as String? ?? '',
        youtubeVerticalUrl: j['youtubeVerticalUrl'] as String? ?? '',
        twitchChannel: j['twitchChannel'] as String? ?? '',
        kickSlug: j['kickSlug'] as String? ?? '',
        youtubeEnabled: j['youtubeEnabled'] as bool? ?? true,
        twitchEnabled: j['twitchEnabled'] as bool? ?? true,
        kickEnabled: j['kickEnabled'] as bool? ?? true,
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14.0,
        bgOpacity: (j['bgOpacity'] as num?)?.toDouble() ?? 0.4,
        messageOpacity: (j['messageOpacity'] as num?)?.toDouble() ?? 1.0,
        showAvatars: j['showAvatars'] as bool? ?? true,
        showPlatformIcons: j['showPlatformIcons'] as bool? ?? true,
        showBadges: j['showBadges'] as bool? ?? true,
        showYoutubeStreamBadges: j['showYoutubeStreamBadges'] as bool? ?? true,
        showTimestamp: j['showTimestamp'] as bool? ?? false,
        showBubble: j['showBubble'] as bool? ?? true,
        showBubbleShadow: j['showBubbleShadow'] as bool? ?? true,
        borderRadius: (j['borderRadius'] as num?)?.toDouble() ?? 8.0,
        messageGap: (j['messageGap'] as num?)?.toDouble() ?? 4.0,
        chatTextAlign: j['chatTextAlign'] as String? ?? 'left',
        chatMaxMessageWidth:
            (j['chatMaxMessageWidth'] as num?)?.toDouble() ?? 0.82,
        chatHorizontalPadding:
            (j['chatHorizontalPadding'] as num?)?.toDouble() ?? 24.0,
        chatLineHeight: (j['chatLineHeight'] as num?)?.toDouble() ?? 1.5,
        chatFontWeight: (j['chatFontWeight'] as num?)?.toDouble() ?? 400.0,
        chatTextShadow: j['chatTextShadow'] as bool? ?? false,
        chatTextStroke: (j['chatTextStroke'] as num?)?.toDouble() ?? 0.0,
        maxMessages: j['maxMessages'] as int? ?? 200,
        blockedUsers: List<String>.from(j['blockedUsers'] as List? ?? []),
        blockedWords: List<String>.from(j['blockedWords'] as List? ?? []),
        ttsEnabled: j['ttsEnabled'] as bool? ?? false,
        ttsMembersOnly: j['ttsMembersOnly'] as bool? ?? false,
        ttsCommandMode: j['ttsCommandMode'] as bool? ?? false,
        ttsCommandIgnoreCase: j['ttsCommandIgnoreCase'] as bool? ?? true,
        ttsCommandPrefix: j['ttsCommandPrefix'] as String? ?? '!v',
        ttsSeparatorText: j['ttsSeparatorText'] as String? ?? '',
        ttsModelId: j['ttsModelId'] as String? ?? 'supertonic-3-hybrid',
        ttsVoice: j['ttsVoice'] as String? ?? 'M1',
        ttsLanguage: j['ttsLanguage'] as String? ?? 'es',
        ttsSpeed: (j['ttsSpeed'] as num?)?.toDouble() ?? 1.05,
        ttsSteps: (j['ttsSteps'] as num?)?.round() ?? 8,
        ttsReferenceAudioPath: j['ttsReferenceAudioPath'] as String? ?? '',
        ttsReferenceText: j['ttsReferenceText'] as String? ?? '',
        liveCaptionsEnabled: j['liveCaptionsEnabled'] as bool? ?? false,
        liveCaptionsModelId:
            j['liveCaptionsModelId'] as String? ?? 'canary-180m-int8',
        liveCaptionsSourceLanguage:
            j['liveCaptionsSourceLanguage'] as String? ?? 'es',
        liveCaptionsTargetLanguage:
            j['liveCaptionsTargetLanguage'] as String? ?? 'es',
        liveCaptionsOverlayEnabled:
            j['liveCaptionsOverlayEnabled'] as bool? ?? true,
        liveCaptionsDenoiseEnabled:
            j['liveCaptionsDenoiseEnabled'] as bool? ?? true,
        voiceCommandsEnabled: j['voiceCommandsEnabled'] as bool? ?? false,
        voiceCommandsWakeWord:
            j['voiceCommandsWakeWord'] as String? ?? 'airstream',
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
        overlayShowYoutubeStreamBadges:
            j['overlayShowYoutubeStreamBadges'] as bool? ?? true,
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
        obsShowRecordingState: j['obsShowRecordingState'] as bool? ?? true,
        obsShowRecordingDuration:
            j['obsShowRecordingDuration'] as bool? ?? true,
        obsShowRecordingSize: j['obsShowRecordingSize'] as bool? ?? false,
      );

  static Map<String, dynamic> _sanitizeJson(Map<String, dynamic> source) {
    final schema = const SettingsModel().toJson();
    final sanitized = <String, dynamic>{};

    for (final entry in source.entries) {
      final expected = schema[entry.key];
      final value = entry.value;
      if (entry.key == 'obsPassword') {
        if (value is String) sanitized[entry.key] = value;
        continue;
      }
      if (expected == null) continue;
      if (expected is bool && value is bool) {
        sanitized[entry.key] = value;
      } else if (expected is int && value is num && value.isFinite) {
        sanitized[entry.key] = value.round();
      } else if (expected is double && value is num && value.isFinite) {
        sanitized[entry.key] = value.toDouble();
      } else if (expected is String && value is String) {
        sanitized[entry.key] = value;
      } else if (expected is List && value is List) {
        sanitized[entry.key] = value.whereType<String>().toList();
      }
    }

    void clampDouble(String key, double minimum, double maximum) {
      final fallback = schema[key]! as num;
      final value = (sanitized[key] as num?) ?? fallback;
      sanitized[key] = value.toDouble().clamp(minimum, maximum);
    }

    void clampInt(String key, int minimum, int maximum) {
      final fallback = schema[key]! as num;
      final value = ((sanitized[key] as num?) ?? fallback).round();
      sanitized[key] = value.clamp(minimum, maximum);
    }

    void allow(String key, Set<String> values, String fallback) {
      if (!values.contains(sanitized[key])) sanitized[key] = fallback;
    }

    void color(String key, String fallback) {
      final value = sanitized[key];
      if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
        sanitized[key] = fallback;
      }
    }

    allow('appLanguageCode', const {'en', 'es'}, 'en');
    allow('chatTextAlign', const {'left', 'center', 'right'}, 'left');
    allow('overlayTextAlign', const {'left', 'center', 'right'}, 'left');
    allow(
      'overlayAnimation',
      const {'slide-up', 'slide-left', 'fade-in', 'zoom-in'},
      'slide-up',
    );
    allow(
        'liveCaptionsModelId', const {'canary-180m-int8'}, 'canary-180m-int8');
    allow('liveCaptionsSourceLanguage', const {'es', 'en'}, 'es');
    allow('liveCaptionsTargetLanguage', const {'es', 'en'}, 'es');

    clampInt('overlayPort', 1, 65535);
    clampInt('maxMessages', 1, 1000);
    clampInt('overlayMaxMessages', 1, 500);
    clampInt('overlayMessageTtlSeconds', 1, 3600);
    clampInt('ttsSteps', 1, 64);
    clampInt('alertDisplaySeconds', 1, 60);

    clampDouble('fontSize', 10, 28);
    clampDouble('bgOpacity', 0, 1);
    clampDouble('messageOpacity', 0, 1);
    clampDouble('borderRadius', 0, 40);
    clampDouble('messageGap', 0, 40);
    clampDouble('chatMaxMessageWidth', 0.4, 1);
    clampDouble('chatHorizontalPadding', 0, 80);
    clampDouble('chatLineHeight', 1, 2);
    clampDouble('chatFontWeight', 100, 900);
    clampDouble('chatTextStroke', 0, 8);
    clampDouble('ttsSpeed', 0.5, 2);
    clampDouble('overlayFontSize', 10, 72);
    clampDouble('overlayBgOpacity', 0, 1);
    clampDouble('overlayMessageOpacity', 0, 1);
    clampDouble('overlayTextStroke', 0, 8);
    clampDouble('overlayLineHeight', 1, 2);
    clampDouble('overlayMessageGap', 0, 80);
    clampDouble('overlayFontWeight', 100, 900);
    clampDouble('overlayBorderRadius', 0, 80);
    clampDouble('overlaySuperChatBarWidth', 1, 8);
    clampDouble('overlayAnimationDuration', 0.1, 2);
    clampDouble('overlayPerspective', 100, 2000);
    clampDouble('overlayRotateX', -180, 180);
    clampDouble('overlayRotateY', -180, 180);
    clampDouble('overlayRotateZ', -180, 180);
    clampDouble('overlaySkewX', -60, 60);
    clampDouble('overlayScale', 0.25, 3);
    clampDouble('alertFontSize', 12, 72);

    color('overlayChromaColor', '#00FF00');
    color('overlayTextStrokeColor', '#000000');
    color('overlaySuperChatBarColor', '#1DE9B6');
    return sanitized;
  }

  factory SettingsModel.fromJsonString(String s) {
    final decoded = jsonDecode(s);
    return decoded is Map<String, dynamic>
        ? SettingsModel.fromJson(decoded)
        : const SettingsModel();
  }

  String toJsonString() => jsonEncode(toJson());
}

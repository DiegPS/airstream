import 'settings_model_codec.dart';

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

  Map<String, dynamic> toJson() => SettingsModelCodec.toJson(this);

  factory SettingsModel.fromJson(Map<String, dynamic> source) =>
      SettingsModelCodec.fromJson(source);

  factory SettingsModel.fromJsonString(String source) =>
      SettingsModelCodec.fromJsonString(source);

  String toJsonString() => SettingsModelCodec.toJsonString(this);
}

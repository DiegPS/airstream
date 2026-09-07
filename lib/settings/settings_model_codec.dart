import 'dart:convert';

import 'settings_model.dart';

abstract final class SettingsModelCodec {
  static Map<String, dynamic> toJson(SettingsModel model) => {
        'appLanguageCode': model.appLanguageCode,
        'youtubeHandle': model.youtubeHandle,
        'youtubeLiveId': model.youtubeLiveId,
        'youtubeDualStreamEnabled': model.youtubeDualStreamEnabled,
        'youtubeHorizontalUrl': model.youtubeHorizontalUrl,
        'youtubeVerticalUrl': model.youtubeVerticalUrl,
        'twitchChannel': model.twitchChannel,
        'kickSlug': model.kickSlug,
        'youtubeEnabled': model.youtubeEnabled,
        'twitchEnabled': model.twitchEnabled,
        'kickEnabled': model.kickEnabled,
        'fontSize': model.fontSize,
        'bgOpacity': model.bgOpacity,
        'messageOpacity': model.messageOpacity,
        'showAvatars': model.showAvatars,
        'showPlatformIcons': model.showPlatformIcons,
        'showBadges': model.showBadges,
        'showYoutubeStreamBadges': model.showYoutubeStreamBadges,
        'showTimestamp': model.showTimestamp,
        'showBubble': model.showBubble,
        'showBubbleShadow': model.showBubbleShadow,
        'borderRadius': model.borderRadius,
        'messageGap': model.messageGap,
        'chatTextAlign': model.chatTextAlign,
        'chatMaxMessageWidth': model.chatMaxMessageWidth,
        'chatHorizontalPadding': model.chatHorizontalPadding,
        'chatLineHeight': model.chatLineHeight,
        'chatFontWeight': model.chatFontWeight,
        'chatTextShadow': model.chatTextShadow,
        'chatTextStroke': model.chatTextStroke,
        'maxMessages': model.maxMessages,
        'providerEventBannerKinds': model.providerEventBannerKinds,
        'providerEventBannerSeconds': model.providerEventBannerSeconds,
        'blockedUsers': model.blockedUsers,
        'blockedWords': model.blockedWords,
        'ttsEnabled': model.ttsEnabled,
        'ttsMembersOnly': model.ttsMembersOnly,
        'ttsCommandMode': model.ttsCommandMode,
        'ttsCommandIgnoreCase': model.ttsCommandIgnoreCase,
        'ttsCommandPrefix': model.ttsCommandPrefix,
        'ttsSeparatorText': model.ttsSeparatorText,
        'ttsModelId': model.ttsModelId,
        'ttsVoice': model.ttsVoice,
        'ttsLanguage': model.ttsLanguage,
        'ttsSpeed': model.ttsSpeed,
        'ttsSteps': model.ttsSteps,
        'ttsReferenceAudioPath': model.ttsReferenceAudioPath,
        'ttsReferenceText': model.ttsReferenceText,
        'liveCaptionsEnabled': model.liveCaptionsEnabled,
        'liveCaptionsModelId': model.liveCaptionsModelId,
        'liveCaptionsSourceLanguage': model.liveCaptionsSourceLanguage,
        'liveCaptionsTargetLanguage': model.liveCaptionsTargetLanguage,
        'liveCaptionsOverlayEnabled': model.liveCaptionsOverlayEnabled,
        'liveCaptionsDenoiseEnabled': model.liveCaptionsDenoiseEnabled,
        'voiceCommandsEnabled': model.voiceCommandsEnabled,
        'voiceCommandsWakeWord': model.voiceCommandsWakeWord,
        'overlayPort': model.overlayPort,
        'overlayEnabled': model.overlayEnabled,
        'overlayChromaMode': model.overlayChromaMode,
        'overlayChromaColor': model.overlayChromaColor,
        'overlayShowGrid': model.overlayShowGrid,
        'overlayHideScrollbar': model.overlayHideScrollbar,
        'overlayFontSize': model.overlayFontSize,
        'overlayBgOpacity': model.overlayBgOpacity,
        'overlayMessageOpacity': model.overlayMessageOpacity,
        'overlayShowAvatars': model.overlayShowAvatars,
        'overlayShowPlatformIcons': model.overlayShowPlatformIcons,
        'overlayShowBadges': model.overlayShowBadges,
        'overlayShowYoutubeStreamBadges': model.overlayShowYoutubeStreamBadges,
        'overlayShowTimestamp': model.overlayShowTimestamp,
        'overlayTextStroke': model.overlayTextStroke,
        'overlayTextStrokeColor': model.overlayTextStrokeColor,
        'overlayLineHeight': model.overlayLineHeight,
        'overlayMessageGap': model.overlayMessageGap,
        'overlayFontWeight': model.overlayFontWeight,
        'overlayBorderRadius': model.overlayBorderRadius,
        'overlayTextShadow': model.overlayTextShadow,
        'overlayShowBubble': model.overlayShowBubble,
        'overlaySuperChatBarEnabled': model.overlaySuperChatBarEnabled,
        'overlaySuperChatBarColor': model.overlaySuperChatBarColor,
        'overlaySuperChatBarWidth': model.overlaySuperChatBarWidth,
        'overlayMaxMessages': model.overlayMaxMessages,
        'overlayMessageTtlSeconds': model.overlayMessageTtlSeconds,
        'overlayAnimation': model.overlayAnimation,
        'overlayAnimationDuration': model.overlayAnimationDuration,
        'overlayTextAlign': model.overlayTextAlign,
        'overlayTwitchBubbleAccent': model.overlayTwitchBubbleAccent,
        'overlayKickBubbleAccent': model.overlayKickBubbleAccent,
        'overlayThreeDEnabled': model.overlayThreeDEnabled,
        'overlayPerspective': model.overlayPerspective,
        'overlayRotateX': model.overlayRotateX,
        'overlayRotateY': model.overlayRotateY,
        'overlayRotateZ': model.overlayRotateZ,
        'overlaySkewX': model.overlaySkewX,
        'overlayScale': model.overlayScale,
        'alertFontSize': model.alertFontSize,
        'alertDisplaySeconds': model.alertDisplaySeconds,
        'alertShowAvatars': model.alertShowAvatars,
        'obsEnabled': model.obsEnabled,
        'obsHost': model.obsHost,
        'obsShowStreamState': model.obsShowStreamState,
        'obsShowCurrentScene': model.obsShowCurrentScene,
        'obsShowBitrate': model.obsShowBitrate,
        'obsShowFps': model.obsShowFps,
        'obsShowDroppedFrames': model.obsShowDroppedFrames,
        'obsShowRecordingState': model.obsShowRecordingState,
        'obsShowRecordingDuration': model.obsShowRecordingDuration,
        'obsShowRecordingSize': model.obsShowRecordingSize,
      };

  static SettingsModel fromJson(Map<String, dynamic> source) {
    final j = _sanitizeJson(source);
    return SettingsModel(
      appLanguageCode: j['appLanguageCode'] as String? ?? 'en',
      youtubeHandle: j['youtubeHandle'] as String? ?? '',
      youtubeLiveId: j['youtubeLiveId'] as String? ?? '',
      youtubeDualStreamEnabled: j['youtubeDualStreamEnabled'] as bool? ?? false,
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
      providerEventBannerKinds: List<String>.from(
        j['providerEventBannerKinds'] as List? ??
            defaultProviderEventBannerKinds,
      ),
      providerEventBannerSeconds: j['providerEventBannerSeconds'] as int? ?? 6,
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
      overlayShowPlatformIcons: j['overlayShowPlatformIcons'] as bool? ?? true,
      overlayShowBadges: j['overlayShowBadges'] as bool? ?? true,
      overlayShowYoutubeStreamBadges:
          j['overlayShowYoutubeStreamBadges'] as bool? ?? true,
      overlayShowTimestamp: j['overlayShowTimestamp'] as bool? ?? false,
      overlayTextStroke: (j['overlayTextStroke'] as num?)?.toDouble() ?? 0.0,
      overlayTextStrokeColor:
          j['overlayTextStrokeColor'] as String? ?? '#000000',
      overlayLineHeight: (j['overlayLineHeight'] as num?)?.toDouble() ?? 1.5,
      overlayMessageGap: (j['overlayMessageGap'] as num?)?.toDouble() ?? 15.0,
      overlayFontWeight: (j['overlayFontWeight'] as num?)?.toDouble() ?? 400.0,
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
      obsShowRecordingDuration: j['obsShowRecordingDuration'] as bool? ?? true,
      obsShowRecordingSize: j['obsShowRecordingSize'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _sanitizeJson(Map<String, dynamic> source) {
    final schema = toJson(const SettingsModel());
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
    clampInt('providerEventBannerSeconds', 1, 60);
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
    final bannerKinds = sanitized['providerEventBannerKinds'];
    sanitized['providerEventBannerKinds'] = bannerKinds is List
        ? bannerKinds
            .where(defaultProviderEventBannerKinds.contains)
            .toSet()
            .toList()
        : defaultProviderEventBannerKinds;
    return sanitized;
  }

  static SettingsModel fromJsonString(String source) {
    final decoded = jsonDecode(source);
    return decoded is Map<String, dynamic>
        ? fromJson(decoded)
        : const SettingsModel();
  }

  static String toJsonString(SettingsModel model) => jsonEncode(toJson(model));
}

import 'package:airstream/settings/overlay_style_presets.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _visualKeys = {
  'overlayFontSize',
  'overlayBgOpacity',
  'overlayMessageOpacity',
  'overlayShowAvatars',
  'overlayShowPlatformIcons',
  'overlayShowBadges',
  'overlayShowYoutubeStreamBadges',
  'overlayShowTimestamp',
  'overlayTextStroke',
  'overlayTextStrokeColor',
  'overlayLineHeight',
  'overlayMessageGap',
  'overlayFontWeight',
  'overlayBorderRadius',
  'overlayTextShadow',
  'overlayShowBubble',
  'overlaySuperChatBarEnabled',
  'overlaySuperChatBarColor',
  'overlaySuperChatBarWidth',
  'overlayAnimation',
  'overlayAnimationDuration',
  'overlayTextAlign',
  'overlayTwitchBubbleAccent',
  'overlayKickBubbleAccent',
  'overlayThreeDEnabled',
  'overlayPerspective',
  'overlayRotateX',
  'overlayRotateY',
  'overlayRotateZ',
  'overlaySkewX',
  'overlayScale',
  'alertFontSize',
  'alertShowAvatars',
};
Map<String, dynamic> _visual(SettingsModel s) =>
    s.toJson()..removeWhere((key, _) => !_visualKeys.contains(key));
Map<String, dynamic> _other(SettingsModel s) =>
    s.toJson()..removeWhere((key, _) => _visualKeys.contains(key));

SettingsModel _different() {
  const d = SettingsModel();
  return d.copyWith(
    appLanguageCode: '${d.appLanguageCode}-custom',
    youtubeHandle: '${d.youtubeHandle}-custom',
    youtubeLiveId: '${d.youtubeLiveId}-custom',
    youtubeDualStreamEnabled: !d.youtubeDualStreamEnabled,
    youtubeHorizontalUrl: '${d.youtubeHorizontalUrl}-custom',
    youtubeVerticalUrl: '${d.youtubeVerticalUrl}-custom',
    twitchChannel: '${d.twitchChannel}-custom',
    kickSlug: '${d.kickSlug}-custom',
    youtubeEnabled: !d.youtubeEnabled,
    twitchEnabled: !d.twitchEnabled,
    kickEnabled: !d.kickEnabled,
    fontSize: d.fontSize + 1,
    bgOpacity: d.bgOpacity + 1,
    messageOpacity: d.messageOpacity + 1,
    showAvatars: !d.showAvatars,
    showPlatformIcons: !d.showPlatformIcons,
    showBadges: !d.showBadges,
    showYoutubeStreamBadges: !d.showYoutubeStreamBadges,
    showTimestamp: !d.showTimestamp,
    showBubble: !d.showBubble,
    showBubbleShadow: !d.showBubbleShadow,
    borderRadius: d.borderRadius + 1,
    messageGap: d.messageGap + 1,
    chatTextAlign: '${d.chatTextAlign}-custom',
    chatMaxMessageWidth: d.chatMaxMessageWidth + 1,
    chatHorizontalPadding: d.chatHorizontalPadding + 1,
    chatLineHeight: d.chatLineHeight + 1,
    chatFontWeight: d.chatFontWeight + 1,
    chatTextShadow: !d.chatTextShadow,
    chatTextStroke: d.chatTextStroke + 1,
    maxMessages: d.maxMessages + 1,
    providerEventBannerKinds: ['raid'],
    providerEventBannerSeconds: d.providerEventBannerSeconds + 1,
    blockedUsers: ['raid'],
    blockedWords: ['raid'],
    highlightMentions: !d.highlightMentions,
    highlightWords: ['raid'],
    highlightSound: !d.highlightSound,
    highlightFirstMessages: !d.highlightFirstMessages,
    saveChatLog: !d.saveChatLog,
    shortcutSilenceTts: '${d.shortcutSilenceTts}-custom',
    shortcutToggleTts: '${d.shortcutToggleTts}-custom',
    profiles: {
      'Gaming': {'fontSize': 22}
    },
    ttsEnabled: !d.ttsEnabled,
    ttsMembersOnly: !d.ttsMembersOnly,
    ttsCommandMode: !d.ttsCommandMode,
    ttsCommandIgnoreCase: !d.ttsCommandIgnoreCase,
    ttsCommandPrefix: '${d.ttsCommandPrefix}-custom',
    ttsSeparatorText: '${d.ttsSeparatorText}-custom',
    ttsModelId: '${d.ttsModelId}-custom',
    ttsVoice: '${d.ttsVoice}-custom',
    ttsLanguage: '${d.ttsLanguage}-custom',
    ttsSpeed: d.ttsSpeed + 1,
    ttsSteps: d.ttsSteps + 1,
    ttsUserCooldownSeconds: d.ttsUserCooldownSeconds + 1,
    ttsIgnoredUsers: ['raid'],
    ttsMaxCharacters: d.ttsMaxCharacters + 1,
    ttsReferenceAudioPath: '${d.ttsReferenceAudioPath}-custom',
    ttsReferenceText: '${d.ttsReferenceText}-custom',
    liveCaptionsEnabled: !d.liveCaptionsEnabled,
    liveCaptionsModelId: '${d.liveCaptionsModelId}-custom',
    liveCaptionsSourceLanguage: '${d.liveCaptionsSourceLanguage}-custom',
    liveCaptionsTargetLanguage: '${d.liveCaptionsTargetLanguage}-custom',
    liveCaptionsOverlayEnabled: !d.liveCaptionsOverlayEnabled,
    liveCaptionsDenoiseEnabled: !d.liveCaptionsDenoiseEnabled,
    voiceCommandsEnabled: !d.voiceCommandsEnabled,
    voiceCommandsWakeWord: '${d.voiceCommandsWakeWord}-custom',
    overlayPort: d.overlayPort + 1,
    overlayEnabled: !d.overlayEnabled,
    overlayChromaMode: !d.overlayChromaMode,
    overlayChromaColor: '#112233',
    overlayShowGrid: !d.overlayShowGrid,
    overlayHideScrollbar: !d.overlayHideScrollbar,
    overlayMaxMessages: 200,
    overlayMessageTtlSeconds: 60,
    alertDisplaySeconds: 12,
    alertDisabledTypes: ['raid'],
    alertPosition: 'bottom',
    alertLayout: 'stacked',
    alertAnimation: 'zoom',
    alertTypeOptions: const {
      'raid': {'seconds': 12},
    },
    connectChatOnLaunch: !d.connectChatOnLaunch,
    obsEnabled: !d.obsEnabled,
    obsConnectOnLaunch: !d.obsConnectOnLaunch,
    obsHost: '${d.obsHost}-custom',
    obsPassword: '${d.obsPassword}-custom',
    obsShowStreamState: !d.obsShowStreamState,
    obsShowCurrentScene: !d.obsShowCurrentScene,
    obsShowBitrate: !d.obsShowBitrate,
    obsShowFps: !d.obsShowFps,
    obsShowDroppedFrames: !d.obsShowDroppedFrames,
    obsShowRecordingState: !d.obsShowRecordingState,
    obsShowRecordingDuration: !d.obsShowRecordingDuration,
    obsShowRecordingSize: !d.obsShowRecordingSize,
    overlayFontSize: 31,
    overlayRotateX: 42,
    overlayScale: 1.7,
    overlayThreeDEnabled: true,
  );
}

void main() {
  for (final preset in OverlayStylePreset.values) {
    test('${preset.name} survives storage and preserves every non-visual field',
        () {
      final current = _different();
      final defaults = _other(const SettingsModel());
      for (final entry in _other(current).entries) {
        expect(entry.value, isNot(equals(defaults[entry.key])),
            reason: entry.key);
      }
      final applied = OverlayStylePresets.apply(current, preset);
      expect(_visual(SettingsModel.fromJsonString(applied.toJsonString())),
          _visual(applied));
      expect(_other(applied), _other(current));
      expect(_visual(applied),
          _visual(OverlayStylePresets.apply(const SettingsModel(), preset)));
      expect(OverlayStylePresets.matching(applied), preset);
      expect(OverlayStylePresets.matching(applied.copyWith(overlayRotateZ: 1)),
          isNull);
      expect(
          OverlayStylePresets.matching(applied.copyWith(
              overlayFontSize: applied.overlayFontSize + 0.00005)),
          preset);
    });
  }
  test('classic matches defaults and the five styles are distinct', () {
    expect(OverlayStylePresets.matching(const SettingsModel()),
        OverlayStylePreset.classic);
    final styles = [
      for (final p in OverlayStylePreset.values)
        _visual(OverlayStylePresets.apply(const SettingsModel(), p))
    ];
    for (var i = 0; i < styles.length; i++) {
      for (var j = i + 1; j < styles.length; j++) {
        expect(styles[i], isNot(equals(styles[j])));
      }
    }
  });
  test('undo restores all visual fields and keeps subsequent non-visual edits',
      () {
    final previous = _different();
    for (final p in OverlayStylePreset.values) {
      final current = OverlayStylePresets.apply(previous, p)
          .copyWith(twitchChannel: 'changed-live', alertDisplaySeconds: 9);
      final restored = OverlayStylePresets.restoreVisual(current, previous);
      expect(_visual(restored), _visual(previous));
      expect(_other(restored), _other(current));
    }
  });
}

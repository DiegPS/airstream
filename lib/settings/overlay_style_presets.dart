import 'settings_model.dart';

enum OverlayStylePreset {
  classic,
  compactGaming,
  bigBubbles,
  cleanTransparent,
  vertical
}

/// Visual-only styles shared by the OBS chat and alerts pages.
abstract final class OverlayStylePresets {
  static SettingsModel apply(
          SettingsModel current, OverlayStylePreset preset) =>
      restoreVisual(current, _settings(preset));

  static SettingsModel _settings(OverlayStylePreset preset) {
    const defaults = SettingsModel();
    return switch (preset) {
      OverlayStylePreset.classic => defaults,
      OverlayStylePreset.compactGaming => defaults.copyWith(
          overlayFontSize: 12,
          overlayMessageOpacity: 0.55,
          overlayShowAvatars: false,
          overlayShowTimestamp: false,
          overlayLineHeight: 1.3,
          overlayMessageGap: 6,
          overlayFontWeight: 500,
          overlayBorderRadius: 8,
          overlaySuperChatBarWidth: 2,
          overlayAnimation: 'fade-in',
          overlayAnimationDuration: 0.25,
          alertFontSize: 22,
          alertShowAvatars: false,
        ),
      OverlayStylePreset.bigBubbles => defaults.copyWith(
          overlayFontSize: 20,
          overlayMessageOpacity: 0.6,
          overlayLineHeight: 1.45,
          overlayMessageGap: 18,
          overlayFontWeight: 600,
          overlayBorderRadius: 22,
          overlayAnimation: 'slide-up',
          overlayAnimationDuration: 0.45,
          alertFontSize: 34,
        ),
      OverlayStylePreset.cleanTransparent => defaults.copyWith(
          overlayFontSize: 16,
          overlayBgOpacity: 0,
          overlayMessageOpacity: 0,
          overlayShowBubble: false,
          overlayShowAvatars: false,
          overlayShowBadges: false,
          overlayTextShadow: true,
          overlayTextStroke: 1.5,
          overlayTextStrokeColor: '#000000',
          overlayFontWeight: 700,
          overlayMessageGap: 8,
          overlayTwitchBubbleAccent: false,
          overlayKickBubbleAccent: false,
          overlayAnimation: 'fade-in',
          overlayAnimationDuration: 0.3,
        ),
      OverlayStylePreset.vertical => defaults.copyWith(
          overlayFontSize: 18,
          overlayMessageOpacity: 0.5,
          overlayShowTimestamp: false,
          overlayLineHeight: 1.35,
          overlayMessageGap: 10,
          overlayFontWeight: 600,
          overlayBorderRadius: 14,
          overlayAnimation: 'slide-left',
          overlayAnimationDuration: 0.35,
          alertFontSize: 24,
        ),
    };
  }

  /// Restores appearance while preserving the current connections and behavior.
  static SettingsModel restoreVisual(
          SettingsModel current, SettingsModel previous) =>
      current.copyWith(
        chatFontFamily: previous.chatFontFamily,
        chatFontInstalledOnly: previous.chatFontInstalledOnly,
        nameColorMode: previous.nameColorMode,
        nameColorSingle: previous.nameColorSingle,
        nameRoleColors: previous.nameRoleColors,
        nameReadability: previous.nameReadability,
        overlayFontSize: previous.overlayFontSize,
        overlayBgOpacity: previous.overlayBgOpacity,
        overlayMessageOpacity: previous.overlayMessageOpacity,
        overlayShowAvatars: previous.overlayShowAvatars,
        overlayShowPlatformIcons: previous.overlayShowPlatformIcons,
        overlayShowBadges: previous.overlayShowBadges,
        overlayShowYoutubeStreamBadges: previous.overlayShowYoutubeStreamBadges,
        overlayShowTimestamp: previous.overlayShowTimestamp,
        overlayTextStroke: previous.overlayTextStroke,
        overlayTextStrokeColor: previous.overlayTextStrokeColor,
        overlayLineHeight: previous.overlayLineHeight,
        overlayMessageGap: previous.overlayMessageGap,
        overlayFontWeight: previous.overlayFontWeight,
        overlayBorderRadius: previous.overlayBorderRadius,
        overlayTextShadow: previous.overlayTextShadow,
        overlayShowBubble: previous.overlayShowBubble,
        overlaySuperChatBarEnabled: previous.overlaySuperChatBarEnabled,
        overlaySuperChatBarColor: previous.overlaySuperChatBarColor,
        overlaySuperChatBarWidth: previous.overlaySuperChatBarWidth,
        overlayAnimation: previous.overlayAnimation,
        overlayAnimationDuration: previous.overlayAnimationDuration,
        overlayTextAlign: previous.overlayTextAlign,
        overlayTwitchBubbleAccent: previous.overlayTwitchBubbleAccent,
        overlayKickBubbleAccent: previous.overlayKickBubbleAccent,
        overlayThreeDEnabled: previous.overlayThreeDEnabled,
        overlayPerspective: previous.overlayPerspective,
        overlayRotateX: previous.overlayRotateX,
        overlayRotateY: previous.overlayRotateY,
        overlayRotateZ: previous.overlayRotateZ,
        overlaySkewX: previous.overlaySkewX,
        overlayScale: previous.overlayScale,
        featuredPosition: previous.featuredPosition,
        featuredFontScale: previous.featuredFontScale,
        alertFontSize: previous.alertFontSize,
        alertShowAvatars: previous.alertShowAvatars,
      );

  static OverlayStylePreset? matching(SettingsModel settings) {
    final actual = _visualValues(settings);
    for (final preset in OverlayStylePreset.values) {
      final expected = _visualValues(_settings(preset));
      if (List.generate(actual.length, (i) {
        final a = actual[i];
        final b = expected[i];
        return a is double && b is double ? (a - b).abs() <= 0.0001 : a == b;
      }).every((equal) => equal)) {
        return preset;
      }
    }
    return null;
  }

  static List<Object> _visualValues(SettingsModel s) => [
        s.chatFontFamily,
        s.chatFontInstalledOnly,
        s.nameColorMode,
        s.nameColorSingle,
        s.nameRoleColors,
        s.nameReadability,
        s.overlayFontSize,
        s.overlayBgOpacity,
        s.overlayMessageOpacity,
        s.overlayShowAvatars,
        s.overlayShowPlatformIcons,
        s.overlayShowBadges,
        s.overlayShowYoutubeStreamBadges,
        s.overlayShowTimestamp,
        s.overlayTextStroke,
        s.overlayTextStrokeColor,
        s.overlayLineHeight,
        s.overlayMessageGap,
        s.overlayFontWeight,
        s.overlayBorderRadius,
        s.overlayTextShadow,
        s.overlayShowBubble,
        s.overlaySuperChatBarEnabled,
        s.overlaySuperChatBarColor,
        s.overlaySuperChatBarWidth,
        s.overlayAnimation,
        s.overlayAnimationDuration,
        s.overlayTextAlign,
        s.overlayTwitchBubbleAccent,
        s.overlayKickBubbleAccent,
        s.overlayThreeDEnabled,
        s.overlayPerspective,
        s.overlayRotateX,
        s.overlayRotateY,
        s.overlayRotateZ,
        s.overlaySkewX,
        s.overlayScale,
        s.featuredPosition,
        s.featuredFontScale,
        s.alertFontSize,
        s.alertShowAvatars,
      ];
}

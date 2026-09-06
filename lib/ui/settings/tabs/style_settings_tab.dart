part of 'package:airstream/ui/chat_screen.dart';

extension _StyleSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildStyleTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.appearance,
          icon: Icons.format_size_rounded,
          children: [
            StyledSliderRow(
              label: l.fontSize,
              value: s.fontSize,
              min: 10,
              max: 28,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(fontSize: v)),
            ),
            StyledSliderRow(
              label: l.lineHeight,
              value: s.chatLineHeight,
              min: 1,
              max: 2,
              onChanged: (v) => notifier.update(s.copyWith(chatLineHeight: v)),
            ),
            StyledSliderRow(
              label: l.fontWeight,
              value: s.chatFontWeight,
              min: 100,
              max: 900,
              divisions: 8,
              onChanged: (v) => notifier.update(s.copyWith(chatFontWeight: v)),
            ),
            _SettingsSidebarState._dropdownRow(
              l.textAlignment,
              s.chatTextAlign,
              const ['left', 'center', 'right'],
              (v) => notifier.update(s.copyWith(chatTextAlign: v)),
              optionLabel: (v) => _SettingsSidebarState._alignmentLabel(l, v),
            ),
            StyledSliderRow(
              label: l.maxMessageWidth,
              value: s.chatMaxMessageWidth,
              min: 0.4,
              max: 1.0,
              unit: '%',
              onChanged: (v) =>
                  notifier.update(s.copyWith(chatMaxMessageWidth: v)),
            ),
            StyledSliderRow(
              label: l.horizontalPadding,
              value: s.chatHorizontalPadding,
              min: 0,
              max: 64,
              unit: 'px',
              onChanged: (v) =>
                  notifier.update(s.copyWith(chatHorizontalPadding: v)),
            ),
          ],
        ),
        UiCard(
          title: l.messageDesign,
          icon: Icons.layers_outlined,
          children: [
            StyledSliderRow(
              label: l.backgroundOpacity,
              value: s.bgOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(bgOpacity: v)),
            ),
            StyledSliderRow(
              label: l.bubbleOpacity,
              value: s.messageOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(messageOpacity: v)),
            ),
            StyledSliderRow(
              label: l.borderRadius,
              value: s.borderRadius,
              min: 0,
              max: 24,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(borderRadius: v)),
            ),
            StyledSliderRow(
              label: l.messageGap,
              value: s.messageGap,
              min: 0,
              max: 16,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(messageGap: v)),
            ),
            _SettingsSidebarState._switchRow(
              l.bubble,
              s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v)),
            ),
            _SettingsSidebarState._switchRow(
              l.bubbleShadow,
              s.showBubbleShadow,
              (v) => notifier.update(s.copyWith(showBubbleShadow: v)),
            ),
            _SettingsSidebarState._switchRow(
              l.textShadow,
              s.chatTextShadow,
              (v) => notifier.update(s.copyWith(chatTextShadow: v)),
            ),
            StyledSliderRow(
              label: l.textOutline,
              value: s.chatTextStroke,
              min: 0,
              max: 4,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(chatTextStroke: v)),
            ),
          ],
        ),
        UiCard(
          title: l.platformDisplay,
          icon: Icons.account_circle_outlined,
          children: [
            _SettingsSidebarState._switchRow(
              l.avatars,
              s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v)),
            ),
            _SettingsSidebarState._switchRow(
              l.platformIcon,
              s.showPlatformIcons,
              (v) => notifier.update(s.copyWith(showPlatformIcons: v)),
            ),
            _SettingsSidebarState._switchRow(
              l.badges,
              s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v)),
            ),
            if (s.youtubeDualStreamEnabled)
              _SettingsSidebarState._switchRow(
                l.youtubeStreamBadges,
                s.showYoutubeStreamBadges,
                (v) => notifier.update(
                  s.copyWith(showYoutubeStreamBadges: v),
                ),
              ),
            _SettingsSidebarState._switchRow(
              l.timestamp,
              s.showTimestamp,
              (v) => notifier.update(s.copyWith(showTimestamp: v)),
            ),
          ],
        ),
      ],
    );
  }
}

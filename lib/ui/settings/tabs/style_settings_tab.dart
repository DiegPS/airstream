part of 'package:airstream/ui/chat_screen.dart';

extension _StyleSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildStyleTab(
    WidgetRef ref,
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _previewCard(ref, l),
        _searchSection('textAndNames',
            _TextAndNamesCard(settings: s, onChanged: notifier.update)),
        UiCard(
          wrapHeader: _searchHeader('appearance'),
          title: l.appearance,
          icon: Icons.format_size_rounded,
          children: [
            StyledSliderRow(
              label: l.fontSize,
              wrapLabel: true,
              value: s.fontSize,
              min: 10,
              max: 28,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(fontSize: v)),
            ),
            StyledSliderRow(
              label: l.lineHeight,
              wrapLabel: true,
              value: s.chatLineHeight,
              min: 1,
              max: 2,
              onChanged: (v) => notifier.update(s.copyWith(chatLineHeight: v)),
            ),
            StyledSliderRow(
              label: l.fontWeight,
              wrapLabel: true,
              value: s.chatFontWeight,
              min: 100,
              max: 900,
              divisions: 8,
              onChanged: (v) => notifier.update(s.copyWith(chatFontWeight: v)),
            ),
            _dropdownRow(
              l.textAlignment,
              s.chatTextAlign,
              const ['left', 'center', 'right'],
              (v) => notifier.update(s.copyWith(chatTextAlign: v)),
              optionLabel: (v) => _alignmentLabel(l, v),
            ),
            StyledSliderRow(
              label: l.maxMessageWidth,
              wrapLabel: true,
              value: s.chatMaxMessageWidth,
              min: 0.4,
              max: 1.0,
              unit: '%',
              onChanged: (v) =>
                  notifier.update(s.copyWith(chatMaxMessageWidth: v)),
            ),
            StyledSliderRow(
              label: l.horizontalPadding,
              wrapLabel: true,
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
          wrapHeader: _searchHeader('messageDesign'),
          title: l.messageDesign,
          icon: Icons.layers_outlined,
          children: [
            StyledSliderRow(
              label: l.backgroundOpacity,
              wrapLabel: true,
              value: s.bgOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(bgOpacity: v)),
            ),
            StyledSliderRow(
              label: l.bubbleOpacity,
              wrapLabel: true,
              value: s.messageOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(messageOpacity: v)),
            ),
            StyledSliderRow(
              label: l.borderRadius,
              wrapLabel: true,
              value: s.borderRadius,
              min: 0,
              max: 24,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(borderRadius: v)),
            ),
            StyledSliderRow(
              label: l.messageGap,
              wrapLabel: true,
              value: s.messageGap,
              min: 0,
              max: 16,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(messageGap: v)),
            ),
            _switchRow(
              l.bubble,
              s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v)),
            ),
            _switchRow(
              l.bubbleShadow,
              s.showBubbleShadow,
              (v) => notifier.update(s.copyWith(showBubbleShadow: v)),
            ),
            _switchRow(
              l.textShadow,
              s.chatTextShadow,
              (v) => notifier.update(s.copyWith(chatTextShadow: v)),
            ),
            StyledSliderRow(
              label: l.textOutline,
              wrapLabel: true,
              value: s.chatTextStroke,
              min: 0,
              max: 4,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(chatTextStroke: v)),
            ),
          ],
        ),
        UiCard(
          wrapHeader: _searchHeader('platformDisplay'),
          title: l.platformDisplay,
          icon: Icons.account_circle_outlined,
          children: [
            _switchRow(
              l.avatars,
              s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v)),
            ),
            _switchRow(
              l.platformIcon,
              s.showPlatformIcons,
              (v) => notifier.update(s.copyWith(showPlatformIcons: v)),
            ),
            _switchRow(
              l.badges,
              s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v)),
            ),
            if (s.youtubeDualStreamEnabled)
              _switchRow(
                l.youtubeStreamBadges,
                s.showYoutubeStreamBadges,
                (v) => notifier.update(
                  s.copyWith(showYoutubeStreamBadges: v),
                ),
              ),
            _switchRow(
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

part of 'package:airstream/ui/chat_screen.dart';

extension _SystemSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildSystemTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    final win = ref.watch(windowStateProvider);
    final winNotifier = ref.read(windowStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.desktopWindow,
          icon: Icons.window_rounded,
          children: [
            _SettingsSidebarState._switchTileWithSubtitle(
              l.clickThrough,
              l.clickThroughDescription,
              win.clickThrough,
              win.globalClickThroughHotKeyRegistered == false
                  ? null
                  : (v) => winNotifier.setClickThrough(v),
              activeThumbColor: const Color(0xFFFFB15C),
            ),
            _SettingsSidebarState._switchTileWithSubtitle(
              l.alwaysOnTop,
              l.alwaysOnTopDescription,
              win.alwaysOnTop,
              (v) => winNotifier.setAlwaysOnTop(v),
            ),
            _SettingsSidebarState._switchTileWithSubtitle(
              l.antiCapture,
              l.antiCaptureDescription,
              win.excludeFromCapture,
              (v) => winNotifier.setExcludeFromCapture(v),
              activeThumbColor: const Color(0xFFBB86FC),
            ),
          ],
        ),
        UiCard(
          title: l.language,
          icon: Icons.language_rounded,
          children: [
            _SettingsSidebarState._dropdownRow(
              l.language,
              s.appLanguageCode,
              const ['en', 'es'],
              (v) => notifier.update(s.copyWith(appLanguageCode: v)),
              optionLabel: (v) => v == 'es' ? l.spanish : l.english,
            ),
          ],
        ),
        UiCard(
          title: l.keyboardShortcuts,
          icon: Icons.keyboard_rounded,
          children: [
            _SettingsSidebarState._shortcutRow(
              'Ctrl + B',
              l.hideSidebarTooltip,
            ),
            _SettingsSidebarState._shortcutRow(
              'Ctrl + Shift + T',
              l.toggleTopBarShortcut,
            ),
            _SettingsSidebarState._shortcutRow(
              'Ctrl + Shift + P',
              l.toggleAlwaysOnTopShortcut,
            ),
            _SettingsSidebarState._shortcutRow(
              'Ctrl + Shift + C',
              l.toggleClickThroughShortcut,
            ),
            if (win.globalClickThroughHotKeyRegistered == false)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.globalClickThroughShortcutUnavailable,
                  style: const TextStyle(
                    color: Color(0xFFFFB15C),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

part of 'package:airstream/ui/chat_screen.dart';

class _DesktopTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DesktopTopBar({
    required this.sidebarVisible,
    required this.onToggleSidebar,
  });

  static const _barHeight = 38.0;
  static const _accent = Color(0xFF53FC18);

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayUrl = ref.watch(overlayUrlProvider);
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final chatRequested = ref.watch(chatConnectionProvider);
    final sessionPhase = ref.watch(chatSessionPhaseProvider);
    final isRunning = sessionPhase == ChatSessionPhase.connecting ||
        sessionPhase == ChatSessionPhase.connected ||
        sessionPhase == ChatSessionPhase.partiallyConnected;
    final hasChannels = (settings.youtubeEnabled &&
            (settings.youtubeHandle.isNotEmpty ||
                settings.youtubeLiveId.isNotEmpty)) ||
        (settings.twitchEnabled && settings.twitchChannel.isNotEmpty) ||
        (settings.kickEnabled && settings.kickSlug.isNotEmpty);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          border: Border(
            bottom: BorderSide(color: Color(0xFF222222)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: _barHeight,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DragToMoveArea(
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _TitleBarCaption(
                      overlayUrl: overlayUrl,
                      showAppName: sidebarVisible,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      _TopBarActionButton(
                        label: isRunning
                            ? l.stop
                            : sessionPhase == ChatSessionPhase.failed
                                ? l.retry
                                : l.start,
                        icon: isRunning
                            ? Icons.stop_circle_rounded
                            : Icons.play_arrow_rounded,
                        enabled: hasChannels,
                        accentColor:
                            isRunning ? const Color(0xFFFF5252) : _accent,
                        onTap: hasChannels
                            ? () {
                                if (isRunning) {
                                  ref
                                      .read(chatConnectionProvider.notifier)
                                      .state = false;
                                } else if (chatRequested) {
                                  ref
                                      .read(appControllerProvider)
                                      .retryChatConnections();
                                } else {
                                  ref
                                      .read(chatConnectionProvider.notifier)
                                      .state = true;
                                }
                              }
                            : null,
                      ),
                      if (sessionPhase == ChatSessionPhase.failed) ...[
                        const SizedBox(width: 6),
                        _TopBarIconButton(
                          tooltip: l.stop,
                          icon: Icons.stop_circle_outlined,
                          active: false,
                          onTap: () => ref
                              .read(chatConnectionProvider.notifier)
                              .state = false,
                        ),
                      ],
                      const SizedBox(width: 6),
                      _TopBarIconButton(
                        tooltip: sidebarVisible
                            ? l.hideSidebarTooltip
                            : l.showSidebarTooltip,
                        icon: sidebarVisible
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        active: sidebarVisible,
                        onTap: onToggleSidebar,
                      ),
                      const SizedBox(width: 6),
                      const WindowControlBar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBarCaption extends StatelessWidget {
  const _TitleBarCaption({
    required this.overlayUrl,
    required this.showAppName,
  });

  final String? overlayUrl;
  final bool showAppName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF53FC18).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: const Color(0xFF53FC18).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.forum_rounded,
              color: Color(0xFF53FC18),
              size: 11,
            ),
          ),
        ),
        if (showAppName) ...[
          const SizedBox(width: 8),
          const Text(
            'AIRSTREAM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 12),
        ] else
          const SizedBox(width: 8),
        _TitleBarCenterStatus(overlayUrl: overlayUrl),
      ],
    );
  }
}

class _TitleBarCenterStatus extends ConsumerWidget {
  const _TitleBarCenterStatus({required this.overlayUrl});

  final String? overlayUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConnectionDots(),
          if (overlayUrl != null) ...[
            const SizedBox(width: 8),
            const Text(
              '•',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                overlayUrl!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.accentColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        enabled ? accentColor.withValues(alpha: 0.16) : Colors.transparent;
    final foregroundColor = enabled ? accentColor : const Color(0xFF5E5E5E);

    return Tooltip(
      message: label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? accentColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foregroundColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = active
        ? const Color(0xFF53FC18).withValues(alpha: 0.15)
        : Colors.transparent;
    final foregroundColor =
        active ? const Color(0xFF53FC18) : const Color(0xFFAAAAAA);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? const Color(0xFF53FC18).withValues(alpha: 0.3)
                    : const Color(0xFF2E2E2E),
              ),
            ),
            child: Icon(icon, size: 15, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _DesktopResizeFrame extends StatelessWidget {
  const _DesktopResizeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragToResizeArea(
      resizeEdgeSize: 8,
      resizeEdgeColor: Colors.transparent,
      child: child,
    );
  }
}

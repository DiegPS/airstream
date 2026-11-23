part of 'package:airstream/ui/chat_screen.dart';

class _ConnectionDots extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final status = ref.watch(connectionStatusProvider);
    // Rebuilds only when the channels change, not on every setting.
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          youtubeConfigured: hasConfiguredYoutubeChat(s),
          youtubeDualStreamEnabled: s.youtubeDualStreamEnabled,
          twitchEnabled: s.twitchEnabled,
          twitchChannel: s.twitchChannel,
          kickEnabled: s.kickEnabled,
          kickSlug: s.kickSlug,
        ),
      ),
    );
    final metadata = ref.watch(youtubeMetadataProvider).valueOrNull;
    final platformMetadata =
        ref.watch(platformMetadataProvider).valueOrNull ?? const {};
    final platforms = <(String, bool, String, String)>[
      ('YT', settings.youtubeConfigured, 'youtube', 'YouTube'),
      (
        'TW',
        settings.twitchEnabled && settings.twitchChannel.isNotEmpty,
        'twitch',
        'Twitch',
      ),
      (
        'KK',
        settings.kickEnabled && settings.kickSlug.isNotEmpty,
        'kick',
        'Kick',
      ),
    ];

    final statusMap = status.valueOrNull ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: platforms.where((p) => p.$2).map((p) {
          final s = p.$3 == 'youtube' && settings.youtubeDualStreamEnabled
              ? combineYoutubeChatStatuses(
                  statusMap['youtubeHorizontal'],
                  statusMap['youtubeVertical'],
                )
              : statusMap[p.$3];
          final serviceStatus = s?.$1 ?? ServiceStatus.idle;
          // Dual YouTube with one stream up and the other failed.
          final partial = p.$3 == 'youtube' &&
              serviceStatus == ServiceStatus.connected &&
              s?.$2 != null;
          final color = switch (serviceStatus) {
            ServiceStatus.connected when partial => Colors.amber,
            ServiceStatus.connected => const Color(0xFF53FC18),
            ServiceStatus.connecting => Colors.amber,
            ServiceStatus.error => const Color(0xFFFF6B6B),
            ServiceStatus.idle || ServiceStatus.ended => Colors.white24,
          };
          return Tooltip(
            message: switch (serviceStatus) {
              ServiceStatus.connected when partial => switch (s?.$2) {
                  youtubeVerticalWaitingStatus =>
                    l.diagnosticsMessage('verticalWaiting', ''),
                  youtubeHorizontalWaitingStatus =>
                    l.diagnosticsMessage('horizontalWaiting', ''),
                  _ => l.youtubePartiallyConnected,
                },
              ServiceStatus.connected => l.platformStatusConnected(p.$4),
              ServiceStatus.connecting => s?.$2 == youtubeWaitingForLiveStatus
                  ? l.youtubeWaitingForLive
                  : l.platformStatusConnecting(p.$4),
              ServiceStatus.error => l.platformConnectionFailed(p.$4),
              ServiceStatus.idle => l.platformStatusIdle(p.$4),
              ServiceStatus.ended => l.youtubeBroadcastEnded,
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    p.$1,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (p.$3 == 'youtube' &&
                      metadata?.totalViewerCount != null) ...[
                    const SizedBox(width: 4),
                    YoutubeLiveStats(summary: metadata!, compact: true),
                  ],
                  if (p.$3 == 'kick' &&
                      platformMetadata[Platform.kick]?.viewerCount != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.visibility_outlined,
                      key: Key('kick-viewers-icon'),
                      size: 11,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${platformMetadata[Platform.kick]!.viewerCount}',
                      key: const Key('kick-viewer-count'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

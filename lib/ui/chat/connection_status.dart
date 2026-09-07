part of 'package:airstream/ui/chat_screen.dart';

class _ConnectionDots extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);
    final metadata = ref.watch(youtubeMetadataProvider).valueOrNull;
    final platformMetadata =
        ref.watch(platformMetadataProvider).valueOrNull ?? const {};
    final youtubeConfigured = settings.youtubeEnabled &&
        (settings.youtubeDualStreamEnabled
            ? settings.youtubeHorizontalUrl.trim().isNotEmpty &&
                settings.youtubeVerticalUrl.trim().isNotEmpty
            : settings.youtubeHandle.trim().isNotEmpty ||
                settings.youtubeLiveId.trim().isNotEmpty);

    final platforms = <(String, bool, String)>[
      ('YT', youtubeConfigured, 'youtube'),
      (
        'TW',
        settings.twitchEnabled && settings.twitchChannel.isNotEmpty,
        'twitch'
      ),
      ('KK', settings.kickEnabled && settings.kickSlug.isNotEmpty, 'kick'),
    ];

    final statusMap = status.valueOrNull ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: platforms.where((p) => p.$2).map((p) {
          final s = p.$3 == 'youtube' && settings.youtubeDualStreamEnabled
              ? _combinedStatus(
                  statusMap['youtubeHorizontal'],
                  statusMap['youtubeVertical'],
                )
              : statusMap[p.$3];
          final serviceStatus = s?.$1 ?? ServiceStatus.idle;
          final error = s?.$2;
          final color = switch (serviceStatus) {
            ServiceStatus.connected => const Color(0xFF53FC18),
            ServiceStatus.connecting => Colors.amber,
            ServiceStatus.error => Colors.red,
            ServiceStatus.idle => Colors.white24,
          };
          return Tooltip(
            message: error ?? serviceStatus.name,
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
                      fontSize: 9,
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
                        fontSize: 9,
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

  static (ServiceStatus, String?) _combinedStatus(
    (ServiceStatus, String?)? first,
    (ServiceStatus, String?)? second,
  ) {
    final statuses = [first, second];
    if (statuses.every((status) => status?.$1 == ServiceStatus.error)) {
      return (
        ServiceStatus.error,
        statuses
            .map((status) => status?.$2)
            .whereType<String>()
            .where((error) => error.isNotEmpty)
            .join('\n'),
      );
    }
    if (statuses.every((status) => status?.$1 == ServiceStatus.connected)) {
      return (ServiceStatus.connected, null);
    }
    return (ServiceStatus.connecting, null);
  }
}

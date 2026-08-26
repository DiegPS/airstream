import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_model.dart';

enum ChatSessionPhase {
  idle,
  connecting,
  connected,
  partiallyConnected,
  failed
}

bool shouldAcceptServiceStatus({
  required bool chatRequested,
  required bool platformConfigured,
  required ServiceStatus status,
}) {
  if (!chatRequested || !platformConfigured) {
    return status == ServiceStatus.idle;
  }
  return status != ServiceStatus.idle;
}

ChatSessionPhase resolveChatSessionPhase({
  required bool requested,
  required SettingsModel settings,
  required Map<String, (ServiceStatus, String?)> statuses,
}) {
  if (!requested) return ChatSessionPhase.idle;

  final configured = <String>[
    if (settings.youtubeEnabled &&
        !settings.youtubeDualStreamEnabled &&
        (settings.youtubeHandle.trim().isNotEmpty ||
            settings.youtubeLiveId.trim().isNotEmpty))
      'youtube',
    if (settings.youtubeEnabled &&
        settings.youtubeDualStreamEnabled &&
        settings.youtubeHorizontalUrl.trim().isNotEmpty)
      'youtubeHorizontal',
    if (settings.youtubeEnabled &&
        settings.youtubeDualStreamEnabled &&
        settings.youtubeVerticalUrl.trim().isNotEmpty)
      'youtubeVertical',
    if (settings.twitchEnabled && settings.twitchChannel.trim().isNotEmpty)
      'twitch',
    if (settings.kickEnabled && settings.kickSlug.trim().isNotEmpty) 'kick',
  ];
  if (configured.isEmpty) return ChatSessionPhase.idle;

  final states = configured
      .map((platform) => statuses[platform]?.$1 ?? ServiceStatus.connecting)
      .toList(growable: false);
  final hasConnected =
      states.any((status) => status == ServiceStatus.connected);
  final hasError = states.any((status) => status == ServiceStatus.error);
  if (hasConnected && hasError) {
    return ChatSessionPhase.partiallyConnected;
  }
  if (hasConnected) {
    return ChatSessionPhase.connected;
  }
  if (states.any((status) => status == ServiceStatus.connecting)) {
    return ChatSessionPhase.connecting;
  }
  if (states.every((status) => status == ServiceStatus.error)) {
    return ChatSessionPhase.failed;
  }
  return ChatSessionPhase.connecting;
}

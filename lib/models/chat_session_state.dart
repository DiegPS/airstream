import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_model.dart';

enum ChatSessionPhase {
  idle,
  connecting,
  connected,
  partiallyConnected,
  failed,
  ended,
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
  if (states.every((status) => status == ServiceStatus.ended)) {
    return ChatSessionPhase.ended;
  }
  if (states.every((status) =>
      status == ServiceStatus.error || status == ServiceStatus.ended)) {
    return ChatSessionPhase.failed;
  }
  return ChatSessionPhase.connecting;
}

(ServiceStatus, String?) combineYoutubeChatStatuses(
  (ServiceStatus, String?)? horizontal,
  (ServiceStatus, String?)? vertical,
) {
  final statuses = [horizontal?.$1, vertical?.$1];
  if (statuses.every((status) => status == ServiceStatus.ended)) {
    return (ServiceStatus.ended, null);
  }
  if (statuses.every((status) =>
      status == ServiceStatus.connected || status == ServiceStatus.ended)) {
    return (ServiceStatus.connected, null);
  }
  if (statuses.every((status) =>
      status == ServiceStatus.error || status == ServiceStatus.ended)) {
    return (ServiceStatus.error, horizontal?.$2 ?? vertical?.$2);
  }
  return (ServiceStatus.connecting, null);
}

/// Whether [settings] name at least one enabled chat that can be started.
bool hasStartableChat(SettingsModel settings) {
  final youtube = settings.youtubeEnabled &&
      (settings.youtubeDualStreamEnabled
          ? settings.youtubeHorizontalUrl.trim().isNotEmpty &&
              settings.youtubeVerticalUrl.trim().isNotEmpty
          : settings.youtubeHandle.trim().isNotEmpty ||
              settings.youtubeLiveId.trim().isNotEmpty);
  return youtube ||
      (settings.twitchEnabled && settings.twitchChannel.trim().isNotEmpty) ||
      (settings.kickEnabled && settings.kickSlug.trim().isNotEmpty);
}

/// Status detail while YouTube waits for the channel to go live.
const youtubeWaitingForLiveStatus = 'youtube-waiting-for-live';

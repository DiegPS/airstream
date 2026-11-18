import 'package:airstream/services/kick_service.dart';
import 'package:airstream/settings/settings_input_normalizer.dart';
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
    if (hasSingleYoutubeChat(settings)) 'youtube',
    if (configuredDualYoutubeVideoIds(settings) != null) ...[
      'youtubeHorizontal',
      'youtubeVertical',
    ],
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
  // One stream works and the other failed: YouTube is up, but partially.
  // The failing stream's message travels with the connected status so the
  // title bar can flag it instead of showing "connecting" forever.
  if (statuses.contains(ServiceStatus.connected) &&
      statuses.contains(ServiceStatus.error)) {
    final failed =
        horizontal?.$1 == ServiceStatus.error ? horizontal : vertical;
    return (ServiceStatus.connected, failed?.$2 ?? youtubePartialStatus);
  }
  return (ServiceStatus.connecting, null);
}

/// Whether [settings] name at least one enabled chat that can be started.
bool hasStartableChat(SettingsModel settings) =>
    hasConfiguredYoutubeChat(settings) ||
    (settings.twitchEnabled && settings.twitchChannel.trim().isNotEmpty) ||
    (settings.kickEnabled && settings.kickSlug.trim().isNotEmpty);

bool hasConfiguredYoutubeChat(SettingsModel settings) =>
    hasSingleYoutubeChat(settings) ||
    configuredDualYoutubeVideoIds(settings) != null;

bool hasSingleYoutubeChat(SettingsModel settings) =>
    settings.youtubeEnabled &&
    !settings.youtubeDualStreamEnabled &&
    (settings.youtubeHandle.trim().isNotEmpty ||
        settings.youtubeLiveId.trim().isNotEmpty);

({String horizontal, String vertical})? configuredDualYoutubeVideoIds(
  SettingsModel settings, {
  String? Function(String) videoIdFromUrl =
      SettingsInputNormalizer.youtubeVideoId,
}) {
  if (!settings.youtubeEnabled || !settings.youtubeDualStreamEnabled) {
    return null;
  }
  return SettingsInputNormalizer.distinctYoutubeVideoIds(
    settings.youtubeHorizontalUrl,
    settings.youtubeVerticalUrl,
    videoIdFromUrl: videoIdFromUrl,
  );
}

/// Status detail while YouTube waits for the channel to go live.
const youtubeWaitingForLiveStatus = 'youtube-waiting-for-live';

/// Fallback detail for a dual YouTube chat where one stream connected and the
/// other failed without a message.
const youtubePartialStatus = 'youtube-partial';

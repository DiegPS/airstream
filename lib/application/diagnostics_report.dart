import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/window/global_shortcuts.dart';

enum DiagnosticStatus { ok, warning, error, off }

class DiagnosticItem {
  const DiagnosticItem(this.area, this.status, this.summary);
  final String area;
  final DiagnosticStatus status;
  final String summary;
}

class DiagnosticsSnapshot {
  const DiagnosticsSnapshot({
    required this.settings,
    this.connections = const {},
    this.chatPhase = ChatSessionPhase.idle,
    this.obs = const ObsState(),
    this.server = const OverlayServerState(),
    this.pages = const {},
    this.tts = const TtsLoadState(),
    this.captions = const LiveCaptionsState(),
    this.shortcutFailures = const {},
  });
  final SettingsModel settings;
  final Map<String, (ServiceStatus, String?)> connections;
  final ChatSessionPhase chatPhase;
  final ObsState obs;
  final OverlayServerState server;
  final Map<String, int> pages;
  final TtsLoadState tts;
  final LiveCaptionsState captions;
  final Set<GlobalShortcutAction> shortcutFailures;
}

typedef DiagnosticsText = String Function(String key, String value);

// Only controlled text crosses the diagnostics boundary. Arbitrary exception
// strings may contain speech, viewer names, credentials or filesystem paths.
String diagnosticErrorKey(Object? error) {
  final text = error.toString().toLowerCase();
  if (text.contains('address already in use') ||
      text.contains('port is taken')) {
    return 'portBusy';
  }
  if (text.contains('authentication') || text.contains('unauthorized')) {
    return 'authentication';
  }
  if (text.contains('connection refused')) return 'refused';
  if (text.contains('timed out') || text.contains('timeout')) return 'timeout';
  return 'failed';
}

const diagnosticEnglish = <String, String>{
  'set': 'set',
  'off': 'Off',
  'idle': 'Not connected',
  'connected': 'Connected',
  'connecting': 'Connecting / reconnecting',
  'waiting': 'Waiting for live stream',
  'failed': 'Failed (private details omitted)',
  'portBusy': 'Port is already in use',
  'authentication': 'Authentication failed',
  'refused': 'Connection refused',
  'timeout': 'Connection timed out',
  'listeningPort': 'Listening on port {value}',
  'starting': 'Starting',
  'noAlerts': 'No alerts page connected in OBS',
  'pages':
      'Pages: chat / alerts / poll / captions / giveaway / goals / timer / custom: {value}',
  'loading': 'Loading {value}',
  'ready': 'Ready: {value}',
  'listening': 'Listening',
  'downloading': 'Downloading {value}',
  'missingModel': 'Model download required',
  'commandsOn': 'Voice commands on',
  'commandsOff': 'Voice commands off',
  'shortcutsOk': 'None assigned or all registered',
  'shortcutTaken': 'Shortcut taken by another app: {value}',
  'silenceTts': 'Silence voice reader',
  'toggleTts': 'Toggle voice reader',
  'channelSet': 'Channel set',
  'channelUnset': 'Channel not set',
  'scene': 'Scene: {value}',
  'metrics': '{value} kbps / dropped frames',
};
String englishDiagnosticsText(String key, String value) =>
    (diagnosticEnglish[key] ?? key).replaceAll('{value}', value);

List<DiagnosticItem> diagnosticItems(DiagnosticsSnapshot snapshot,
    {DiagnosticsText text = englishDiagnosticsText, bool forReport = false}) {
  final s = snapshot.settings;
  String t(String key, [String value = '']) => text(key, value);
  // On screen the streamer sees the real error: it is their own computer and
  // the connection badges already show it. The copied report keeps only a
  // safe category.
  String err(Object? error) {
    final key = diagnosticErrorKey(error);
    if (forReport || key != 'failed' || error == null) return t(key);
    var detail = error.toString().split('\n').first.trim();
    if (s.obsPassword.isNotEmpty) {
      detail = detail.replaceAll(s.obsPassword, '•••');
    }
    if (detail.length > 160) detail = '${detail.substring(0, 157)}…';
    return detail.isEmpty ? t(key) : detail;
  }

  final items = <DiagnosticItem>[];
  for (final platform in ['youtube', 'twitch', 'kick']) {
    final enabled = switch (platform) {
      'youtube' => s.youtubeEnabled,
      'twitch' => s.twitchEnabled,
      _ => s.kickEnabled,
    };
    final configured = switch (platform) {
      'youtube' => s.youtubeDualStreamEnabled
          ? s.youtubeHorizontalUrl.trim().isNotEmpty ||
              s.youtubeVerticalUrl.trim().isNotEmpty
          : s.youtubeHandle.trim().isNotEmpty ||
              s.youtubeLiveId.trim().isNotEmpty,
      'twitch' => s.twitchChannel.trim().isNotEmpty,
      _ => s.kickSlug.trim().isNotEmpty,
    };
    var state = snapshot.connections[platform] ?? (ServiceStatus.idle, null);
    if (platform == 'youtube' && s.youtubeDualStreamEnabled) {
      final a = snapshot.connections['youtubeHorizontal'];
      final b = snapshot.connections['youtubeVertical'];
      state = [a, b].every((v) => v?.$1 == ServiceStatus.connected)
          ? (ServiceStatus.connected, null)
          : [a, b].every((v) => v?.$1 == ServiceStatus.error)
              ? (ServiceStatus.error, a?.$2 ?? b?.$2)
              : (ServiceStatus.connecting, null);
    }
    final active = enabled && configured;
    final status = !active
        ? DiagnosticStatus.off
        : switch (state.$1) {
            ServiceStatus.connected => DiagnosticStatus.ok,
            ServiceStatus.connecting => DiagnosticStatus.warning,
            ServiceStatus.error => DiagnosticStatus.error,
            ServiceStatus.idle => DiagnosticStatus.off,
          };
    final message = !active
        ? t('off')
        : switch (state.$1) {
            ServiceStatus.connected => t('connected'),
            ServiceStatus.connecting => t(
                state.$2 == youtubeWaitingForLiveStatus
                    ? 'waiting'
                    : 'connecting'),
            ServiceStatus.error => err(state.$2),
            ServiceStatus.idle => t(
                snapshot.chatPhase == ChatSessionPhase.connecting
                    ? 'connecting'
                    : 'idle'),
          };
    items.add(DiagnosticItem(platform, status,
        '$message · ${t(configured ? 'channelSet' : 'channelUnset')}'));
  }
  final obs = snapshot.obs;
  final obsStatus = !s.obsEnabled
      ? DiagnosticStatus.off
      : obs.connecting || obs.reconnecting
          ? DiagnosticStatus.warning
          : obs.error != null
              ? DiagnosticStatus.error
              : obs.connected
                  ? (obs.dropPercentage > 1
                      ? DiagnosticStatus.warning
                      : DiagnosticStatus.ok)
                  : DiagnosticStatus.off;
  var obsSummary = !s.obsEnabled
      ? t('off')
      : obs.connecting || obs.reconnecting
          ? t('connecting')
          : obs.error != null
              ? err('${obs.statusMessage} ${obs.error}'.trim())
              : obs.connected
                  ? t('connected')
                  : t('idle');
  if (s.obsEnabled && obs.connected) {
    // The report omits the scene name; the streamer's own screen shows it.
    if (!forReport && obs.currentScene.isNotEmpty) {
      obsSummary += ' · ${t('scene', obs.currentScene)}';
    }
    if (obs.outputActive) {
      obsSummary +=
          ' · ${t('metrics', obs.bitrateKbps.toStringAsFixed(0))} ${obs.dropPercentage.toStringAsFixed(2)}%';
    }
  }
  items.add(DiagnosticItem('obs', obsStatus, obsSummary));
  final server = snapshot.server;
  final ready = s.overlayEnabled && server.phase == OverlayServerPhase.ready;
  final noAlerts = ready &&
      alertTypeIds.any((id) => !s.alertDisabledTypes.contains(id)) &&
      (snapshot.pages['alerts'] ?? 0) == 0;
  items.add(DiagnosticItem(
      'overlay',
      !s.overlayEnabled
          ? DiagnosticStatus.off
          : server.phase == OverlayServerPhase.error
              ? DiagnosticStatus.error
              : ready
                  ? (noAlerts ? DiagnosticStatus.warning : DiagnosticStatus.ok)
                  : DiagnosticStatus.warning,
      !s.overlayEnabled
          ? t('off')
          : server.phase == OverlayServerPhase.error
              ? err(server.error)
              : ready
                  ? '${t('listeningPort', '${server.port ?? s.overlayPort}')} · ${t('pages', [
                        'chat',
                        'alerts',
                        'poll',
                        'captions',
                        'giveaway',
                        'goals',
                        'timer',
                        'custom'
                      ].map((v) => snapshot.pages[v] ?? 0).join(' / '))}${noAlerts ? ' · ${t('noAlerts')}' : ''}'
                  : t('starting')));
  final tts = snapshot.tts;
  // Catalog names, never model IDs or filenames from an exception.
  final model = TtsModelCatalog.models.where((m) => m.id == tts.modelId);
  items.add(DiagnosticItem(
      'tts',
      !s.ttsEnabled
          ? DiagnosticStatus.off
          : tts.phase == TtsLoadPhase.error
              ? DiagnosticStatus.error
              : tts.isReady
                  ? DiagnosticStatus.ok
                  : DiagnosticStatus.warning,
      !s.ttsEnabled
          ? t('off')
          : tts.phase == TtsLoadPhase.error
              ? err(tts.error)
              : tts.isReady
                  ? t('ready', model.isEmpty ? 'TTS' : model.first.name)
                  : t(
                      'loading',
                      tts.progress == null
                          ? ''
                          : '${(tts.progress! * 100).round()}%')));
  final captions = snapshot.captions;
  final captionsEnabled = s.liveCaptionsEnabled || s.voiceCommandsEnabled;
  items.add(DiagnosticItem(
      'captions',
      !captionsEnabled
          ? DiagnosticStatus.off
          : captions.phase == LiveCaptionsPhase.error
              ? DiagnosticStatus.error
              : captions.isListening
                  ? DiagnosticStatus.ok
                  : DiagnosticStatus.warning,
      '${!captionsEnabled ? t('off') : captions.phase == LiveCaptionsPhase.error ? err(captions.error) : captions.isListening ? t('listening') : captions.phase == LiveCaptionsPhase.missingModel ? t('missingModel') : t(captions.phase == LiveCaptionsPhase.downloading ? 'downloading' : 'loading', captions.progress == null ? '' : '${(captions.progress! * 100).round()}%')} · ${t(s.voiceCommandsEnabled ? 'commandsOn' : 'commandsOff')}'));
  items.add(DiagnosticItem(
      'shortcuts',
      snapshot.shortcutFailures.isEmpty
          ? DiagnosticStatus.ok
          : DiagnosticStatus.warning,
      snapshot.shortcutFailures.isEmpty
          ? t('shortcutsOk')
          : t(
              'shortcutTaken',
              GlobalShortcutAction.values
                  .where(snapshot.shortcutFailures.contains)
                  .map((a) => t(a.name))
                  .join(', '))));
  return List.unmodifiable(items);
}

int diagnosticAttentionCount(List<DiagnosticItem> items) => items
    .where((item) =>
        item.status == DiagnosticStatus.warning ||
        item.status == DiagnosticStatus.error)
    .length;

String diagnosticsReport(DiagnosticsSnapshot snapshot,
    {required DateTime dateTime, required String operatingSystemVersion}) {
  final items = diagnosticItems(snapshot, forReport: true);
  return [
    'Airstream diagnostics',
    dateTime.toIso8601String(),
    operatingSystemVersion,
    for (final item in items)
      '${item.area}: ${item.status.name.toUpperCase()} - ${item.summary}'
  ].join('\n');
}

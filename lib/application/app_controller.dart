import 'dart:async';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/coordinator_notice.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/settings/settings_model.dart';

/// Stable facade consumed by the UI.
///
/// Feature orchestration lives in focused coordinators; this class only wires
/// their event streams together and preserves the application's public API.
class AppController {
  AppController({
    YouTubeService? youtube,
    YouTubeService? youtubeHorizontal,
    YouTubeService? youtubeVertical,
    KickService? kick,
    TwitchService? twitch,
    OverlayServer? overlay,
    ObsService? obs,
    TtsService? tts,
    LiveCaptionsService? captions,
    MessagePipeline? pipeline,
    ChatCoordinator? chatCoordinator,
    AudioCoordinator? audioCoordinator,
    OverlayCoordinator? overlayCoordinator,
    ObsCoordinator? obsCoordinator,
  }) {
    _chat = chatCoordinator ??
        ChatCoordinator(
          youtube: YouTubeChatServiceAdapter(youtube ?? YouTubeService()),
          youtubeHorizontal: YouTubeChatServiceAdapter(
            youtubeHorizontal ??
                YouTubeService(
                  streamOrientation: YoutubeStreamOrientation.horizontal,
                ),
          ),
          youtubeVertical: YouTubeChatServiceAdapter(
            youtubeVertical ??
                YouTubeService(
                  streamOrientation: YoutubeStreamOrientation.vertical,
                ),
          ),
          kick: KickChatServiceAdapter(kick ?? KickService()),
          twitch: TwitchChatServiceAdapter(twitch ?? TwitchService()),
          pipeline: pipeline,
        );
    _audio = audioCoordinator ??
        AudioCoordinator(
          tts: TtsServiceAdapter(tts ?? TtsService()),
          captions: CaptionsServiceAdapter(captions ?? LiveCaptionsService()),
        );
    _overlay = overlayCoordinator ??
        OverlayCoordinator(
          overlay: OverlayServerAdapter(overlay ?? OverlayServer()),
        );
    _obs = obsCoordinator ??
        ObsCoordinator(obs: ObsServiceAdapter(obs ?? ObsService()));

    _subscriptions.addAll([
      _chat.messages.listen(_audio.handleChatMessage),
      _audio.finalizedCaptions.listen(_overlay.broadcastCaption),
      _audio.voiceCommands.listen(
        (command) => unawaited(_obs.executeVoiceCommand(command)),
      ),
      _audio.notices.listen(_emitNotice),
      _obs.notices.listen(_emitNotice),
    ]);
  }

  late final ChatCoordinator _chat;
  late final AudioCoordinator _audio;
  late final OverlayCoordinator _overlay;
  late final ObsCoordinator _obs;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _noticeController = StreamController<AppNotice>.broadcast();
  SettingsModel? _lastSettings;
  int _noticeId = 0;
  bool _disposed = false;

  Stream<List<ChatMessage>> get messageListStream => _chat.messageListStream;
  Stream<Map<String, (ServiceStatus, String?)>> get connectionStatusStream =>
      _chat.connectionStatusStream;
  Stream<String?> get youtubeBadgeValueStream => _chat.youtubeBadgeValueStream;
  Stream<YoutubeLiveMetadataSummary> get youtubeMetadataStream =>
      _chat.youtubeMetadataStream;
  Stream<TtsLoadState> get ttsLoadStateStream => _audio.ttsLoadStateStream;
  Stream<bool> get ttsBusyStream => _audio.ttsBusyStream;
  Stream<LiveCaptionsState> get liveCaptionsStateStream =>
      _audio.liveCaptionsStateStream;
  Stream<ObsState> get obsStateStream => _obs.stateStream;
  Stream<int> get overlayClientCountStream => _overlay.clientCountStream;
  Stream<AppNotice> get noticeStream => _noticeController.stream;
  Stream<OverlayServerState> get overlayStateStream => _overlay.stateStream;
  String? get overlayUrl => _overlay.url;

  bool testTts(String text) => _audio.testTts(text);
  Future<void> downloadTtsModel() => _audio.downloadTtsModel();
  Future<void> removeTtsModel(String modelId) => _audio.removeTtsModel(modelId);
  Future<void> downloadLiveCaptionsModel() =>
      _audio.downloadLiveCaptionsModel();
  Future<void> connectObs() => _obs.connect();
  Future<void> disconnectObs() => _obs.disconnect();
  bool reloadOverlay() => _overlay.reload();
  bool testOverlayAlert(String kind) => _overlay.testAlert(kind);
  void retryChatConnections() => _chat.retryConnections();
  void retryChatPlatform(String platform) => _chat.retryPlatform(platform);

  void applySettings(SettingsModel settings, {required bool connectChats}) {
    if (_disposed) return;
    final previous = _lastSettings;
    _lastSettings = settings;
    _chat.applySettings(settings, connectChats: connectChats);
    _audio.applySettings(settings, connectChats: connectChats);
    _overlay.applySettings(
      settings,
      previous: previous,
      messages: _chat.messages,
    );
    _obs.applySettings(settings, previous: previous);
  }

  void _emitNotice(CoordinatorNotice notice) {
    if (_noticeController.isClosed) return;
    _noticeController.add(
      AppNotice(
        code: notice.code,
        severity: notice.severity,
        id: ++_noticeId,
      ),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _chat.dispose();
    await _audio.dispose();
    await _overlay.dispose();
    await _obs.dispose();
    await _noticeController.close();
  }
}

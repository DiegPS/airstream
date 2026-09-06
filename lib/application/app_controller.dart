import 'dart:async';
import 'dart:collection';

import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/tts_message_policy.dart';

class AppController {
  final YouTubeService _youtube;
  final YouTubeService _youtubeHorizontal;
  final YouTubeService _youtubeVertical;
  final KickService _kick;
  final TwitchService _twitch;
  final OverlayServer _overlay;
  final ObsService _obs;
  final TtsService _tts;
  final LiveCaptionsService _captions;
  final MessagePipeline _pipeline;
  StreamSubscription<ChatMessage>? _pipelineSub;
  StreamSubscription<(ServiceStatus, String?)>? _youtubeStatusSub;
  StreamSubscription<(ServiceStatus, String?)>? _youtubeHorizontalStatusSub;
  StreamSubscription<(ServiceStatus, String?)>? _youtubeVerticalStatusSub;
  StreamSubscription<(ServiceStatus, String?)>? _kickStatusSub;
  StreamSubscription<(ServiceStatus, String?)>? _twitchStatusSub;
  StreamSubscription<LiveCaptionsState>? _captionsSub;
  StreamSubscription<Object>? _ttsPlaybackErrorSub;
  final _spokenMessageKeys = <String>{};
  final _spokenMessageOrder = Queue<String>();

  final _listController =
      // ignore: close_sinks
      StreamController<List<ChatMessage>>.broadcast();

  final _statusController =
      // ignore: close_sinks
      StreamController<Map<String, (ServiceStatus, String?)>>.broadcast();
  final _youtubeBadgeController =
      // ignore: close_sinks
      StreamController<String?>.broadcast();
  final _noticeController = StreamController<AppNotice>.broadcast();
  final _overlayStateController =
      StreamController<OverlayServerState>.broadcast();

  final _platformStatus = <String, (ServiceStatus, String?)>{
    'youtube': (ServiceStatus.idle, null),
    'youtubeHorizontal': (ServiceStatus.idle, null),
    'youtubeVertical': (ServiceStatus.idle, null),
    'twitch': (ServiceStatus.idle, null),
    'kick': (ServiceStatus.idle, null),
  };
  String? _youtubeBadgeValue;
  OverlayServerState _overlayState = const OverlayServerState();
  int _noticeId = 0;
  int _overlayGeneration = 0;
  int _chatAttemptGeneration = 0;

  SettingsModel? _lastSettings;
  bool? _lastConnectChats;
  DateTime? _ttsSessionStartedAt;
  bool _obsConnectRequested = false;

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
  })  : _youtube = youtube ?? YouTubeService(),
        _youtubeHorizontal = youtubeHorizontal ??
            YouTubeService(
              streamOrientation: YoutubeStreamOrientation.horizontal,
            ),
        _youtubeVertical = youtubeVertical ??
            YouTubeService(
              streamOrientation: YoutubeStreamOrientation.vertical,
            ),
        _kick = kick ?? KickService(),
        _twitch = twitch ?? TwitchService(),
        _overlay = overlay ?? OverlayServer(),
        _obs = obs ?? ObsService(),
        _tts = tts ?? TtsService(),
        _captions = captions ?? LiveCaptionsService(),
        _pipeline = pipeline ?? MessagePipeline(const SettingsModel()) {
    _pipeline.addSource(_youtube.messages);
    _pipeline.addSource(_youtubeHorizontal.messages);
    _pipeline.addSource(_youtubeVertical.messages);
    _pipeline.addSource(_kick.messages);
    _pipeline.addSource(_twitch.messages);
    _pipelineSub = _pipeline.stream.listen((msg) {
      _listController.add(_pipeline.buffer);
      _speakMessageIfEligible(msg);
    });
    // Forward per-service status to the aggregated stream.
    _youtubeStatusSub =
        _youtube.statusStream.listen((s) => _handleServiceStatus('youtube', s));
    _youtubeHorizontalStatusSub = _youtubeHorizontal.statusStream
        .listen((s) => _handleServiceStatus('youtubeHorizontal', s));
    _youtubeVerticalStatusSub = _youtubeVertical.statusStream
        .listen((s) => _handleServiceStatus('youtubeVertical', s));
    _kickStatusSub =
        _kick.statusStream.listen((s) => _handleServiceStatus('kick', s));
    _twitchStatusSub =
        _twitch.statusStream.listen((s) => _handleServiceStatus('twitch', s));
    _ttsPlaybackErrorSub = _tts.playbackErrors.listen((error) {
      _emitNotice(AppNoticeCode.ttsPlaybackFailed, AppNoticeSeverity.error);
    });
    _captionsSub = _captions.states.listen((state) {
      if (state.captionFinal &&
          (_lastSettings?.liveCaptionsOverlayEnabled ?? false)) {
        _overlay.broadcastCaption(state.caption);
      }
      if (state.captionFinal &&
          (_lastSettings?.voiceCommandsEnabled ?? false)) {
        final command = VoiceCommand.parse(
          state.caption,
          wakeWord: _lastSettings?.voiceCommandsWakeWord ?? 'airstream',
        );
        if (command != null) unawaited(_executeVoiceCommand(command));
      }
    });
  }

  Future<void> _connectYoutube(SettingsModel s, int generation) async {
    _youtubeBadgeValue = null;
    _emitYoutubeBadgeValue();
    try {
      await _youtube.connect(handle: s.youtubeHandle, liveId: s.youtubeLiveId);
      if (generation != _chatAttemptGeneration || _lastConnectChats != true) {
        return;
      }
      _youtubeBadgeValue = _youtube.resolvedLiveId.isNotEmpty
          ? _youtube.resolvedLiveId
          : s.youtubeHandle.trim();
      _emitYoutubeBadgeValue();
    } catch (e, stack) {
      AppLogger.error(
        'YouTube connection failed',
        error: e,
        stackTrace: stack,
      );
      await _youtube.disconnect();
      if (generation != _chatAttemptGeneration || _lastConnectChats != true) {
        return;
      }
      _youtubeBadgeValue = null;
      _emitYoutubeBadgeValue();
      _updateStatus('youtube', (ServiceStatus.error, e.toString()));
    }
  }

  Future<void> _connectYoutubeStream({
    required YouTubeService service,
    required String statusKey,
    required String url,
    required int generation,
  }) async {
    final videoId = YouTubeService.videoIdFromUrl(url);
    if (videoId == null) {
      _updateStatus(
        statusKey,
        (ServiceStatus.error, 'A valid YouTube video URL is required.'),
      );
      return;
    }
    try {
      await service.connect(liveId: videoId);
      if (generation != _chatAttemptGeneration || _lastConnectChats != true) {
        return;
      }
    } catch (e, stack) {
      AppLogger.error(
        '$statusKey connection failed',
        error: e,
        stackTrace: stack,
      );
      await service.disconnect();
      if (generation == _chatAttemptGeneration && _lastConnectChats == true) {
        _updateStatus(statusKey, (ServiceStatus.error, e.toString()));
      }
    }
  }

  Future<void> _connectTwitch(SettingsModel s, int generation) async {
    try {
      await _twitch.connect(s.twitchChannel);
      if (generation != _chatAttemptGeneration || _lastConnectChats != true) {
        return;
      }
    } catch (e, stack) {
      AppLogger.error(
        'Twitch connection failed',
        error: e,
        stackTrace: stack,
      );
      await _twitch.disconnect();
      if (generation != _chatAttemptGeneration || _lastConnectChats != true) {
        return;
      }
      _updateStatus('twitch', (ServiceStatus.error, e.toString()));
    }
  }

  void _updateStatus(String platform, (ServiceStatus, String?) status) {
    _platformStatus[platform] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_platformStatus));
    }
  }

  void _handleServiceStatus(
    String platform,
    (ServiceStatus, String?) status,
  ) {
    if (!shouldAcceptServiceStatus(
      chatRequested: _lastConnectChats == true,
      platformConfigured: _isPlatformConfigured(platform),
      status: status.$1,
    )) {
      return;
    }
    _updateStatus(platform, status);
  }

  bool _isPlatformConfigured(String platform) {
    final settings = _lastSettings;
    if (settings == null) return false;
    return switch (platform) {
      'youtube' => settings.youtubeEnabled &&
          !settings.youtubeDualStreamEnabled &&
          (settings.youtubeHandle.trim().isNotEmpty ||
              settings.youtubeLiveId.trim().isNotEmpty),
      'youtubeHorizontal' => settings.youtubeEnabled &&
          settings.youtubeDualStreamEnabled &&
          YouTubeService.videoIdFromUrl(settings.youtubeHorizontalUrl) != null,
      'youtubeVertical' => settings.youtubeEnabled &&
          settings.youtubeDualStreamEnabled &&
          YouTubeService.videoIdFromUrl(settings.youtubeVerticalUrl) != null,
      'twitch' =>
        settings.twitchEnabled && settings.twitchChannel.trim().isNotEmpty,
      'kick' => settings.kickEnabled && settings.kickSlug.trim().isNotEmpty,
      _ => false,
    };
  }

  Stream<List<ChatMessage>> get messageListStream async* {
    yield List<ChatMessage>.from(_pipeline.buffer);
    yield* _listController.stream;
  }

  Stream<Map<String, (ServiceStatus, String?)>>
      get connectionStatusStream async* {
    yield Map.from(_platformStatus);
    yield* _statusController.stream;
  }

  Stream<String?> get youtubeBadgeValueStream async* {
    yield _youtubeBadgeValue;
    yield* _youtubeBadgeController.stream;
  }

  Stream<TtsLoadState> get ttsLoadStateStream async* {
    yield _tts.currentLoadState;
    yield* _tts.loadStateStream;
  }

  Stream<bool> get ttsBusyStream async* {
    yield _tts.isBusy;
    yield* _tts.busyStream;
  }

  Stream<LiveCaptionsState> get liveCaptionsStateStream => _captions.states;

  Stream<ObsState> get obsStateStream async* {
    yield _obs.currentState;
    yield* _obs.stateStream;
  }

  Stream<int> get overlayClientCountStream => _overlay.clientCountStream;

  Stream<AppNotice> get noticeStream => _noticeController.stream;

  Stream<OverlayServerState> get overlayStateStream async* {
    yield _overlayState;
    yield* _overlayStateController.stream;
  }

  String? get overlayUrl => _overlayState.phase == OverlayServerPhase.ready
      ? _overlay.overlayUrl
      : null;

  bool testTts(String text) {
    if (text.isEmpty) return false;
    if (_tts.currentLoadState.isLoading || _tts.isBusy) return false;
    _tts.speak(text, allowDownload: true);
    return true;
  }

  Future<void> downloadTtsModel() => _tts.prepareModel();

  Future<void> removeTtsModel(String modelId) => _tts.removeModel(modelId);

  Future<void> downloadLiveCaptionsModel() => _captions.prepareModel();

  Future<void> _executeVoiceCommand(VoiceCommand command) async {
    try {
      switch (command.type) {
        case VoiceCommandType.startRecording:
          await _obs.startRecording();
          return;
        case VoiceCommandType.stopRecording:
          await _obs.stopRecording();
          return;
        case VoiceCommandType.pauseRecording:
          await _obs.pauseRecording();
          return;
        case VoiceCommandType.resumeRecording:
          await _obs.resumeRecording();
          return;
        case VoiceCommandType.switchScene:
          await _obs.switchScene(command.argument);
          return;
      }
    } catch (error, stack) {
      AppLogger.error(
        'Voice command failed',
        error: error,
        stackTrace: stack,
      );
      _emitNotice(AppNoticeCode.voiceCommandFailed, AppNoticeSeverity.error);
    }
  }

  Future<void> connectObs() async {
    final settings = _lastSettings;
    if (settings == null || !settings.obsEnabled) return;
    _obsConnectRequested = true;
    await _obs.connect(host: settings.obsHost, password: settings.obsPassword);
  }

  Future<void> disconnectObs() async {
    _obsConnectRequested = false;
    await _obs.disconnect();
  }

  bool reloadOverlay() => _overlay.reloadClients();

  bool testOverlayAlert(String kind) => _overlay.broadcastTestAlert(kind);

  void retryChatConnections() {
    final settings = _lastSettings;
    if (settings == null || _lastConnectChats != true) return;
    final generation = ++_chatAttemptGeneration;
    if (settings.youtubeEnabled &&
        !settings.youtubeDualStreamEnabled &&
        (settings.youtubeHandle.trim().isNotEmpty ||
            settings.youtubeLiveId.trim().isNotEmpty) &&
        _platformStatus['youtube']?.$1 == ServiceStatus.error) {
      unawaited(_connectYoutube(settings, generation));
    }
    if (settings.youtubeEnabled && settings.youtubeDualStreamEnabled) {
      if (_platformStatus['youtubeHorizontal']?.$1 == ServiceStatus.error) {
        unawaited(_connectYoutubeStream(
          service: _youtubeHorizontal,
          statusKey: 'youtubeHorizontal',
          url: settings.youtubeHorizontalUrl,
          generation: generation,
        ));
      }
      if (_platformStatus['youtubeVertical']?.$1 == ServiceStatus.error) {
        unawaited(_connectYoutubeStream(
          service: _youtubeVertical,
          statusKey: 'youtubeVertical',
          url: settings.youtubeVerticalUrl,
          generation: generation,
        ));
      }
    }
    if (settings.twitchEnabled &&
        settings.twitchChannel.trim().isNotEmpty &&
        _platformStatus['twitch']?.$1 == ServiceStatus.error) {
      unawaited(_connectTwitch(settings, generation));
    }
    if (settings.kickEnabled &&
        settings.kickSlug.trim().isNotEmpty &&
        _platformStatus['kick']?.$1 == ServiceStatus.error) {
      unawaited(_kick.connect(settings.kickSlug));
    }
  }

  void retryChatPlatform(String platform) {
    final settings = _lastSettings;
    if (settings == null || _lastConnectChats != true) return;
    final generation = ++_chatAttemptGeneration;
    switch (platform) {
      case 'youtube':
        if (_isPlatformConfigured(platform)) {
          unawaited(_connectYoutube(settings, generation));
        }
        return;
      case 'youtubeHorizontal':
        if (_isPlatformConfigured(platform)) {
          unawaited(_connectYoutubeStream(
            service: _youtubeHorizontal,
            statusKey: platform,
            url: settings.youtubeHorizontalUrl,
            generation: generation,
          ));
        }
        return;
      case 'youtubeVertical':
        if (_isPlatformConfigured(platform)) {
          unawaited(_connectYoutubeStream(
            service: _youtubeVertical,
            statusKey: platform,
            url: settings.youtubeVerticalUrl,
            generation: generation,
          ));
        }
        return;
      case 'twitch':
        if (_isPlatformConfigured(platform)) {
          unawaited(_connectTwitch(settings, generation));
        }
        return;
      case 'kick':
        if (_isPlatformConfigured(platform)) {
          unawaited(_kick.connect(settings.kickSlug));
        }
        return;
    }
  }

  void _emitNotice(AppNoticeCode code, AppNoticeSeverity severity) {
    if (_noticeController.isClosed) return;
    _noticeController.add(
      AppNotice(code: code, severity: severity, id: ++_noticeId),
    );
  }

  void _emitOverlayState(OverlayServerState state) {
    _overlayState = state;
    if (!_overlayStateController.isClosed) {
      _overlayStateController.add(state);
    }
  }

  Future<void> _startOverlay(SettingsModel settings) async {
    final generation = ++_overlayGeneration;
    _emitOverlayState(
      OverlayServerState(
        phase: OverlayServerPhase.starting,
        port: settings.overlayPort,
      ),
    );
    try {
      await _overlay.start(
        messages: _pipeline.stream,
        settings: settings,
        port: settings.overlayPort,
      );
      if (generation != _overlayGeneration) return;
      _emitOverlayState(
        OverlayServerState(
          phase: OverlayServerPhase.ready,
          port: _overlay.port,
        ),
      );
    } catch (error, stack) {
      if (generation != _overlayGeneration) return;
      AppLogger.error(
        'Overlay server failed to start on port ${settings.overlayPort}',
        error: error,
        stackTrace: stack,
      );
      _emitOverlayState(
        OverlayServerState(
          phase: OverlayServerPhase.error,
          port: settings.overlayPort,
          error: error,
        ),
      );
    }
  }

  void _speakMessageIfEligible(ChatMessage msg) {
    final settings = _lastSettings;
    if (settings == null || !settings.ttsEnabled) return;
    if (settings.ttsMembersOnly && !msg.isMembership) return;
    if (!isTtsMessageFresh(msg, _ttsSessionStartedAt)) return;

    final speakKey = msg.dedupeKey;
    if (_spokenMessageKeys.contains(speakKey)) return;

    final authorName = sanitizeTtsAuthorName(msg.author.name);
    var text = msg.ttsText.trim();
    if (text.isEmpty) return;

    if (settings.ttsCommandMode) {
      final prefix = settings.ttsCommandPrefix.trim().isEmpty
          ? '!v'
          : settings.ttsCommandPrefix.trim();
      final commandText = extractTtsCommandText(
        text,
        prefix: prefix,
        ignoreCase: settings.ttsCommandIgnoreCase,
      );
      if (commandText == null) return;
      text = commandText;
    }

    _rememberSpokenMessage(speakKey);
    final separator = settings.ttsSeparatorText.trim().isEmpty
        ? (settings.appLanguageCode == 'es' ? 'dice' : 'says')
        : settings.ttsSeparatorText;
    final spokenAuthor = authorName.isEmpty ? 'Chat' : authorName;
    _tts.speak('$spokenAuthor $separator: $text');
  }

  void _rememberSpokenMessage(String key) {
    _spokenMessageKeys.add(key);
    _spokenMessageOrder.addLast(key);
    while (_spokenMessageOrder.length > _maxTrackedTtsMessages) {
      final oldest = _spokenMessageOrder.removeFirst();
      _spokenMessageKeys.remove(oldest);
    }
  }

  void _resetTtsSession() {
    _ttsSessionStartedAt = DateTime.now().toUtc();
    _spokenMessageKeys.clear();
    _spokenMessageOrder.clear();
  }

  void _clearTtsHistory() {
    _spokenMessageKeys.clear();
    _spokenMessageOrder.clear();
    _ttsSessionStartedAt = null;
  }

  void _clearChatMessages() {
    _pipeline.clear();
    if (!_listController.isClosed) {
      _listController.add(const []);
    }
  }

  void _emitYoutubeBadgeValue() {
    if (!_youtubeBadgeController.isClosed) {
      _youtubeBadgeController.add(_youtubeBadgeValue);
    }
  }

  int get _maxTrackedTtsMessages {
    final maxMessages = _lastSettings?.maxMessages ?? 200;
    final scaled = maxMessages * 10;
    if (scaled < 500) return 500;
    if (scaled > 3000) return 3000;
    return scaled;
  }

  void applySettings(SettingsModel s, {required bool connectChats}) {
    final prev = _lastSettings;
    _lastSettings = s;
    final visibleMessagesChanged = _pipeline.updateSettings(s);
    if (visibleMessagesChanged && !_listController.isClosed) {
      _listController.add(_pipeline.buffer);
    }

    unawaited(_tts.updateConfig(
      enabled: s.ttsEnabled,
      modelId: s.ttsModelId,
      voice: s.ttsVoice,
      language: s.ttsLanguage,
      speed: s.ttsSpeed,
      steps: s.ttsSteps,
      referenceAudioPath: s.ttsReferenceAudioPath,
      referenceText: s.ttsReferenceText,
    ));
    unawaited(_captions.updateConfig(
      enabled: s.liveCaptionsEnabled,
      sourceLanguage: s.liveCaptionsSourceLanguage,
      targetLanguage: s.liveCaptionsTargetLanguage,
      denoise: s.liveCaptionsDenoiseEnabled,
    ));

    // Reconnect YouTube if connection params changed.
    final connectionChanged = prev == null ||
        _lastConnectChats == null ||
        _lastConnectChats != connectChats;
    _lastConnectChats = connectChats;

    final horizontalYoutubeId =
        YouTubeService.videoIdFromUrl(s.youtubeHorizontalUrl);
    final verticalYoutubeId =
        YouTubeService.videoIdFromUrl(s.youtubeVerticalUrl);
    final hasYoutubeTarget = s.youtubeEnabled &&
        (s.youtubeDualStreamEnabled
            ? horizontalYoutubeId != null &&
                verticalYoutubeId != null &&
                horizontalYoutubeId != verticalYoutubeId
            : s.youtubeHandle.isNotEmpty || s.youtubeLiveId.isNotEmpty);
    final hasTwitchTarget = s.twitchEnabled && s.twitchChannel.isNotEmpty;
    final hasKickTarget = s.kickEnabled && s.kickSlug.isNotEmpty;

    final ytChanged = connectionChanged ||
        prev.youtubeEnabled != s.youtubeEnabled ||
        prev.youtubeDualStreamEnabled != s.youtubeDualStreamEnabled ||
        prev.youtubeHorizontalUrl != s.youtubeHorizontalUrl ||
        prev.youtubeVerticalUrl != s.youtubeVerticalUrl ||
        prev.youtubeHandle != s.youtubeHandle ||
        prev.youtubeLiveId != s.youtubeLiveId;
    final twChanged = connectionChanged ||
        prev.twitchEnabled != s.twitchEnabled ||
        prev.twitchChannel != s.twitchChannel;
    final kickChanged = connectionChanged ||
        prev.kickEnabled != s.kickEnabled ||
        prev.kickSlug != s.kickSlug;
    final chatAttemptGeneration = ytChanged || twChanged || kickChanged
        ? ++_chatAttemptGeneration
        : _chatAttemptGeneration;

    final shouldResetTtsSession = connectChats &&
        ((ytChanged && hasYoutubeTarget) ||
            (twChanged && hasTwitchTarget) ||
            (kickChanged && hasKickTarget));
    if (shouldResetTtsSession) {
      _clearChatMessages();
      _resetTtsSession();
    } else if (!connectChats) {
      _clearChatMessages();
      _clearTtsHistory();
    }

    if (ytChanged) {
      unawaited(_youtube.disconnect());
      unawaited(_youtubeHorizontal.disconnect());
      unawaited(_youtubeVertical.disconnect());
      _updateStatus('youtube', (ServiceStatus.idle, null));
      _updateStatus('youtubeHorizontal', (ServiceStatus.idle, null));
      _updateStatus('youtubeVertical', (ServiceStatus.idle, null));
      if (connectChats && hasYoutubeTarget) {
        if (s.youtubeDualStreamEnabled) {
          _youtubeBadgeValue = '2 streams';
          _emitYoutubeBadgeValue();
          unawaited(_connectYoutubeStream(
            service: _youtubeHorizontal,
            statusKey: 'youtubeHorizontal',
            url: s.youtubeHorizontalUrl,
            generation: chatAttemptGeneration,
          ));
          unawaited(_connectYoutubeStream(
            service: _youtubeVertical,
            statusKey: 'youtubeVertical',
            url: s.youtubeVerticalUrl,
            generation: chatAttemptGeneration,
          ));
        } else {
          unawaited(_connectYoutube(s, chatAttemptGeneration));
        }
      } else {
        _youtubeBadgeValue = null;
        _emitYoutubeBadgeValue();
        _updateStatus('youtube', (ServiceStatus.idle, null));
      }
    }

    // Twitch
    if (twChanged) {
      if (connectChats && hasTwitchTarget) {
        unawaited(_connectTwitch(s, chatAttemptGeneration));
      } else {
        _twitch.disconnect();
        _updateStatus('twitch', (ServiceStatus.idle, null));
      }
    }

    // Kick
    if (kickChanged) {
      if (connectChats && hasKickTarget) {
        _kick.connect(s.kickSlug);
      } else {
        _kick.disconnect();
        _updateStatus('kick', (ServiceStatus.idle, null));
      }
    }

    // Overlay server
    final overlayChanged = prev == null ||
        prev.overlayPort != s.overlayPort ||
        prev.overlayEnabled != s.overlayEnabled;
    if (overlayChanged) {
      if (s.overlayEnabled) {
        unawaited(_startOverlay(s));
      } else {
        ++_overlayGeneration;
        unawaited(_overlay.stop());
        _emitOverlayState(const OverlayServerState());
      }
    }
    if (s.overlayEnabled) {
      _overlay.setSettings(s);
    }

    final obsChanged = prev == null ||
        prev.obsEnabled != s.obsEnabled ||
        prev.obsHost != s.obsHost ||
        prev.obsPassword != s.obsPassword;
    if (obsChanged) {
      if (!s.obsEnabled) {
        _obsConnectRequested = false;
        unawaited(_obs.disconnect());
      } else if (_obsConnectRequested) {
        unawaited(_obs.connect(host: s.obsHost, password: s.obsPassword));
      }
    }
  }

  Future<void> dispose() async {
    await _pipelineSub?.cancel();
    await _youtubeStatusSub?.cancel();
    await _youtubeHorizontalStatusSub?.cancel();
    await _youtubeVerticalStatusSub?.cancel();
    await _kickStatusSub?.cancel();
    await _twitchStatusSub?.cancel();
    await _captionsSub?.cancel();
    await _ttsPlaybackErrorSub?.cancel();
    _youtube.dispose();
    _youtubeHorizontal.dispose();
    _youtubeVertical.dispose();
    _kick.dispose();
    _twitch.dispose();
    await _overlay.dispose();
    _obs.dispose();
    await _tts.dispose();
    await _captions.dispose();
    _pipeline.dispose();
    await _listController.close();
    await _statusController.close();
    await _youtubeBadgeController.close();
    await _noticeController.close();
    await _overlayStateController.close();
  }
}

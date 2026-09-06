import 'dart:async';
import 'dart:collection';

import 'package:airstream/application/coordinator_notice.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/voice_command.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/tts_message_policy.dart';

abstract interface class TtsClient {
  Stream<TtsLoadState> get loadStateStream;
  Stream<bool> get busyStream;
  Stream<Object> get playbackErrors;
  TtsLoadState get currentLoadState;
  bool get isBusy;
  Future<void> updateConfig({
    required bool enabled,
    required String modelId,
    required String voice,
    required String language,
    required double speed,
    required int steps,
    required String referenceAudioPath,
    required String referenceText,
  });
  Future<void> prepareModel();
  Future<void> removeModel(String modelId);
  void speak(String text, {bool allowDownload});
  Future<void> dispose();
}

abstract interface class CaptionsClient {
  Stream<LiveCaptionsState> get states;
  Future<void> updateConfig({
    required bool enabled,
    required String sourceLanguage,
    required String targetLanguage,
    required bool denoise,
  });
  Future<void> prepareModel();
  Future<void> dispose();
}

class TtsServiceAdapter implements TtsClient {
  TtsServiceAdapter(this.service);

  final TtsService service;

  @override
  Stream<TtsLoadState> get loadStateStream => service.loadStateStream;
  @override
  Stream<bool> get busyStream => service.busyStream;
  @override
  Stream<Object> get playbackErrors => service.playbackErrors;
  @override
  TtsLoadState get currentLoadState => service.currentLoadState;
  @override
  bool get isBusy => service.isBusy;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String modelId,
    required String voice,
    required String language,
    required double speed,
    required int steps,
    required String referenceAudioPath,
    required String referenceText,
  }) =>
      service.updateConfig(
        enabled: enabled,
        modelId: modelId,
        voice: voice,
        language: language,
        speed: speed,
        steps: steps,
        referenceAudioPath: referenceAudioPath,
        referenceText: referenceText,
      );
  @override
  Future<void> prepareModel() => service.prepareModel();
  @override
  Future<void> removeModel(String modelId) => service.removeModel(modelId);
  @override
  void speak(String text, {bool allowDownload = false}) =>
      service.speak(text, allowDownload: allowDownload);
  @override
  Future<void> dispose() => service.dispose();
}

class CaptionsServiceAdapter implements CaptionsClient {
  CaptionsServiceAdapter(this.service);

  final LiveCaptionsService service;

  @override
  Stream<LiveCaptionsState> get states => service.states;
  @override
  Future<void> updateConfig({
    required bool enabled,
    required String sourceLanguage,
    required String targetLanguage,
    required bool denoise,
  }) =>
      service.updateConfig(
        enabled: enabled,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        denoise: denoise,
      );
  @override
  Future<void> prepareModel() => service.prepareModel();
  @override
  Future<void> dispose() => service.dispose();
}

class AudioCoordinator {
  AudioCoordinator({
    required TtsClient tts,
    required CaptionsClient captions,
    String? Function(String value)? youtubeVideoIdFromUrl,
  })  : _tts = tts,
        _captions = captions,
        _youtubeVideoIdFromUrl =
            youtubeVideoIdFromUrl ?? YouTubeService.videoIdFromUrl {
    _ttsErrorSubscription = _tts.playbackErrors.listen((_) {
      _emitNotice(
        const CoordinatorNotice(
          AppNoticeCode.ttsPlaybackFailed,
          AppNoticeSeverity.error,
        ),
      );
    });
    _captionsSubscription = _captions.states.listen(_handleCaptionsState);
  }

  final TtsClient _tts;
  final CaptionsClient _captions;
  final String? Function(String value) _youtubeVideoIdFromUrl;
  final _spokenMessageKeys = <String>{};
  final _spokenMessageOrder = Queue<String>();
  final _captionController = StreamController<String>.broadcast();
  final _voiceCommandController = StreamController<VoiceCommand>.broadcast();
  final _noticeController = StreamController<CoordinatorNotice>.broadcast();
  StreamSubscription<Object>? _ttsErrorSubscription;
  StreamSubscription<LiveCaptionsState>? _captionsSubscription;
  SettingsModel? _lastSettings;
  bool? _lastConnectChats;
  DateTime? _ttsSessionStartedAt;
  bool _disposed = false;

  Stream<TtsLoadState> get ttsLoadStateStream async* {
    yield _tts.currentLoadState;
    yield* _tts.loadStateStream;
  }

  Stream<bool> get ttsBusyStream async* {
    yield _tts.isBusy;
    yield* _tts.busyStream;
  }

  Stream<LiveCaptionsState> get liveCaptionsStateStream => _captions.states;
  Stream<String> get finalizedCaptions => _captionController.stream;
  Stream<VoiceCommand> get voiceCommands => _voiceCommandController.stream;
  Stream<CoordinatorNotice> get notices => _noticeController.stream;

  bool testTts(String text) {
    if (text.isEmpty || _tts.currentLoadState.isLoading || _tts.isBusy) {
      return false;
    }
    _tts.speak(text, allowDownload: true);
    return true;
  }

  Future<void> downloadTtsModel() => _tts.prepareModel();
  Future<void> removeTtsModel(String modelId) => _tts.removeModel(modelId);
  Future<void> downloadLiveCaptionsModel() => _captions.prepareModel();

  void applySettings(SettingsModel settings, {required bool connectChats}) {
    if (_disposed) return;
    final previous = _lastSettings;
    final connectionChanged = previous == null ||
        _lastConnectChats == null ||
        _lastConnectChats != connectChats;
    _lastSettings = settings;
    _lastConnectChats = connectChats;

    unawaited(_updateTtsConfig(settings));
    unawaited(_updateCaptionsConfig(settings));

    final youtubeChanged = connectionChanged ||
        previous.youtubeEnabled != settings.youtubeEnabled ||
        previous.youtubeDualStreamEnabled !=
            settings.youtubeDualStreamEnabled ||
        previous.youtubeHorizontalUrl != settings.youtubeHorizontalUrl ||
        previous.youtubeVerticalUrl != settings.youtubeVerticalUrl ||
        previous.youtubeHandle != settings.youtubeHandle ||
        previous.youtubeLiveId != settings.youtubeLiveId;
    final twitchChanged = connectionChanged ||
        previous.twitchEnabled != settings.twitchEnabled ||
        previous.twitchChannel != settings.twitchChannel;
    final kickChanged = connectionChanged ||
        previous.kickEnabled != settings.kickEnabled ||
        previous.kickSlug != settings.kickSlug;
    final horizontalYoutubeId =
        _youtubeVideoIdFromUrl(settings.youtubeHorizontalUrl);
    final verticalYoutubeId =
        _youtubeVideoIdFromUrl(settings.youtubeVerticalUrl);
    final hasYoutubeTarget = settings.youtubeEnabled &&
        (settings.youtubeDualStreamEnabled
            ? horizontalYoutubeId != null &&
                verticalYoutubeId != null &&
                horizontalYoutubeId != verticalYoutubeId
            : settings.youtubeHandle.isNotEmpty ||
                settings.youtubeLiveId.isNotEmpty);
    final hasTwitchTarget =
        settings.twitchEnabled && settings.twitchChannel.isNotEmpty;
    final hasKickTarget = settings.kickEnabled && settings.kickSlug.isNotEmpty;
    final shouldResetSession = connectChats &&
        ((youtubeChanged && hasYoutubeTarget) ||
            (twitchChanged && hasTwitchTarget) ||
            (kickChanged && hasKickTarget));
    if (shouldResetSession) {
      _resetTtsSession();
    } else if (!connectChats) {
      _clearTtsHistory();
    }
  }

  Future<void> _updateTtsConfig(SettingsModel settings) async {
    try {
      await _tts.updateConfig(
        enabled: settings.ttsEnabled,
        modelId: settings.ttsModelId,
        voice: settings.ttsVoice,
        language: settings.ttsLanguage,
        speed: settings.ttsSpeed,
        steps: settings.ttsSteps,
        referenceAudioPath: settings.ttsReferenceAudioPath,
        referenceText: settings.ttsReferenceText,
      );
    } catch (error, stack) {
      AppLogger.error(
        'TTS configuration failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> _updateCaptionsConfig(SettingsModel settings) async {
    try {
      await _captions.updateConfig(
        enabled: settings.liveCaptionsEnabled,
        sourceLanguage: settings.liveCaptionsSourceLanguage,
        targetLanguage: settings.liveCaptionsTargetLanguage,
        denoise: settings.liveCaptionsDenoiseEnabled,
      );
    } catch (error, stack) {
      AppLogger.error(
        'Live captions configuration failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void handleChatMessage(ChatMessage message) {
    final settings = _lastSettings;
    if (settings == null || !settings.ttsEnabled) return;
    if (settings.ttsMembersOnly && !message.isMembership) return;
    if (!isTtsMessageFresh(message, _ttsSessionStartedAt)) return;

    final speakKey = message.dedupeKey;
    if (_spokenMessageKeys.contains(speakKey)) return;
    final authorName = sanitizeTtsAuthorName(message.author.name);
    var text = message.ttsText.trim();
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

  void _handleCaptionsState(LiveCaptionsState state) {
    if (!state.captionFinal) return;
    final settings = _lastSettings;
    if (settings?.liveCaptionsOverlayEnabled == true &&
        !_captionController.isClosed) {
      _captionController.add(state.caption);
    }
    if (settings?.voiceCommandsEnabled != true) return;
    final command = VoiceCommand.parse(
      state.caption,
      wakeWord: settings?.voiceCommandsWakeWord ?? 'airstream',
    );
    if (command != null && !_voiceCommandController.isClosed) {
      _voiceCommandController.add(command);
    }
  }

  void _rememberSpokenMessage(String key) {
    _spokenMessageKeys.add(key);
    _spokenMessageOrder.addLast(key);
    while (_spokenMessageOrder.length > _maxTrackedTtsMessages) {
      _spokenMessageKeys.remove(_spokenMessageOrder.removeFirst());
    }
  }

  int get _maxTrackedTtsMessages {
    final scaled = (_lastSettings?.maxMessages ?? 200) * 10;
    if (scaled < 500) return 500;
    if (scaled > 3000) return 3000;
    return scaled;
  }

  void _resetTtsSession() {
    _ttsSessionStartedAt = DateTime.now().toUtc();
    _spokenMessageKeys.clear();
    _spokenMessageOrder.clear();
  }

  void _clearTtsHistory() {
    _ttsSessionStartedAt = null;
    _spokenMessageKeys.clear();
    _spokenMessageOrder.clear();
  }

  void _emitNotice(CoordinatorNotice notice) {
    if (!_noticeController.isClosed) _noticeController.add(notice);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _ttsErrorSubscription?.cancel();
    await _captionsSubscription?.cancel();
    await _tts.dispose();
    await _captions.dispose();
    await _captionController.close();
    await _voiceCommandController.close();
    await _noticeController.close();
  }
}

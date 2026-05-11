import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/pipeline/message_pipeline.dart';
import 'package:airchat_flutter/services/kick_service.dart';
export 'package:airchat_flutter/services/kick_service.dart' show ServiceStatus;
export 'package:airchat_flutter/services/tts_service.dart'
    show TtsLoadPhase, TtsLoadState;
import 'package:airchat_flutter/services/overlay_server.dart';
import 'package:airchat_flutter/services/obs_service.dart';
import 'package:airchat_flutter/services/twitch_service.dart';
import 'package:airchat_flutter/services/youtube_service.dart';
import 'package:airchat_flutter/services/tts_service.dart';
import 'package:airchat_flutter/settings/tts_message_policy.dart';
import 'package:airchat_flutter/settings/settings_model.dart';

const _prefsKey = 'AIRCHAT_SETTINGS';

// ── providers ────────────────────────────────────────────────────────────────

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsModel>(
  (ref) => SettingsNotifier(),
);

final chatConnectionProvider = StateProvider<bool>((ref) => false);

final chatProvider = StreamProvider<List<ChatMessage>>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.messageListStream;
});

final overlayUrlProvider = Provider<String?>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.overlayUrl;
});

final youtubeBadgeValueProvider = StreamProvider<String?>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.youtubeBadgeValueStream;
});

/// Per-platform connection status: map of platform name → (status, error message).
final connectionStatusProvider =
    StreamProvider<Map<String, (ServiceStatus, String?)>>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.connectionStatusStream;
});

final ttsLoadStateProvider = StreamProvider<TtsLoadState>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.ttsLoadStateStream;
});

final ttsBusyProvider = StreamProvider<bool>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.ttsBusyStream;
});

final obsStateProvider = StreamProvider<ObsState>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.obsStateStream;
});

final appControllerProvider = Provider<AppController>((ref) {
  final settings = ref.watch(settingsProvider);
  final connectChats = ref.watch(chatConnectionProvider);
  final controller = ref.read(_appControllerInstanceProvider);
  controller.applySettings(settings, connectChats: connectChats);
  return controller;
});

final _appControllerInstanceProvider = Provider<AppController>((ref) {
  final c = AppController();
  ref.onDispose(c.dispose);
  return c;
});

// ── SettingsNotifier ─────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<SettingsModel> {
  SettingsNotifier() : super(const SettingsModel()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      try {
        state = SettingsModel.fromJsonString(json);
      } catch (_) {}
    }
  }

  Future<void> update(SettingsModel settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, settings.toJsonString());
  }
}

// ── AppController ─────────────────────────────────────────────────────────────

/// Owns all services. Reconnects when settings change.
class AppController {
  final _youtube = YouTubeService();
  final _kick = KickService();
  final _twitch = TwitchService();
  final _overlay = OverlayServer();
  final _obs = ObsService();
  final _tts = TtsService();
  late final MessagePipeline _pipeline;
  StreamSubscription<ChatMessage>? _pipelineSub;
  StreamSubscription<(ServiceStatus, String?)>? _kickStatusSub;
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

  final _platformStatus = <String, (ServiceStatus, String?)>{
    'youtube': (ServiceStatus.idle, null),
    'twitch': (ServiceStatus.idle, null),
    'kick': (ServiceStatus.idle, null),
  };
  String? _youtubeBadgeValue;

  SettingsModel? _lastSettings;
  bool? _lastConnectChats;
  DateTime? _ttsSessionStartedAt;
  bool _obsConnectRequested = false;

  AppController() {
    _pipeline = MessagePipeline(const SettingsModel());
    _pipeline.addSource(_youtube.messages);
    _pipeline.addSource(_kick.messages);
    _pipeline.addSource(_twitch.messages);
    _pipelineSub = _pipeline.stream.listen((msg) {
      _listController.add(_pipeline.buffer);
      _speakMessageIfEligible(msg);
    });
    // Forward per-service status to the aggregated stream.
    _kickStatusSub = _kick.statusStream.listen((s) => _updateStatus('kick', s));
  }

  Future<void> _connectYoutube(SettingsModel s) async {
    _updateStatus('youtube', (ServiceStatus.connecting, null));
    _youtubeBadgeValue = null;
    _emitYoutubeBadgeValue();
    try {
      await _youtube.connect(handle: s.youtubeHandle, liveId: s.youtubeLiveId);
      _youtubeBadgeValue = _youtube.resolvedLiveId.isNotEmpty
          ? _youtube.resolvedLiveId
          : s.youtubeHandle.trim();
      _emitYoutubeBadgeValue();
      _updateStatus('youtube', (ServiceStatus.connected, null));
    } catch (e) {
      debugPrint('YouTubeService.connect failed: $e');
      await _youtube.disconnect();
      _youtubeBadgeValue = null;
      _emitYoutubeBadgeValue();
      _updateStatus('youtube', (ServiceStatus.error, e.toString()));
    }
  }

  Future<void> _connectTwitch(SettingsModel s) async {
    _updateStatus('twitch', (ServiceStatus.connecting, null));
    try {
      await _twitch.connect(s.twitchChannel);
      _updateStatus('twitch', (ServiceStatus.connected, null));
    } catch (e) {
      debugPrint('TwitchService.connect failed: $e');
      await _twitch.disconnect();
      _updateStatus('twitch', (ServiceStatus.error, e.toString()));
    }
  }

  void _updateStatus(String platform, (ServiceStatus, String?) status) {
    _platformStatus[platform] = status;
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_platformStatus));
    }
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

  Stream<ObsState> get obsStateStream async* {
    yield _obs.currentState;
    yield* _obs.stateStream;
  }

  String? get overlayUrl => _overlay.localIp != null
      ? 'http://${_overlay.localIp}:${_overlay.port}'
      : null;

  bool testTts(String text) {
    if (text.isEmpty) return false;
    if (_tts.currentLoadState.isLoading || _tts.isBusy) return false;
    _tts.speak(text);
    return true;
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

  void _speakMessageIfEligible(ChatMessage msg) {
    final settings = _lastSettings;
    if (settings == null || !settings.ttsEnabled) return;
    if (settings.ttsMembersOnly && !msg.isMembership) return;
    if (!isTtsMessageFresh(msg, _ttsSessionStartedAt)) return;

    final speakKey = msg.dedupeKey;
    if (_spokenMessageKeys.contains(speakKey)) return;

    final authorName = sanitizeTtsAuthorName(msg.author.name);
    var text = msg.plainText.trim();
    if (text.isEmpty) return;

    if (settings.ttsCommandMode) {
      final prefix = settings.ttsCommandPrefix.trim().toLowerCase();
      if (prefix.isNotEmpty) {
        if (!text.toLowerCase().startsWith(prefix)) return;
        text = text.substring(prefix.length).trim();
        if (text.isEmpty) return;
      }
    }

    _rememberSpokenMessage(speakKey);
    final separator = settings.ttsSeparatorText;
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
    _pipeline.updateSettings(s);

    _tts.updateConfig(s.ttsVoice, s.ttsLanguage);

    // Reconnect YouTube if connection params changed.
    final connectionChanged = prev == null ||
        _lastConnectChats == null ||
        _lastConnectChats != connectChats;
    _lastConnectChats = connectChats;

    final hasYoutubeTarget =
        s.youtubeHandle.isNotEmpty || s.youtubeLiveId.isNotEmpty;
    final hasTwitchTarget = s.twitchChannel.isNotEmpty;
    final hasKickTarget = s.kickSlug.isNotEmpty;

    final ytChanged = connectionChanged ||
        prev.youtubeHandle != s.youtubeHandle ||
        prev.youtubeLiveId != s.youtubeLiveId;
    final twChanged =
        connectionChanged || prev.twitchChannel != s.twitchChannel;
    final kickChanged = connectionChanged || prev.kickSlug != s.kickSlug;

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
      if (connectChats && hasYoutubeTarget) {
        unawaited(_connectYoutube(s));
      } else {
        _youtube.disconnect();
        _youtubeBadgeValue = null;
        _emitYoutubeBadgeValue();
        _updateStatus('youtube', (ServiceStatus.idle, null));
      }
    }

    // Twitch
    if (twChanged) {
      if (connectChats && hasTwitchTarget) {
        unawaited(_connectTwitch(s));
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
      }
    }

    // Overlay server
    final overlayChanged = prev == null ||
        prev.overlayPort != s.overlayPort ||
        prev.overlayEnabled != s.overlayEnabled;
    if (overlayChanged) {
      if (s.overlayEnabled) {
        _overlay
            .start(
              messages: _pipeline.stream,
              settings: s,
              port: s.overlayPort,
            )
            .catchError((e) => debugPrint('OverlayServer.start failed: $e'));
      } else {
        _overlay.stop();
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

  void dispose() {
    _pipelineSub?.cancel();
    _kickStatusSub?.cancel();
    _youtube.dispose();
    _kick.dispose();
    _twitch.dispose();
    _overlay.stop();
    _obs.dispose();
    _tts.dispose();
    _pipeline.dispose();
    _listController.close();
    _statusController.close();
    _youtubeBadgeController.close();
  }
}

import 'dart:async';

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
import 'package:airchat_flutter/services/twitch_service.dart';
import 'package:airchat_flutter/services/youtube_service.dart';
import 'package:airchat_flutter/services/tts_service.dart';
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
  final _tts = TtsService();
  late final MessagePipeline _pipeline;

  final _listController =
      // ignore: close_sinks
      StreamController<List<ChatMessage>>.broadcast();

  final _statusController =
      // ignore: close_sinks
      StreamController<Map<String, (ServiceStatus, String?)>>.broadcast();

  final _platformStatus = <String, (ServiceStatus, String?)>{
    'youtube': (ServiceStatus.idle, null),
    'twitch': (ServiceStatus.idle, null),
    'kick': (ServiceStatus.idle, null),
  };

  SettingsModel? _lastSettings;
  bool? _lastConnectChats;

  AppController() {
    _pipeline = MessagePipeline(const SettingsModel());
    _pipeline.addSource(_youtube.messages);
    _pipeline.addSource(_kick.messages);
    _pipeline.addSource(_twitch.messages);
    _pipeline.stream.listen((msg) {
      _listController.add(_pipeline.buffer);

      // Trigger TTS if enabled
      if (_lastSettings?.ttsEnabled == true) {
        if (_lastSettings?.ttsMembersOnly == true && !msg.isMembership) {
          // Skip if members only
        } else {
          final authorName = msg.author.name;
          var text = msg.plainText;

          if (text.isNotEmpty) {
            // Command mode
            if (_lastSettings?.ttsCommandMode == true) {
              final prefix = (_lastSettings?.ttsCommandPrefix ?? '!voz')
                  .trim()
                  .toLowerCase();
              if (prefix.isNotEmpty) {
                if (!text.toLowerCase().startsWith(prefix)) {
                  return; // Skip if it doesn't start with prefix
                }
                // Remove prefix
                text = text.substring(prefix.length).trim();
                if (text.isEmpty) return;
              }
            }

            final separator = _lastSettings?.ttsSeparatorText ?? 'dice';
            _tts.speak('$authorName $separator: $text');
          }
        }
      }
    });
    // Forward per-service status to the aggregated stream.
    _kick.statusStream.listen((s) => _updateStatus('kick', s));
  }

  Future<void> _connectYoutube(SettingsModel s) async {
    _updateStatus('youtube', (ServiceStatus.connecting, null));
    try {
      await _youtube.connect(handle: s.youtubeHandle, liveId: s.youtubeLiveId);
      _updateStatus('youtube', (ServiceStatus.connected, null));
    } catch (e) {
      debugPrint('YouTubeService.connect failed: $e');
      await _youtube.disconnect();
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

  Stream<TtsLoadState> get ttsLoadStateStream async* {
    yield _tts.currentLoadState;
    yield* _tts.loadStateStream;
  }

  String? get overlayUrl => _overlay.localIp != null
      ? 'http://${_overlay.localIp}:${_overlay.port}'
      : null;

  void testTts(String text) {
    if (text.isNotEmpty) {
      _tts.speak(text);
    }
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

    final ytChanged = connectionChanged ||
        prev.youtubeHandle != s.youtubeHandle ||
        prev.youtubeLiveId != s.youtubeLiveId;
    if (ytChanged) {
      if (connectChats &&
          (s.youtubeHandle.isNotEmpty || s.youtubeLiveId.isNotEmpty)) {
        unawaited(_connectYoutube(s));
      } else {
        _youtube.disconnect();
        _updateStatus('youtube', (ServiceStatus.idle, null));
      }
    }

    // Twitch
    final twChanged =
        connectionChanged || prev.twitchChannel != s.twitchChannel;
    if (twChanged) {
      if (connectChats && s.twitchChannel.isNotEmpty) {
        unawaited(_connectTwitch(s));
      } else {
        _twitch.disconnect();
        _updateStatus('twitch', (ServiceStatus.idle, null));
      }
    }

    // Kick
    final kickChanged = connectionChanged || prev.kickSlug != s.kickSlug;
    if (kickChanged) {
      if (connectChats && s.kickSlug.isNotEmpty) {
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
            .start(messages: _pipeline.stream, port: s.overlayPort)
            .catchError((e) => debugPrint('OverlayServer.start failed: $e'));
      } else {
        _overlay.stop();
      }
    }
  }

  void dispose() {
    _youtube.dispose();
    _kick.dispose();
    _twitch.dispose();
    _overlay.stop();
    _tts.dispose();
    _pipeline.dispose();
  }
}

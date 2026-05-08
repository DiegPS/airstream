import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/pipeline/message_pipeline.dart';
import 'package:airchat_flutter/services/kick_service.dart';
export 'package:airchat_flutter/services/kick_service.dart' show ServiceStatus;
import 'package:airchat_flutter/services/overlay_server.dart';
import 'package:airchat_flutter/services/twitch_service.dart';
import 'package:airchat_flutter/services/youtube_service.dart';
import 'package:airchat_flutter/services/tts_service.dart';
import 'package:airchat_flutter/settings/settings_model.dart';
import 'package:airchat_flutter/services/window_control_service.dart';

const _prefsKey = 'AIRCHAT_SETTINGS';

// ── providers ────────────────────────────────────────────────────────────────

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsModel>(
  (ref) => SettingsNotifier(),
);

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

final appControllerProvider = Provider<AppController>((ref) {
  final settings = ref.watch(settingsProvider);
  final controller = ref.read(_appControllerInstanceProvider);
  controller.applySettings(settings);
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
              final prefix = (_lastSettings?.ttsCommandPrefix ?? '!voz').trim().toLowerCase();
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

  Stream<Map<String, (ServiceStatus, String?)>> get connectionStatusStream async* {
    yield Map.from(_platformStatus);
    yield* _statusController.stream;
  }

  String? get overlayUrl => _overlay.localIp != null
      ? 'http://${_overlay.localIp}:${_overlay.port}'
      : null;

  void testTts(String text) {
    if (text.isNotEmpty) {
      _tts.speak(text);
    }
  }

  void applySettings(SettingsModel s) {
    final prev = _lastSettings;
    _lastSettings = s;
    _pipeline.updateSettings(s);

    _tts.updateConfig(s.ttsVoice, s.ttsLanguage);

    // Reconnect YouTube if connection params changed.
    final ytChanged = prev == null ||
        prev.youtubeHandle != s.youtubeHandle ||
        prev.youtubeLiveId != s.youtubeLiveId;
    if (ytChanged) {
      if (s.youtubeHandle.isNotEmpty || s.youtubeLiveId.isNotEmpty) {
        _youtube.connect(
            handle: s.youtubeHandle, liveId: s.youtubeLiveId);
      } else {
        _youtube.disconnect();
      }
    }

    // Twitch
    final twChanged = prev == null || prev.twitchChannel != s.twitchChannel;
    if (twChanged) {
      if (s.twitchChannel.isNotEmpty) {
        _twitch.connect(s.twitchChannel);
      } else {
        _twitch.disconnect();
      }
    }

    // Kick
    final kickChanged = prev == null ||
        prev.kickSlug != s.kickSlug ||
        prev.kickChatroomId != s.kickChatroomId;
    if (kickChanged) {
      if (s.kickChatroomId > 0) {
        // Direct ID — no HTTP lookup, bypasses Cloudflare.
        _kick.connectById(s.kickChatroomId);
      } else if (s.kickSlug.isNotEmpty) {
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

    // Window behaviour (Windows-only) — aplica inmediatamente a la ventana nativa.
    final winChanged = prev == null ||
        prev.clickThrough != s.clickThrough ||
        prev.alwaysOnTop != s.alwaysOnTop;
    if (winChanged) {
      WindowControlService.setClickThrough(s.clickThrough);
      WindowControlService.setAlwaysOnTop(s.alwaysOnTop);
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

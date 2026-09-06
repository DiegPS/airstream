import 'dart:async';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatConnectionProvider = StateProvider<bool>((ref) => false);

final chatProvider = StreamProvider<List<ChatMessage>>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.messageListStream;
});

final overlayUrlProvider = Provider<String?>((ref) {
  ref.watch(overlayServerStateProvider);
  final app = ref.watch(appControllerProvider);
  return app.overlayUrl;
});

final overlayClientCountProvider = StreamProvider<int>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.overlayClientCountStream;
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

final chatSessionPhaseProvider = Provider<ChatSessionPhase>((ref) {
  return resolveChatSessionPhase(
    requested: ref.watch(chatConnectionProvider),
    settings: ref.watch(settingsProvider),
    statuses: ref.watch(connectionStatusProvider).valueOrNull ?? const {},
  );
});

final appNoticeProvider = StreamProvider<AppNotice>((ref) {
  return ref.watch(appControllerProvider).noticeStream;
});

final overlayServerStateProvider = StreamProvider<OverlayServerState>((ref) {
  return ref.watch(appControllerProvider).overlayStateStream;
});

final ttsLoadStateProvider = StreamProvider<TtsLoadState>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.ttsLoadStateStream;
});

final ttsBusyProvider = StreamProvider<bool>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.ttsBusyStream;
});

final liveCaptionsStateProvider = StreamProvider<LiveCaptionsState>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.liveCaptionsStateStream;
});

final obsStateProvider = StreamProvider<ObsState>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.obsStateStream;
});

final appControllerProvider = Provider<AppController>((ref) {
  final settings = ref.watch(settingsProvider);
  final connectChats = ref.watch(chatConnectionProvider);
  final controller = ref.read(_appControllerInstanceProvider);
  final initialization = ref.watch(settingsInitializationProvider);
  if (initialization is AsyncData<void>) {
    controller.applySettings(settings, connectChats: connectChats);
  }
  return controller;
});

final _appControllerInstanceProvider = Provider<AppController>((ref) {
  final c = AppController();
  ref.onDispose(() => unawaited(c.dispose()));
  return c;
});

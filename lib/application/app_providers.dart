import 'dart:async';

import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/chat_view_filter.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/pipeline/chat_highlighter.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/window/global_shortcuts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final chatConnectionProvider = StateProvider<bool>((ref) => false);

/// Which chat messages stand out: mentions and highlight words.
final chatHighlighterProvider = Provider<ChatHighlighter>((ref) {
  ref.watch(settingsProvider.select((s) => (
        s.highlightMentions,
        s.highlightWords,
        s.twitchChannel,
        s.kickSlug,
        s.youtubeHandle,
      )));
  return ChatHighlighter.fromSettings(ref.read(settingsProvider));
});

/// What Airstream's chat window shows. Not saved: the chat always opens
/// showing everything.
final chatViewFilterProvider =
    StateProvider<ChatViewFilter>((ref) => const ChatViewFilter());

/// The current chat poll, if any.
final chatPollProvider = StreamProvider<ChatPoll?>((ref) {
  return ref.watch(appControllerProvider).pollStream;
});

final recentAlertsProvider = StreamProvider<List<Map<String, Object?>>>((ref) {
  return ref.watch(appControllerProvider).recentAlerts;
});

/// Whether the search field above the chat is open.
final chatSearchOpenProvider = StateProvider<bool>((ref) => false);

/// The global shortcuts the user assigned, registered with Windows. Its
/// state is the set of actions whose shortcut another app already owns.
final globalShortcutsProvider =
    StateNotifierProvider<GlobalShortcutsNotifier, Set<GlobalShortcutAction>>(
  (ref) {
    final shortcuts = GlobalShortcutsNotifier(
      onPressed: (action) {
        switch (action) {
          case GlobalShortcutAction.silenceTts:
            unawaited(ref.read(appControllerProvider).silenceTts());
          case GlobalShortcutAction.toggleTts:
            final settings = ref.read(settingsProvider);
            unawaited(ref.read(settingsProvider.notifier).update(
                  settings.copyWith(ttsEnabled: !settings.ttsEnabled),
                ));
        }
      },
    );
    ref.listen(
      settingsProvider
          .select((s) => (s.shortcutSilenceTts, s.shortcutToggleTts)),
      (_, next) => unawaited(shortcuts.apply({
        GlobalShortcutAction.silenceTts: next.$1,
        GlobalShortcutAction.toggleTts: next.$2,
      })),
      fireImmediately: true,
    );
    return shortcuts;
  },
);

/// Whether the chat and the OBS overlay show sample messages.
final chatPreviewProvider = StateProvider<bool>((ref) => false);

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

final youtubeMetadataProvider =
    StreamProvider<YoutubeLiveMetadataSummary>((ref) {
  final app = ref.watch(appControllerProvider);
  return app.youtubeMetadataStream;
});

final platformMetadataProvider =
    StreamProvider<Map<Platform, PlatformLiveMetadata>>((ref) {
  return ref.watch(appControllerProvider).platformMetadataStream;
});

final chatProviderEventProvider = StreamProvider<ChatProviderEvent>((ref) {
  return ref.watch(appControllerProvider).chatProviderEvents;
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

/// The application controller.
///
/// Settings and the chat switch are pushed to it through listeners, so the
/// provider itself never rebuilds: every stream provider below depends on it,
/// and rebuilding it would resubscribe all of them (and rebuild every widget
/// that watches them) on each settings change, such as each slider step.
final appControllerProvider = Provider<AppController>((ref) {
  final controller = ref.watch(_appControllerInstanceProvider);
  void apply() {
    if (ref.read(settingsInitializationProvider) is! AsyncData<void>) return;
    controller.applySettings(
      ref.read(settingsProvider),
      connectChats: ref.read(chatConnectionProvider),
    );
  }

  ref.listen(settingsProvider, (_, __) => apply());
  ref.listen(chatConnectionProvider, (_, __) => apply());
  ref.listen(settingsInitializationProvider, (_, __) => apply());
  apply();
  return controller;
});

final _appControllerInstanceProvider = Provider<AppController>((ref) {
  final c = AppController();
  ref.onDispose(() => unawaited(c.dispose()));
  return c;
});

final overlayViewCountsProvider = StreamProvider<Map<String, int>>((ref) {
  return ref.watch(appControllerProvider).overlayViewCountsStream;
});

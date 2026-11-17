import 'rules/rule_engine.dart';
import 'rules/rule_events.dart';
import 'rules/rule_actions.dart';
import 'dart:io';
import 'dart:async';
import 'package:airstream/settings/goals.dart';
import 'package:airstream/application/goal_tracker.dart';

import 'package:airstream/services/overlay/featured_message_delivery.dart';

import 'package:airstream/application/session_summary.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/coordinator_notice.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/services/chat_log_writer.dart';
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

    rules = RuleEngine(
        target: RuleActions(
            settings: () => _lastSettings ?? const SettingsModel(),
            writeSettings: (s, depth) async {
              final write = ruleSettingsWriter;
              if (write == null) throw StateError('Settings unavailable');
              _settingsDepth = depth;
              try {
                final pending = write(s);
                _settingsDepth = 0;
                await pending;
              } finally {
                _settingsDepth = 0;
              }
            },
            obs: _obs,
            audio: _audio,
            giveaway: _giveaway,
            server: () => templateServer,
            feature: featureMessageOnStream,
            draw: (depth) {
              final winner = _giveaway.draw();
              if (winner != null) _winnerEvent(depth);
            }));
    _subscriptions.addAll([
      _chat.messages
          .listen((m) => _emitGoalIncrements(_goalTracker.message(m))),
      _chat.providerEvents
          .listen((e) => _emitGoalIncrements(_goalTracker.event(e))),
      _chat.messages.listen(_chatLog.write),
      _chat.messages.listen(_sessionSummary.handleMessage),
      _chat.providerEvents.listen(_sessionSummary.handleProviderEvent),
      _chat.messages.listen(_giveaway.handleMessage),
      _giveaway.states.listen(
          (state) => _overlay.broadcastGiveaway(state?.toOverlayJson())),
      _chat.messages.listen(_poll.handleMessage),
      _poll.states.listen(
        (poll) => _overlay.broadcastPoll(poll?.toOverlayJson()),
      ),
      _chat.messages.listen(_overlayFeed.add),
      _chat.messages.listen(_audio.handleChatMessage),
      _chat.messages.listen((m) {
        if (rules.active) {
          for (final e in _ruleAdapter.message(m,
              firstInSession: m.isOwner || m.isMembershipEvent
                  ? null
                  : m.isFirstInSession)) {
            rules.handle(e);
          }
        }
      }),
      _chat.providerEvents.listen((e) {
        if (rules.active) {
          final event = _ruleAdapter.provider(e);
          if (event != null) rules.handle(event);
        }
      }),
      _giveaway.states.listen((g) {
        if (g != null && g.drawId > _lastDrawId) {
          _winnerEvent(0);
        }
      }),
      _poll.states.listen((p) {
        if (rules.active && _pollWasOpen && p?.closed == true) {
          rules.handle(RuleEvent(
              type: 'poll.ended', eventId: 'poll_${++_ruleEventSequence}'));
        }
        _pollWasOpen = p != null && !p.closed;
      }),
      _chat.moderationEvents.listen(_audio.handleModeration),
      _chat.moderationEvents.listen(_overlay.broadcastModeration),
      _chat.providerEvents.listen(_overlay.broadcastProviderEvent),
      _audio.finalizedCaptions.listen(_overlay.broadcastCaption),
      _audio.voiceCommands.listen(
        (command) => unawaited(_obs.executeVoiceCommand(command)),
      ),
      _audio.notices.listen(_emitNotice),
      _obs.notices.listen(_emitNotice),
      _obs.stateStream.listen((state) {
        final events = _obs.ruleEvents.observe(state);
        rules.updateEnvironment();
        if (rules.active) {
          for (final event in events) {
            rules.handle(event);
          }
        }
      }),
      _chat.connectionStatusStream.listen((states) => rules.updateEnvironment(
          chatConnected:
              states.values.any((s) => s.$1 == ServiceStatus.connected))),
    ]);
  }

  OverlayServer? get templateServer => _overlay.templateServer;
  late final RuleEngine rules;
  final _ruleAdapter = RuleEventAdapter();
  Future<void> Function(SettingsModel)? ruleSettingsWriter;
  int _settingsDepth = 0, _lastDrawId = 0, _ruleEventSequence = 0;
  bool _pollWasOpen = false;
  Timer? _ruleEndTimer;
  void _winnerEvent(int depth) {
    final g = _giveaway.current;
    if (g == null || g.drawId <= _lastDrawId) return;
    _lastDrawId = g.drawId;
    if (rules.active) {
      rules.handle(RuleEvent(
          type: 'giveaway.winner',
          eventId: 'draw:${g.drawId}',
          chainDepth: depth,
          platform: g.winner?.platform.name ?? '',
          author: RuleAuthor(
              name: g.winner?.name ?? '', id: g.winner?.authorId ?? '')));
    }
  }

  late final ChatCoordinator _chat;
  late final AudioCoordinator _audio;
  late final OverlayCoordinator _overlay;
  late final ObsCoordinator _obs;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _goalTracker = GoalTracker();
  final _goalIncrements = StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get goalIncrements => _goalIncrements.stream;
  void _emitGoalIncrements(Map<String, int> increments) {
    if (increments.values.any((n) => n > 0)) _goalIncrements.add(increments);
  }

  final _poll = ChatPollController();
  final _giveaway = ChatGiveawayController();
  final _sessionSummary = SessionSummaryCollector();
  final _chatLog = ChatLogWriter();
  bool _chatRunning = false;

  /// Chat for the overlay: live messages plus any preview samples.
  final _overlayFeed = StreamController<ChatMessage>.broadcast();
  List<ChatMessage> _overlayPreview = const [];
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
  Stream<ChatProviderEvent> get chatProviderEvents => _chat.providerEvents;
  Stream<ChatModerationEvent> get chatModerationEvents =>
      _chat.moderationEvents;
  Stream<Map<Platform, PlatformLiveMetadata>> get platformMetadataStream =>
      _chat.platformMetadataStream;
  Stream<TtsLoadState> get ttsLoadStateStream => _audio.ttsLoadStateStream;
  Stream<bool> get ttsBusyStream => _audio.ttsBusyStream;
  Stream<LiveCaptionsState> get liveCaptionsStateStream =>
      _audio.liveCaptionsStateStream;
  Stream<ObsState> get obsStateStream => _obs.stateStream;
  Stream<Map<String, int>> get overlayViewCountsStream =>
      _overlay.viewCountsStream;

  Stream<int> get overlayClientCountStream => _overlay.clientCountStream;
  Stream<AppNotice> get noticeStream => _noticeController.stream;
  Stream<OverlayServerState> get overlayStateStream => _overlay.stateStream;
  String? get overlayUrl => _overlay.url;

  bool testTts(String text) => _audio.testTts(text);
  Future<void> silenceTts() => _audio.silenceTts();
  Future<void> downloadTtsModel() => _audio.downloadTtsModel();
  Future<void> removeTtsModel(String modelId) => _audio.removeTtsModel(modelId);
  Future<void> downloadLiveCaptionsModel() =>
      _audio.downloadLiveCaptionsModel();
  Future<void> connectObs() => _obs.connect();
  Future<void> disconnectObs() => _obs.disconnect();
  bool reloadOverlay() => _overlay.reload();
  bool testOverlayAlert(String kind) => _overlay.testAlert(kind);
  FeaturedMessageDelivery featureMessageOnStream(ChatMessage message) =>
      _overlay.featureMessage(message);

  /// Where session chat logs are saved.
  Future<Directory> chatLogDirectory() => ChatLogWriter.defaultDirectory();

  /// What happened since the chat was last started.
  SessionSummary get sessionSummary => _sessionSummary.summary;

  Stream<List<Map<String, Object?>>> get recentAlerts => _overlay.recentAlerts;
  bool replayRecentAlert(String id) => _overlay.replayRecentAlert(id);

  Stream<ChatGiveaway?> get giveawayStream => _giveaway.states;
  void startGiveaway({required String keyword, required bool membersOnly}) =>
      _giveaway.start(keyword: keyword, membersOnly: membersOnly);
  void closeGiveaway() => _giveaway.close();
  GiveawayEntrant? drawGiveaway() => _giveaway.draw();
  void clearGiveaway() => _giveaway.clear();

  Stream<ChatPoll?> get pollStream => _poll.states;
  void startPoll({
    required String question,
    required List<String> options,
    Duration? duration,
  }) =>
      _poll.start(question: question, options: options, duration: duration);
  void endPoll() => _poll.end();
  void clearPoll() => _poll.clear();

  /// Shows [samples] in the overlay, replacing an earlier preview. They never
  /// reach TTS.
  void showOverlayPreview(List<ChatMessage> samples) {
    hideOverlayPreview();
    _overlayPreview = samples;
    for (final message in samples) {
      if (!_overlayFeed.isClosed) _overlayFeed.add(message);
    }
  }

  /// Removes the preview samples from the overlay.
  void hideOverlayPreview() {
    for (final message in _overlayPreview) {
      _overlay.broadcastModeration(ChatModerationEvent.message(
        platform: message.platform,
        messageId: message.id,
      ));
    }
    _overlayPreview = const [];
  }

  void retryChatConnections() => _chat.retryConnections();
  void retryChatPlatform(String platform) => _chat.retryPlatform(platform);

  void applySettings(SettingsModel settings, {required bool connectChats}) {
    if (_disposed) return;
    final previous = _lastSettings;
    _lastSettings = settings;
    rules.updateSettings(enabled: settings.rulesEnabled, rules: settings.rules);
    _ruleEndTimer?.cancel();
    _ruleEndTimer = null;
    if (rules.active) {
      if (previous != null) {
        for (final e in settings.goals.entries) {
          final old = previous.goals[e.key];
          if (old != null &&
              (old['current'] as int) < (old['target'] as int) &&
              (e.value['current'] as int) >= (e.value['target'] as int)) {
            rules.handle(RuleEvent(
                type: 'goal.reached',
                goalId: e.key,
                eventId: 'goal:${++_ruleEventSequence}',
                chainDepth: _settingsDepth));
          }
        }
        if (previous.subathonPhase == 'running' &&
            settings.subathonPhase == 'ended') {
          rules.handle(RuleEvent(
              type: 'subathon.ended',
              eventId: 'timer:${previous.subathonEndsAtMs}',
              chainDepth: _settingsDepth));
        }
      }
      if (settings.subathonPhase == 'running' &&
          rules.rules.any((r) =>
              r['enabled'] == true &&
              (r['trigger'] as Map)['type'] == 'subathon.ended')) {
        _ruleEndTimer = Timer(
            Duration(
                milliseconds: (settings.subathonEndsAtMs -
                        DateTime.now().millisecondsSinceEpoch)
                    .clamp(0, 8640000000000000)), () {
          if (rules.active) {
            rules.handle(RuleEvent(
                type: 'subathon.ended',
                eventId: 'timer:${settings.subathonEndsAtMs}'));
          }
        });
      }
    }
    if (connectChats != _chatRunning) {
      _chatRunning = connectChats;
      if (connectChats) {
        _ruleAdapter.startSession();
        _sessionSummary.start();
        _overlay.clearRecentAlerts();
      } else {
        _sessionSummary.stop();
      }
      unawaited(connectChats
          ? _chatLog.startSession(enabled: settings.saveChatLog)
          : _chatLog.endSession());
    } else if (connectChats && previous?.saveChatLog != settings.saveChatLog) {
      unawaited(_chatLog.setEnabled(settings.saveChatLog));
    }
    _chat.applySettings(settings, connectChats: connectChats);
    _audio.applySettings(settings, connectChats: connectChats);
    _overlay.broadcastGoals(Goals.payload(settings.goals));
    _overlay.applySettings(
      settings,
      previous: previous,
      messages: _overlayFeed.stream,
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
    _ruleEndTimer?.cancel();
    await rules.dispose();
    await (rules.target as RuleActions).sounds.dispose();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _chat.dispose();
    await _audio.dispose();
    await _overlay.dispose();
    await _obs.dispose();
    await _noticeController.close();
    await _overlayFeed.close();
    await _poll.dispose();
    await _giveaway.dispose();
    await _goalIncrements.close();
    await _chatLog.endSession();
  }
}

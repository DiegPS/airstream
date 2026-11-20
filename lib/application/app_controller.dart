import 'rules/rule_engine.dart';
import 'rules/rule_events.dart';
import 'rules/rule_actions.dart';
import 'dart:io';
import 'dart:async';
import 'package:airstream/settings/goals.dart';
import 'package:airstream/application/goal_tracker.dart';
import 'package:airstream/application/twitch_gift_groups.dart';

import 'package:airstream/services/overlay/featured_message_delivery.dart';

import 'package:airstream/application/session_summary.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/live_clock.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/settings/chat_reading_options.dart';
import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/application/rules/rule_sound_player.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/coordinator_notice.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/pipeline/chat_filter.dart';
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
    DateTime Function()? clock,
    RuleSoundPlayer? clockSounds,
    ChatLogWriter? chatLog,
  })  : _clockNow = clock ?? DateTime.now,
        _chatLog = chatLog ?? ChatLogWriter() {
    _clockSounds = clockSounds ??
        RuleSoundPlayer(settings: () => _lastSettings ?? const SettingsModel());
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
        clock: _clockNow,
        target: RuleActions(
            settings: () => _lastSettings ?? const SettingsModel(),
            writeSettings: _writeRuleSettings,
            obs: _obs,
            audio: _audio,
            giveaway: _giveaway,
            queue: queue,
            server: () => templateServer,
            feature: featureMessageOnStream,
            draw: (count, depth) => drawGiveaways(count, depth: depth),
            now: _clockNow,
            clock: (op, seconds, depth) =>
                operateClock(op, seconds: seconds, depth: depth)));
    templateServer?.queueState = queue.overlayState;
    templateServer?.sessionState = () =>
        _sessionSummary.templateState(live: _chatRunning && _chatConnected);
    _subscriptions.addAll([
      _chat.messages.listen(
          (m) => _emitGoalIncrements(_goalTracker.message(m), message: m)),
      _chat.providerAccountingEvents
          .listen((e) => _emitGoalIncrements(_goalTracker.event(e))),
      _chat.messages.listen(_chatLog.write),
      _chat.messages.listen((message) {
        if (TwitchGiftGroups.includes(message)) {
          if (_chatRunning && !_chatEnded) {
            _sessionGiftGroups.add(message, _recordSessionGift);
          }
        } else {
          _recordSessionMessage(message);
        }
      }),
      _chat.providerAccountingEvents.listen((event) {
        if (_sessionSummary.handleProviderEvent(event)) {
          templateServer?.sessionChanged();
        }
      }),
      queue.states.listen(
          (state) => templateServer?.broadcastQueue(queue.overlayState(state))),
      _chat.messages.listen(_giveaway.handleMessage),
      _giveaway.states.listen(
          (state) => _overlay.broadcastGiveaway(_giveaway.overlayState(state))),
      _poll.states.listen(
        (poll) => _overlay.broadcastPoll(poll?.toOverlayJson()),
      ),
      _chat.providerEvents.listen(_audio.handleProviderEvent),
      _chat.messages.listen((m) {
        final hiddenVote = _poll.hasOpenPoll && _poll.handleMessage(m);
        if (hiddenVote) {
          for (final id in [m.id, m.sharedSource?.messageId]) {
            if (id != null && id.isNotEmpty) {
              _withheldVoteIds.add((m.platform, id));
            }
          }
        }
        final publicMessage = _withoutPrivateReplyText(m);
        final message = hiddenVote
            ? publicMessage.copyWith(items: const [])
            : publicMessage;
        if (hiddenVote) {
          _overlay.broadcastChatSupport(message);
        } else {
          _audio.handleChatMessage(message);
          _overlayFeed.add(message);
          queue.handleMessage(message);
        }
        if (rules.active) {
          for (final e
              in _ruleAdapter.message(message, supportOnly: hiddenVote)) {
            rules.handle(e);
          }
          if (TwitchGiftGroups.includes(message)) {
            _ruleGiftGroups.add(message, (first, count) {
              if (!rules.active) return;
              for (final event in _ruleAdapter.message(first,
                  supportOnly: true, twitchGiftCount: count)) {
                rules.handle(event);
              }
            });
          }
        }
      }),
      _chat.providerEvents.listen((e) {
        if (rules.active) {
          final event = _ruleAdapter.provider(e);
          if (event != null) rules.handle(event);
        }
      }),
      _poll.ended.listen((poll) {
        if (rules.active) {
          rules.handle(RuleEvent.pollEnded(poll,
              eventId: 'poll_${++_ruleEventSequence}'));
        }
      }),
      _chat.moderationEvents.listen(_audio.handleModeration),
      _chat.moderationEvents.listen(_poll.handleModeration),
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
      _chat.connectionStatusStream.listen((states) {
        final connected =
            states.values.any((s) => s.$1 == ServiceStatus.connected);
        rules.updateEnvironment(chatConnected: connected);
        _syncChatSession();
        if (_chatConnected != connected) {
          _chatConnected = connected;
          if (_chatRunning) templateServer?.sessionChanged();
        }
      }),
    ]);
  }

  OverlayServer? get templateServer => _overlay.templateServer;
  late final RuleEngine rules;
  final _ruleAdapter = RuleEventAdapter();
  final _ruleGiftGroups = TwitchGiftGroups();
  final _sessionGiftGroups = TwitchGiftGroups();

  void _recordSessionMessage(ChatMessage message, {int? twitchGiftCount}) {
    if (_sessionSummary.handleMessage(message,
        twitchGiftCount: twitchGiftCount)) {
      templateServer?.sessionChanged();
    }
  }

  void _recordSessionGift(ChatMessage first, int count) =>
      _recordSessionMessage(first, twitchGiftCount: count);

  Future<void> Function(SettingsModel)? ruleSettingsWriter;
  Future<void> Function(SettingsModel Function(SettingsModel))?
      clockExpiryWriter;
  Future<void> Function(SettingsModel Function(SettingsModel))?
      subathonExpiryWriter;
  Future<void> Function(QueueState)? queueSettingsWriter;
  Future<void>? _queueWrite;
  bool _publishingQueueSettings = false;

  late final queue = ChatQueueController(
    onJoined: (entry, position) => _queueEvent(
      'queue.joined',
      entry,
      position: position,
    ),
    onNext: (entries, depth) => _queueEvent(
      'queue.next',
      entries.first,
      count: entries.length,
      depth: depth,
    ),
    onPersist: (state) {
      final write = queueSettingsWriter;
      if (write == null) return;
      _publishingQueueSettings = true;
      try {
        _queueWrite = Future<void>.sync(() => write(state))
            .catchError((Object error, StackTrace stack) {
          AppLogger.warning('Queue persistence failed',
              error: error, stackTrace: stack);
        });
      } finally {
        _publishingQueueSettings = false;
      }
    },
  );

  void _queueEvent(String type, QueueEntry entry,
      {int? position, int count = 0, int depth = 0}) {
    if (!rules.active) return;
    rules.handle(RuleEvent(
      type: type,
      eventId: 'queue:${++_ruleEventSequence}',
      chainDepth: depth,
      origin: depth == 0 ? null : RuleEventOrigin.current,
      platform: entry.platform.name,
      author:
          RuleAuthor(name: entry.name, id: entry.identity, roles: entry.roles),
      note: position == null ? null : entry.note,
      position: position,
      count: count,
    ));
  }

  Future<void> _winnerNotifications = Future.value();
  int _settingsDepth = 0, _ruleEventSequence = 0;
  Timer? _subathonEndTimer, _clockEndTimer;

  /// The live deadline an enabled subathon.ended rule was listening for.
  int? _watchedSubathonDeadline;
  (int, RuleEventOrigin?)? _pendingSubathonEnd;

  /// A countdown that ended while the app was closed is marked ended on
  /// launch without running clock.ended rules or the end sound.
  bool _clockEndSilently = false;
  (LiveClock, int)? _pendingClockEnd;
  final DateTime Function() _clockNow;
  late final RuleSoundPlayer _clockSounds;

  Future<void> _writeRuleSettings(SettingsModel settings, int depth) async {
    final write = ruleSettingsWriter;
    if (write == null) throw StateError('Settings unavailable');
    final previousDepth = _settingsDepth;
    _settingsDepth = depth;
    late Future<void> pending;
    try {
      pending = write(settings);
    } finally {
      _settingsDepth = previousDepth;
    }
    await pending;
  }

  void _trackSubathon(SettingsModel? previous, SettingsModel settings) {
    final phase = settings.subathonPhase;
    final deadline = settings.subathonEndsAtMs;
    final changed = previous?.subathonPhase != phase ||
        previous?.subathonEndsAtMs != deadline;
    final pendingEnd = _pendingSubathonEnd;
    final watched = _watchedSubathonDeadline;
    if (changed) {
      _subathonEndTimer?.cancel();
      _subathonEndTimer = null;
      _pendingSubathonEnd = null;
      _watchedSubathonDeadline = null;
    }

    final listening = rules.active &&
        rules.rules.any((rule) =>
            rule['enabled'] == true &&
            (rule['trigger'] as Map)['type'] == 'subathon.ended');
    if (!listening) _watchedSubathonDeadline = null;
    if (phase == 'running') {
      // Past deadlines loaded at startup or restored from a backup are
      // baseline settings. Never arm a watch once the deadline has passed.
      if (deadline > _clockNow().millisecondsSinceEpoch) {
        if (listening) _watchedSubathonDeadline = deadline;
        if (changed && subathonExpiryWriter != null) {
          _scheduleSubathonEnd(deadline, previous == null ? 0 : _settingsDepth,
              previous == null ? null : RuleEventOrigin.current);
        }
      }
    } else if (phase == 'ended' &&
        previous != null &&
        listening &&
        (previous.subathonPhase == 'paused' ||
            (previous.subathonPhase == 'running' &&
                previous.subathonEndsAtMs == watched))) {
      final (depth, origin) =
          pendingEnd ?? (_settingsDepth, RuleEventOrigin.current);
      rules.handle(RuleEvent(
          type: 'subathon.ended',
          eventId: 'subathon:${++_ruleEventSequence}',
          chainDepth: depth,
          origin: origin));
    }
  }

  void _scheduleSubathonEnd(int deadline, int depth, RuleEventOrigin? origin) {
    final remaining = deadline - _clockNow().millisecondsSinceEpoch;
    late final Timer timer;
    timer =
        Timer(Duration(milliseconds: remaining.clamp(0, 8640000000000000)), () {
      if (deadline > _clockNow().millisecondsSinceEpoch) {
        _scheduleSubathonEnd(deadline, depth, origin);
        return;
      }
      final writeLatest = subathonExpiryWriter;
      if (writeLatest == null) return;
      unawaited(writeLatest((settings) {
        // A restore can defer this write and replace the running timer,
        // even when the restored settings contain the same deadline.
        if (_disposed ||
            !identical(_subathonEndTimer, timer) ||
            settings.subathonEndsAtMs != deadline) {
          return settings;
        }
        final next = SubathonTimer.normalize(
            settings, _clockNow().millisecondsSinceEpoch);
        if (!identical(next, settings)) _pendingSubathonEnd = (depth, origin);
        return next;
      }).catchError((Object error, StackTrace stack) {
        AppLogger.warning('Subathon persistence failed',
            error: error, stackTrace: stack);
      }));
    });
    _subathonEndTimer = timer;
  }

  Future<void> operateClock(String op, {int seconds = 0, int depth = 0}) async {
    final settings = _lastSettings;
    if (settings == null || _disposed || ruleSettingsWriter == null) return;
    final now = _clockNow().millisecondsSinceEpoch;
    final current = settings.clock;
    // Commit a deadline that has already passed before accepting a restart/reset.
    if (!identical(current.expire(now), current)) {
      final expired = await _expireClock(current.anchorMs, depth);
      if (!_disposed &&
          expired != null &&
          identical(_lastSettings?.clock, expired) &&
          (op == 'start' || op == 'reset')) {
        await operateClock(op, seconds: seconds, depth: depth);
      }
      return;
    }
    final next = current.perform(op, now, seconds: seconds);
    if (identical(next, current)) return;
    // Taking the last seconds off a running or paused countdown ends it: that
    // end gets the same one-time sound and clock.ended rules as running out.
    final endsNow = next.phase == ClockPhase.ended &&
        current.mode == ClockMode.countdown &&
        (current.phase == ClockPhase.running ||
            current.phase == ClockPhase.paused);
    if (endsNow) _pendingClockEnd = (next, depth);
    try {
      await _writeRuleSettings(settings.copyWith(clock: next), depth);
    } finally {
      if (endsNow && identical(_pendingClockEnd?.$1, next)) {
        _pendingClockEnd = null;
      }
    }
  }

  void _trackClock(LiveClock? previous, LiveClock clock) {
    if (previous?.mode != clock.mode ||
        previous?.phase != clock.phase ||
        previous?.anchorMs != clock.anchorMs) {
      _clockEndTimer?.cancel();
      _clockEndTimer = null;
      if (clock.mode == ClockMode.countdown &&
          clock.phase == ClockPhase.running) {
        _clockEndSilently = previous == null &&
            clock.anchorMs <= _clockNow().millisecondsSinceEpoch;
        _scheduleClockEnd(clock, _settingsDepth);
      }
    }
  }

  Future<LiveClock?> _expireClock(int deadline, int depth) async {
    LiveClock? expired;
    SettingsModel change(SettingsModel settings) {
      final clock = settings.clock;
      if (_disposed || clock.anchorMs != deadline) return settings;
      final next = clock.expire(_clockNow().millisecondsSinceEpoch);
      if (identical(next, clock)) return settings;
      expired = next;
      _pendingClockEnd = (next, depth);
      return settings.copyWith(clock: next);
    }

    final writeLatest = clockExpiryWriter;
    try {
      if (writeLatest != null) {
        await writeLatest(change);
      } else if (_lastSettings case final settings?) {
        final next = change(settings);
        if (!identical(next, settings)) await _writeRuleSettings(next, depth);
      }
      return expired;
    } finally {
      if (identical(_pendingClockEnd?.$1, expired)) _pendingClockEnd = null;
    }
  }

  void _clockEnded(LiveClock clock, int depth) {
    if (rules.active) {
      rules.handle(RuleEvent(
        type: 'clock.ended',
        eventId: 'clock:${++_ruleEventSequence}',
        chainDepth: depth,
        origin: RuleEventOrigin.current,
      ));
    }
    if (clock.sound != HighlightSounds.none) {
      final sound = HighlightSounds.builtIn.contains(clock.sound)
          ? {'source': 'builtin', 'name': clock.sound}
          : {'source': 'library', 'mediaId': clock.sound};
      unawaited(_clockSounds.play(sound).then<void>((_) {}).catchError(
          (Object error, StackTrace stack) => AppLogger.warning(
              'Timer sound failed',
              error: error,
              stackTrace: stack)));
    }
  }

  void _scheduleClockEnd(LiveClock clock, int depth) {
    _clockEndTimer = Timer(
        Duration(
            milliseconds: clock.shownAt(_clockNow().millisecondsSinceEpoch)),
        () {
      final current = _lastSettings;
      if (_disposed || current == null) return;
      final latest = current.clock;
      if (latest.mode != ClockMode.countdown ||
          latest.phase != ClockPhase.running ||
          latest.anchorMs != clock.anchorMs) {
        return;
      }
      if (latest.anchorMs > _clockNow().millisecondsSinceEpoch) {
        _scheduleClockEnd(latest, depth);
      } else if (ruleSettingsWriter != null) {
        unawaited(_expireClock(clock.anchorMs, depth).then<void>((_) {},
            onError: (Object error, StackTrace stack) => AppLogger.warning(
                'Timer persistence failed',
                error: error,
                stackTrace: stack)));
      }
    });
  }

  late final ChatCoordinator _chat;
  late final AudioCoordinator _audio;
  late final OverlayCoordinator _overlay;
  late final ObsCoordinator _obs;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _goalTracker = GoalTracker();
  final _goalIncrements =
      StreamController<(Map<String, int>, RuleEventOrigin)>.broadcast();
  Stream<(Map<String, int>, RuleEventOrigin)> get goalIncrements =>
      _goalIncrements.stream;
  void _emitGoalIncrements(Map<String, int> increments,
      {ChatMessage? message}) {
    if (!increments.values.any((n) => n > 0)) return;
    _goalIncrements.add((
      increments,
      RuleEventOrigin(viewer: true, roles: [
        if (message?.isOwner == true) 'owner',
        if (message?.isModerator == true) 'moderator',
      ]),
    ));
  }

  final _poll = ChatPollController();
  final _withheldVoteIds = <(Platform, String)>{};

  ChatMessage _withoutPrivateReplyText(ChatMessage message) {
    final reply = message.reply;
    if (reply == null ||
        !_withheldVoteIds.contains((message.platform, reply.messageId))) {
      return message;
    }
    return message.copyWith(
        reply: ChatReplyContext(
      messageId: reply.messageId,
      authorId: reply.authorId,
      authorName: reply.authorName,
    ));
  }

  late final _giveaway = ChatGiveawayController(onHistoryChanged: (history) {
    final settings = _lastSettings;
    if (settings == null || ruleSettingsWriter == null) return;
    unawaited(_writeRuleSettings(settings.copyWith(giveawayHistory: history), 0)
        .catchError((Object error, StackTrace stack) => AppLogger.warning(
            'Giveaway history persistence failed',
            error: error,
            stackTrace: stack)));
  });
  late final _sessionSummary = SessionSummaryCollector(clock: _clockNow);
  final ChatLogWriter _chatLog;
  bool _chatRunning = false;
  bool _chatEnded = false;
  bool _chatConnected = false;

  /// Chat for the overlay: live messages plus any preview samples.
  final _overlayFeed = StreamController<ChatMessage>.broadcast();
  List<ChatMessage> _overlayPreview = const [];
  final _noticeController = StreamController<AppNotice>.broadcast();
  SettingsModel? _lastSettings;
  int _noticeId = 0;
  bool _disposed = false;

  Stream<List<ChatMessage>> get messageListStream =>
      _chat.messageListStream.map((messages) => _withheldVoteIds.isEmpty
          ? messages
          : messages.map(_withoutPrivateReplyText).toList());
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
      _poll.isPrivateVote(message)
          ? FeaturedMessageDelivery.noReceiver()
          : _overlay.featureMessage(_withoutPrivateReplyText(message));

  /// Where session chat logs are saved.
  Future<Directory> chatLogDirectory() => ChatLogWriter.defaultDirectory();

  /// What happened since the chat was last started.
  SessionSummary get sessionSummary => _sessionSummary.summary;
  List<ChatMessage> get sessionChat => _chat.sessionMessages;
  bool get sessionChatTruncated => _chat.sessionMessagesTruncated;

  Stream<AlertQueueStatus> get alertQueueStatusStream =>
      _overlay.alertQueueStatusStream;
  void controlAlertQueue(AlertQueueOperation op) =>
      _overlay.controlAlertQueue(op);
  void removeFeaturedMessage() => _overlay.removeFeaturedMessage();

  Stream<List<Map<String, Object?>>> get recentAlerts => _overlay.recentAlerts;
  bool replayRecentAlert(String id) => _overlay.replayRecentAlert(id);

  Stream<ChatGiveaway?> get giveawayStream => _giveaway.states;
  void startGiveaway({required String keyword, required bool membersOnly}) =>
      _giveaway.start(keyword: keyword, membersOnly: membersOnly);
  void closeGiveaway() => _giveaway.close();
  GiveawayEntrant? drawGiveaway() => drawGiveaways(1).firstOrNull;

  List<GiveawayEntrant> drawGiveaways(int count, {int depth = 0}) {
    final events = <RuleEvent>[];
    final winners = _giveaway.drawMany(count, onDraw: (winner, drawId) {
      if (!rules.active) return;
      events.add(RuleEvent(
        type: 'giveaway.winner',
        eventId: 'draw:$drawId',
        chainDepth: depth,
        origin: depth == 0 ? null : RuleEventOrigin.current,
        platform: winner.platform.name,
        author: RuleAuthor(name: winner.name, id: winner.authorId),
      ));
    });
    if (events.isNotEmpty) {
      // Let the rule engine begin each run before offering the next winner.
      // Cooldowns and overlap still apply to each announcement.
      _winnerNotifications = _winnerNotifications.then((_) async {
        for (final event in events) {
          if (_disposed) return;
          rules.handle(event);
          await Future<void>(() {});
        }
      });
    }
    return winners;
  }

  void clearGiveawayHistory() => _giveaway.clearHistory();
  void clearGiveaway() => _giveaway.clear();

  Stream<ChatPoll?> get pollStream => _poll.states;
  void startPoll({
    required String question,
    List<String> options = const [],
    Duration? duration,
    PollMode mode = PollMode.numbered,
    bool hideResults = false,
    QueueRole allowed = QueueRole.everyone,
    bool allowChange = true,
    String command = ChatPoll.defaultCommand,
    String? language,
  }) =>
      _poll.start(
        question: question,
        options: options,
        duration: duration,
        mode: mode,
        hideResults: hideResults,
        allowed: allowed,
        allowChange: allowChange,
        command: command,
        language: language ?? _lastSettings?.appLanguageCode ?? 'en',
      );
  void launchSavedPoll(SavedPoll setup, {required String language}) =>
      startPoll(
        question: setup.question,
        options: setup.options,
        duration:
            setup.minutes == null ? null : Duration(minutes: setup.minutes!),
        mode: setup.mode,
        allowed: setup.allowed,
        hideResults: setup.hideResults,
        allowChange: setup.allowChange,
        command: setup.command,
        language: language,
      );

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

  void retryChatConnections() {
    if (!_restartEndedChat()) _chat.retryConnections();
  }

  void retryChatPlatform(String platform) => _chat.retryPlatform(platform);

  bool _restartEndedChat() {
    final settings = _lastSettings;
    if (settings == null || !_chatRunning) return false;
    _syncChatSession();
    if (!_chatEnded) return false;
    _chat.applySettings(settings, connectChats: false);
    _startChatSession(settings);
    _chat.applySettings(settings, connectChats: true);
    return true;
  }

  void _syncChatSession() {
    final settings = _lastSettings;
    if (settings == null || !_chatRunning) return;
    final phase = _chat.sessionPhase;
    if (_chat.sessionHasEnded && !_chatEnded) {
      _chatEnded = true;
      _chat.endSession();
      _audio.cancelChatSpeech();
      _finishChatSession();
    } else if (_chatEnded &&
        (phase == ChatSessionPhase.connecting ||
            phase == ChatSessionPhase.connected ||
            phase == ChatSessionPhase.partiallyConnected)) {
      _chat.startSession();
      _startChatSession(settings);
    }
  }

  void _startChatSession(SettingsModel settings) {
    _chatEnded = false;
    if (!_poll.hasOpenPoll) _withheldVoteIds.clear();
    _audio.startSession();
    _sessionSummary.start();
    _overlay.resetAlertDeliveries();
    _overlay.clearRecentAlerts();
    templateServer?.sessionChanged();
    unawaited(_chatLog.startSession(enabled: settings.saveChatLog));
  }

  void _finishChatSession() {
    _sessionGiftGroups.flush(_recordSessionGift);
    _sessionSummary.stop();
    _ruleGiftGroups.clear();
    _chatConnected = false;
    _overlay.resetAlertDeliveries();
    templateServer?.sessionChanged();
    unawaited(_chatLog.endSession());
  }

  void applySettings(SettingsModel settings,
      {required bool connectChats, bool restoringBackup = false}) {
    if (_disposed) return;
    final previous = _lastSettings;
    _lastSettings = settings;
    // Queue writes synchronously notify Riverpod. Keep the new snapshot for
    // subsequent rule writes without reapplying chat, OBS or browser settings.
    if (_publishingQueueSettings && previous != null) return;
    queue.configure(settings.queueOptions, settings.appLanguageCode);
    final restoreQueue = previous == null ||
        (restoringBackup &&
            !identical(previous.queueState, settings.queueState));
    if (restoreQueue) {
      queue.restore(settings.queueState);
    }
    final blocksChanged =
        previous == null || !ChatFilter.sameBlockLists(previous, settings);
    if (restoreQueue || blocksChanged) {
      final filter = ChatFilter(settings);
      queue.applyFilter(filter);
      if (blocksChanged) {
        _giveaway.applyFilter(filter);
        _poll.applyFilter(filter);
        _sessionSummary.applyBlockFilter(filter);
        templateServer?.sessionChanged();
      }
    }
    _giveaway.restoreHistory(settings.giveawayHistory);
    rules.updateSettings(enabled: settings.rulesEnabled, rules: settings.rules);
    if (!rules.active || restoringBackup) _ruleGiftGroups.clear();
    templateServer?.rulesEngine = rules;
    _trackClock(restoringBackup ? null : previous?.clock, settings.clock);
    if (rules.active && previous != null && !restoringBackup) {
      for (final e in settings.goals.entries) {
        final old = previous.goals[e.key];
        if (old != null &&
            (old['current'] as int) < (old['target'] as int) &&
            (e.value['current'] as int) >= (e.value['target'] as int)) {
          rules.handle(RuleEvent(
              type: 'goal.reached',
              goalId: e.key,
              eventId: 'goal:${++_ruleEventSequence}',
              chainDepth: _settingsDepth,
              origin: RuleEventOrigin.current));
        }
      }
    }
    _trackSubathon(restoringBackup ? null : previous, settings);
    if (connectChats != _chatRunning) {
      _chatRunning = connectChats;
      if (connectChats) {
        _startChatSession(settings);
      } else {
        _chatEnded = false;
        _finishChatSession();
      }
    } else if (connectChats &&
        !_chatEnded &&
        previous?.saveChatLog != settings.saveChatLog) {
      unawaited(_chatLog.setEnabled(settings.saveChatLog));
    }
    _chat.applySettings(settings, connectChats: connectChats);
    _syncChatSession();
    _audio.applySettings(settings, connectChats: connectChats);
    _overlay.broadcastGoals(Goals.payload(settings.goals),
        replay: restoringBackup);
    _overlay.applySettings(
      settings,
      previous: previous,
      messages: _overlayFeed.stream,
    );
    _obs.applySettings(settings, previous: previous);
    if (_pendingClockEnd case (final clock, final depth)
        when identical(settings.clock, clock)) {
      _pendingClockEnd = null;
      final silent = _clockEndSilently;
      _clockEndSilently = false;
      if (!silent) {
        scheduleMicrotask(() {
          if (!_disposed) _clockEnded(clock, depth);
        });
      }
    }
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
    _ruleGiftGroups.clear();
    _sessionGiftGroups.clear();
    _subathonEndTimer?.cancel();
    _clockEndTimer?.cancel();
    final queueDisposed = queue.dispose();
    await _winnerNotifications;
    await rules.dispose();
    await queueDisposed;
    await (rules.target as RuleActions).sounds.dispose();
    await _clockSounds.dispose();
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
    await _queueWrite;
    await _goalIncrements.close();
    await _chatLog.endSession();
  }
}

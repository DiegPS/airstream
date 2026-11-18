import 'dart:async';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_sound_player.dart';
import 'package:airstream/services/overlay_server.dart';
// Flutter's existing test dependency supplies deterministic timers.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/live_clock.dart';
import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/application/chat_queue.dart';
import '../chat_queue_test.dart' show queueMessage;
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';
import 'package:airstream/settings/settings_model.dart';

class RuleOverlay extends OverlayServer {
  final triggers = <Map<String, String>>[];
  bool feedSeen = false;
  @override
  bool broadcastRuleTrigger(
      {required String name, required String data, required String rule}) {
    expect(feedSeen, true,
        reason: 'feed receives chat before the first rule action');
    triggers.add({'name': name, 'data': data, 'rule': rule});
    return true;
  }
}

class _PollOverlay extends RuleOverlay {
  final chat = <String>[];
  final polls = <Map<String, Object?>?>[];
  StreamSubscription<ChatMessage>? _messages;

  @override
  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) async {
    _messages = messages.listen((message) {
      feedSeen = true;
      chat.add(message.plainText);
    });
  }

  @override
  void broadcastPoll(Map<String, Object?>? poll) => polls.add(poll);

  @override
  Future<void> dispose() async {
    await _messages?.cancel();
    await super.dispose();
  }
}

class _ClockSounds implements RuleSoundPlayer {
  final played = <Map<String, dynamic>>[];

  @override
  Future<bool> play(Map<String, dynamic> action) async {
    played.add(action);
    return true;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  AppController makeController(
          FakeChannelChatClient twitch, OverlayServer server,
          {ChatCoordinator? chat,
          DateTime Function()? clock,
          RuleSoundPlayer? clockSounds}) =>
      AppController(
          clock: clock,
          clockSounds: clockSounds,
          chatCoordinator: chat ??
              ChatCoordinator(
                  youtube: FakeYouTubeChatClient(),
                  youtubeHorizontal: FakeYouTubeChatClient(),
                  youtubeVertical: FakeYouTubeChatClient(),
                  kick: FakeChannelChatClient(),
                  twitch: twitch),
          audioCoordinator: AudioCoordinator(
              tts: FakeTtsClient(), captions: FakeCaptionsClient()),
          obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
          overlayCoordinator:
              OverlayCoordinator(overlay: OverlayServerAdapter(server)));

  test('a reloaded countdown fires clock.ended once then persists the result',
      () {
    fakeAsync((fake) {
      final server = RuleOverlay()..feedSeen = true;
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final sounds = _ClockSounds();
      final app = makeController(FakeChannelChatClient(), server,
          clock: now, clockSounds: sounds);
      final rule = {
        ...RuleSchema.newRule('clock.ended', id: 'finish'),
        'enabled': true,
        'actions': [
          {
            'id': 'send',
            'type': 'template.trigger',
            'name': 'finish',
            'data': 'done'
          }
        ],
      };
      final running = (const LiveClock(durationSeconds: 2, sound: 'chime'))
          .start(now().millisecondsSinceEpoch);
      final disk = SettingsDocumentCodec.encode(SettingsModel(
        clock: running,
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [rule],
      ));
      fake.elapse(const Duration(milliseconds: 750));
      var restored = SettingsDocumentCodec.decode(disk).settings;
      app.ruleSettingsWriter = (settings) async {
        restored = settings;
        app.applySettings(settings, connectChats: false);
      };
      app.applySettings(restored, connectChats: false);
      fake.elapse(const Duration(milliseconds: 1249));
      expect(server.triggers, isEmpty);
      fake.elapse(const Duration(milliseconds: 1));
      fake.flushMicrotasks();
      expect(restored.clock.phase, ClockPhase.ended);
      expect(server.triggers.single['name'], 'finish');
      app.applySettings(restored, connectChats: false);
      fake.elapse(const Duration(seconds: 5));
      expect(server.triggers, hasLength(1));
      expect(sounds.played, [
        {'source': 'builtin', 'name': 'chime'}
      ]);
      expect(
        SettingsDocumentCodec.decode(SettingsDocumentCodec.encode(restored))
            .settings
            .clock
            .phase,
        ClockPhase.ended,
      );
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('a countdown that ended while the app was closed ends silently', () {
    fakeAsync((fake) {
      final server = RuleOverlay()..feedSeen = true;
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final sounds = _ClockSounds();
      final app = makeController(FakeChannelChatClient(), server,
          clock: now, clockSounds: sounds);
      final rule = {
        ...RuleSchema.newRule('clock.ended', id: 'finish'),
        'enabled': true,
        'actions': [
          {
            'id': 'send',
            'type': 'template.trigger',
            'name': 'finish',
            'data': 'done'
          }
        ],
      };
      final running = (const LiveClock(durationSeconds: 2, sound: 'chime'))
          .start(now().millisecondsSinceEpoch);
      final disk = SettingsDocumentCodec.encode(SettingsModel(
        clock: running,
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [rule],
      ));
      // The app was closed for an hour; the countdown ended meanwhile.
      fake.elapse(const Duration(hours: 1));
      var restored = SettingsDocumentCodec.decode(disk).settings;
      app.ruleSettingsWriter = (settings) async {
        restored = settings;
        app.applySettings(settings, connectChats: false);
      };
      app.applySettings(restored, connectChats: false);
      fake.elapse(const Duration(seconds: 1));
      fake.flushMicrotasks();
      expect(restored.clock.phase, ClockPhase.ended);
      expect(server.triggers, isEmpty);
      expect(sounds.played, isEmpty);

      // A new countdown in the same session still announces its end.
      unawaited(app.operateClock('start'));
      fake.flushMicrotasks();
      fake.elapse(const Duration(seconds: 3));
      fake.flushMicrotasks();
      expect(server.triggers.single['name'], 'finish');
      expect(sounds.played, hasLength(1));
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('rules can operate the clock and draw winners with optional count', () {
    fakeAsync((fake) {
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final twitch = FakeChannelChatClient();
      final server = RuleOverlay()..feedSeen = true;
      final app = makeController(twitch, server, clock: now);
      Map<String, dynamic> actionRule(
              String id, String type, Map<String, Object> params) =>
          {
            ...RuleSchema.newRule('manual', id: id),
            'enabled': true,
            'actions': [
              {'id': 'op', 'type': type, ...params}
            ],
          };
      var settings = SettingsModel(
        overlayEnabled: false,
        rules: [
          actionRule('start', 'clock', {'op': 'start'}),
          actionRule('add', 'clock', {'op': 'add', 'seconds': 10}),
          actionRule('pause', 'clock', {'op': 'pause'}),
          actionRule('reset', 'clock', {'op': 'reset'}),
          actionRule('draw', 'giveaway', {'op': 'draw', 'count': 10}),
          actionRule('old', 'giveaway', {'op': 'draw'}),
          {
            ...RuleSchema.newRule('giveaway.winner', id: 'winner'),
            'enabled': true,
            'actions': [
              {
                'id': 'op',
                'type': 'template.trigger',
                'name': 'winner',
                'data': '{user}'
              }
            ],
          },
        ],
      );
      app.ruleSettingsWriter = (next) async {
        settings = next;
        app.applySettings(settings, connectChats: false);
      };
      app.applySettings(settings, connectChats: false);
      void run(String id) {
        expect(app.rules.runNow(id, const RuleEvent(type: 'manual')), isNull);
        fake.elapse(Duration.zero);
      }

      run('start');
      expect(settings.clock.phase, ClockPhase.running);
      final deadline = settings.clock.anchorMs;
      run('add');
      expect(settings.clock.anchorMs, deadline + 10000);
      run('pause');
      expect(settings.clock.phase, ClockPhase.paused);
      run('reset');
      expect(settings.clock.phase, ClockPhase.idle);

      app.startGiveaway(keyword: 'go', membersOnly: false);
      final names = {for (var i = 0; i < 11; i++) 'Viewer $i'};
      for (final name in names) {
        twitch.messageController.add(queueMessage(name, 'go'));
      }
      fake.flushMicrotasks();
      run('draw');
      expect(settings.giveawayHistory.single.winners, hasLength(10));
      run('old');
      expect(settings.giveawayHistory.single.winners, hasLength(11));
      expect(server.triggers.map((entry) => entry['data']).toSet(), names);
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test(
      'launching a saved poll starts a fresh timer with its saved voting setup',
      () async {
    final app = makeController(FakeChannelChatClient(), RuleOverlay());
    addTearDown(app.dispose);
    final setup = SavedPoll.fromJson({
      'name': 'Feedback',
      'question': 'How was it?',
      'mode': 'freeAnswer',
      'minutes': 5,
      'allowed': 'member',
      'hideResults': true,
      'allowChange': false,
      'command': '!opina',
    })!;
    app.launchSavedPoll(setup, language: 'es');
    final poll = (await app.pollStream.first)!;
    expect(poll.question, setup.question);
    expect(poll.mode, setup.mode);
    expect(poll.allowed, setup.allowed);
    expect(poll.hideResults, true);
    expect(poll.allowChange, false);
    expect(poll.command, '!opina');
    expect(poll.endsAt!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(298, 300));
  });

  test('session chat export keeps the moderated buffer after disconnect',
      () async {
    final twitch = FakeChannelChatClient();
    final app = makeController(twitch, RuleOverlay());
    addTearDown(app.dispose);
    const settings = SettingsModel(
      overlayEnabled: false,
      twitchChannel: 'channel',
      maxMessages: 2,
    );
    app.applySettings(settings, connectChats: true);
    final old = queueMessage('Ana', 'old');
    final removed = queueMessage('Beto', 'removed');
    final retained = queueMessage('Carla', 'retained');
    twitch.messageController
      ..add(old)
      ..add(removed)
      ..add(retained);
    await settleCoordinatorTasks();
    expect(app.sessionSummary.messages, 3);
    expect(app.sessionChat.map((message) => message.plainText),
        ['removed', 'retained']);
    twitch.moderationController.add(ChatModerationEvent.author(
      platform: removed.platform,
      authorChannelId: removed.author.channelId,
      authorName: removed.author.name,
    ));
    await settleCoordinatorTasks();
    app.applySettings(settings, connectChats: false);
    expect(await app.messageListStream.first, isEmpty);
    expect(app.sessionChat.map((message) => message.plainText), ['retained']);
    expect(app.sessionSummary.participants.length, 3);
    app.applySettings(settings, connectChats: true);
    expect(app.sessionChat, isEmpty);
    expect(app.sessionSummary.participants, isEmpty);
  });

  test('hidden submissions stay local until poll.ended publishes the winner',
      () async {
    final twitch = FakeChannelChatClient();
    final server = _PollOverlay();
    final app = makeController(twitch, server);
    addTearDown(app.dispose);
    app.applySettings(
        SettingsModel(
          overlayEnabled: true,
          queueState: const QueueState(status: QueueStatus.open),
          queueOptions: const QueueOptions(command: '!reply'),
          rules: [
            {
              ...RuleSchema.newRule('chat.command', id: 'echo'),
              'enabled': true,
              'trigger': {'type': 'chat.command', 'command': '!reply'},
              'actions': [
                {
                  'id': 'echo',
                  'type': 'template.trigger',
                  'name': 'echo',
                  'data': '{message}'
                },
              ],
            },
            {
              ...RuleSchema.newRule('poll.ended', id: 'result'),
              'enabled': true,
              'actions': [
                {
                  'id': 'out',
                  'type': 'template.trigger',
                  'name': 'result',
                  'data': '{winner}/{total}'
                },
              ],
            },
          ],
        ),
        connectChats: false);
    app.startPoll(
        question: 'Q',
        mode: PollMode.freeAnswer,
        command: '!reply',
        hideResults: true);
    const answer = '<b>Private answer</b>';
    twitch.messageController.add(queueMessage('Viewer', '!reply $answer'));
    twitch.messageController.add(queueMessage('Viewer', 'Ordinary chat'));
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(server.chat, ['Ordinary chat']);
    expect(app.queue.current.entries, isEmpty);
    expect(server.triggers, isEmpty);
    expect(server.polls.last?['total'], 1);
    expect(server.polls.last?.containsKey('answers'), false);
    final messages = await app.messageListStream.first;
    final submission = messages
        .singleWhere((message) => message.plainText == '!reply $answer');
    expect(app.featureMessageOnStream(submission).status,
        FeaturedMessageStatus.noReceiver);
    final completed = app.rules.historyStream.firstWhere((runs) =>
        runs.any((run) => run.event.type == 'poll.ended' && run.completed));
    app.endPoll();
    app.endPoll();
    await completed.timeout(const Duration(seconds: 2));
    expect(server.polls.last?['answers'], [
      {'text': answer, 'votes': 1}
    ]);
    expect(server.triggers.single['data'], '$answer/1');
  });

  test(
      'queue joins from chat trigger rules, move players and save coalesced state',
      () {
    fakeAsync((async) {
      final twitch = FakeChannelChatClient();
      final server = RuleOverlay()..feedSeen = true;
      final app = makeController(twitch, server);
      final saved = <QueueState>[];
      final settings = SettingsModel(
        overlayEnabled: false,
        queueState: const QueueState(status: QueueStatus.open),
        rules: [
          {
            ...RuleSchema.newRule('queue.joined', id: 'join'),
            'enabled': true,
            'actions': [
              {
                'id': 'first',
                'type': 'template.trigger',
                'name': 'joined',
                'data': '{user}/{note}/{position}'
              },
              {'id': 'pick', 'type': 'queue.next', 'count': 1, 'random': false},
            ],
          },
          {
            ...RuleSchema.newRule('queue.next', id: 'next'),
            'enabled': true,
            'actions': [
              {
                'id': 'show',
                'type': 'template.trigger',
                'name': 'next',
                'data': '{user}/{count}'
              },
            ],
          }
        ],
      );
      app.queueSettingsWriter = (state) async {
        saved.add(state);
        app.applySettings(settings.copyWith(queueState: state),
            connectChats: false);
      };
      app.applySettings(settings, connectChats: false);
      async.flushMicrotasks();
      expect(server.triggers, isEmpty);
      twitch.messageController.add(queueMessage('Alex', '!join Ready 🎮'));
      async.elapse(Duration.zero);
      expect(server.triggers.map((entry) => entry['data']),
          ['Alex/Ready 🎮/1', 'Alex/1']);
      expect(app.queue.current.playing.single.name, 'Alex');
      expect(app.rules.history.map((run) => run.event.chainDepth), [1, 0]);
      expect(saved, isEmpty);
      async.elapse(const Duration(milliseconds: 250));
      expect(saved.single.playing.single.name, 'Alex');
      List<ChatMessage>? buffered;
      unawaited(app.messageListStream.first.then<void>((messages) {
        buffered = messages;
      }));
      async.flushMicrotasks();
      expect(buffered?.single.author.name, 'Alex');
      unawaited(app.dispose());
      async.flushMicrotasks();
    });
  });

  test('real wiring delivers Bits feed before rule actions and adjusts goal',
      () async {
    final twitch = FakeChannelChatClient(), server = RuleOverlay();
    final chat = ChatCoordinator(
        youtube: FakeYouTubeChatClient(),
        youtubeHorizontal: FakeYouTubeChatClient(),
        youtubeVertical: FakeYouTubeChatClient(),
        kick: FakeChannelChatClient(),
        twitch: twitch);
    final feed = chat.messages.listen((m) {
      if (m.id == 'bits500') server.feedSeen = true;
    });
    addTearDown(feed.cancel);
    final c = makeController(twitch, server, chat: chat);
    addTearDown(c.dispose);
    var settings = SettingsModel(overlayEnabled: false, rules: [
      {
        ...RuleSchema.newRule('support.bits', id: 'bits'),
        'name': 'Bits celebration',
        'enabled': true,
        'trigger': {'type': 'support.bits', 'min': 100},
        'actions': [
          {
            'id': 'template',
            'type': 'template.trigger',
            'name': 'bits',
            'data': '{count}'
          },
          {'id': 'goal', 'type': 'goal.adjust', 'goalId': 'goal', 'delta': 5},
        ]
      }
    ], goals: {
      'goal': {'title': 'Goal', 'type': 'manual', 'current': 0, 'target': 10}
    });
    c.ruleSettingsWriter = (s) async {
      settings = s;
      c.applySettings(s, connectChats: false);
    };
    c.applySettings(settings, connectChats: false);
    final sub = c.messageListStream.listen((messages) {
      if (messages.any((m) => m.id == 'bits500')) server.feedSeen = true;
    });
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);
    twitch.messageController.add(ChatMessage(
        platform: Platform.twitch,
        id: 'bits500',
        author: const ChatAuthor(name: 'Alex', channelId: 'alex'),
        items: const [MessageItem.text('Cheer!')],
        timestamp: DateTime.now(),
        superChat: const SuperChat(amount: '500 Bits', color: '#ffffff')));
    for (var i = 0; i < 20 && settings.goals['goal']!['current'] == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(server.feedSeen, true);
    expect(server.triggers.single['data'], '500');
    expect(settings.goals['goal']!['current'], 5);
  });
  test(
      'goal crossings baseline on startup and action chains stop at depth three',
      () async {
    final c = makeController(FakeChannelChatClient(), OverlayServer());
    addTearDown(c.dispose);
    var s = SettingsModel(overlayEnabled: false, goals: {
      'goal': {'title': 'Goal', 'type': 'manual', 'target': 1, 'current': 1}
    }, rules: [
      {
        ...RuleSchema.newRule('goal.reached', id: 'loop'),
        'enabled': true,
        'actions': [
          {'id': 'down', 'type': 'goal.adjust', 'goalId': 'goal', 'delta': -1},
          {'id': 'up', 'type': 'goal.adjust', 'goalId': 'goal', 'delta': 1},
        ]
      }
    ]);
    c.ruleSettingsWriter = (next) async {
      s = next;
      c.applySettings(s, connectChats: false);
    };
    c.applySettings(s, connectChats: false);
    expect(c.rules.history, isEmpty);
    s = s.copyWith(goals: {
      'goal': {...s.goals['goal']!, 'current': 0}
    });
    c.applySettings(s, connectChats: false);
    s = s.copyWith(goals: {
      'goal': {...s.goals['goal']!, 'current': 1}
    });
    c.applySettings(s, connectChats: false);
    for (var i = 0;
        i < 20 &&
            (c.rules.history.length < 3 || !c.rules.history.first.completed);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.rules.history.map((r) => r.event.chainDepth), [2, 1, 0]);
    expect(c.rules.history.every((r) => r.completed), true);
  });
  test('subathon ended owns exactly one timer only with an enabled rule', () {
    fakeAsync((a) {
      final c = makeController(FakeChannelChatClient(), OverlayServer());
      final base = SettingsModel(
          overlayEnabled: false,
          subathonPhase: 'running',
          subathonEndsAtMs: DateTime.now().millisecondsSinceEpoch + 60000);
      c.applySettings(base, connectChats: false);
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 0);
      final rule = {
        ...RuleSchema.newRule('subathon.ended', id: 'timer'),
        'enabled': true
      };
      c.applySettings(base.copyWith(rules: [rule]), connectChats: false);
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 1);
      c.applySettings(base.copyWith(rules: [rule]), connectChats: false);
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 1);
      c.applySettings(
          base.copyWith(rules: [
            {...rule, 'enabled': false}
          ]),
          connectChats: false);
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 0);
      unawaited(c.dispose());
      a.flushMicrotasks();
    });
  });
  test('starting each chat session clears recent alerts, settings edits do not',
      () async {
    final youtube = FakeYouTubeChatClient();
    final horizontal = FakeYouTubeChatClient();
    final vertical = FakeYouTubeChatClient();
    final kick = FakeChannelChatClient();
    final twitch = FakeChannelChatClient();
    final overlay = FakeOverlayClient();
    final controller = AppController(
      chatCoordinator: ChatCoordinator(
        youtube: youtube,
        youtubeHorizontal: horizontal,
        youtubeVertical: vertical,
        kick: kick,
        twitch: twitch,
      ),
      audioCoordinator: AudioCoordinator(
        tts: FakeTtsClient(),
        captions: FakeCaptionsClient(),
      ),
      overlayCoordinator: OverlayCoordinator(overlay: overlay),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
    );
    addTearDown(controller.dispose);

    const settings = SettingsModel(overlayEnabled: false);
    controller.applySettings(settings, connectChats: false);
    overlay.recent.add({'id': 'old'});
    controller.applySettings(settings, connectChats: true);
    expect(overlay.recent, isEmpty);
    expect(overlay.clearRecentCount, 1);
    overlay.recent.add({'id': 'current'});
    controller.applySettings(settings.copyWith(alertDisabledTypes: ['bits']),
        connectChats: true);
    expect(overlay.recent.single['id'], 'current');
    controller.applySettings(settings, connectChats: false);
    controller.applySettings(settings, connectChats: true);
    expect(overlay.recent, isEmpty);
    expect(overlay.clearRecentCount, 2);
  });

  test('forwards moderation and provider events to the overlay facade',
      () async {
    final youtube = FakeYouTubeChatClient();
    final horizontal = FakeYouTubeChatClient();
    final vertical = FakeYouTubeChatClient();
    final kick = FakeChannelChatClient();
    final twitch = FakeChannelChatClient();
    final overlay = FakeOverlayClient();
    final controller = AppController(
      chatCoordinator: ChatCoordinator(
        youtube: youtube,
        youtubeHorizontal: horizontal,
        youtubeVertical: vertical,
        kick: kick,
        twitch: twitch,
      ),
      audioCoordinator: AudioCoordinator(
        tts: FakeTtsClient(),
        captions: FakeCaptionsClient(),
      ),
      overlayCoordinator: OverlayCoordinator(overlay: overlay),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
    );
    addTearDown(controller.dispose);

    twitch.moderationController.add(const ChatModerationEvent.message(
      platform: Platform.twitch,
      messageId: 'deleted',
    ));
    kick.eventController.add(ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.poll,
      id: 'poll',
      timestamp: DateTime.utc(2026, 9, 7),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(overlay.moderationCount, 1);
    expect(overlay.providerEventCount, 1);
  });
}

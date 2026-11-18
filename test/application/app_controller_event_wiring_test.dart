import 'dart:async';
import 'package:airstream/application/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_sound_player.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/obs_service.dart';
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
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'coordinator_fakes.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_repository.dart';
import 'package:airstream/settings/chat_reading_options.dart';

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
  final feed = <ChatMessage>[];
  final support = <ChatMessage>[];
  FeaturedMessageDelivery? featuredDelivery;

  @override
  void broadcastChatSupport(ChatMessage message) => support.add(message);

  @override
  FeaturedMessageDelivery broadcastFeaturedMessage(ChatMessage message) =>
      featuredDelivery ?? super.broadcastFeaturedMessage(message);

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
      feed.add(message);
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
          RuleSoundPlayer? clockSounds,
          FakeTtsClient? tts,
          FakeObsClient? obs,
          FakeAlertSound? alertSound}) =>
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
              tts: tts ?? FakeTtsClient(),
              captions: FakeCaptionsClient(),
              alertSound: alertSound),
          obsCoordinator: ObsCoordinator(obs: obs ?? FakeObsClient()),
          overlayCoordinator:
              OverlayCoordinator(overlay: OverlayServerAdapter(server)));

  test('queue.next skips stream control for every initiating role', () {
    for (final moderator in [false, true]) {
      fakeAsync((fake) {
        final twitch = FakeChannelChatClient();
        final obs = FakeObsClient()..state = const ObsState(connected: true);
        final app = makeController(twitch, RuleOverlay(), obs: obs);
        app.applySettings(
          SettingsModel(
            overlayEnabled: false,
            obsEnabled: true,
            queueState: const QueueState(status: QueueStatus.open),
            rules: [
              {
                ...RuleSchema.newRule('chat.command', id: 'advance'),
                'enabled': true,
                'trigger': {'type': 'chat.command', 'command': '!advance'},
                'actions': [
                  {'id': 'pick', 'type': 'queue.next', 'count': 1},
                ],
              },
              {
                ...RuleSchema.newRule('queue.next', id: 'stream'),
                'enabled': true,
                'actions': [
                  {'id': 'start', 'type': 'obs.stream', 'state': 'start'},
                ],
              },
            ],
          ),
          connectChats: false,
        );
        twitch.messageController.add(queueMessage('Entrant', '!join',
            id: 'entrant', moderator: !moderator));
        twitch.messageController.add(queueMessage('Initiator', '!advance',
            id: 'initiator', moderator: moderator));
        fake.elapse(Duration.zero);
        final run = app.rules.history.first;
        expect(run.event.type, 'queue.next');
        expect(run.event.author.name, 'Entrant');
        expect(run.results.single.reason, 'publicStreamControl');
        expect(obs.ruleControls, isEmpty);
        unawaited(app.dispose());
        fake.flushMicrotasks();
      });
    }
  });

  for (final platform in [Platform.twitch, Platform.kick]) {
    test(
        '${platform.name} replies keep the author but omit a withheld poll answer',
        () async {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      addTearDown(app.dispose);
      app.applySettings(const SettingsModel(overlayEnabled: true),
          connectChats: false);
      app.startPoll(
          question: 'Q',
          mode: PollMode.freeAnswer,
          command: '!vote',
          hideResults: true);

      void send(String id, String text,
          {ChatReplyContext? reply, Platform? from}) {
        twitch.messageController.add(ChatMessage(
          platform: from ?? platform,
          id: id,
          author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
          items: [MessageItem.text(text)],
          timestamp: DateTime.utc(2026),
          reply: reply,
        ));
      }

      final lists = <List<ChatMessage>>[];
      final subscription = app.messageListStream.listen(lists.add);
      addTearDown(subscription.cancel);
      await settleCoordinatorTasks();
      send('vote', '!vote secret');
      send('immediate-reply', 'Reply during the poll',
          reply:
              const ChatReplyContext(messageId: 'vote', text: '!vote secret'));
      await settleCoordinatorTasks();
      app.endPoll();
      send('reply', 'Ordinary chat',
          reply: const ChatReplyContext(
            messageId: 'vote',
            authorId: 'viewer',
            authorName: 'Viewer',
            text: '!vote secret',
          ));
      send('public-reply', 'Another message',
          reply: const ChatReplyContext(
            messageId: 'reply',
            authorName: 'Viewer',
            text: 'Ordinary chat',
          ));
      send('other-platform-reply', 'Cross-platform ID collision',
          from: platform == Platform.twitch ? Platform.kick : Platform.twitch,
          reply:
              const ChatReplyContext(messageId: 'vote', text: 'Public text'));
      await settleCoordinatorTasks();

      expect(server.chat, [
        'Reply during the poll',
        'Ordinary chat',
        'Another message',
        'Cross-platform ID collision',
      ]);
      expect(server.feed.first.reply?.text, isEmpty);
      final preview = server.feed[1].reply!;
      expect((
        preview.messageId,
        preview.authorId,
        preview.authorName,
        preview.text
      ), (
        'vote',
        'viewer',
        'Viewer',
        ''
      ));
      expect(server.feed[2].reply?.text, 'Ordinary chat');
      expect(server.feed.last.reply?.text, 'Public text');
      final previews = lists.expand((messages) => messages).where((message) =>
          message.platform == platform && message.reply?.messageId == 'vote');
      expect(previews, isNotEmpty);
      expect(previews.map((message) => message.reply!.text),
          everyElement(isEmpty));
    });
  }

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

  test(
      'session chat export outlives display trimming and applies moderation after disconnect',
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
        ['old', 'removed', 'retained']);
    app.applySettings(settings, connectChats: false);
    expect(await app.messageListStream.first, isEmpty);
    twitch.messageController.add(queueMessage('Late', 'after disconnect'));
    twitch.moderationController.add(ChatModerationEvent.author(
      platform: removed.platform,
      authorChannelId: removed.author.channelId,
      authorName: removed.author.name,
    ));
    await settleCoordinatorTasks();
    expect(app.sessionChat.map((message) => message.plainText),
        ['old', 'retained']);
    expect(app.sessionSummary.participants.length, 3);
    app.applySettings(settings, connectChats: true);
    expect(app.sessionChat, isEmpty);
    expect(app.sessionSummary.participants, isEmpty);
  });

  test('hidden paid votes count and run support rules with redacted text',
      () async {
    final twitch = FakeChannelChatClient();
    final youtube = FakeYouTubeChatClient();
    final chat = ChatCoordinator(
      youtube: youtube,
      youtubeHorizontal: FakeYouTubeChatClient(),
      youtubeVertical: FakeYouTubeChatClient(),
      kick: FakeChannelChatClient(),
      twitch: twitch,
    );
    final server = _PollOverlay()..feedSeen = true;
    final tts = FakeTtsClient();
    final app = makeController(twitch, server, chat: chat, tts: tts);
    addTearDown(app.dispose);
    app.applySettings(
        SettingsModel(
          overlayEnabled: true,
          twitchChannel: 'channel',
          ttsEnabled: true,
          rules: [
            for (final type in [
              'support.bits',
              'support.superchat',
              'chat.command'
            ])
              {
                ...RuleSchema.newRule(type, id: type.replaceAll('.', '_')),
                'enabled': true,
                if (type == 'chat.command')
                  'trigger': {'type': type, 'command': '!1'},
                'actions': [
                  {
                    'id': 'out',
                    'type': 'template.trigger',
                    'name': 'vote',
                    'data': '{amount}|{message}'
                  },
                ],
              },
          ],
        ),
        connectChats: true);
    await settleCoordinatorTasks();
    app.startPoll(question: 'Q', options: ['One', 'Two'], hideResults: true);
    final supportRuns = app.rules.historyStream
        .firstWhere((runs) => runs.where((run) => run.completed).length == 2);
    for (final (source, platform, amount) in [
      (twitch.messageController, Platform.twitch, '500 Bits'),
      (youtube.messageController, Platform.youtube, r'$5.00'),
    ]) {
      source.add(ChatMessage(
        id: platform.name,
        platform: platform,
        author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
        items: const [MessageItem.text('!1')],
        timestamp: DateTime.now(),
        superChat: SuperChat(amount: amount, color: '#ffffff'),
      ));
    }
    await supportRuns.timeout(const Duration(seconds: 2));
    expect((await app.pollStream.first)!.total, 2);
    expect(server.chat, isEmpty);
    expect(tts.spoken, isEmpty);
    expect(server.support.map((message) => message.plainText), ['', '']);
    expect(server.support.map((message) => message.superChat!.amount),
        ['500 Bits', r'$5.00']);
    expect(server.triggers.map((event) => event['data']),
        ['500 Bits|', r'$5.00|']);
    expect(app.sessionSummary.supporters.map((support) => support.type),
        containsAll(['bits', 'superchat']));
  });

  test('featured rules record the delivery outcome in history', () async {
    final twitch = FakeChannelChatClient();
    final server = _PollOverlay();
    final app = makeController(twitch, server);
    addTearDown(app.dispose);
    app.applySettings(
        SettingsModel(overlayEnabled: true, rules: [
          {
            ...RuleSchema.newRule('chat.message', id: 'feature'),
            'cooldownSeconds': 0,
            'trigger': {
              'type': 'chat.message',
              'text': 'highlight',
              'match': 'contains'
            },
            'enabled': true,
            'actions': [
              {'id': 'out', 'type': 'featured'}
            ],
          },
        ]),
        connectChats: false);
    await settleCoordinatorTasks();
    for (final (outcome, status, reason) in [
      (FeaturedMessageStatus.noReceiver, 'skipped', 'noReceiver'),
      (FeaturedMessageStatus.disconnected, 'failed', 'noReceiver'),
      (FeaturedMessageStatus.sent, 'done', null),
      (FeaturedMessageStatus.rendered, 'done', null),
    ]) {
      server.featuredDelivery = outcome == FeaturedMessageStatus.noReceiver
          ? FeaturedMessageDelivery.noReceiver()
          : FeaturedMessageDelivery(
              'id', FeaturedMessageStatus.sent, Future.value(outcome));
      final completed = app.rules.historyStream.firstWhere((runs) =>
          runs.first.completed && runs.first.event.message?.id == outcome.name);
      twitch.messageController.add(ChatMessage(
        platform: Platform.twitch,
        id: outcome.name,
        author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
        items: const [MessageItem.text('highlight')],
        timestamp: DateTime.now(),
      ));
      final runs = await completed.timeout(const Duration(seconds: 2));
      final result = runs.first.results.single;
      expect((result.status, result.reason), (status, reason));
    }
  });

  test('hidden submissions skip audio, overlay and chat rules until poll.ended',
      () async {
    final twitch = FakeChannelChatClient();
    final server = _PollOverlay();
    final tts = FakeTtsClient();
    final alertSound = FakeAlertSound();
    final app =
        makeController(twitch, server, tts: tts, alertSound: alertSound);
    addTearDown(app.dispose);
    app.applySettings(
        SettingsModel(
          overlayEnabled: true,
          ttsEnabled: true,
          highlightWords: const ['private', 'ordinary'],
          highlightSounds: const {HighlightKind.word: 'coin'},
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
    ChatMessage chatMessage(String text) => ChatMessage(
        platform: Platform.twitch,
        id: text,
        author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
        items: [MessageItem.text(text)],
        timestamp: DateTime.now());
    twitch.messageController.add(chatMessage('!reply $answer'));
    await settleCoordinatorTasks();
    expect(tts.spoken, isEmpty);
    expect(alertSound.sources, isEmpty);
    twitch.messageController.add(chatMessage('Ordinary chat'));
    await Future<void>.delayed(const Duration(milliseconds: 280));
    expect(server.chat, ['Ordinary chat']);
    expect(tts.spoken.single, contains('Ordinary chat'));
    expect(alertSound.sources, ['coin']);
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

  for (final plainJson in [false, true]) {
    test(
        plainJson
            ? 'importing a crossed goal rebaselines automation and the next crossing fires'
            : 'restoring a crossed goal rebaselines automation and the next crossing fires',
        () async {
      final server = RuleOverlay()..feedSeen = true;
      final app = makeController(FakeChannelChatClient(), server);
      addTearDown(app.dispose);
      SettingsModel withProgress(SettingsModel settings, int current) =>
          settings.copyWith(
            goals: {
              'g': {
                'title': 'Goal',
                'type': 'manual',
                'current': current,
                'target': 10
              }
            },
          );
      final initial = withProgress(
          SettingsModel(overlayEnabled: false, rules: [
            {
              ...RuleSchema.newRule('goal.reached', id: 'goal'),
              'enabled': true,
              'actions': [
                {
                  'id': 'out',
                  'type': 'template.trigger',
                  'name': 'goal',
                  'data': 'crossed'
                }
              ],
            },
          ]),
          5);
      final notifier = SettingsNotifier(
        settingsRepository:
            _RestoreSettingsRepository(SettingsDocumentCodec.encode(initial)),
        secureStore: _RestoreSecureStore(),
      );
      addTearDown(notifier.dispose);
      await notifier.ready;
      final unsubscribe = notifier.addListener((settings) => app.applySettings(
          settings,
          connectChats: false,
          restoringBackup: notifier.publishingRestore));
      addTearDown(unsubscribe);
      if (plainJson) {
        await notifier.importSettings(
            SettingsDocumentCodec.encode(withProgress(initial, 10)));
      } else {
        await notifier.restoreBackup(
            (current, commit) => commit(withProgress(current, 10)));
      }
      await settleCoordinatorTasks();
      expect(app.rules.history, isEmpty);
      expect(server.triggers, isEmpty);

      await notifier.update(withProgress(initial, 0));
      await notifier.update(withProgress(initial, 10));
      await settleCoordinatorTasks();
      expect(app.rules.history.single.event.type, 'goal.reached');
      expect(server.triggers.single['data'], 'crossed');
    });
  }

  for (final dual in [false, true]) {
    test(
        '${dual ? 'dual' : 'single'} YouTube chat runs intervals until the last broadcast ends',
        () {
      fakeAsync((time) {
        final primary = FakeYouTubeChatClient();
        final horizontal = FakeYouTubeChatClient();
        final vertical = FakeYouTubeChatClient();
        final twitch = FakeChannelChatClient();
        final obs = FakeObsClient()..state = const ObsState(connected: true);
        final baseline = DateTime.utc(2026);
        final app = makeController(twitch, RuleOverlay(),
            clock: () => baseline.add(time.elapsed),
            obs: obs,
            chat: ChatCoordinator(
              youtube: primary,
              youtubeHorizontal: horizontal,
              youtubeVertical: vertical,
              kick: FakeChannelChatClient(),
              twitch: twitch,
            ));
        final states = <Map<String, (ServiceStatus, String?)>>[];
        final subscription = app.connectionStatusStream.listen(states.add);
        app.applySettings(
            SettingsModel(
              overlayEnabled: false,
              obsEnabled: true,
              youtubeHandle: '@creator',
              youtubeDualStreamEnabled: dual,
              youtubeHorizontalUrl: 'https://youtu.be/abcdefghijk',
              youtubeVerticalUrl: 'https://youtu.be/12345678901',
              rules: [
                {
                  ...RuleSchema.newRule('interval', id: 'timer'),
                  'enabled': true,
                  'actions': [
                    {'id': 'record', 'type': 'obs.recording', 'state': 'start'}
                  ],
                }
              ],
            ),
            connectChats: true);
        time.flushMicrotasks();

        final first = dual ? horizontal : primary;
        final firstKey = dual ? 'youtubeHorizontal' : 'youtube';
        first.statusController.add((ServiceStatus.connected, null));
        if (dual) {
          vertical.statusController.add((ServiceStatus.connected, null));
        }
        time.flushMicrotasks();
        expect(app.rules.intervalTimerActive, isTrue);

        first.statusController.add((ServiceStatus.idle, null));
        time.flushMicrotasks();
        expect(states.last[firstKey]?.$1, ServiceStatus.connected);
        const period = Duration(minutes: 5);
        time.elapse(period);
        expect(app.rules.history, hasLength(1));

        first.statusController.add((ServiceStatus.ended, null));
        time.flushMicrotasks();
        expect(states.last[firstKey]?.$1, ServiceStatus.ended);
        if (dual) {
          expect(app.rules.intervalTimerActive, isTrue);
          time.elapse(period);
          expect(app.rules.history, hasLength(2));
          vertical.statusController.add((ServiceStatus.ended, null));
          time.flushMicrotasks();
          expect(states.last['youtubeVertical']?.$1, ServiceStatus.ended);
        }

        expect(app.rules.intervalTimerActive, isFalse);
        time.elapse(period);
        expect(app.rules.history, hasLength(dual ? 2 : 1));
        unawaited(subscription.cancel());
        unawaited(app.dispose());
        time.flushMicrotasks();
      });
    });
  }

  test('contributions during restore accumulate on the restored goal and timer',
      () async {
    final twitch = FakeChannelChatClient();
    final app = makeController(twitch, RuleOverlay());
    addTearDown(app.dispose);
    final notifier = SettingsNotifier(
      secureStore: _RestoreSecureStore(),
      settingsRepository: _RestoreSettingsRepository('{}'),
    );
    await notifier.ready;
    final deadline = DateTime.now().millisecondsSinceEpoch + 120000;
    const initial = SettingsModel(overlayEnabled: false, goals: {
      'bits': {'title': 'Bits', 'type': 'bits', 'current': 20, 'target': 100},
    });
    await notifier.update(initial.copyWith(
      subathonPhase: 'running',
      subathonEndsAtMs: deadline - 60000,
      subathonSecondsPer100Bits: 2,
    ));
    final container = ProviderContainer(overrides: [
      appControllerProvider.overrideWithValue(app),
      settingsProvider.overrideWith((ref) => notifier),
    ]);
    addTearDown(container.dispose);
    container.read(goalTrackingProvider);
    container.read(subathonTrackingProvider);

    await notifier.restoreBackup((current, commit) async {
      final received = app.goalIncrements.take(2).drain<void>();
      for (final id in ['first', 'second']) {
        twitch.messageController.add(ChatMessage(
          platform: Platform.twitch,
          id: id,
          author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
          items: const [MessageItem.text('Cheer!')],
          timestamp: DateTime.utc(2026),
          superChat: const SuperChat(amount: '1 Bits', color: '#ffffff'),
        ));
      }
      await received;
      expect(notifier.state.goals['bits']?['current'], 20);
      await commit(current.copyWith(
        goals: {
          'bits': {...current.goals['bits']!, 'current': 80},
        },
        subathonEndsAtMs: deadline,
        subathonSecondsPer100Bits: 10,
      ));
    });
    await settleCoordinatorTasks();
    expect(
      (
        notifier.state.goals['bits']?['current'],
        notifier.state.subathonEndsAtMs
      ),
      (82, deadline + 200),
    );
  });

  test('a viewer-funded goal does not start the stream', () async {
    final twitch = FakeChannelChatClient();
    final obs = FakeObsClient()..state = const ObsState(connected: true);
    final app = makeController(twitch, RuleOverlay(), obs: obs);
    addTearDown(app.dispose);
    final notifier = SettingsNotifier(
      secureStore: _RestoreSecureStore(),
      settingsRepository: _RestoreSettingsRepository('{}'),
    );
    await notifier.ready;
    await notifier.update(SettingsModel(
      overlayEnabled: false,
      obsEnabled: true,
      goals: {
        'bits': {'title': 'Bits', 'type': 'bits', 'current': 0, 'target': 1}
      },
      rules: [
        {
          ...RuleSchema.newRule('goal.reached', id: 'goal'),
          'enabled': true,
          'trigger': {'type': 'goal.reached', 'goalId': 'bits'},
          'actions': [
            {'id': 'stream', 'type': 'obs.stream', 'state': 'start'}
          ],
        }
      ],
    ));
    final container = ProviderContainer(overrides: [
      appControllerProvider.overrideWithValue(app),
      settingsProvider.overrideWith((ref) => notifier),
    ]);
    addTearDown(container.dispose);
    final unsubscribe = notifier
        .addListener((next) => app.applySettings(next, connectChats: false));
    addTearDown(unsubscribe);
    container.read(goalTrackingProvider);
    twitch.messageController.add(ChatMessage(
      platform: Platform.twitch,
      id: 'cheer',
      author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
      items: const [MessageItem.text('Cheer!')],
      timestamp: DateTime.utc(2026),
      superChat: const SuperChat(amount: '1 Bits', color: '#ffffff'),
    ));
    await settleCoordinatorTasks();
    await settleCoordinatorTasks();
    expect(notifier.state.goals['bits']?['current'], 1);
    final run = app.rules.history.single;
    expect(run.results.single.reason, 'publicStreamControl');
    expect(run.event.origin.isUnprivilegedViewer, isTrue);
    expect(obs.ruleControls, isEmpty);
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

class _RestoreSettingsRepository implements SettingsRepository {
  _RestoreSettingsRepository(this.source);
  String source;

  @override
  Future<String?> read() async => source;

  @override
  Future<void> write(String json) async => source = json;
}

class _RestoreSecureStore implements SecureSettingsStore {
  @override
  Future<String?> readObsPassword() async => null;

  @override
  Future<void> writeObsPassword(String password) async {}

  @override
  Future<void> deleteObsPassword() async {}
}

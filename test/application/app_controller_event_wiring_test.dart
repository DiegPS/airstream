import 'dart:async';
import 'dart:io';
import 'package:airstream/application/subathon_timer.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_sound_player.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/chat_log_writer.dart';
import 'package:airstream/services/obs_service.dart';
// Flutter's existing test dependency supplies deterministic timers.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_giveaway.dart';
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
  final providerIds = <String>[];
  FeaturedMessageDelivery? featuredDelivery;

  @override
  void broadcastChatSupport(ChatMessage message) => support.add(message);

  @override
  void broadcastProviderEvent(ChatProviderEvent event,
          {bool alreadyFiltered = false}) =>
      providerIds.add(event.id);

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

  final giveaways = <Map<String, Object?>?>[];

  @override
  void broadcastGiveaway(Map<String, Object?>? giveaway) =>
      giveaways.add(giveaway);

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
          FakeAlertSound? alertSound,
          ChatLogWriter? chatLog}) =>
      AppController(
          clock: clock,
          clockSounds: clockSounds,
          chatLog: chatLog,
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

  test('moderation republishes open votes in every mode and preserves results',
      () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      app.applySettings(const SettingsModel(overlayEnabled: false),
          connectChats: true);
      fake.flushMicrotasks();

      for (final (mode, first, replacement) in [
        (PollMode.numbered, '!1', '!2'),
        (PollMode.word, 'Apple', 'Pear'),
        (PollMode.yesNo, 'yes', 'no'),
        (PollMode.rating, '1', '2'),
        (PollMode.freeAnswer, '!vote Apple', '!vote Pear'),
      ]) {
        app.startPoll(
            question: 'Pick',
            options: ['Apple', 'Pear'],
            mode: mode,
            command: '!vote');
        void send(String text, String id) {
          twitch.messageController.add(ChatMessage(
              platform: Platform.twitch,
              id: '${mode.name}-$id',
              author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
              items: [MessageItem.text(text)],
              timestamp: DateTime.utc(2026)));
          fake.elapse(const Duration(milliseconds: 250));
        }

        void delete(String id, [Platform platform = Platform.twitch]) {
          twitch.moderationController.add(ChatModerationEvent.message(
              platform: platform, messageId: '${mode.name}-$id'));
          fake.flushMicrotasks();
        }

        const ban = ChatModerationEvent.author(
            platform: Platform.twitch, authorChannelId: 'ana');

        send(first, 'first');
        send(replacement, 'replacement');
        delete('first');
        delete('replacement', Platform.kick);
        expect(server.polls.last?['total'], 1);
        delete('replacement');
        expect(server.polls.last?['total'], 0);
        if (mode == PollMode.freeAnswer) {
          expect(server.polls.last?['answers'], isEmpty);
        }
        send(first, 'another');
        twitch.moderationController.add(ban);
        fake.flushMicrotasks();
        expect(server.polls.last?['total'], 0);
        send(first, 'last');
        app.endPoll();
        fake.flushMicrotasks();
        final result = server.polls.last;
        expect(result?['total'], 1);
        delete('last');
        twitch.moderationController.add(ban);
        fake.flushMicrotasks();
        expect(server.polls.last, same(result));
      }
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('a block-list change drops open poll votes from blocked viewers or text',
      () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      const base = SettingsModel(overlayEnabled: false);
      app.applySettings(base, connectChats: true);
      fake.flushMicrotasks();
      app.startPoll(
          question: 'Pick',
          options: const ['Apple', 'Pear'],
          mode: PollMode.freeAnswer,
          command: '!vote');
      void send(String name, String text) {
        twitch.messageController.add(ChatMessage(
            platform: Platform.twitch,
            id: 'm-$name',
            author: ChatAuthor(name: name, channelId: name.toLowerCase()),
            items: [MessageItem.text(text)],
            timestamp: DateTime.utc(2026)));
        fake.elapse(const Duration(milliseconds: 250));
      }

      send('Ana', '!vote Apple');
      send('Beto', '!vote rude words here');
      send('Carla', '!vote Pear');
      expect(server.polls.last?['total'], 3);
      app.applySettings(
          base.copyWith(blockedUsers: ['ana'], blockedWords: ['rude words']),
          connectChats: true);
      fake.flushMicrotasks();
      expect(server.polls.last?['total'], 1);
      final answers = server.polls.last?['answers'] as List;
      expect(answers.map((a) => (a as Map)['text']), ['Pear']);
      app.endPoll();
      fake.flushMicrotasks();
      expect(server.polls.last?['total'], 1);
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('blocking a drawn winner republishes the public giveaway only', () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      const settings = SettingsModel(overlayEnabled: false);
      app.applySettings(settings, connectChats: true);
      app.startGiveaway(keyword: 'go', membersOnly: false);
      fake.flushMicrotasks();
      twitch.messageController.add(queueMessage('Ana', 'go', id: 'ana'));
      fake.elapse(const Duration(milliseconds: 250));
      expect(app.drawGiveaway()?.name, 'Ana');
      fake.flushMicrotasks();
      expect(server.giveaways.last?['winner'],
          {'name': 'Ana', 'platform': 'twitch'});
      final drawId = server.giveaways.last?['drawId'];

      app.applySettings(settings.copyWith(blockedUsers: ['ana']),
          connectChats: false);
      fake.flushMicrotasks();
      expect(server.giveaways.last?['winner'], isNull);
      expect(server.giveaways.last?['drawId'], drawId);
      ChatGiveaway? privateState;
      app.giveawayStream.first.then((state) => privateState = state);
      fake.flushMicrotasks();
      expect(privateState?.winner?.name, 'Ana');

      app.applySettings(settings, connectChats: false);
      fake.flushMicrotasks();
      expect(server.giveaways.last?['winner'],
          {'name': 'Ana', 'platform': 'twitch'});
      expect(server.giveaways.last?['drawId'], drawId);
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test(
      'blocking giveaway entrants republishes the count and excludes them from draws',
      () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      const settings = SettingsModel(overlayEnabled: false);
      app.applySettings(settings, connectChats: true);
      fake.flushMicrotasks();
      app.startGiveaway(keyword: 'go', membersOnly: false);
      twitch.messageController
          .add(queueMessage('BlockedViewer', 'go', id: 'one'));
      twitch.messageController.add(queueMessage('OtherName', 'go', id: 'two'));
      twitch.messageController
          .add(queueMessage('AllowedViewer', 'go', id: 'three'));
      fake.elapse(const Duration(milliseconds: 250));
      expect(server.giveaways.last?['entrantCount'], 3);

      app.applySettings(
        settings.copyWith(blockedUsers: ['@BlockedViewer', 'two']),
        connectChats: false,
      );
      fake.flushMicrotasks();
      expect(server.giveaways.last?['entrantCount'], 1);
      expect(app.drawGiveaways(10).map((entrant) => entrant.name),
          ['AllowedViewer']);
      fake.flushMicrotasks();
      expect(server.giveaways.last?['winner'], {
        'name': 'AllowedViewer',
        'platform': 'twitch',
      });
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('blocked Kicks events reach accounting but never banners, OBS or speech',
      () {
    fakeAsync((fake) {
      final kick = FakeChannelChatClient();
      final tts = FakeTtsClient();
      final server = _PollOverlay();
      final app = makeController(FakeChannelChatClient(), server,
          tts: tts,
          chat: ChatCoordinator(
              youtube: FakeYouTubeChatClient(),
              youtubeHorizontal: FakeYouTubeChatClient(),
              youtubeVertical: FakeYouTubeChatClient(),
              kick: kick,
              twitch: FakeChannelChatClient()));
      final visible = <String>[];
      final subscription =
          app.chatProviderEvents.listen((event) => visible.add(event.id));
      app.applySettings(
          const SettingsModel(
            overlayEnabled: false,
            ttsEnabled: true,
            ttsAlwaysReadSupport: true,
            blockedWords: ['blocked phrase'],
          ),
          connectChats: true);
      fake.flushMicrotasks();
      for (final (id, body) in [
        ('blocked', 'A blocked, phrase!'),
        ('safe', 'Thanks for streaming'),
      ]) {
        kick.eventController.add(ChatProviderEvent(
          platform: Platform.kick,
          kind: ChatProviderEventKind.support,
          id: id,
          authorName: 'Supporter',
          count: 10,
          text: body,
          timestamp: DateTime.now().toUtc(),
        ));
      }
      fake.flushMicrotasks();
      expect(visible, ['safe']);
      expect(server.providerIds, ['safe']);
      expect(tts.spoken.single, contains('Thanks for streaming'));
      expect(app.sessionSummary.supporters, hasLength(2));
      unawaited(subscription.cancel());
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('public session omits blocked names and keeps support accounting', () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      const settings = SettingsModel(overlayEnabled: false);
      app.applySettings(settings, connectChats: true);
      fake.flushMicrotasks();

      void raid(String name, String id) {
        twitch.eventController.add(ChatProviderEvent(
          platform: Platform.twitch,
          kind: ChatProviderEventKind.raid,
          id: id,
          authorName: name,
          authorChannelId: id,
          count: 10,
          timestamp: DateTime.utc(2026),
        ));
        fake.flushMicrotasks();
      }

      void cheer(String name, String id, String amount) {
        twitch.messageController.add(ChatMessage(
          platform: Platform.twitch,
          id: 'bits-$id',
          author: ChatAuthor(name: name, channelId: id),
          timestamp: DateTime.utc(2026),
          items: const [MessageItem.text('Hello')],
          superChat: SuperChat(amount: amount, color: ''),
        ));
        fake.flushMicrotasks();
      }

      raid('Visible', 'visible');
      raid('Hide by Name', 'other');
      cheer('Visible', 'visible', '10 Bits');
      cheer('Hide by Name', 'other', '100 Bits');
      final before = server.sessionState!()!;
      expect((before['latest'] as Map)['bits']['name'], 'Hide by Name');
      app.applySettings(
          settings.copyWith(blockedUsers: ['@hide by name', 'private-id']),
          connectChats: true);
      final afterBlock = server.sessionState!()!;
      expect((afterBlock['latest'] as Map)['bits']['name'], 'Visible');
      expect(afterBlock['supporterCount'], before['supporterCount']);
      raid('Hide by ID', 'private-id');

      final payload = server.sessionState!()!;
      expect(payload['supporterCount'], (before['supporterCount'] as int) + 1);
      expect((payload['supporters'] as List).map((row) => row['name']),
          ['Visible', 'Visible']);
      expect((payload['latest'] as Map)['raid']['name'], 'Visible');
      expect(
          ((payload['top'] as Map)['bits'] as List).single['name'], 'Visible');
      expect((payload['topChatters'] as List).single['name'], 'Visible');
      expect(payload.toString(), isNot(contains('Hide by')));
      expect(app.sessionSummary.supporters, hasLength(5));
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test(
      'block-list edits publish and persist sanitized waiting and playing entries',
      () {
    fakeAsync((fake) {
      final app = makeController(FakeChannelChatClient(), _PollOverlay());
      final saved = <QueueState>[];
      final published = <QueueState>[];
      final sub = app.queue.states.listen(published.add);
      app.queueSettingsWriter = (state) async => saved.add(state);
      const settings = SettingsModel(overlayEnabled: false);
      app.applySettings(settings, connectChats: false);
      app.queue.setStatus(QueueStatus.open);
      for (final name in ['Playing', 'DropPlaying', 'Waiting', 'DropWaiting']) {
        app.queue.handleMessage(queueMessage(name, '!join A bad, phrase!'));
      }
      app.queue.next(2);
      fake.elapse(const Duration(milliseconds: 250));
      expect(saved.single.playing, hasLength(2));
      saved.clear();
      published.clear();

      app.applySettings(
          settings.copyWith(
              blockedWords: ['bad phrase'],
              blockedUsers: ['@DropPlaying', '@DropWaiting']),
          connectChats: false);
      fake.elapse(const Duration(milliseconds: 250));
      for (final state in [app.queue.current, saved.single, published.single]) {
        expect(state.entries.single.name, 'Waiting');
        expect(state.playing.single.name, 'Playing');
        expect(state.entries.single.note, isEmpty);
        expect(state.playing.single.note, isEmpty);
      }
      unawaited(sub.cancel());
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('session latest, recent and rankings count a Twitch gift batch once',
      () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = _PollOverlay();
      final app = makeController(twitch, server);
      const settings = SettingsModel(overlayEnabled: false);
      app.applySettings(settings, connectChats: true);
      void gift(int i) {
        twitch.messageController.add(ChatMessage(
          platform: Platform.twitch,
          id: 'gift-$i',
          timestamp: DateTime.utc(2026, 11, 18, 12, 0, i),
          author: const ChatAuthor(name: 'Gifter', channelId: 'gifter'),
          items: const [],
          isMembershipEvent: true,
          membershipEventKind: MembershipEventKind.gift,
        ));
      }

      for (var i = 0; i < 5; i++) {
        gift(i);
      }
      fake.elapse(const Duration(seconds: 3));
      final state = server.sessionState!.call()!;
      final latest = (state['latest'] as Map)['gift'] as Map;
      expect(latest['count'], 5);
      expect(state['supporters'], [latest]);
      expect(((state['top'] as Map)['gift'] as List).single['value'], 5);
      expect(app.sessionSummary.supporters.single.count, 5);
      gift(5);
      fake.flushMicrotasks();
      app.applySettings(settings, connectChats: false);
      expect(app.sessionSummary.supporters.map((s) => s.count), [5, 1]);
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('one Twitch gift batch satisfies minCount five and singles count one',
      () {
    fakeAsync((fake) {
      final twitch = FakeChannelChatClient();
      final server = RuleOverlay()..feedSeen = true;
      final app = makeController(twitch, server);
      app.applySettings(
          SettingsModel(
            overlayEnabled: false,
            rulesEnabled: true,
            rules: [
              for (final count in [1, 5])
                {
                  ...RuleSchema.newRule('support.gift', id: 'gift_$count'),
                  'enabled': true,
                  'trigger': {'type': 'support.gift', 'min': count},
                  'actions': [
                    {
                      'id': 'out',
                      'type': 'template.trigger',
                      'name': 'gift',
                      'data': '{count}'
                    },
                  ],
                }
            ],
          ),
          connectChats: false);

      void gift(String id) => twitch.messageController.add(ChatMessage(
            platform: Platform.twitch,
            id: id,
            timestamp: DateTime.utc(2026),
            author: const ChatAuthor(name: 'Gifter', channelId: 'gifter'),
            items: const [],
            isMembershipEvent: true,
            membershipEventKind: MembershipEventKind.gift,
          ));

      for (var i = 0; i < 5; i++) {
        gift('batch-$i');
      }
      fake.elapse(const Duration(seconds: 3));
      expect(app.rules.history.map((run) => run.event.count), [5, 5]);
      expect(app.rules.history.map((run) => run.event.eventId).toSet(),
          hasLength(1));

      gift('single');
      fake.elapse(const Duration(seconds: 3));
      expect(app.rules.history.map((run) => run.event.count), [1, 5, 5]);
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

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

  test('countdown expiry during a full restore preserves the restored clock',
      () {
    fakeAsync((fake) {
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final sounds = _ClockSounds();
      final app = makeController(FakeChannelChatClient(), RuleOverlay(),
          clock: now, clockSounds: sounds);
      final original = const LiveClock(durationSeconds: 2, sound: 'chime')
          .start(now().millisecondsSinceEpoch);
      const restored = LiveClock(durationSeconds: 15, label: 'Restored');
      final notifier = SettingsNotifier(
        secureStore: _RestoreSecureStore(),
        settingsRepository: _RestoreSettingsRepository(
          SettingsDocumentCodec.encode(
              SettingsModel(overlayEnabled: false, clock: original)),
        ),
      );
      fake.flushMicrotasks();
      app.ruleSettingsWriter = notifier.update;
      app.clockExpiryWriter = notifier.updateLatest;
      final remove = notifier.addListener((settings) => app.applySettings(
          settings,
          connectChats: false,
          restoringBackup: notifier.publishingRestore));

      var committed = false;
      unawaited(notifier.restoreBackup((current, commit) async {
        fake.elapse(const Duration(seconds: 2));
        expect(notifier.state.clock.phase, ClockPhase.running);
        await commit(current.copyWith(clock: restored));
        committed = true;
      }));
      fake.flushMicrotasks();
      expect(committed, isTrue);
      expect(notifier.state.clock, same(restored));
      expect(sounds.played, isEmpty);
      remove();
      notifier.dispose();
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

  test('removing the last seconds of a countdown ends it with sound and rules',
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
      var current = SettingsModel(
        clock: const LiveClock(durationSeconds: 30, sound: 'chime'),
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [rule],
      );
      app.ruleSettingsWriter = (settings) async {
        current = settings;
        app.applySettings(settings, connectChats: false);
      };
      app.applySettings(current, connectChats: false);
      unawaited(app.operateClock('start'));
      fake.flushMicrotasks();
      fake.elapse(const Duration(seconds: 5));
      // −1 min with 25 s left takes the countdown straight to zero.
      unawaited(app.operateClock('add', seconds: -60));
      fake.flushMicrotasks();
      fake.elapse(const Duration(seconds: 1));
      fake.flushMicrotasks();
      expect(current.clock.phase, ClockPhase.ended);
      expect(server.triggers.single['name'], 'finish');
      expect(sounds.played, hasLength(1));
      // Nothing else fires later.
      fake.elapse(const Duration(minutes: 1));
      fake.flushMicrotasks();
      expect(server.triggers, hasLength(1));
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

  test('the last ended chat freezes the session and Start resets it', () async {
    final logs = await Directory.systemTemp.createTemp('ended-chat-test-');
    addTearDown(() => logs.delete(recursive: true));
    final log = ChatLogWriter(
        directory: () async => logs, clock: () => DateTime(2026, 11, 19));
    final youtube = FakeYouTubeChatClient();
    final twitch = FakeChannelChatClient();
    final app = makeController(twitch, RuleOverlay(),
        chatLog: log,
        chat: ChatCoordinator(
          youtube: youtube,
          youtubeHorizontal: FakeYouTubeChatClient(),
          youtubeVertical: FakeYouTubeChatClient(),
          kick: FakeChannelChatClient(),
          twitch: twitch,
        ));
    addTearDown(app.dispose);
    const settings = SettingsModel(
      overlayEnabled: false,
      youtubeHandle: '@creator',
      twitchChannel: 'channel',
      saveChatLog: true,
    );
    app.applySettings(settings, connectChats: true);
    youtube.statusController.add((ServiceStatus.connected, null));
    twitch.statusController.add((ServiceStatus.connected, null));
    final first = queueMessage('Ana', 'first', platform: Platform.youtube);
    youtube.messageController.add(first);
    await settleCoordinatorTasks();
    expect(app.sessionSummary.messages, 1);
    expect(app.sessionChat.single.isFirstInSession, isTrue);

    youtube.statusController.add((ServiceStatus.ended, null));
    await settleCoordinatorTasks();
    expect(app.sessionSummary.endedAt, isNull);

    youtube.statusController.add((ServiceStatus.connected, null));
    app.applySettings(settings.copyWith(twitchEnabled: false),
        connectChats: true);
    await settleCoordinatorTasks();
    expect(app.sessionSummary.endedAt, isNull);
    youtube.statusController.add((ServiceStatus.ended, null));
    await settleCoordinatorTasks();
    final end = app.sessionSummary.endedAt;
    expect(end, isNotNull);
    expect(app.sessionSummary.duration(end!.add(const Duration(hours: 1))),
        app.sessionSummary.duration(end));
    expect(app.sessionChat.single.plainText, 'first');
    expect(app.sessionSummary.messages, 1);

    app.retryChatConnections();
    expect(youtube.connectCount, 2);
    expect(app.sessionSummary.messages, 0);
    expect(app.sessionSummary.endedAt, isNull);
    expect(app.sessionChat, isEmpty);
    expect(await app.messageListStream.first, isEmpty);
    youtube.statusController.add((ServiceStatus.connected, null));
    youtube.messageController
        .add(queueMessage('Ana', 'second', platform: Platform.youtube));
    await settleCoordinatorTasks();
    expect(app.sessionChat.single.isFirstInSession, isTrue);
    expect(app.sessionSummary.messages, 1);
    await log.endSession();
    final files = await logs.list().cast<File>().toList();
    expect(files, hasLength(2));
    final lines = await Future.wait(files.map((file) => file.readAsLines()));
    expect(lines.map((log) => log.single),
        unorderedEquals([endsWith('Ana: first'), endsWith('Ana: second')]));
  });

  test('Start after every chat ended restarts the voice reader session',
      () async {
    final youtube = FakeYouTubeChatClient();
    final audio =
        AudioCoordinator(tts: FakeTtsClient(), captions: FakeCaptionsClient());
    final app = AppController(
      audioCoordinator: audio,
      chatCoordinator: ChatCoordinator(
        youtube: youtube,
        youtubeHorizontal: FakeYouTubeChatClient(),
        youtubeVertical: FakeYouTubeChatClient(),
        twitch: FakeChannelChatClient(),
        kick: FakeChannelChatClient(),
      ),
      overlayCoordinator: OverlayCoordinator(overlay: FakeOverlayClient()),
      obsCoordinator: ObsCoordinator(obs: FakeObsClient()),
    );
    addTearDown(app.dispose);
    const settings = SettingsModel(
        overlayEnabled: false, youtubeHandle: '@creator', ttsEnabled: true);
    app.applySettings(settings, connectChats: true);
    youtube.statusController.add((ServiceStatus.connected, null));
    await settleCoordinatorTasks();
    final first = audio.ttsSessionStartedAt;
    expect(first, isNotNull);

    youtube.statusController.add((ServiceStatus.ended, null));
    await settleCoordinatorTasks();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    app.retryChatConnections();
    // The old start time would let the new connection's history be read
    // aloud once the backlog window of the first session has passed.
    expect(audio.ttsSessionStartedAt!.isAfter(first!), isTrue);
  });

  test('Retry starts a fresh broadcast when the other chat failed', () async {
    final logs = await Directory.systemTemp.createTemp('failed-chat-test-');
    addTearDown(() => logs.delete(recursive: true));
    final log = ChatLogWriter(directory: () async => logs);
    final youtube = FakeYouTubeChatClient();
    final kick = FakeChannelChatClient();
    final twitch = FakeChannelChatClient();
    final chat = ChatCoordinator(
      youtube: youtube,
      youtubeHorizontal: FakeYouTubeChatClient(),
      youtubeVertical: FakeYouTubeChatClient(),
      twitch: twitch,
      kick: kick,
    );
    final app = makeController(twitch, RuleOverlay(), chat: chat, chatLog: log);
    addTearDown(app.dispose);
    app.applySettings(
        const SettingsModel(
            overlayEnabled: false,
            youtubeHandle: '@creator',
            kickSlug: 'channel',
            saveChatLog: true),
        connectChats: true);
    youtube.statusController.add((ServiceStatus.connected, null));
    kick.statusController.add((ServiceStatus.error, 'unavailable'));
    youtube.messageController
        .add(queueMessage('Ana', 'first', platform: Platform.youtube));
    await settleCoordinatorTasks();
    youtube.statusController.add((ServiceStatus.ended, null));
    await settleCoordinatorTasks();
    expect(chat.sessionPhase.name, 'failed');
    expect(app.sessionSummary.endedAt, isNotNull);
    expect(app.sessionChat.single.plainText, 'first');

    app.retryChatConnections();
    expect(youtube.connectCount, 2);
    expect(app.sessionSummary.messages, 0);
    expect(app.sessionSummary.endedAt, isNull);
    expect(app.sessionChat, isEmpty);
    youtube.statusController.add((ServiceStatus.connected, null));
    youtube.messageController
        .add(queueMessage('Ana', 'second', platform: Platform.youtube));
    await settleCoordinatorTasks();
    await log.endSession();
    final files = await logs.list().cast<File>().toList();
    expect(files, hasLength(2));
    final lines = await Future.wait(files.map((file) => file.readAsLines()));
    expect(lines.map((log) => log.single),
        unorderedEquals([endsWith('Ana: first'), endsWith('Ana: second')]));
  });

  test('natural chat end cancels queued chat speech and preserves other speech',
      () async {
    final youtube = FakeYouTubeChatClient();
    final twitch = FakeChannelChatClient();
    final tts = FakeTtsClient();
    final app = makeController(twitch, RuleOverlay(),
        tts: tts,
        chat: ChatCoordinator(
          youtube: youtube,
          youtubeHorizontal: FakeYouTubeChatClient(),
          youtubeVertical: FakeYouTubeChatClient(),
          twitch: twitch,
          kick: FakeChannelChatClient(),
        ));
    addTearDown(app.dispose);
    app.applySettings(
        const SettingsModel(
            overlayEnabled: false, youtubeHandle: '@creator', ttsEnabled: true),
        connectChats: true);
    youtube.statusController.add((ServiceStatus.connected, null));
    tts.speak('other speech');
    for (final text in ['first', 'second']) {
      youtube.messageController.add(ChatMessage(
        platform: Platform.youtube,
        id: text,
        author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
        items: [MessageItem.text(text)],
        timestamp: DateTime.now().toUtc(),
      ));
    }
    await settleCoordinatorTasks();
    expect(tts.tags.whereType<ChatMessage>(), hasLength(2));
    youtube.statusController.add((ServiceStatus.ended, null));
    await settleCoordinatorTasks();
    expect(app.sessionSummary.endedAt, isNotNull);
    expect(tts.spoken, ['other speech']);
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
  test('natural subathon expiry persists ended and fires its rule once',
      () async {
    final server = RuleOverlay()..feedSeen = true;
    final app = makeController(FakeChannelChatClient(), server);
    addTearDown(app.dispose);
    final repository = _RestoreSettingsRepository(SettingsDocumentCodec.encode(
        const SettingsModel(overlayEnabled: false)));
    final notifier = SettingsNotifier(
      secureStore: _RestoreSecureStore(),
      settingsRepository: repository,
    );
    addTearDown(notifier.dispose);
    await notifier.ready;
    app.subathonExpiryWriter = notifier.updateLatest;
    final remove = notifier.addListener(
        (settings) => app.applySettings(settings, connectChats: false));
    addTearDown(remove);

    await notifier.update(notifier.state.copyWith(
      rulesEnabled: true,
      rules: [
        {
          ...RuleSchema.newRule('subathon.ended', id: 'finish'),
          'enabled': true,
          'actions': [
            {'id': 'send', 'type': 'template.trigger', 'name': 'finish'},
          ],
        }
      ],
      subathonPhase: 'running',
      subathonEndsAtMs: DateTime.now().millisecondsSinceEpoch + 150,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await settleCoordinatorTasks();
    expect(server.triggers, hasLength(1));

    for (var i = 0; i < 2001; i++) {
      app.rules.handle(RuleEvent(type: 'chat.message', eventId: 'chat:$i'));
    }
    await notifier.update(notifier.state.copyWith(saveChatLog: true));
    await settleCoordinatorTasks();
    await settleCoordinatorTasks();

    expect(
      (notifier.state.subathonPhase, server.triggers.length),
      ('ended', 1),
    );
    final saved = SettingsDocumentCodec.decode(repository.source).settings;
    expect(saved.subathonPhase, 'ended');
    expect(saved.subathonEndsAtMs, 0);
  });

  test('adding time by rule skips a subathon whose deadline already passed',
      () async {
    final app = makeController(FakeChannelChatClient(), RuleOverlay());
    addTearDown(app.dispose);
    var writes = 0;
    app.ruleSettingsWriter = (_) async => writes++;
    app.applySettings(
      SettingsModel(
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [
          {
            ...RuleSchema.newRule('manual', id: 'add'),
            'enabled': true,
            'actions': [
              {'id': 'time', 'type': 'subathon.adjust', 'seconds': 60},
            ],
          }
        ],
        subathonPhase: 'running',
        subathonEndsAtMs: DateTime.now().millisecondsSinceEpoch - 60000,
      ),
      connectChats: false,
    );
    expect(app.rules.runNow('add', const RuleEvent(type: 'manual')), isNull);
    await settleCoordinatorTasks();
    final result = app.rules.history.single.results.single;
    expect((result.status, result.reason, writes),
        ('skipped', 'timerNotRunning', 0));
  });

  test('startup subathon normalization does not run ended rules', () async {
    final server = RuleOverlay()..feedSeen = true;
    final app = makeController(FakeChannelChatClient(), server);
    addTearDown(app.dispose);
    final notifier = SettingsNotifier(
      secureStore: _RestoreSecureStore(),
      settingsRepository:
          _RestoreSettingsRepository(SettingsDocumentCodec.encode(
        SettingsModel(
          overlayEnabled: false,
          rulesEnabled: true,
          rules: [
            {
              ...RuleSchema.newRule('subathon.ended', id: 'finish'),
              'enabled': true,
              'actions': [
                {'id': 'send', 'type': 'template.trigger', 'name': 'finish'},
              ],
            },
          ],
          subathonPhase: 'running',
          subathonEndsAtMs: DateTime.now().millisecondsSinceEpoch - 60000,
        ),
      )),
    );
    final container = ProviderContainer(overrides: [
      appControllerProvider.overrideWithValue(app),
      settingsProvider.overrideWith((ref) => notifier),
    ]);
    addTearDown(container.dispose);
    await notifier.ready;
    expect(notifier.state.subathonPhase, 'running');
    notifier.addListener(
        (settings) => app.applySettings(settings, connectChats: false));
    container.read(subathonTrackingProvider);
    await settleCoordinatorTasks();
    expect(notifier.state.subathonPhase, 'ended');
    expect(app.rules.history, isEmpty);
    expect(server.triggers, isEmpty);

    await notifier.update(notifier.state.copyWith(
      subathonPhase: 'running',
      subathonEndsAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    ));
    await notifier.update(notifier.state.copyWith(subathonPhase: 'ended'));
    await settleCoordinatorTasks();
    expect(app.rules.history, hasLength(1));
  });

  test('a live subathon owns exactly one expiry timer even without automation',
      () {
    fakeAsync((a) {
      DateTime now() => DateTime.utc(2026).add(a.elapsed);
      final c =
          makeController(FakeChannelChatClient(), OverlayServer(), clock: now);
      c.subathonExpiryWriter = (_) async {};
      final base = SettingsModel(
          overlayEnabled: false,
          subathonPhase: 'running',
          subathonEndsAtMs: now().millisecondsSinceEpoch + 60000);
      c.applySettings(base, connectChats: false);
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 1);
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
      expect(a.nonPeriodicTimerCount, 1);
      unawaited(c.dispose());
      a.flushMicrotasks();
      expect(a.nonPeriodicTimerCount, 0);
    });
  });
  test('expiry with automation off persists ended and stays silent on enable',
      () {
    fakeAsync((fake) {
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final c =
          makeController(FakeChannelChatClient(), OverlayServer(), clock: now);
      final rule = {
        ...RuleSchema.newRule('subathon.ended', id: 'timer'),
        'enabled': true
      };
      var settings = SettingsModel(
          overlayEnabled: false,
          rulesEnabled: false,
          rules: [rule],
          subathonPhase: 'running',
          subathonEndsAtMs: now().millisecondsSinceEpoch + 60000);
      c.subathonExpiryWriter = (change) async {
        settings = change(settings);
        c.applySettings(settings, connectChats: false);
      };
      c.applySettings(settings, connectChats: false);
      fake.elapse(const Duration(minutes: 1));
      expect(settings.subathonPhase, 'ended');
      c.applySettings(settings.copyWith(rulesEnabled: true),
          connectChats: false);
      fake.elapse(Duration.zero);
      expect(c.rules.history, isEmpty);
      expect(fake.nonPeriodicTimerCount, 0);
      unawaited(c.dispose());
      fake.flushMicrotasks();
    });
  });

  test('subathon deadline that passed during restore stays silent', () {
    fakeAsync((fake) {
      DateTime now() => DateTime.utc(2026).add(fake.elapsed);
      final server = RuleOverlay()..feedSeen = true;
      final app = makeController(FakeChannelChatClient(), server, clock: now);
      final deadline = now().millisecondsSinceEpoch + 2000;
      final running = SettingsModel(
        overlayEnabled: false,
        subathonPhase: 'running',
        subathonEndsAtMs: deadline,
        rules: [
          {
            ...RuleSchema.newRule('subathon.ended', id: 'finish'),
            'enabled': true,
            'actions': [
              {'id': 'send', 'type': 'template.trigger', 'name': 'finish'},
            ],
          }
        ],
      );
      final repository =
          _RestoreSettingsRepository(SettingsDocumentCodec.encode(running));
      final notifier = SettingsNotifier(
        secureStore: _RestoreSecureStore(),
        settingsRepository: repository,
      );
      fake.flushMicrotasks();
      app.subathonExpiryWriter = notifier.updateLatest;
      final remove = notifier.addListener((settings) => app.applySettings(
          settings,
          connectChats: false,
          restoringBackup: notifier.publishingRestore));

      unawaited(notifier.restoreBackup((current, commit) async {
        fake.elapse(const Duration(seconds: 2));
        await commit(current.copyWith(saveChatLog: true));
      }));
      fake.flushMicrotasks();
      fake.elapse(Duration.zero);
      expect(notifier.state.saveChatLog, isTrue);
      expect(notifier.state.subathonEndsAtMs, deadline);
      expect(repository.source, SettingsDocumentCodec.encode(notifier.state));
      expect(app.rules.history, isEmpty);

      unawaited(notifier.updateLatest((settings) =>
          SubathonTimer.normalize(settings, now().millisecondsSinceEpoch)));
      fake.elapse(Duration.zero);
      expect(notifier.state.subathonPhase, 'ended');
      expect(app.rules.history, isEmpty);
      expect(server.triggers, isEmpty);
      remove();
      notifier.dispose();
      unawaited(app.dispose());
      fake.flushMicrotasks();
    });
  });

  test('ending a paused subathon with −1m runs its end rule once', () async {
    final server = RuleOverlay()..feedSeen = true;
    final c = makeController(FakeChannelChatClient(), server);
    addTearDown(c.dispose);
    final rule = {
      ...RuleSchema.newRule('subathon.ended', id: 'end'),
      'enabled': true,
      'actions': [
        {'id': 'send', 'type': 'template.trigger', 'name': 'end', 'data': ''}
      ],
    };
    final paused = SettingsModel(
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [rule],
        subathonPhase: 'paused',
        subathonRemainingMs: 30000);
    c.applySettings(paused, connectChats: false);
    final ended = SubathonTimer.addSeconds(
        paused, DateTime.now().millisecondsSinceEpoch, -60);
    expect(ended.subathonPhase, 'ended');
    c.applySettings(ended, connectChats: false);
    c.applySettings(ended, connectChats: false);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.rules.history, hasLength(1));
    expect(c.rules.history.single.event.type, 'subathon.ended');
  });

  test('a subathon that ran out with automation off never fires its end rule',
      () async {
    final server = RuleOverlay()..feedSeen = true;
    final c = makeController(FakeChannelChatClient(), server);
    addTearDown(c.dispose);
    final rule = {
      ...RuleSchema.newRule('subathon.ended', id: 'end'),
      'enabled': true,
      'actions': [
        {'id': 'send', 'type': 'template.trigger', 'name': 'end', 'data': ''}
      ],
    };
    final now = DateTime.now().millisecondsSinceEpoch;
    // Watched while ahead, then automation is turned off before it ends.
    final running = SettingsModel(
        overlayEnabled: false,
        rulesEnabled: true,
        rules: [rule],
        subathonPhase: 'running',
        subathonEndsAtMs: now + 60000);
    c.applySettings(running, connectChats: false);
    c.applySettings(running.copyWith(rulesEnabled: false), connectChats: false);
    // It runs out; automation comes back; a later edit (any subathon
    // setting) normalizes the phase to ended.
    final expired = running.copyWith(subathonEndsAtMs: now - 1000);
    c.applySettings(expired.copyWith(rulesEnabled: false), connectChats: false);
    c.applySettings(expired, connectChats: false);
    c.applySettings(expired.copyWith(subathonPhase: 'ended'),
        connectChats: false);
    // Let the rule engine drain any run it accepted.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.rules.history, isEmpty);
    expect(server.triggers, isEmpty);
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
    expect(overlay.resetAlertDeliveryCount, 1);
    overlay.recent.add({'id': 'current'});
    controller.applySettings(settings.copyWith(alertDisabledTypes: ['bits']),
        connectChats: true);
    expect(overlay.recent.single['id'], 'current');
    expect(overlay.resetAlertDeliveryCount, 1);
    controller.applySettings(settings, connectChats: false);
    expect(overlay.resetAlertDeliveryCount, 2);
    expect(overlay.recent.single['id'], 'current');
    controller.applySettings(settings, connectChats: true);
    expect(overlay.recent, isEmpty);
    expect(overlay.clearRecentCount, 2);
    expect(overlay.resetAlertDeliveryCount, 3);
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

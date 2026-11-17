import 'dart:async';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/services/overlay_server.dart';
// Flutter's existing test dependency supplies deterministic timers.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_coordinator.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/overlay_coordinator.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
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

void main() {
  AppController makeController(
          FakeChannelChatClient twitch, OverlayServer server,
          {ChatCoordinator? chat}) =>
      AppController(
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

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
// Flutter's existing test dependency supplies deterministic timers.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_validation.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';

class Target implements RuleActionTarget {
  final calls = <String>[];
  Completer<RuleActionResult>? gate;
  void Function(RuleRun)? onAction;
  @override
  bool streaming = true;
  @override
  String currentScene = 'Original';
  @override
  Map<String, int> counters = {};
  @override
  String? skipReason(Map<String, dynamic> a, RuleEvent e) =>
      a['type'] == 'tts.say' ? 'ttsOff' : null;
  @override
  Future<RuleActionResult> execute(Map<String, dynamic> a, RuleRun r) async {
    calls.add(a['type'] as String);
    onAction?.call(r);
    if (a['type'] == 'obs.scene') currentScene = a['scene'] as String;
    if (a['type'] == 'obs.previousScene') currentScene = r.previousScene!;
    return gate == null ? RuleActionResult.done : await gate!.future;
  }
}

Map<String, dynamic> rule(
        {String id = 'r',
        String type = 'manual',
        String overlap = 'queue',
        List<Map<String, dynamic>>? actions,
        int cooldown = 0,
        int userCooldown = 0}) =>
    {
      ...RuleSchema.newRule(type, id: id),
      'enabled': true,
      'overlap': overlap,
      'cooldownSeconds': cooldown,
      'userCooldownSeconds': userCooldown,
      'actions': actions ??
          [
            {
              'id': 'a',
              'type': 'counter',
              'name': 'count',
              'op': 'add',
              'value': 1
            }
          ],
    };
void main() {
  void setup(FakeAsync a, void Function(RuleEngine, Target) body,
      {List<Map<String, dynamic>>? rules}) {
    final t = Target();
    // Construct with the fake clock as well as fake timers.
    final engine =
        RuleEngine(target: t, clock: () => DateTime.utc(2026).add(a.elapsed));
    engine.updateSettings(enabled: true, rules: rules ?? [rule()]);
    body(engine, t);
    unawaited(engine.dispose());
    a.flushMicrotasks();
  }

  test(
      'ordered actions and previous scene belongs to each run',
      () => fakeAsync((a) => setup(a, (e, t) {
            e.runNow('r', const RuleEvent(type: 'manual'));
            a.elapse(Duration.zero);
            expect(t.calls, ['obs.scene', 'obs.previousScene']);
            expect(t.currentScene, 'Original');
            expect(e.history.single.results.first.reason, 'noPreviousScene');
          }, rules: [
            rule(actions: [
              {'id': 'p', 'type': 'obs.previousScene'},
              {'id': 's', 'type': 'obs.scene', 'scene': 'New'},
              {'id': 'back', 'type': 'obs.previousScene'}
            ])
          ])));
  test(
      'skip overlap and queue cap while action is blocked',
      () => fakeAsync((a) => setup(a, (e, t) {
            t.gate = Completer();
            expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
            a.elapse(Duration.zero);
            for (var i = 0; i < 5; i++) {
              expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
            }
            expect(e.runNow('r', const RuleEvent(type: 'manual')), 'queueFull');
            e.updateSettings(enabled: true, rules: [rule(overlap: 'skip')]);
            expect(e.history.where((r) => r.completed), hasLength(6));
            t.gate!.complete(RuleActionResult.done);
            a.flushMicrotasks();
            e.runNow('r', const RuleEvent(type: 'manual'));
            a.elapse(Duration.zero);
            // A completed gate may finish immediately: use a fresh one.
            t.gate = Completer();
            e.runNow('r', const RuleEvent(type: 'manual'));
            a.elapse(Duration.zero);
            expect(e.runNow('r', const RuleEvent(type: 'manual')),
                'overlapSkipped');
            t.gate!.complete(RuleActionResult.done);
            a.flushMicrotasks();
          })));
  test(
      'global queue caps at 20 waiting',
      () => fakeAsync((a) => setup(a, (e, t) {
            t.gate = Completer();
            for (var i = 0; i < 5; i++) {
              e.runNow('r$i', const RuleEvent(type: 'manual'));
              a.elapse(Duration.zero);
            }
            for (var i = 0; i < 20; i++) {
              expect(
                  e.runNow('r${i % 5}', const RuleEvent(type: 'manual')), null);
            }
            expect(
                e.runNow('r0', const RuleEvent(type: 'manual')), 'queueFull');
            t.gate!.complete(RuleActionResult.done);
            a.flushMicrotasks();
          }, rules: List.generate(5, (i) => rule(id: 'r$i')))));
  for (final change in ['disable', 'edit', 'off', 'delete']) {
    test(
        '$change cancels during wait and remaining actions',
        () => fakeAsync((a) => setup(a, (e, t) {
              e.runNow('r', const RuleEvent(type: 'manual'));
              a.elapse(Duration.zero);
              expect(a.nonPeriodicTimerCount, 1);
              final r = rule(actions: [
                {'id': 'wait', 'type': 'wait', 'seconds': 10},
                {
                  'id': 'a',
                  'type': 'counter',
                  'name': 'count',
                  'op': 'add',
                  'value': 1
                }
              ]);
              e.updateSettings(
                  enabled: change != 'off',
                  rules: change == 'delete'
                      ? []
                      : [
                          {
                            ...r,
                            if (change == 'disable') 'enabled': false,
                            if (change == 'edit') 'name': 'Edited'
                          }
                        ]);
              a.elapse(const Duration(seconds: 20));
              expect(t.calls, isEmpty);
              expect(e.history.single.results.map((r) => r.status),
                  ['cancelled', 'cancelled']);
            }, rules: [
              rule(actions: [
                {'id': 'wait', 'type': 'wait', 'seconds': 10},
                {
                  'id': 'a',
                  'type': 'counter',
                  'name': 'count',
                  'op': 'add',
                  'value': 1
                }
              ])
            ])));
  }
  test(
      'cooldowns, user cooldown and repeated event dedupe',
      () => fakeAsync((a) => setup(a, (e, t) {
            const event = RuleEvent(
                type: 'manual', eventId: 'one', author: RuleAuthor(id: 'u'));
            expect(e.handle(event)['r'], null);
            a.elapse(Duration.zero);
            expect(e.handle(event), isEmpty);
            expect(
                e.handle(const RuleEvent(
                    type: 'manual', author: RuleAuthor(id: 'u')))['r'],
                'cooldown');
            a.elapse(const Duration(seconds: 31));
            expect(
                e.handle(const RuleEvent(
                    type: 'manual', author: RuleAuthor(id: 'u')))['r'],
                'userCooldown');
            expect(
                e.handle(const RuleEvent(
                    type: 'manual', author: RuleAuthor(id: 'v')))['r'],
                null);
          }, rules: [rule(cooldown: 30, userCooldown: 60)])));
  test(
      'breaker trips on 31, cancels and reset re-enables',
      () => fakeAsync((a) => setup(a, (e, t) {
            for (var i = 0; i < 30; i++) {
              expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
              a.elapse(Duration.zero);
            }
            expect(e.runNow('r', const RuleEvent(type: 'manual')), 'tripped');
            expect(e.tripped, 'runRateExceeded');
            e.resetBreaker();
            expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
            a.elapse(Duration.zero);
          })));
  test(
      'chain limit stops recursive goal actions at depth 3',
      () => fakeAsync((a) => setup(a, (e, t) {
            t.onAction = (r) => e.handle(RuleEvent(
                type: 'goal.reached',
                goalId: 'goal',
                chainDepth: r.event.chainDepth + 1));
            e.handle(const RuleEvent(type: 'goal.reached', goalId: 'goal'));
            a.elapse(Duration.zero);
            a.flushMicrotasks();
            expect(t.calls, hasLength(3));
            expect(e.history, hasLength(3));
          }, rules: [
            rule(type: 'goal.reached', actions: [
              {'id': 'a', 'type': 'goal.adjust', 'goalId': 'goal', 'delta': 1}
            ])
          ])));
  test(
      'OBS times out uncertain once and subsequent action runs',
      () => fakeAsync((a) => setup(a, (e, t) {
            t.gate = Completer();
            e.runNow('r', const RuleEvent(type: 'manual'));
            a.elapse(Duration.zero);
            a.elapse(const Duration(seconds: 5));
            expect(t.calls, ['obs.scene']);
            expect(e.history.single.results.map((r) => r.status),
                ['uncertain', 'skipped']);
            t.gate!.complete(RuleActionResult.done);
            a.flushMicrotasks();
            expect(t.calls, hasLength(1));
          }, rules: [
            rule(actions: [
              {'id': 's', 'type': 'obs.scene', 'scene': 'New'},
              {'id': 't', 'type': 'tts.say', 'text': 'Hello'}
            ])
          ])));
  test(
      'simulate has no calls history cooldown or timers; manual ignores trigger and cooldown',
      () => fakeAsync((a) => setup(a, (e, t) {
            final sample = e.sampleEvent('chat.command');
            final simulation = e.simulate(e.rules.single, sample);
            expect(simulation.matched, true);
            expect(simulation.actions.single['text'], 'Hello Alex');
            expect(simulation.results.single.reason, 'ttsOff');
            expect(t.calls, isEmpty);
            expect(e.history, isEmpty);
            expect(a.nonPeriodicTimerCount, 0);
            expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
            a.elapse(Duration.zero);
            expect(e.runNow('r', const RuleEvent(type: 'manual')), null);
            a.elapse(Duration.zero);
            expect(e.history.first.triggerSummary, 'manual');
          }, rules: [
            rule(type: 'chat.command', cooldown: 30, actions: [
              {'id': 'a', 'type': 'tts.say', 'text': 'Hello {user}'}
            ])
          ])));
  test(
      'history retains 50 newest, idle has no timers',
      () => fakeAsync((a) => setup(a, (e, t) {
            for (var i = 0; i < 55; i++) {
              e.runNow('r', const RuleEvent(type: 'manual'));
              a.elapse(const Duration(seconds: 3));
            }
            expect(e.history, hasLength(50));
            expect(e.history.first.id, 'run_55');
            e.updateSettings(enabled: true, rules: []);
            expect(e.handle(const RuleEvent(type: 'manual')), isEmpty);
            expect(a.nonPeriodicTimerCount, 0);
          })));
  test('Test samples carry a chat message only where live events do', () {
    final engine = RuleEngine(target: Target());
    addTearDown(engine.dispose);
    final adapter = RuleEventAdapter();
    for (final (kind, platform) in [
      (ChatProviderEventKind.raid, Platform.twitch),
      (ChatProviderEventKind.host, Platform.kick),
      (ChatProviderEventKind.support, Platform.kick),
    ]) {
      final live = adapter.provider(ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: kind.name,
        authorName: 'Alex',
        timestamp: DateTime.utc(2026),
      ))!;
      expect(live.message, isNull, reason: live.type);
      // A featured-message action is skipped live, so Test must agree.
      expect(engine.sampleEvent(live.type).message, isNull, reason: live.type);
    }
    for (final type in ['chat.message', 'support.superchat', 'support.bits']) {
      expect(engine.sampleEvent(type).message, isNotNull, reason: type);
    }
  });

  test('simulation resolves subsequent text against dry-run counters only', () {
    final target = Target();
    target.counters = {'count': 2};
    final engine = RuleEngine(target: target);
    addTearDown(engine.dispose);
    final r = rule(actions: [
      {'id': 'c', 'type': 'counter', 'name': 'count', 'op': 'add', 'value': 3},
      {'id': 't', 'type': 'tts.say', 'text': '{counter.count}'}
    ]);
    expect(
        engine
            .simulate(r, const RuleEvent(type: 'manual'))
            .actions
            .last['text'],
        '5');
    expect(target.counters, {'count': 2});
    expect(target.calls, isEmpty);
    expect(engine.history, isEmpty);
  });
  test(
      'only allowlisted triggers and privileged viewer filters control the stream',
      () {
    const always = {
      'manual',
      'interval',
      'clock.ended',
      'obs.streamStarted',
      'obs.streamStopped',
      'obs.recordingStarted',
      'obs.recordingStopped',
    };
    const viewerTriggers = {
      'chat.message',
      'chat.command',
      'chat.firstMessage',
      'queue.joined',
      'support.superchat',
      'support.bits',
      'support.membership',
      'support.gift',
      'support.raid',
      'support.kicks',
    };
    for (final type in RuleSchema.triggers.keys) {
      for (final (roles, privileged) in [
        (<String>[], false),
        if (RuleSchema.supportsRoleFilter(type)) ...[
          (['owner'], true),
          (['moderator'], true),
          (['owner', 'moderator'], true),
          (['owner', 'member'], false),
          (['everyone'], false),
        ],
      ]) {
        final allowed = always.contains(type) ||
            (viewerTriggers.contains(type) && privileged);
        final scenario = '$type with $roles';
        final definition = rule(type: type, actions: [
          {'id': 'stream', 'type': 'obs.stream', 'state': 'start'},
        ]);
        definition['conditions']['roles'] = roles;
        expect(ruleProblems(definition)['action-0-state'],
            allowed ? isNull : 'publicStreamControl',
            reason: scenario);
        final event = RuleEvent(
          type: type,
          author: const RuleAuthor(roles: ['owner', 'moderator', 'member']),
          text: (definition['trigger']['command'] ??
              definition['trigger']['text'] ??
              '') as String,
          amount: 1000000,
          count: 1000000000,
          months: 1200,
        );
        fakeAsync((time) => setup(time, (engine, target) {
              if (type == 'manual') {
                expect(engine.fireManual('r'), isNull, reason: scenario);
              } else if (type == 'interval') {
                engine.updateEnvironment(chatConnected: true);
                time.elapse(const Duration(minutes: 5));
              } else {
                expect(engine.handle(event)['r'], isNull, reason: scenario);
              }
              time.elapse(Duration.zero);
              expect(engine.history.single.results.single.reason,
                  allowed ? isNull : 'publicStreamControl',
                  reason: scenario);
              expect(target.calls, allowed ? ['obs.stream'] : isEmpty,
                  reason: scenario);
            }, rules: [definition]));
      }
    }
    final unknown = rule(actions: [
      {'id': 'stream', 'type': 'obs.stream', 'state': 'start'},
    ])
      ..['trigger'] = {'type': 'future.trigger'};
    expect(ruleProblems(unknown)['action-0-state'], 'publicStreamControl');
    final unknownChat = {
      ...unknown,
      'trigger': {'type': 'chat.future'},
      'conditions': {
        'roles': ['owner']
      },
    };
    expect(ruleProblems(unknownChat)['action-0-state'], 'publicStreamControl');
    fakeAsync((time) => setup(time, (engine, target) {
          expect(engine.runNow('r', const RuleEvent(type: 'manual')),
              'invalidRule');
          time.elapse(Duration.zero);
          expect(target.calls, isEmpty);
        }, rules: [unknown]));
  });

  test('viewer stream control skips member, VIP and mixed roles at runtime',
      () {
    for (final (roles, blocked) in [
      (['member'], true),
      (['vip'], true),
      (['member', 'moderator'], true),
      (['moderator'], false),
      (['owner'], false),
    ]) {
      fakeAsync((a) {
        final definition = rule(type: 'chat.firstMessage', actions: [
          {'id': 'stream', 'type': 'obs.stream', 'state': 'start'},
        ]);
        definition['conditions']['roles'] = roles;
        setup(a, (engine, target) {
          engine.handle(RuleEvent(
              type: 'chat.firstMessage',
              author: RuleAuthor(name: 'Alex', roles: roles)));
          a.elapse(Duration.zero);
          final result = engine.history.single.results.single;
          expect(result.reason, blocked ? 'publicStreamControl' : isNull);
          expect(target.calls, blocked ? isEmpty : ['obs.stream']);
        }, rules: [definition]);
      });
    }
  });

  test(
      'first-message rules honor the pipeline flag and exclude membership notices',
      () {
    final adapter = RuleEventAdapter();
    ChatMessage m(String id, {bool first = false, bool membership = false}) =>
        ChatMessage(
          platform: Platform.twitch,
          id: id,
          author: const ChatAuthor(name: 'Alex', channelId: 'u'),
          items: const [MessageItem.text('hello')],
          timestamp: DateTime.utc(2026),
          isFirstInSession: first,
          isMembershipEvent: membership,
          membershipEventKind:
              membership ? MembershipEventKind.subscription : null,
        );
    Iterable<String> types(ChatMessage message) =>
        adapter.message(message).map((event) => event.type);
    expect(
        types(m('notice', first: true, membership: true)),
        allOf(contains('support.membership'),
            isNot(contains('chat.firstMessage'))));
    expect(types(m('seen')), isNot(contains('chat.firstMessage')));
    expect(types(m('chat', first: true)), contains('chat.firstMessage'));
  });
}

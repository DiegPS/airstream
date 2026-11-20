import 'dart:convert';

import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/chat_filter.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_engine_test.dart' show Target, rule;

ChatMessage _vote(String author, String text,
        {Platform platform = Platform.twitch,
        String? channelId,
        QueueRole role = QueueRole.everyone,
        bool owner = false}) =>
    ChatMessage(
      platform: platform,
      id: '$author-$text-${platform.name}',
      author: ChatAuthor(
          name: author, channelId: channelId ?? author.toLowerCase()),
      items: [MessageItem.text(text)],
      timestamp: DateTime.utc(2026, 11, 15),
      isOwner: owner,
      isMembership: role == QueueRole.member,
      isVip: role == QueueRole.vip,
      isModerator: role == QueueRole.moderator,
    );

class _MessageSpy extends ChatMessage {
  _MessageSpy()
      : super(
          platform: Platform.twitch,
          id: 'spy',
          author: const ChatAuthor(name: 'Alex', channelId: 'alex'),
          items: const [MessageItem.text('!1')],
          timestamp: DateTime.utc(2026),
        );

  var reads = 0;
  @override
  String get plainText {
    reads++;
    return super.plainText;
  }
}

Future<void> _published() =>
    Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('falls back to the latest eligible vote after filtering or deletion',
      () async {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    polls.start(
        question: 'Pick one', options: ['A', 'B'], allowed: QueueRole.member);
    final first = _vote('Ana', '!1', role: QueueRole.member);
    final second = _vote('Ana', '!2 first comment', role: QueueRole.member);
    polls
      ..handleMessage(first)
      ..handleMessage(second)
      ..handleMessage(_vote('Ana', '!1 blocked phrase', role: QueueRole.member))
      ..applyFilter(
          ChatFilter(const SettingsModel(blockedWords: ['blocked phrase'])));
    expect(polls.current!.counts, [0, 1]);
    polls
      ..handleMessage(_vote('Ana', '!2 blocked phrase', role: QueueRole.member))
      ..handleMessage(_vote('Ana', '!1 ineligible'))
      ..applyFilter(
          ChatFilter(const SettingsModel(blockedWords: ['blocked phrase'])));
    expect(polls.current!.counts, [0, 1]);
    polls.handleModeration(ChatModerationEvent.message(
        platform: second.platform, messageId: second.id));
    expect(polls.current!.counts, [1, 0]);
  });

  test('classic numbered polls preserve the original JSON fields', () {
    final polls = ChatPollController(clock: () => DateTime.utc(1970));
    addTearDown(polls.dispose);
    polls.start(
        question: 'Pick one',
        options: ['Red', 'Blue'],
        duration: const Duration(minutes: 1));
    polls
      ..handleMessage(_vote('Ana', '!1 please'))
      ..handleMessage(_vote('Ben', '!2'))
      ..handleMessage(_vote('Ana', '!2'))
      ..handleMessage(_vote('Chad', '!1'));
    expect(
        jsonEncode(polls.current!.toOverlayJson()..remove('leaderIndices')),
        '{"question":"Pick one","options":[{"label":"Red","votes":1,'
        '"percent":33},{"label":"Blue","votes":2,"percent":67}],"total":3,'
        '"closed":false,"endsAt":60000}');
  });

  for (final mode in [PollMode.numbered, PollMode.freeAnswer]) {
    test('poll.ended and the page payload use all tied leaders for $mode', () {
      final polls = ChatPollController();
      addTearDown(polls.dispose);
      polls.start(
          question: 'Q',
          options: ['Red', 'Blue', 'Green'],
          mode: mode,
          hideResults: true);
      final free = mode == PollMode.freeAnswer;
      for (final (viewer, option, answer) in [
        ('A', '!1', 'Red'),
        ('B', '!2', 'Blue'),
        ('C', '!1', 'Red'),
        ('D', '!2', 'Blue'),
        ('E', '!3', 'Green'),
      ]) {
        polls.handleMessage(_vote(viewer, free ? '!r $answer' : option));
      }
      expect(polls.current!.toOverlayJson(), isNot(contains('leaderIndices')));
      polls.end();
      final poll = polls.current!;
      expect(poll.toOverlayJson()['leaderIndices'], [0, 1]);
      expect(
          RuleEvent.pollEnded(poll).winner, free ? 'Blue / Red' : 'Red / Blue');
    });
  }

  test('the hot path does not read chat text without an open poll', () async {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    final message = _MessageSpy();
    polls.handleMessage(message);
    expect(message.reads, 0);
    polls.start(question: 'Q', options: ['A', 'B']);
    polls.handleMessage(message);
    expect(message.reads, 1);
    polls.end();
    polls.handleMessage(message);
    polls.clear();
    polls.handleMessage(message);
    expect(message.reads, 1);
  });

  const scenarios = [
    (PollMode.numbered, '!1 more', '!2', '1', 'Blue'),
    (PollMode.word, ' !RE\u0301D   APPLE ', 'bluÉ', 'Blue please', 'Blue'),
    (PollMode.yesNo, ' SÍ ', ' !2 ', 'no thanks', 'No'),
    (PollMode.rating, ' 1 ', '!10', '10.0', '7.0'),
    (PollMode.freeAnswer, '!r Red apple', '!R Blue', '!reply Blue', 'Blue'),
  ];
  test('a tie between spellings shows the one written first', () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    polls.start(question: 'Q', mode: PollMode.freeAnswer);
    polls
      ..handleMessage(_vote('A', '!r Minecraft'))
      ..handleMessage(_vote('B', '!r minecraft'))
      ..handleMessage(_vote('C', '!r MINECRAFT'));
    final top = polls.current!.answers.top.single;
    expect(top.text, 'Minecraft');
    expect(top.votes, 3);
  });

  for (final (mode, first, second, invalid, winner) in scenarios) {
    test('$mode enforces roles and vote changes by platform and identity', () {
      final polls = ChatPollController();
      addTearDown(polls.dispose);
      for (final role in QueueRole.values) {
        for (final change in [true, false]) {
          polls.start(
              question: 'Pick',
              mode: mode,
              options: ['Red apple', 'Blue'],
              allowed: role,
              allowChange: change);
          if (role != QueueRole.everyone) {
            for (final other in QueueRole.values.where((r) => r != role)) {
              polls.handleMessage(
                  _vote('unqualified-${other.name}', first, role: other));
            }
          }
          polls
            ..handleMessage(
                _vote('Name', first, channelId: '  Account ', role: role))
            ..handleMessage(
                _vote('New name', second, channelId: 'account', role: role))
            ..handleMessage(_vote('Kick', first,
                channelId: 'Account', role: role, platform: Platform.kick))
            ..handleMessage(_vote('Owner', second, owner: true, channelId: ''))
            ..handleMessage(
                _vote(' owner ', second, owner: true, channelId: ''))
            ..handleMessage(_vote('Invalid', invalid, owner: true));
          final poll = polls.current!;
          expect(poll.total, 3);
          if (mode == PollMode.freeAnswer) {
            expect(poll.answers.top.first.votes, 2);
            expect(poll.answers.top.first.text, change ? 'Blue' : 'Red apple');
          } else {
            final bucket = mode == PollMode.rating ? 9 : 1;
            expect(poll.counts[0], change ? 1 : 2);
            expect(poll.counts[bucket], change ? 2 : 1);
          }
        }
      }
    });

    test('poll.ended resolves winner and total in simulate for $mode', () {
      final polls = ChatPollController();
      final target = Target();
      final engine = RuleEngine(target: target);
      addTearDown(polls.dispose);
      addTearDown(engine.dispose);
      final definition = rule(type: 'poll.ended', actions: [
        {
          'id': 'a',
          'type': 'template.trigger',
          'name': 'result',
          'data': '{winner} / {total}'
        },
      ]);
      engine.updateSettings(enabled: true, rules: [definition]);
      polls.start(question: 'Pick', mode: mode, options: ['Red apple', 'Blue']);
      polls
        ..handleMessage(_vote('A', first))
        ..handleMessage(_vote('B', second))
        ..handleMessage(_vote('C', second))
        ..end();
      final simulated =
          engine.simulate(definition, RuleEvent.pollEnded(polls.current!));
      expect(simulated.matched, isTrue);
      expect(simulated.actions.single['data'], '$winner / 3');
      expect(target.calls, isEmpty);
      expect(
          engine
              .simulate(definition, engine.sampleEvent('poll.ended'))
              .actions
              .single['data'],
          'Adventure / 12');
    });
  }

  test('word options reject ambiguity, empty normalization and >40 characters',
      () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    for (final options in [
      ['Café  frío', '!CAFE frio'],
      ['\u0301', 'Blue'],
      ['a' * 41, 'Blue'],
    ]) {
      expect(
        () => polls.start(question: 'Q', options: options, mode: PollMode.word),
        throwsArgumentError,
      );
      expect(polls.current, isNull);
    }
    polls.start(
        question: 'Q',
        options: ['Lộ Ạnh!', 'Łódź?', 'a' * 40],
        mode: PollMode.word);
    polls
      ..handleMessage(_vote('A', 'lo anh!'))
      ..handleMessage(_vote('B', 'Lo Anh'))
      ..handleMessage(_vote('C', 'ŁODZ?'));
    expect(polls.current!.counts, [1, 1, 0]);
    polls.start(question: 'Q', options: ['!Red', 'Blue'], mode: PollMode.word);
    polls
      ..handleMessage(_vote('A', '!red'))
      ..handleMessage(_vote('B', '!!RED'))
      ..handleMessage(_vote('C', 'RED'));
    expect(polls.current!.counts, [2, 0]);
  });

  test('yes/no has localized fixed options and accepts exact aliases only', () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    polls.start(
        question: 'Q',
        mode: PollMode.yesNo,
        language: 'es',
        options: ['Ignored']);
    final yes = ['sí', 'si', ' YES ', 'y', '1', '!1'];
    final no = ['NO', 'n', ' 2 ', '!2'];
    final invalid = ['!yes', 'yeah', 'yes dinner', '1 please', 'non', '!3'];
    for (final (i, text) in [...yes, ...no, ...invalid].indexed) {
      polls.handleMessage(_vote('Viewer $i', text));
    }
    expect(polls.current!.options, ['Sí', 'No']);
    expect(polls.current!.counts, [6, 4]);
  });

  test('rating rounds the public average and includes all ten buckets', () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    polls.start(question: 'Q', mode: PollMode.rating);
    expect(polls.current!.toOverlayJson()['average'], isNull);
    for (final (i, text) in [
      '!10',
      '10',
      '1',
      '0',
      '11',
      '-1',
      '5.0',
      '5 words',
      '! 5'
    ].indexed) {
      polls.handleMessage(_vote('Viewer $i', text));
    }
    final poll = polls.current!;
    expect(poll.total, 3);
    expect(poll.average, 7);
    expect(
        poll.toOverlayJson()['distribution'], [1, 0, 0, 0, 0, 0, 0, 0, 0, 2]);
    polls.handleMessage(_vote('Viewer 0', '9'));
    expect(polls.current!.toOverlayJson()['average'], 6.7);
  });

  test('free answers group normalized spellings, rank ten and count all groups',
      () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    expect(
        () => polls.start(
            question: 'Q', mode: PollMode.freeAnswer, command: '!next'),
        throwsArgumentError);
    polls.start(question: 'Q', mode: PollMode.freeAnswer, command: ' !Reply ');
    for (final (i, text) in [
      '!REPLY  Café  frío',
      '!reply cafe frio',
      '!reply cafe frio',
      '!reply café frío!',
      '!reply',
      '!r invalid',
      '!replyish invalid',
      '!reply ${'🧑‍🍳' * 40}',
      '!reply ${'🧑‍🍳' * 41}',
      for (var i = 0; i < 10; i++) '!reply Answer $i',
    ].indexed) {
      polls.handleMessage(_vote('Viewer $i', text));
    }
    final poll = polls.current!;
    expect(poll.total, 15);
    final payload = poll.toOverlayJson();
    expect(payload['command'], '!reply');
    expect(payload['distinct'], 13);
    expect(payload['answers'], hasLength(10));
    expect(
        (payload['answers'] as List).first, {'text': 'cafe frio', 'votes': 3});
    expect(poll.freeVotes.values.map((answer) => answer.original),
        contains('🧑‍🍳' * 40));
    polls.handleMessage(_vote('Viewer 1', '!reply Different'));
    expect(polls.current!.total, 15);
    expect(polls.current!.answers.distinct, 14);
    expect(polls.current!.answers.top.first.votes, 2);
  });

  test('reads !1 to !9 as votes for existing options only', () {
    expect(ChatPollController.parseVote('!1', 3), 0);
    expect(ChatPollController.parseVote('  !3 por favor', 3), 2);
    expect(ChatPollController.parseVote('!4', 3), isNull);
    expect(ChatPollController.parseVote('!12', 3), isNull);
    expect(ChatPollController.parseVote('voto !1', 3), isNull);
    expect(ChatPollController.parseVote('hola', 3), isNull);
  });

  test('needs a question and two to five options', () {
    final polls = ChatPollController();
    addTearDown(polls.dispose);
    expect(() => polls.start(question: ' ', options: ['a', 'b']),
        throwsArgumentError);
    expect(() => polls.start(question: 'Q', options: ['a', ' ']),
        throwsArgumentError);
    polls.start(question: ' ¿Qué juego? ', options: ['Uno', ' ', 'Dos']);
    expect(polls.current!.question, '¿Qué juego?');
    expect(polls.current!.options, ['Uno', 'Dos']);
  });

  test('counts one vote per viewer and platform, keeping the last one',
      () async {
    final polls = ChatPollController(publishInterval: Duration.zero);
    addTearDown(polls.dispose);
    polls.start(question: '¿Qué juego?', options: ['Uno', 'Dos', 'Tres']);

    polls
      ..handleMessage(_vote('Ana', '!1'))
      ..handleMessage(_vote('Beto', '!2'))
      ..handleMessage(_vote('ana', '!3')) // Ana changes her mind.
      ..handleMessage(_vote('Ana', '!2', platform: Platform.kick))
      ..handleMessage(_vote('Carla', 'hola'));
    await _published();

    expect(polls.current!.counts, [0, 2, 1]);
    expect(polls.current!.total, 3);
    final overlay = polls.current!.toOverlayJson();
    expect((overlay['options'] as List).first, {
      'label': 'Uno',
      'votes': 0,
      'percent': 0,
    });
    expect(((overlay['options'] as List)[1] as Map)['percent'], 67);
  });

  test('a closed poll keeps its results and takes no more votes', () async {
    final polls = ChatPollController(publishInterval: Duration.zero);
    addTearDown(polls.dispose);
    final states = <ChatPoll?>[];
    polls.states.listen(states.add);
    polls.start(question: 'Q', options: ['a', 'b']);
    polls.handleMessage(_vote('Ana', '!1'));
    polls.end();
    polls.handleMessage(_vote('Beto', '!2'));
    await _published();

    expect(polls.current!.closed, isTrue);
    expect(polls.current!.counts, [1, 0]);
    expect(states.last!.closed, isTrue);

    polls.clear();
    await _published();
    expect(polls.current, isNull);
    expect(states.last, isNull);
  });

  test('a poll with a time limit closes on its own', () async {
    final polls = ChatPollController(publishInterval: Duration.zero);
    addTearDown(polls.dispose);
    polls.start(
      question: 'Q',
      options: ['a', 'b'],
      duration: const Duration(milliseconds: 30),
    );
    expect(polls.current!.endsAt, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(polls.current!.closed, isTrue);
  });

  test('a burst of votes is published a few times, not once per vote',
      () async {
    final polls = ChatPollController(
      publishInterval: const Duration(milliseconds: 40),
    );
    addTearDown(polls.dispose);
    var published = 0;
    polls.states.skip(1).listen((_) => published++);
    polls.start(question: 'Q', options: ['a', 'b']);
    await _published();
    published = 0;
    for (var i = 0; i < 50; i++) {
      polls.handleMessage(_vote('viewer$i', '!1'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(published, 1);
    expect(polls.current!.total, 50);
  });
}

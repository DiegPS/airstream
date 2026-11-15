import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _vote(String author, String text,
        {Platform platform = Platform.twitch}) =>
    ChatMessage(
      platform: platform,
      id: '$author-$text-${platform.name}',
      author: ChatAuthor(name: author, channelId: author.toLowerCase()),
      items: [MessageItem.text(text)],
      timestamp: DateTime.utc(2026, 11, 15),
    );

Future<void> _published() =>
    Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
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

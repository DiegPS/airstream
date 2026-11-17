import 'dart:math';

import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/models/chat_message.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 17, 12);

ChatMessage queueMessage(
  String name,
  String text, {
  String id = '',
  Platform platform = Platform.twitch,
  bool owner = false,
  bool moderator = false,
  bool vip = false,
  bool member = false,
}) =>
    ChatMessage(
      platform: platform,
      id: '',
      author: ChatAuthor(name: name, channelId: id),
      items: [MessageItem.text(text)],
      timestamp: _now,
      isOwner: owner,
      isModerator: moderator,
      isVip: vip,
      isMembership: member,
    );

class _MessageSpy extends ChatMessage {
  _MessageSpy(String text)
      : super(
          platform: Platform.kick,
          id: '',
          author: const ChatAuthor(name: 'Alex', channelId: ''),
          items: [const MessageItem.text(''), MessageItem.text(text)],
          timestamp: _now,
        );

  int reads = 0;
  @override
  String get plainText {
    reads++;
    return super.plainText;
  }
}

void main() {
  late ChatQueueController queue;
  List<String> waiting() => queue.current.entries.map((e) => e.name).toList();
  void open() => queue.setStatus(QueueStatus.open);

  setUp(() {
    queue = ChatQueueController(clock: () => _now, random: Random(23));
  });
  tearDown(() => queue.dispose());

  test('closed commands and ordinary chat do not build or parse plain text',
      () {
    final join = _MessageSpy('!join note');
    final plain = _MessageSpy('Hello !join');
    queue.handleMessage(join);
    expect(join.reads, 0);
    open();
    queue.handleMessage(plain);
    expect(plain.reads, 0);
    queue.handleMessage(join);
    expect(join.reads, 1);
    expect(waiting(), ['Alex']);
  });

  test('people still in a closed queue can leave it', () {
    open();
    queue.handleMessage(queueMessage('Alex', '!join'));
    queue.handleMessage(queueMessage('Morgan', '!join', id: 'm'));
    queue.setStatus(QueueStatus.closed);
    queue.handleMessage(queueMessage('Alex', '!salir'));
    queue.handleMessage(queueMessage('Sam', '!join', id: 's'));
    expect(waiting(), ['Morgan']);
  });

  test(
      'deduplicates per platform, updates only the note and accepts both leaves',
      () {
    open();
    queue.handleMessage(queueMessage('Alex', '!JOIN    first  '));
    queue.handleMessage(queueMessage('Morgan', '!join', id: 'm'));
    final first = queue.current.entries.first;
    queue.handleMessage(queueMessage('aLeX', '!join newer'));
    queue.handleMessage(queueMessage('Renamed', '!join other', id: 'm'));
    queue.handleMessage(queueMessage('Alex', '!join', platform: Platform.kick));
    expect(waiting(), ['Alex', 'Morgan', 'Alex']);
    expect(queue.current.entries.map((e) => e.note), ['newer', 'other', '']);
    expect(queue.current.entries.first.id, first.id);
    expect(queue.current.entries.first.joinedAt, _now);
    queue.handleMessage(queueMessage('ALEX', '!leave'));
    queue
        .handleMessage(queueMessage('Alex', '!SALIR', platform: Platform.kick));
    expect(waiting(), ['Morgan']);
  });

  test('matches the full first word and sanitizes and bounds the note', () {
    expect(QueueOptions.validCommand('!ÚNETE_23'), isTrue);
    expect(QueueOptions.reservedCommand('!SALIR'), isTrue);
    expect(QueueOptions.reservedCommand('!next'), isTrue);
    expect(const QueueOptions(command: '!leave').commandFor('en'), '!join');
    for (final invalid in ['join', '!join?', '!join here', '!${'x' * 25}']) {
      expect(QueueOptions.validCommand(invalid), isFalse);
    }
    queue.configure(const QueueOptions(command: '!Únete'), 'es');
    open();
    queue.handleMessage(queueMessage('Alex', '!Úneter no'));
    expect(waiting(), isEmpty);
    queue.handleMessage(
        queueMessage('Alex', '!únete   🎮\u0000x\u0080${'y' * 40}  '));
    expect(queue.current.entries.single.note, '🎮x${'y' * 28}');
  });

  test('only configured roles and the owner can join', () {
    open();
    for (final role in QueueRole.values.where((r) => r != QueueRole.everyone)) {
      queue.clear();
      queue.configure(QueueOptions(role: role), 'en');
      queue.handleMessage(queueMessage('Regular', '!join'));
      queue.handleMessage(queueMessage('Owner', '!join', owner: true));
      queue.handleMessage(queueMessage('Eligible', '!join',
          member: role == QueueRole.member,
          vip: role == QueueRole.vip,
          moderator: role == QueueRole.moderator));
      expect(waiting(), ['Owner', 'Eligible'], reason: role.name);
    }
  });

  test('capacity, status and priority preserve arrival order in each group',
      () {
    queue.configure(const QueueOptions(max: 5, priority: true), 'es');
    queue.handleMessage(queueMessage('Closed', '!unirme'));
    queue.setStatus(QueueStatus.paused);
    queue.handleMessage(queueMessage('Paused', '!unirme'));
    open();
    for (var i = 0; i < 6; i++) {
      queue
          .handleMessage(queueMessage('Viewer $i', '!unirme', member: i.isOdd));
    }
    expect(waiting(),
        ['Viewer 1', 'Viewer 3', 'Viewer 0', 'Viewer 2', 'Viewer 4']);
    queue.setStatus(QueueStatus.paused);
    queue.handleMessage(queueMessage('Viewer 1', '!salir'));
    expect(waiting().first, 'Viewer 3');
  });

  test('FIFO and seeded random take distinct players and cap playing at ten',
      () {
    open();
    for (var i = 0; i < 15; i++) {
      queue.handleMessage(queueMessage('$i', '!join'));
    }
    expect(
        queue.next(8).map((e) => e.name), [for (var i = 0; i < 8; i++) '$i']);
    final pool = [for (var i = 8; i < 15; i++) '$i'];
    final expectedRandom = Random(23);
    final expected = List.generate(
        4, (_) => pool.removeAt(expectedRandom.nextInt(pool.length)));
    final drawn = queue.next(4, random: true);
    expect(drawn.map((e) => e.name), expected);
    expect(queue.current.playing.map((e) => e.name),
        ['2', '3', '4', '5', '6', '7', ...expected]);
    expect(waiting(), pool);
    queue.done(drawn.first.id);
    expect(queue.current.playing, hasLength(9));
    queue.remove(queue.current.entries.first.id);
    expect(waiting(), pool.skip(1));
    queue.clear();
    expect(waiting(), isEmpty);
    expect(queue.current.playing, isEmpty);
  });

  test('playing cannot rejoin; completed players follow the rejoin setting',
      () {
    open();
    final alex = queueMessage('Alex', '!join');
    queue.handleMessage(alex);
    final first = queue.next(1).single;
    queue.handleMessage(alex);
    expect(waiting(), isEmpty);
    queue.done(first.id);
    queue.handleMessage(alex);
    final second = queue.next(1).single;
    expect(second.id, isNot(first.id));
    queue.done(second.id);
    queue.configure(const QueueOptions(rejoin: false), 'en');
    queue.handleMessage(alex);
    expect(waiting(), isEmpty);
    queue.clear();
    queue.handleMessage(alex);
    expect(waiting(), ['Alex']);
  });

  test('moderation is opt-in and restricted to the owner or a moderator', () {
    void owner(String text) =>
        queue.handleMessage(queueMessage('Owner', text, owner: true));
    void mod(String text) =>
        queue.handleMessage(queueMessage('Mod', text, moderator: true));
    void guest(String text) => queue
        .handleMessage(queueMessage('Guest', text, member: true, vip: true));
    owner('!abrir');
    expect(queue.status, QueueStatus.closed);
    queue.configure(
        const QueueOptions(moderatorCommands: true, nextCount: 2), 'en');
    guest('!open');
    expect(queue.status, QueueStatus.closed);
    mod('!open');
    for (final p in Platform.values) {
      queue.handleMessage(queueMessage('Guest Name', '!join', platform: p));
    }
    guest('!next 1');
    guest('!remove Guest Name');
    guest('!close');
    expect(queue.status, QueueStatus.open);
    expect(waiting(), hasLength(3));
    owner('!quitar GuEsT nAmE');
    expect(queue.current.entries.first.platform, Platform.twitch);
    mod('!pausar');
    expect(queue.status, QueueStatus.paused);
    mod('!next 100');
    expect(queue.current.playing, isEmpty);
    mod('!siguiente');
    expect(queue.current.playing, hasLength(2));
    owner('!close');
    expect(queue.status, QueueStatus.closed);
  });

  test('publishes and persists at most one snapshot every 250 ms', () {
    fakeAsync((async) {
      final joined = <int>[];
      final persisted = <QueueState>[];
      final queue = ChatQueueController(
        clock: () => _now,
        onJoined: (_, position) => joined.add(position),
        onPersist: persisted.add,
      );
      final states = <QueueState>[];
      queue.states.listen(states.add);
      queue.setStatus(QueueStatus.open);
      queue.handleMessage(queueMessage('Alex', '!join'));
      queue.handleMessage(queueMessage('Sam', '!join'));
      queue.handleMessage(queueMessage('Alex', '!join edited'));
      expect(joined, [1, 2]);
      async.elapse(const Duration(milliseconds: 249));
      expect(states, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
      expect(states.single.entries.first.note, 'edited');
      expect(persisted, states);
      queue.next(1);
      queue.setStatus(QueueStatus.paused);
      async.elapse(const Duration(milliseconds: 250));
      expect(states, hasLength(2));
      expect(states.last.status, QueueStatus.paused);
      expect(states.last.playing.single.name, 'Alex');
      queue.clear();
      queue.dispose();
      async.flushMicrotasks();
      expect(states, hasLength(2));
      expect(persisted.last.playing, isEmpty);
    });
  });
}

import 'dart:convert';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(String name, String text,
        {Platform platform = Platform.twitch,
        String? id,
        bool member = false,
        bool event = false,
        bool moderator = false,
        bool owner = false,
        SuperChat? support}) =>
    ChatMessage(
        platform: platform,
        id: '$name-$text',
        author: ChatAuthor(name: name, channelId: id ?? name),
        items: [MessageItem.text(text)],
        timestamp: DateTime.utc(2026),
        isMembership: member,
        isMembershipEvent: event,
        isModerator: moderator,
        isOwner: owner,
        superChat: support);
void main() {
  late ChatGiveawayController c;
  setUp(() {
    c = ChatGiveawayController();
  });
  tearDown(() => c.dispose());
  test('normalizes case accents punctuation and keyword plus text', () {
    c.start(keyword: ' !CAFÉ! ', membersOnly: false);
    expect(c.current!.keyword, '!CAFÉ!');
    for (final (i, text) in [
      'café',
      'CAFE!!!',
      '!cafe por favor',
      'cafe-text',
      'cafeteria',
      'quiero cafe',
      'no'
    ].indexed) {
      c.handleMessage(message('$i', text));
    }
    expect(c.current!.entrantCount, 4);
    expect(
        () => c.start(keyword: '!!!', membersOnly: false), throwsArgumentError);
  });
  test(
      'deduplicates platform and exact author id with lower case name fallback',
      () {
    c.start(keyword: 'go', membersOnly: false);
    c.handleMessage(message('Ana', 'go', id: 'ID'));
    c.handleMessage(message('Renamed', 'go', id: 'ID'));
    c.handleMessage(message('Ana', 'go', id: 'ID', platform: Platform.kick));
    c.handleMessage(message('Fallback', 'go', id: ''));
    c.handleMessage(message('FALLBACK', 'go', id: ''));
    expect(c.current!.entrantCount, 3);
    expect(() => c.current!.entrants.clear(), throwsUnsupportedError);
  });
  test('members only excludes owners moderators nonmembers and support events',
      () {
    c.start(keyword: 'go', membersOnly: true);
    c.handleMessage(message('owner', 'go', owner: true));
    c.handleMessage(message('mod', 'go', moderator: true));
    c.handleMessage(message('viewer', 'go'));
    c.handleMessage(message('event', 'go', member: true, event: true));
    c.handleMessage(message('support', 'go',
        member: true, support: const SuperChat(amount: '5', color: '#fff')));
    c.handleMessage(message('member', 'go', member: true));
    expect(c.current!.entrants.single.name, 'member');
  });
  test('close rejects entries and start replaces previous giveaway', () {
    c.start(keyword: 'go', membersOnly: false);
    c.handleMessage(message('Ana', 'go'));
    c.close();
    c.handleMessage(message('Beto', 'go'));
    expect(c.current!.phase, GiveawayPhase.closed);
    expect(c.current!.entrantCount, 1);
    c.start(keyword: 'new', membersOnly: true);
    expect(c.current!.entrantCount, 0);
    expect(c.current!.winners, isEmpty);
  });
  test(
      'draw chooses entrants without repeating winners and empty draw changes nothing',
      () {
    c.start(keyword: 'go', membersOnly: false);
    final empty = c.current;
    expect(c.draw(), isNull);
    expect(c.current, same(empty));
    for (var i = 0; i < 20; i++) {
      c.handleMessage(message('$i', 'go'));
    }
    final entrants = c.current!.entrants;
    final winners = <String>{};
    var lastId = 0;
    for (var i = 0; i < 20; i++) {
      final winner = c.draw()!;
      expect(entrants, contains(winner));
      expect(winners.add(winner.identity), isTrue);
      expect(c.current!.drawId, greaterThan(lastId));
      lastId = c.current!.drawId;
      expect(c.current!.phase, GiveawayPhase.drawn);
    }
    final exhausted = c.current;
    expect(c.draw(), isNull);
    expect(c.current, same(exhausted));
    c.handleMessage(message('late', 'go'));
    expect(c.current, same(exhausted));
    expect(c.current!.winners.last.identity, winners.last);
    c.clear();
    expect(c.current, isNull);
    c.start(keyword: 'go', membersOnly: false);
    c.handleMessage(message('Ana', 'go'));
    c.draw();
    expect(c.current!.drawId, greaterThan(lastId));
  });

  test('a batch publishes each distinct winner and persists one round',
      () async {
    final states = <ChatGiveaway?>[];
    final subscription = c.states.listen(states.add);
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    c.start(keyword: 'enter', membersOnly: false);
    for (var i = 0; i < 6; i++) {
      c.handleMessage(
          message('viewer $i', 'enter', platform: Platform.values[i % 3]));
    }
    final first = c.draw()!;
    final ids = <int>[];
    final batch = c.drawMany(10, onDraw: (_, id) => ids.add(id));
    expect(batch.map((winner) => winner.identity).toSet(), hasLength(5));
    expect(batch, isNot(contains(first)));
    expect(ids, [2, 3, 4, 5, 6]);
    await Future<void>.delayed(Duration.zero);
    expect(
        states
            .where((state) => state?.batchDraw == true)
            .map((state) => state!.drawId),
        ids);
    final round = c.history.single;
    expect(round.entrantCount, 6);
    expect(round.endedAt.isBefore(round.startedAt), false);
    expect(round.winners, [first, ...batch]);
    final disk =
        SettingsDocumentCodec.encode(SettingsModel(giveawayHistory: c.history));
    final restored =
        SettingsDocumentCodec.decode(disk).settings.giveawayHistory;
    expect(restored.single.toJson(), round.toJson());
    expect(disk, isNot(contains('authorId')));
  });

  test('retains the latest 20 rounds across restart and clears them', () {
    for (var i = 0; i < 25; i++) {
      c.start(keyword: 'round $i', membersOnly: false);
      c.close();
    }
    final saved = SettingsModel(giveawayHistory: c.history).toJson();
    final restored = SettingsModel.fromJson(saved).giveawayHistory;
    expect(restored.map((round) => round.keyword),
        [for (var i = 24; i >= 5; i--) 'round $i']);
    c.restoreHistory(restored);
    c.clearHistory();
    c.clear();
    expect(c.history, isEmpty);
  });

  test('caps entries at 50000 and preserves earlier immutable snapshots', () {
    c.start(keyword: 'go', membersOnly: false);
    c.handleMessage(message('first', 'go'));
    final snapshot = c.current!;
    for (var i = 1; i <= 50000; i++) {
      c.handleMessage(message('$i', 'go'));
    }
    expect(c.current!.entrantCount, 50000);
    expect(snapshot.entrantCount, 1);
    expect(c.current!.entrants.last.name, '49999');
  });
  test('overlay JSON exposes only summary and current winner', () {
    c.start(keyword: 'go', membersOnly: false);
    c.handleMessage(message('secret', 'go', id: 'private-id'));
    c.draw();
    expect(c.current!.toOverlayJson(), {
      'keyword': 'go',
      'phase': 'drawn',
      'entrantCount': 1,
      'winner': {'name': 'secret', 'platform': 'twitch'},
      'drawId': 1
    });
    expect(
        jsonEncode(c.current!.toOverlayJson()), isNot(contains('private-id')));
    expect(c.current!.toOverlayJson().containsKey('entrants'), isFalse);
  });
  test('publishes entries at most every 250ms and controls immediately',
      () async {
    final states = <ChatGiveaway?>[];
    final sub = c.states.listen(states.add);
    await Future<void>.delayed(Duration.zero);
    c.start(keyword: 'go', membersOnly: false);
    await Future<void>.delayed(Duration.zero);
    final before = states.length;
    for (var i = 0; i < 100; i++) {
      c.handleMessage(message('$i', 'go'));
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(states.length, before);
    await Future<void>.delayed(const Duration(milliseconds: 170));
    expect(states.length, before + 1);
    expect(states.last!.entrantCount, 100);
    c.handleMessage(message('extra', 'go'));
    c.close();
    await Future<void>.delayed(Duration.zero);
    expect(states.last!.phase, GiveawayPhase.closed);
    c.draw();
    await Future<void>.delayed(Duration.zero);
    expect(states.last!.phase, GiveawayPhase.drawn);
    c.clear();
    await Future<void>.delayed(Duration.zero);
    expect(states.last, isNull);
    final length = states.length;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(states.length, length);
    await sub.cancel();
  });
}

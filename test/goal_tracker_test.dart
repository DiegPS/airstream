import 'package:airstream/application/goal_tracker.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/settings/goals.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(Platform platform,
        {String id = 'm',
        MembershipEventKind? kind,
        int? gifts,
        bool member = false,
        String? amount}) =>
    ChatMessage(
        platform: platform,
        id: id,
        author: const ChatAuthor(name: 'A', channelId: 'a'),
        items: const [MessageItem.text('Hello')],
        timestamp: DateTime.utc(2026),
        membershipEventKind: kind,
        membershipGiftCount: gifts,
        isMembershipEvent: member,
        superChat: amount == null
            ? null
            : SuperChat(amount: amount, color: '#ffffff'));
ChatProviderEvent event(
        {String id = 'e',
        int? count,
        Platform platform = Platform.kick,
        ChatProviderEventKind kind = ChatProviderEventKind.support}) =>
    ChatProviderEvent(
        platform: platform,
        kind: kind,
        id: id,
        count: count,
        timestamp: DateTime.utc(2026));
void main() {
  for (final platform in Platform.values) {
    for (final kind in MembershipEventKind.values) {
      test('${platform.name} ${kind.name} counts support', () {
        final tracker = GoalTracker();
        expect(tracker.message(message(platform, kind: kind, gifts: 5)),
            {'subs': kind == MembershipEventKind.gift ? 5 : 1});
        expect(
            tracker.message(message(platform, kind: kind, gifts: 5)), isEmpty);
      });
    }
    test(
        '${platform.name} gift defaults to one',
        () => expect(
            GoalTracker()
                .message(message(platform, kind: MembershipEventKind.gift)),
            {'subs': 1}));
  }
  test(
      'YouTube new member counts one',
      () => expect(
          GoalTracker().message(message(Platform.youtube, member: true)),
          {'subs': 1}));
  test('Twitch Bits use the exact integer amount', () {
    expect(GoalTracker().message(message(Platform.twitch, amount: '123 Bits')),
        {'bits': 123});
    for (final amount in ['USD 12', '12.5 Bits', '-5 Bits']) {
      expect(GoalTracker().message(message(Platform.twitch, amount: amount)),
          isEmpty);
    }
    expect(GoalTracker().message(message(Platform.youtube, amount: '12 Bits')),
        isEmpty);
  });
  test('Kick support uses count, ignores repeats and null counts', () {
    final t = GoalTracker();
    expect(t.event(event(count: 200)), {'kicks': 200});
    expect(t.event(event(count: 200)), isEmpty);
    expect(t.event(event(id: 'null')), {'kicks': 0});
    expect(
        t.event(
            event(id: 'other', kind: ChatProviderEventKind.raid, count: 10)),
        isEmpty);
    expect(t.event(event(platform: Platform.twitch, count: 10)), isEmpty);
  });
  test('ordinary chat and manual goals never advance', () {
    expect(GoalTracker().message(message(Platform.twitch)), isEmpty);
    final goals = {
      'm': {'title': 'Manual', 'type': 'manual', 'target': 10, 'current': 0}
    };
    expect(
        Goals.advance(goals, {'subs': 10, 'bits': 100, 'kicks': 100}), goals);
  });
  test('only the last 2000 ids are retained across messages and events', () {
    final t = GoalTracker();
    final m = message(Platform.twitch, kind: MembershipEventKind.subscription);
    expect(t.message(m), {'subs': 1});
    for (var i = 0; i < 1999; i++) {
      t.event(event(id: '$i'));
    }
    expect(t.message(m), isEmpty);
    t.event(event(id: 'last'));
    expect(t.message(m), {'subs': 1});
  });
  test('goals sanitize bounds, titles, invalid entries and maximum count', () {
    final valid = {
      'title': '  Title  ',
      'type': 'manual',
      'target': 10,
      'current': 0
    };
    final loaded = SettingsModel.fromJson({
      'goals': {
        'badType': {...valid, 'type': 'other'},
        'zero': {...valid, 'target': 0},
        'negative': {...valid, 'current': -1},
        'high': {...valid, 'current': 10000001},
        'long': {...valid, 'title': 'x' * 70},
        'two': valid,
        'three': valid,
        'four': valid,
      }
    });
    expect(loaded.goals.keys, ['long', 'two', 'three']);
    expect((loaded.goals['long']!['title'] as String).length, 60);
    expect(loaded.goals['two']!['title'], 'Title');
    expect(SettingsModel.fromJsonString(loaded.toJsonString()).goals,
        loaded.goals);
    expect(
        Goals.advance({
          'g': {...valid, 'current': 9999999}
        }, {
          'manual': 10
        })['g']!['current'],
        10000000);
    expect(Goals.advance({'g': valid}, {'manual': -10})['g']!['current'], 0);
    expect(SettingsProfiles.capture(loaded), isNot(contains('goals')));
    expect(SettingsProfiles.apply(loaded, {'goals': {}, 'fontSize': 20}).goals,
        loaded.goals);
    expect(SettingsProfiles.resetToDefaults(loaded).goals, loaded.goals);
  });
}

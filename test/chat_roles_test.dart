import 'package:airstream/services/twitch_service.dart';
import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Twitch IRC parser accepts subscription and resubscription notices', () {
    final subscription = TwitchIrcParser.parse(
      r'@badges=subscriber/1;color=#00FF00;display-name=Ana;id=sub-1;login=ana;msg-id=sub;subscriber=1 :tmi.twitch.tv USERNOTICE #channel',
    );
    final resubscription = TwitchIrcParser.parse(
      r'@badges=vip/1,subscriber/12;display-name=Bob;id=resub-1;login=bob;msg-id=resub;msg-param-cumulative-months=12;system-msg=Bob\ssubscribed :tmi.twitch.tv USERNOTICE #channel :¡Un año!',
    );

    expect(subscription?.type, TwitchIrcEventType.membership);
    expect(subscription?.username, 'ana');
    expect(resubscription?.type, TwitchIrcEventType.membership);
    expect(resubscription?.text, '¡Un año!');
    expect(resubscription?.tags['system-msg'], 'Bob subscribed');
    expect(resubscription?.tags['msg-param-cumulative-months'], '12');
  });

  test('Twitch roles preserve broadcaster, moderator, VIP and subscriber', () {
    final owner = TwitchUserRoles.fromTags(const {
      'badges': 'broadcaster/1,subscriber/24,bits/1000',
      'subscriber': '1',
      'mod': '0',
    });
    final staff = TwitchUserRoles.fromTags(const {
      'badges': 'moderator/1,vip/1,founder/0',
      'subscriber': '0',
      'mod': '1',
    });

    expect(owner.isOwner, isTrue);
    expect(owner.isSubscriber, isTrue);
    expect(owner.badges['bits'], '1000');
    expect(staff.isModerator, isTrue);
    expect(staff.isVip, isTrue);
    expect(staff.isSubscriber, isTrue);
  });

  test('Twitch emotes honor exact Unicode ranges and mix native with 7TV', () {
    final service = TwitchService();
    addTearDown(service.dispose);

    final items = service.parseMessageForTesting(
      text: '😀 Kappa! OMEGALUL',
      nativeEmotesTag: '25:2-6',
      thirdPartyUrls: const {
        'OMEGALUL': 'https://cdn.example/omegalul.webp',
      },
    );

    expect(
      items.map((item) => item.isEmoji ? item.emoji!.alt : item.text).join(),
      '😀 Kappa! OMEGALUL',
    );
    expect(items.where((item) => item.isEmoji).map((item) => item.emoji!.alt), [
      'Kappa',
      'OMEGALUL',
    ]);
    expect(
      items.where((item) => !item.isEmoji).map((item) => item.text).join(),
      '😀 ! ',
    );
  });

  test('Kick library derives roles across legacy and modern badges', () {
    const identity = kick.Identity(
      color: '#fff',
      badges: [
        kick.Badge(type: 'subscriber', text: 'Subscriber', count: 8),
        kick.Badge(type: 'moderator', text: 'Moderator', count: 1),
      ],
      badgesV2: [
        kick.BadgeV2(
          name: 'vip',
          badgeType: 'channel',
          imageUrl: 'https://cdn/vip.png',
          selected: true,
          sortOrder: 1,
          metadata: {},
        ),
        kick.BadgeV2(
          name: 'broadcaster',
          badgeType: 'channel',
          imageUrl: '',
          selected: true,
          sortOrder: 2,
          metadata: {},
        ),
      ],
    );

    expect(identity.isSubscriber, isTrue);
    expect(identity.isModerator, isTrue);
    expect(identity.isVip, isTrue);
    expect(identity.isBroadcaster, isTrue);
  });
}

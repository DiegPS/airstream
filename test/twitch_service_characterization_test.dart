import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:dart_twitch_chat/dart_twitch_chat.dart' show TwitchSocket;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('TwitchIrcParser', () {
    test('parses PRIVMSG framing and unescapes IRC tags', () {
      final event = TwitchIrcParser.parse(
        r'@badges=vip/1;display-name=Ana\sMaría;system-msg=hola\smundo\:x\\y\nfin :ana!ana@ana.tmi.twitch.tv PRIVMSG #canal :Hola chat',
      );

      expect(event, isNotNull);
      expect(event!.type, TwitchIrcEventType.message);
      expect(event.username, 'ana');
      expect(event.text, 'Hola chat');
      expect(event.tags['display-name'], 'Ana María');
      expect(event.tags['system-msg'], 'hola mundo;x\\y\nfin');
    });

    test('recognizes every membership notice currently supported', () {
      for (final notice in const ['sub', 'resub', 'subgift', 'anonsubgift']) {
        final event = TwitchIrcParser.parse(
          '@msg-id=$notice;login=member :tmi.twitch.tv USERNOTICE #canal :mensaje',
        );

        expect(event?.type, TwitchIrcEventType.membership, reason: notice);
        expect(event?.username, 'member', reason: notice);
      }
    });

    test('ignores unsupported commands, notices and malformed frames', () {
      expect(TwitchIrcParser.parse(''), isNull);
      expect(TwitchIrcParser.parse('@tags-without-command'), isNull);
      expect(TwitchIrcParser.parse(':server NOTICE #canal :notice'), isNull);
      expect(
        TwitchIrcParser.parse(
          '@msg-id=raid :tmi.twitch.tv USERNOTICE #canal :raid',
        ),
        isNull,
      );
    });
  });

  group('TwitchUserRoles', () {
    test('derives roles and preserves every badge version', () {
      final roles = TwitchUserRoles.fromTags(const {
        'badges':
            'broadcaster/1,moderator/1,vip/1,subscriber/24,founder/0,bits/1000',
        'mod': '1',
        'subscriber': '1',
      });

      expect(roles.isOwner, isTrue);
      expect(roles.isModerator, isTrue);
      expect(roles.isVip, isTrue);
      expect(roles.isSubscriber, isTrue);
      expect(roles.badges['subscriber'], '24');
      expect(roles.badges['bits'], '1000');
    });

    test('marks membership notices as subscriber without badge tags', () {
      final roles = TwitchUserRoles.fromTags(
        const {},
        membershipEvent: true,
      );

      expect(roles.isSubscriber, isTrue);
    });
  });

  group('TwitchService', () {
    late _FakeTwitchSocket socket;
    late TwitchService service;

    setUp(() {
      socket = _FakeTwitchSocket();
      service = TwitchService(
        socketFactory: (_) => socket,
        httpClient: _emptyEmoteClient(),
        reconnectDelay: const Duration(milliseconds: 1),
      );
    });

    tearDown(() => service.dispose());

    test('connects anonymously, requests tags and joins normalized channel',
        () async {
      await service.connect('#MyChannel');

      expect(socket.sent[0], 'CAP REQ :twitch.tv/tags twitch.tv/commands\r\n');
      expect(socket.sent[1], 'PASS oauth:anonymous\r\n');
      expect(socket.sent[2], matches(RegExp(r'^NICK justinfan\d+\r\n$')));
      expect(socket.sent[3], 'JOIN #mychannel\r\n');
    });

    test('answers server PING with PONG', () async {
      await service.connect('channel');
      socket.receive('PING :tmi.twitch.tv\r\n');

      await _eventually(
        () => socket.sent.contains('PONG :tmi.twitch.tv\r\n'),
      );
    });

    test('maps IRC message identity, roles, badges and native emotes',
        () async {
      await service.connect('channel');
      final messageFuture = service.messages.first;

      socket.receive(
        '@badges=broadcaster/1,subscriber/24,bits/1000;color=#00FF00;'
        'display-name=Streamer;emotes=25:2-6;id=message-1;mod=1;subscriber=1 '
        ':streamer!streamer@streamer.tmi.twitch.tv PRIVMSG #channel '
        ':😀 Kappa hello\r\n',
      );

      final message = await messageFuture.timeout(const Duration(seconds: 1));
      expect(message.platform, Platform.twitch);
      expect(message.id, 'message-1');
      expect(message.author.name, 'Streamer');
      expect(message.author.channelId, 'streamer');
      expect(message.author.color, '#00FF00');
      expect(message.author.avatarUrl, isNull);
      expect(message.author.badges.map((badge) => badge.kind),
          ['broadcaster', 'subscriber', 'bits']);
      expect(message.author.badges.last.label, 'Bits 1000');
      expect(message.isOwner, isTrue);
      expect(message.isModerator, isTrue);
      expect(message.isMembership, isTrue);
      expect(message.plainText, '😀 Kappa hello');
      expect(message.items.where((item) => item.isEmoji).single.emoji!.alt,
          'Kappa');
    });

    test('maps rich identity, server time, Bits and Twitch GIFs', () async {
      await service.connect('channel');
      final messageFuture = service.messages.first;

      socket.receive(
        '@badges=;bits=250;color=#9146FF;display-name=RichUser;emotes=;'
        'first-msg=1;gifs=0-4|gif-id|https://cdn.example/hello.gif;'
        'id=rich-1;returning-chatter=1;room-id=room-1;'
        'tmi-sent-ts=1760000000123;user-id=user-42 '
        ':richuser!richuser@richuser.tmi.twitch.tv PRIVMSG #channel :Hello\r\n',
      );

      final message = await messageFuture.timeout(const Duration(seconds: 1));
      expect(message.author.channelId, 'user-42');
      expect(message.timestamp,
          DateTime.fromMillisecondsSinceEpoch(1760000000123, isUtc: true));
      expect(message.superChat?.amount, '250 Bits');
      expect(message.superChat?.color, '#9146FF');
      expect(message.items.single.emoji?.url, 'https://cdn.example/hello.gif');
      expect(message.items.single.emoji?.alt, 'Hello');
      expect(message.items.single.emoji?.isAnimated, isTrue);
    });

    test('maps Twitch deletions, user bans and room clears to moderation',
        () async {
      await service.connect('channel');
      final events = <ChatModerationEvent>[];
      final subscription = service.moderationEvents.listen(events.add);
      addTearDown(subscription.cancel);

      socket.receive(
        '@login=author;room-id=room;target-msg-id=message-1;'
        'tmi-sent-ts=1760000000123 '
        ':tmi.twitch.tv CLEARMSG #channel :deleted\r\n'
        '@ban-duration=600;room-id=room;target-user-id=user-42;'
        'tmi-sent-ts=1760000001123 '
        ':tmi.twitch.tv CLEARCHAT #channel :author\r\n'
        '@room-id=room;tmi-sent-ts=1760000002123 '
        ':tmi.twitch.tv CLEARCHAT #channel\r\n',
      );

      await _eventually(() => events.length == 3);
      expect(events[0].scope, ChatModerationScope.message);
      expect(events[0].messageId, 'message-1');
      expect(events[1].scope, ChatModerationScope.author);
      expect(events[1].authorChannelId, 'user-42');
      expect(events[2].scope, ChatModerationScope.platform);
      expect(
          events.every((event) => event.platform == Platform.twitch), isTrue);
    });

    test('maps resubscription kind and cumulative months', () async {
      await service.connect('channel');
      final messageFuture = service.messages.first;

      socket.receive(
        '@badges=subscriber/12;display-name=Member;id=resub-1;login=member;'
        'msg-id=resub;msg-param-cumulative-months=12;subscriber=1 '
        ':tmi.twitch.tv USERNOTICE #channel :Un año\r\n',
      );

      final message = await messageFuture.timeout(const Duration(seconds: 1));
      expect(message.isMembershipEvent, isTrue);
      expect(message.membershipEventKind, MembershipEventKind.resubscription);
      expect(message.membershipMonths, 12);
      expect(message.plainText, 'Un año');
    });

    test('keeps Unicode offsets exact and only replaces full emote tokens', () {
      final items = service.parseMessageForTesting(
        text: '😀 Kappa! OMEGALUL OMEGALULx',
        nativeEmotesTag: '25:2-6',
        thirdPartyUrls: const {
          'OMEGALUL': 'https://cdn.example/omegalul.webp',
        },
      );

      expect(
        items.map((item) => item.isEmoji ? item.emoji!.alt : item.text).join(),
        '😀 Kappa! OMEGALUL OMEGALULx',
      );
      expect(
        items.where((item) => item.isEmoji).map((item) => item.emoji!.alt),
        ['Kappa', 'OMEGALUL'],
      );
    });

    test('disconnect closes the socket and leaves the service idle', () async {
      final statuses = <Object>[];
      final subscription = service.statusStream.listen(statuses.add);
      addTearDown(subscription.cancel);
      await service.connect('channel');

      await service.disconnect();

      expect(socket.closed, isTrue);
      expect(statuses, isNotEmpty);
    });
  });
}

MockClient _emptyEmoteClient() => MockClient((request) async {
      if (request.url.host == 'api.frankerfacez.com') {
        return http.Response('{"sets":{}}', 200);
      }
      if (request.url.host == '7tv.io') {
        return http.Response('{"emotes":[]}', 200);
      }
      return http.Response('[]', 200);
    });

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not reached.');
}

class _FakeTwitchSocket implements TwitchSocket {
  final controller = StreamController<dynamic>();
  final sent = <String>[];
  bool closed = false;

  @override
  Future<void> get ready async {}

  @override
  Stream<dynamic> get stream => controller.stream;

  @override
  void add(String data) => sent.add(data);

  void receive(String data) => controller.add(data);

  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) await controller.close();
  }
}

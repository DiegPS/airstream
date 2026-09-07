import 'dart:async';

import 'package:airstream/services/chat/kick_transport.dart';
import 'package:airstream/services/chat/youtube_transport.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/models/chat_message.dart' as app;
import 'package:airstream/models/chat_provider_event.dart';
import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;
import 'package:dart_twitch_chat/dart_twitch_chat.dart' show TwitchSocket;
import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

void main() {
  test('Twitch times out an unresponsive socket and closes it', () async {
    final socket = _FakeTwitchSocket(ready: Completer<void>().future);
    final service = TwitchService(
      socketFactory: (_) => socket,
      httpClient: MockClient((_) async => http.Response('[]', 200)),
      connectionTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);

    await expectLater(
        service.connect('channel'), throwsA(isA<TimeoutException>()));
    expect(socket.closed, isTrue);
  });

  test('Twitch reconnects after remote close without duplicating sockets',
      () async {
    final sockets = <_FakeTwitchSocket>[];
    final service = TwitchService(
      socketFactory: (_) {
        final socket = _FakeTwitchSocket();
        sockets.add(socket);
        return socket;
      },
      httpClient: MockClient((_) async => http.Response('[]', 200)),
      reconnectDelay: const Duration(milliseconds: 1),
    );
    addTearDown(service.dispose);

    await service.connect('channel');
    await sockets.single.remoteClose();
    await _eventually(
      () =>
          sockets.length == 2 &&
          sockets.last.sent.any((line) => line.startsWith('JOIN ')),
    );
    expect(sockets, hasLength(2));
    expect(sockets.last.sent.where((line) => line.startsWith('JOIN ')),
        hasLength(1));
  });

  test('YouTube reports timeout and provider errors through status', () async {
    final transport = _FakeYouTubeTransport(
      startFuture: Completer<void>().future,
    );
    final timedOut = YouTubeService(
      transportFactory: (_) => transport,
      connectionTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(timedOut.dispose);
    await expectLater(timedOut.connect(liveId: 'abcdefghijk'),
        throwsA(isA<TimeoutException>()));

    final ready = _FakeYouTubeTransport();
    final service = YouTubeService(
      transportFactory: (_) => ready,
    );
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);
    await service.connect(liveId: 'abcdefghijk');
    ready.chatErrorController.add(Exception('provider failure'));
    await _eventually(
        () => statuses.any((event) => event.$1 == ServiceStatus.error));
    expect(statuses.last.$2, contains('provider failure'));
    await service.disconnect();
    expect(ready.stopped, isTrue);
  });

  test('YouTube rejects foreign URLs before creating a transport', () async {
    var transports = 0;
    final service = YouTubeService(
      transportFactory: (_) {
        transports++;
        return _FakeYouTubeTransport();
      },
    );
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);

    await expectLater(
      service.connect(
        handle: 'https://example.test/watch?v=dQw4w9WgXcQ',
      ),
      throwsFormatException,
    );

    expect(transports, 0);
    await _eventually(() => statuses.isNotEmpty);
    expect(statuses.last.$1, ServiceStatus.error);
  });

  test('YouTube normalizes every media URL and preserves custom emoji',
      () async {
    final transport = _FakeYouTubeTransport();
    final service = YouTubeService(
      transportFactory: (_) => transport,
    );
    addTearDown(service.dispose);
    await service.connect(liveId: 'abcdefghijk');
    final converted = service.messages.first;
    transport.messageController.add(
      yt.ChatItem(
        id: 'message-1',
        author: const yt.Author(
          name: 'Author',
          channelId: 'channel-1',
          thumbnail: yt.ImageItem(
            url: '//lh3.googleusercontent.com/avatar-large',
            alt: 'Author',
            variants: [
              yt.ImageVariant(
                url: '//lh3.googleusercontent.com/avatar-32',
                width: 32,
                height: 32,
              ),
              yt.ImageVariant(
                url: '//lh3.googleusercontent.com/avatar-88',
                width: 88,
                height: 88,
              ),
              yt.ImageVariant(
                url: '//lh3.googleusercontent.com/avatar-176',
                width: 176,
                height: 176,
              ),
            ],
          ),
          badge: yt.Badge(
            thumbnail: yt.ImageItem(
              url: '//lh3.googleusercontent.com/badge',
              alt: 'Member',
            ),
            label: 'Member',
          ),
          badges: [
            yt.Badge(
              thumbnail: yt.ImageItem(
                url: '//lh3.googleusercontent.com/badge',
                alt: 'Member',
              ),
              label: 'Member',
            ),
            yt.Badge(
              thumbnail: yt.ImageItem(
                url: '//lh3.googleusercontent.com/moderator',
                alt: 'Moderator',
              ),
              label: 'Moderator',
            ),
          ],
        ),
        message: const [
          yt.MessageItem.emoji(yt.EmojiItem(
            url: '//lh3.googleusercontent.com/emoji',
            alt: ':custom:',
            emojiText: ':custom:',
            isCustomEmoji: true,
          )),
        ],
        superChat: const yt.SuperChat(
          amount: r'$1.00',
          color: '#00FF00',
          sticker: yt.ImageItem(
            url: '//lh3.googleusercontent.com/sticker',
            alt: 'Sticker',
          ),
        ),
        isMembership: true,
        isOwner: false,
        isVerified: false,
        isModerator: false,
        timestamp: DateTime.utc(2026),
      ),
    );

    final message = await converted;
    expect(message.author.avatarUrl, startsWith('https://'));
    expect(message.author.avatarUrl, endsWith('avatar-88'));
    expect(message.author.badge!.imageUrl, startsWith('https://'));
    expect(message.author.allBadges.map((badge) => badge.label),
        ['Member', 'Moderator']);
    expect(message.superChat!.stickerUrl, startsWith('https://'));
    final emoji = message.items.single.emoji!;
    expect(emoji.url, startsWith('https://'));
    expect(emoji.isCustom, isTrue);
    expect(message.platform, app.Platform.youtube);
  });

  test('YouTube consumes accumulated live metadata and stops on disconnect',
      () async {
    final chat = _FakeYouTubeTransport();
    final service = YouTubeService(
      streamOrientation: app.YoutubeStreamOrientation.horizontal,
      transportFactory: (_) => chat,
    );
    addTearDown(service.dispose);

    final updates = <Object?>[];
    final subscription = service.metadataStream.listen(updates.add);
    addTearDown(subscription.cancel);
    await service.connect(liveId: 'abcdefghijk');
    chat.metadataStateController.add(_metadataState(
      viewers: 1200,
      title: 'Horizontal broadcast',
    ));
    await _eventually(() => service.currentMetadata?.viewerCount == 1200);
    chat.metadataStateController.add(_metadataState(
      viewers: 1350,
      title: 'Horizontal broadcast',
    ));
    await _eventually(() => service.currentMetadata?.viewerCount == 1350);

    expect(service.currentMetadata?.title, 'Horizontal broadcast');
    expect(service.currentMetadata?.streamOrientation,
        app.YoutubeStreamOrientation.horizontal);
    expect(updates.whereType<Object>(), isNotEmpty);

    await service.disconnect();
    expect(chat.stopped, isTrue);
    expect(service.currentMetadata, isNull);
  });

  test('YouTube metadata errors preserve chat status and last metadata',
      () async {
    final chat = _FakeYouTubeTransport();
    final service = YouTubeService(transportFactory: (_) => chat);
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);
    await service.connect(liveId: 'abcdefghijk');
    chat.metadataStateController.add(_metadataState(viewers: 777));
    await _eventually(() => service.currentMetadata?.viewerCount == 777);

    chat.metadataErrorController.add(Exception('metadata unavailable'));
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(statuses.last.$1, ServiceStatus.connected);
    expect(service.currentMetadata?.viewerCount, 777);
  });

  test('YouTube reports the explicit end of a live session', () async {
    final chat = _FakeYouTubeTransport();
    final service = YouTubeService(transportFactory: (_) => chat);
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    service.statusStream.listen(statuses.add);
    final status = service.statusStream.firstWhere(
      (value) => value.$1 == ServiceStatus.idle,
    );
    final event = service.appEvents.firstWhere(
      (value) => value.kind == ChatProviderEventKind.streamOffline,
    );
    await service.connect(liveId: 'abcdefghijk');

    chat.lifecycleController.add(yt.YoutubeLiveLifecycle.ended);

    expect((await status).$1, ServiceStatus.idle);
    expect((await event).platform, app.Platform.youtube);
    chat.pollController.add(DateTime.now().toUtc());
    await Future<void>.delayed(Duration.zero);
    expect(statuses.last.$1, ServiceStatus.idle);
  });

  test('YouTube converts and deduplicates gifted membership events', () async {
    final chat = _FakeYouTubeTransport();
    final service = YouTubeService(transportFactory: (_) => chat);
    addTearDown(service.dispose);
    await service.connect(liveId: 'abcdefghijk');
    final messages = <app.ChatMessage>[];
    final subscription = service.messages.listen(messages.add);
    addTearDown(subscription.cancel);
    final event = yt.LiveChatEvent(
      kind: yt.LiveChatEventKind.membershipGiftPurchased,
      actionType: 'addChatItemAction',
      rendererType: 'liveChatSponsorshipsGiftPurchaseAnnouncementRenderer',
      id: 'gift-1',
      text: 'Gifted 5 memberships',
      authorChannelId: 'gifter-channel',
      authorName: 'Gifter',
      authorThumbnail: const yt.ImageItem(
        url: '//lh3.googleusercontent.com/gifter',
        alt: 'Gifter',
      ),
      giftMembershipCount: 5,
      timestamp: DateTime.utc(2026),
    );

    chat.eventController.add(event);
    chat.eventController.add(event);
    await _eventually(() => messages.isNotEmpty);

    expect(messages, hasLength(1));
    expect(messages.single.author.name, 'Gifter');
    expect(messages.single.author.avatarUrl, startsWith('https://'));
    expect(messages.single.isMembershipEvent, isTrue);
    expect(messages.single.membershipEventKind, app.MembershipEventKind.gift);
    expect(messages.single.membershipGiftCount, 5);
    expect(messages.single.plainText, 'Gifted 5 memberships');
  });

  test('YouTube converts provider deletion events into moderation events',
      () async {
    final chat = _FakeYouTubeTransport();
    final service = YouTubeService(
      streamOrientation: app.YoutubeStreamOrientation.vertical,
      transportFactory: (_) => chat,
    );
    addTearDown(service.dispose);
    await service.connect(liveId: 'abcdefghijk');

    final deletedMessage = service.moderationEvents.first;
    chat.eventController.add(const yt.LiveChatEvent(
      kind: yt.LiveChatEventKind.messageDeleted,
      actionType: 'markChatItemAsDeletedAction',
      rendererType: '',
      targetItemId: 'message-1',
      raw: {
        'markChatItemAsDeletedAction': {'targetItemId': 'message-1'},
      },
    ));

    final event = await deletedMessage;
    expect(event.scope, app.ChatModerationScope.message);
    expect(event.messageId, 'message-1');
    expect(
        event.youtubeStreamOrientation, app.YoutubeStreamOrientation.vertical);
  });

  test('Kick injects connection, reports transport errors, and closes once',
      () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);

    await service.connect('creator');
    expect(transport.joined, ['creator']);
    transport.errorController.add(Exception('corrupt provider frame'));
    await _eventually(
        () => statuses.any((event) => event.$1 == ServiceStatus.error));
    await service.disconnect();
    expect(transport.closeCount, 1);
  });

  test('Kick reports a transport timeout and leaves no active client',
      () async {
    final pending = Completer<KickChatTransport>();
    final service = KickService(
      transportFactory: () => pending.future,
      connectionTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);

    await service.connect('creator');

    await _eventually(
      () => statuses.any((event) => event.$1 == ServiceStatus.error),
    );
    expect(statuses.last.$1, ServiceStatus.error);
    expect(statuses.last.$2, contains('TimeoutException'));
  });

  test('Kick converts subscription gifts once per correlated batch', () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final messages = <app.ChatMessage>[];
    final subscription = service.messages.listen(messages.add);
    addTearDown(subscription.cancel);
    await service.connect('creator');

    final payload = {
      'gifter_username': 'generous',
      'gifted_usernames': ['one', 'two'],
      'gifted_total': 2,
      'gifter_total': 8,
      'chunk_details': {
        'correlation_id': 'gift-batch',
        'chunk_index': 0,
        'total_chunks': 2,
      },
    };
    transport.eventController.add(
      kick.parseKickEvent('GiftedSubscriptionsEvent', payload),
    );
    transport.eventController.add(
      kick.parseKickEvent('GiftedSubscriptionsEvent', payload),
    );
    await _eventually(() => messages.isNotEmpty);

    expect(messages, hasLength(1));
    expect(messages.single.membershipEventKind, app.MembershipEventKind.gift);
    expect(messages.single.membershipGiftCount, 2);
  });

  test('Kick applies message, author and room moderation events', () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final events = <app.ChatModerationEvent>[];
    service.moderationEvents.listen(events.add);
    await service.connect('creator');

    transport.eventController.add(kick.parseKickEvent(
      r'App\Events\MessageDeletedEvent',
      {
        'message': {'id': 'message-1'}
      },
    ));
    transport.eventController.add(kick.parseKickEvent(
      r'App\Events\UserBannedEvent',
      {
        'user': {'slug': 'author-1'},
      },
    ));
    transport.eventController.add(kick.parseKickEvent(
      r'App\Events\ChatroomClearEvent',
      const <String, Object?>{},
    ));
    await _eventually(() => events.length == 3);

    expect(events[0].messageId, 'message-1');
    expect(events[1].authorChannelId, 'author-1');
    expect(events[2].scope, app.ChatModerationScope.platform);
  });

  test('Kick exposes anonymous live viewer metadata', () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final metadata =
        service.metadataStream.firstWhere((value) => value != null);
    await service.connect('creator');

    transport.metadataController.add(kick.KickChannel.fromJson({
      'id': 1,
      'slug': 'creator',
      'user': const <String, Object?>{},
      'chatroom': {'id': 2},
      'livestream': {
        'id': 3,
        'is_live': true,
        'session_title': 'Anonymous live',
        'viewer_count': 321,
      },
    }));

    expect((await metadata)!.viewerCount, 321);
  });

  test('Kick forwards public polls, pins and KICK gifts as common events',
      () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final events = <ChatProviderEvent>[];
    service.appEvents.listen(events.add);
    await service.connect('creator');

    transport.eventController.add(kick.parseKickEvent(
      r'App\Events\PollUpdateEvent',
      {'id': 'poll-1'},
    ));
    transport.eventController.add(kick.parseKickEvent(
      'KicksGifted',
      {'id': 'gift-1'},
    ));
    await _eventually(() => events.length == 2);

    expect(events.map((event) => event.kind), [
      ChatProviderEventKind.poll,
      ChatProviderEventKind.reward,
    ]);
  });

  test('Kick consumes modern image badges, roles and supplied avatars',
      () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final messageFuture = service.messages.first;
    await service.connect('creator');
    transport.messageController.add(kick.ChatMessage.fromJson({
      'id': 'kick-message',
      'chatroom_id': 9,
      'content': 'hello',
      'type': 'celebration',
      'metadata': {
        'celebration': {
          'type': 'subscription_renewed',
          'total_months': 12,
        },
      },
      'created_at': '2026-09-06T12:00:00Z',
      'sender': {
        'id': 7,
        'username': 'viewer',
        'slug': 'viewer',
        'profile_pic': 'https://cdn/avatar.webp',
        'identity': {
          'color': '#53FC18',
          'badges': [],
          'badges_v2': [
            {
              'name': 'verified',
              'badge_type': 'global',
              'image_url': 'https://cdn/verified.png',
              'selected': true,
              'sort_order': 1,
              'metadata': {},
            },
          ],
        },
      },
    }));

    final message = await messageFuture;
    expect(message.author.avatarUrl, 'https://cdn/avatar.webp');
    expect(message.author.badges.single.imageUrl, 'https://cdn/verified.png');
    expect(message.isVerified, isTrue);
    expect(message.isMembershipEvent, isTrue);
    expect(message.membershipEventKind, app.MembershipEventKind.resubscription);
    expect(message.membershipMonths, 12);
  });
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  fail('Condition was not reached.');
}

class _FakeTwitchSocket implements TwitchSocket {
  _FakeTwitchSocket({Future<void>? ready})
      : _ready = ready ?? Future<void>.value();
  final Future<void> _ready;
  final controller = StreamController<dynamic>();
  final sent = <String>[];
  bool closed = false;

  @override
  Future<void> get ready => _ready;
  @override
  Stream<dynamic> get stream => controller.stream;
  @override
  void add(String data) => sent.add(data);
  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) unawaited(controller.close());
  }

  Future<void> remoteClose() => controller.close();
}

class _FakeYouTubeTransport
    implements YouTubeChatTransport, YouTubeLifecycleTransport {
  _FakeYouTubeTransport({Future<void>? startFuture})
      : _startFuture = startFuture ?? Future<void>.value();
  final Future<void> _startFuture;
  final messageController = StreamController<yt.ChatItem>.broadcast();
  final eventController = StreamController<yt.LiveChatEvent>.broadcast();
  final metadataStateController =
      StreamController<yt.UpdatedMetadataState>.broadcast();
  final chatErrorController = StreamController<Exception>.broadcast();
  final metadataErrorController = StreamController<Exception>.broadcast();
  final lifecycleController =
      StreamController<yt.YoutubeLiveLifecycle>.broadcast();
  final pollController = StreamController<DateTime>.broadcast();
  bool stopped = false;
  @override
  Stream<yt.ChatItem> get messages => messageController.stream;
  @override
  Stream<yt.LiveChatEvent> get events => eventController.stream;
  @override
  Stream<yt.UpdatedMetadataState> get metadataStates =>
      metadataStateController.stream;
  @override
  Stream<Exception> get chatErrors => chatErrorController.stream;
  @override
  Stream<Exception> get metadataErrors => metadataErrorController.stream;
  @override
  Stream<yt.YoutubeLiveLifecycle> get lifecycle => lifecycleController.stream;
  @override
  Stream<DateTime> get polls => pollController.stream;
  @override
  String get liveId => 'live-id';
  @override
  Future<void> start() => _startFuture;
  @override
  void stop() => stopped = true;
}

yt.UpdatedMetadataState _metadataState({
  required int viewers,
  String? title,
}) {
  final batch = yt.UpdatedMetadataBatch.fromJson({
    'actions': [
      {
        'updateViewershipAction': {
          'viewCount': {
            'videoViewCountRenderer': {
              'isLive': true,
              'originalViewCount': '$viewers',
              'unlabeledViewCountValue': {'simpleText': '$viewers'},
            },
          },
        },
      },
      if (title != null)
        {
          'updateTitleAction': {
            'title': {'simpleText': title},
          },
        },
    ],
  });
  return const yt.UpdatedMetadataState().apply(batch);
}

class _FakeKickTransport implements KickChatTransport, KickMetadataTransport {
  final messageController = StreamController<kick.ChatMessage>.broadcast();
  final eventController = StreamController<kick.KickEvent>.broadcast();
  final errorController = StreamController<Exception>.broadcast();
  final metadataController = StreamController<kick.KickChannel>.broadcast();
  final joined = <String>[];
  int closeCount = 0;
  @override
  Stream<kick.ChatMessage> get messages => messageController.stream;
  @override
  Stream<kick.KickEvent> get events => eventController.stream;
  @override
  Stream<Exception> get errors => errorController.stream;
  @override
  Stream<kick.KickChannel> get metadata => metadataController.stream;
  @override
  Future<void> joinBySlug(String slug) async => joined.add(slug);
  @override
  Future<void> close() async => closeCount++;
}

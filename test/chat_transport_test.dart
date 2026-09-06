import 'dart:async';

import 'package:airstream/services/chat/kick_transport.dart';
import 'package:airstream/services/chat/twitch_transport.dart';
import 'package:airstream/services/chat/youtube_transport.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/twitch_service.dart';
import 'package:airstream/services/youtube_service.dart';
import 'package:airstream/models/chat_message.dart' as app;
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

  test('YouTube reports timeout and malformed messages through status',
      () async {
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
    final service = YouTubeService(transportFactory: (_) => ready);
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);
    await service.connect(liveId: 'abcdefghijk');
    ready.messageController.add({'corrupt': true});
    await _eventually(
        () => statuses.any((event) => event.$1 == ServiceStatus.error));
    expect(statuses.last.$2, contains('Invalid YouTube'));
    await service.disconnect();
    expect(ready.stopped, isTrue);
  });

  test('YouTube normalizes every media URL and preserves custom emoji',
      () async {
    final transport = _FakeYouTubeTransport();
    final service = YouTubeService(transportFactory: (_) => transport);
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
            url: '//lh3.googleusercontent.com/avatar',
            alt: 'Author',
          ),
          badge: yt.Badge(
            thumbnail: yt.ImageItem(
              url: '//lh3.googleusercontent.com/badge',
              alt: 'Member',
            ),
            label: 'Member',
          ),
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
    expect(message.author.badge!.imageUrl, startsWith('https://'));
    expect(message.superChat!.stickerUrl, startsWith('https://'));
    final emoji = message.items.single.emoji!;
    expect(emoji.url, startsWith('https://'));
    expect(emoji.isCustom, isTrue);
    expect(message.platform, app.Platform.youtube);
  });

  test('Kick injects connection, reports corrupt messages, and closes once',
      () async {
    final transport = _FakeKickTransport();
    final service = KickService(transportFactory: () async => transport);
    addTearDown(service.dispose);
    final statuses = <(ServiceStatus, String?)>[];
    final subscription = service.statusStream.listen(statuses.add);
    addTearDown(subscription.cancel);

    await service.connect('creator');
    expect(transport.joined, ['creator']);
    transport.messageController.add({'invalid': true});
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

class _FakeYouTubeTransport implements YouTubeChatTransport {
  _FakeYouTubeTransport({Future<void>? startFuture})
      : _startFuture = startFuture ?? Future<void>.value();
  final Future<void> _startFuture;
  final messageController = StreamController<dynamic>.broadcast();
  final errorController = StreamController<dynamic>.broadcast();
  final pollController = StreamController<dynamic>.broadcast();
  bool stopped = false;
  @override
  Stream<dynamic> get messages => messageController.stream;
  @override
  Stream<dynamic> get errors => errorController.stream;
  @override
  Stream<dynamic> get polls => pollController.stream;
  @override
  String get liveId => 'live-id';
  @override
  Future<void> start() => _startFuture;
  @override
  void stop() => stopped = true;
}

class _FakeKickTransport implements KickChatTransport {
  final messageController = StreamController<dynamic>.broadcast();
  final errorController = StreamController<dynamic>.broadcast();
  final joined = <String>[];
  int closeCount = 0;
  @override
  Stream<dynamic> get messages => messageController.stream;
  @override
  Stream<dynamic> get errors => errorController.stream;
  @override
  Future<void> joinBySlug(String slug) async => joined.add(slug);
  @override
  Future<void> close() async => closeCount++;
}

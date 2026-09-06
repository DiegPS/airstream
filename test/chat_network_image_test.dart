import 'dart:io';

import 'package:airstream/models/chat_media.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/ui/widgets/author_avatar.dart';
import 'package:airstream/ui/widgets/chat_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cacheRoot;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    cacheRoot = await Directory.systemTemp.createTemp('airstream-image-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (_) async => cacheRoot.path);
  });

  tearDownAll(() async {
    await ChatImageCache.instance.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('normalizes protocol-relative and trusted HTTP image URLs', () {
    expect(normalizeChatImageUrl('//lh3.googleusercontent.com/avatar'),
        'https://lh3.googleusercontent.com/avatar');
    expect(normalizeChatImageUrl('http://yt4.ggpht.com/avatar'),
        'https://yt4.ggpht.com/avatar');
  });

  test('cache keys are stable and change when the image changes', () {
    final first = ChatImageCache.key(
      kind: 'avatar',
      identity: 'youtube:channel-1',
      url: '//lh3.googleusercontent.com/avatar-a',
    );
    expect(
      first,
      ChatImageCache.key(
        kind: 'avatar',
        identity: ' YouTube:Channel-1 ',
        url: 'https://lh3.googleusercontent.com/avatar-a',
      ),
    );
    expect(
      first,
      isNot(ChatImageCache.key(
        kind: 'avatar',
        identity: 'youtube:channel-1',
        url: 'https://lh3.googleusercontent.com/avatar-b',
      )),
    );
  });

  test('chat cache supports disk resizing required by CachedNetworkImage', () {
    expect(ChatImageCache.instance, isA<ImageCacheManager>());
  });

  testWidgets('configures instant fade and size-aware decoding',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2),
          child: ChatNetworkImage(
            imageUrl: '//example.invalid/avatar',
            cacheKey: 'avatar:test',
            width: 44,
            height: 44,
            placeholder: Text('AB'),
          ),
        ),
      ),
    );
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.invalid/avatar');
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(image.memCacheWidth, 88);
    expect(image.memCacheHeight, 88);
    expect(image.maxWidthDiskCache, 88);
    expect(image.placeholder, isNotNull);
  });

  testWidgets('avatar has initials available as its loading placeholder',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthorAvatar(
          name: '@Ada Lovelace',
          platform: Platform.youtube,
          channelId: 'ada',
          url: 'https://example.invalid/avatar',
        ),
      ),
    );
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.placeholder, isNotNull);
    expect(find.text('AL'), findsOneWidget);
  });
}

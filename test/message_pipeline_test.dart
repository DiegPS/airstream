import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deduplicates repeated messages before they reach the buffer and stream',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);

    pipeline.addSource(source.stream);

    final baseTime = DateTime.utc(2026, 5, 9, 12, 0, 0);
    source.add(_message(id: 'abc', text: 'Hola chat', timestamp: baseTime));
    source.add(_message(id: 'abc', text: 'Hola chat', timestamp: baseTime));
    source.add(_message(id: 'def', text: 'Hola chat', timestamp: baseTime));
    source.add(_message(
      id: 'ghi',
      text: 'Hola chat',
      timestamp: baseTime.add(const Duration(seconds: 2)),
    ));

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted.map((msg) => msg.id).toList(), ['abc', 'def', 'ghi']);
    expect(
      pipeline.buffer.map((msg) => msg.id).toList(),
      ['abc', 'def', 'ghi'],
    );

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test('uses content fallback only when a platform provides no message ID',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);
    pipeline.addSource(source.stream);

    final time = DateTime.utc(2026, 5, 9, 12);
    source.add(_message(id: 'known', text: 'GG', timestamp: time));
    source.add(_message(id: '', text: 'GG', timestamp: time));
    source.add(_message(id: '', text: 'GG', timestamp: time));

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted.map((message) => message.id), ['known', '']);

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test('keeps messages from separate YouTube broadcasts distinct', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final time = DateTime.utc(2026, 5, 9, 12);

    source.add(_message(
      id: 'same-provider-id',
      text: 'Hola',
      timestamp: time,
      youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
    ));
    source.add(_message(
      id: 'same-provider-id',
      text: 'Hola',
      timestamp: time,
      youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(pipeline.buffer, hasLength(2));
    expect(
      pipeline.buffer.map((message) => message.youtubeStreamOrientation),
      [
        YoutubeStreamOrientation.horizontal,
        YoutubeStreamOrientation.vertical,
      ],
    );

    await source.close();
    pipeline.dispose();
  });

  test('blocks users at the pipeline root for all downstream consumers',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(
      maxMessages: 10,
      blockedUsers: ['@nightbot'],
    ));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);

    pipeline.addSource(source.stream);

    final baseTime = DateTime.utc(2026, 5, 9, 12, 0, 0);
    source.add(_message(
      id: 'hidden',
      text: 'This should not pass',
      authorName: 'Nightbot',
      authorChannelId: 'nightbot',
      timestamp: baseTime,
    ));
    source.add(_message(
      id: 'visible',
      text: 'Hola chat',
      authorName: 'Tester',
      authorChannelId: 'tester-channel',
      timestamp: baseTime,
    ));

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted.map((msg) => msg.id).toList(), ['visible']);
    expect(pipeline.buffer.map((msg) => msg.id).toList(), ['visible']);

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test(
      'blocks normalized word tokens and phrases without substring false positives',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(
      maxMessages: 10,
      blockedWords: ['puta', 'callate bot'],
    ));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);

    pipeline.addSource(source.stream);

    final baseTime = DateTime.utc(2026, 5, 9, 12, 0, 0);
    source.add(_message(
      id: 'blocked-word',
      text: 'Eso estuvo puta madre',
      timestamp: baseTime,
    ));
    source.add(_message(
      id: 'blocked-phrase',
      text: 'Callate, bot por favor',
      timestamp: baseTime.add(const Duration(seconds: 1)),
    ));
    source.add(_message(
      id: 'allowed-substring',
      text: 'La disputa sigue manana',
      timestamp: baseTime.add(const Duration(seconds: 2)),
    ));

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted.map((msg) => msg.id).toList(), ['allowed-substring']);
    expect(
      pipeline.buffer.map((msg) => msg.id).toList(),
      ['allowed-substring'],
    );

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test('reducing max messages trims the current buffer immediately', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 5));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final baseTime = DateTime.utc(2026, 5, 9, 12);

    for (var index = 0; index < 5; index++) {
      source.add(_message(
        id: 'message-$index',
        text: 'Message $index',
        timestamp: baseTime.add(Duration(seconds: index)),
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final changed = pipeline.updateSettings(
      const SettingsModel(maxMessages: 2),
    );

    expect(changed, isTrue);
    expect(
      pipeline.buffer.map((message) => message.id),
      ['message-3', 'message-4'],
    );

    await source.close();
    pipeline.dispose();
  });

  test('new filters remove matching messages from the current buffer',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final baseTime = DateTime.utc(2026, 5, 9, 12);

    source.add(_message(
      id: 'blocked-user',
      text: 'First',
      authorName: 'Nightbot',
      timestamp: baseTime,
    ));
    source.add(_message(
      id: 'blocked-word',
      text: 'Spoiler final',
      timestamp: baseTime.add(const Duration(seconds: 1)),
    ));
    source.add(_message(
      id: 'visible',
      text: 'Hello',
      timestamp: baseTime.add(const Duration(seconds: 2)),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final changed = pipeline.updateSettings(
      const SettingsModel(
        maxMessages: 10,
        blockedUsers: ['nightbot'],
        blockedWords: ['spoiler'],
      ),
    );

    expect(changed, isTrue);
    expect(pipeline.buffer.map((message) => message.id), ['visible']);

    await source.close();
    pipeline.dispose();
  });

  test('enriches buffered author avatars without replaying messages', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);
    pipeline.addSource(source.stream);
    source.add(_message(
      id: 'kick-1',
      text: 'Hello',
      authorName: 'Viewer',
      timestamp: DateTime.utc(2026, 9, 7),
      platform: Platform.kick,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final changed = pipeline.applyAuthorUpdate(const ChatAuthorUpdate(
      platform: Platform.kick,
      authorName: 'viewer',
      avatarUrl: 'https://kick/avatar.webp',
    ));

    expect(changed, isTrue);
    expect(pipeline.buffer.single.author.avatarUrl, 'https://kick/avatar.webp');
    expect(emitted, hasLength(1));

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test('applies message and author moderation within the matching stream',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final timestamp = DateTime.utc(2026, 9, 6);

    source.add(_message(
      id: 'horizontal-1',
      text: 'First',
      authorChannelId: 'author-1',
      timestamp: timestamp,
      youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
    ));
    source.add(_message(
      id: 'horizontal-2',
      text: 'Second',
      authorChannelId: 'author-1',
      timestamp: timestamp,
      youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
    ));
    source.add(_message(
      id: 'vertical-1',
      text: 'Vertical',
      authorChannelId: 'author-1',
      timestamp: timestamp,
      youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      pipeline.applyModeration(const ChatModerationEvent.message(
        platform: Platform.youtube,
        messageId: 'horizontal-1',
        youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
      )),
      isTrue,
    );
    expect(
      pipeline.applyModeration(const ChatModerationEvent.author(
        platform: Platform.youtube,
        authorChannelId: 'author-1',
        youtubeStreamOrientation: YoutubeStreamOrientation.horizontal,
      )),
      isTrue,
    );

    expect(pipeline.buffer.map((message) => message.id), ['vertical-1']);
    await source.close();
    pipeline.dispose();
  });

  test('platform moderation clears only that provider', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final timestamp = DateTime.utc(2026, 9, 6);

    source.add(_message(
      id: 'twitch-1',
      text: 'Twitch',
      timestamp: timestamp,
      platform: Platform.twitch,
    ));
    source.add(_message(
      id: 'youtube-1',
      text: 'YouTube',
      timestamp: timestamp,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      pipeline.applyModeration(
        const ChatModerationEvent.platform(platform: Platform.twitch),
      ),
      isTrue,
    );
    expect(pipeline.buffer.map((message) => message.id), ['youtube-1']);

    await source.close();
    pipeline.dispose();
  });
}

ChatMessage _message({
  required String id,
  required String text,
  required DateTime timestamp,
  String authorName = 'Tester',
  String authorChannelId = 'tester-channel',
  Platform platform = Platform.youtube,
  YoutubeStreamOrientation? youtubeStreamOrientation,
}) {
  return ChatMessage(
    platform: platform,
    id: id,
    author: ChatAuthor(
      name: authorName,
      channelId: authorChannelId,
    ),
    items: [MessageItem.text(text)],
    youtubeStreamOrientation: youtubeStreamOrientation,
    timestamp: timestamp,
  );
}

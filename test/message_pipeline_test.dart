import 'dart:async';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/pipeline/message_pipeline.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session export drops the oldest past 20000 and resets the limit flag',
      () async {
    final pipeline = MessagePipeline(
        const SettingsModel(maxMessages: 1, blockedWords: ['blocked']))
      ..startSession();
    final source = StreamController<ChatMessage>(sync: true);
    pipeline.addSource(source.stream);
    addTearDown(pipeline.dispose);
    addTearDown(source.close);
    final time = DateTime.utc(2026);
    source.add(_message(id: 'blocked', text: 'blocked', timestamp: time));
    for (var i = 0; i < 20000; i++) {
      source.add(_message(id: '$i', text: 'accepted', timestamp: time));
    }
    expect(pipeline.sessionMessages, hasLength(20000));
    expect(pipeline.sessionMessages.first.id, '0');
    expect(pipeline.sessionMessagesTruncated, isFalse);

    source.add(_message(id: '20000', text: 'accepted', timestamp: time));
    expect(pipeline.sessionMessages, hasLength(20000));
    expect(pipeline.sessionMessages.first.id, '1');
    expect(pipeline.sessionMessagesTruncated, isTrue);
    pipeline.applyModeration(const ChatModerationEvent.message(
        platform: Platform.youtube, messageId: '1'));
    expect(pipeline.sessionMessages.first.id, '2');
    expect(pipeline.sessionMessagesTruncated, isTrue);

    pipeline.startSession();
    expect(pipeline.sessionMessages, isEmpty);
    expect(pipeline.sessionMessagesTruncated, isFalse);
  });

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

  test('blocks words written in any script as whole words', () async {
    final pipeline = MessagePipeline(const SettingsModel(
      maxMessages: 20,
      blockedWords: ['сука', 'バカ', 'garçon', 'Öl'],
    ));
    final source = StreamController<ChatMessage>();
    final emitted = <ChatMessage>[];
    final sub = pipeline.stream.listen(emitted.add);
    pipeline.addSource(source.stream);

    final baseTime = DateTime.utc(2026, 5, 9, 12, 0, 0);
    final texts = {
      'cyrillic': 'ты сука!',
      'japanese': 'お前は バカ だ',
      'cedilla': 'Hey GARÇON, ven',
      'umlaut': 'kein öl mehr',
      'split-cedilla': 'gar on es otra cosa',
      'partial': 'garçonnière bonita',
    };
    var offset = 0;
    for (final entry in texts.entries) {
      source.add(_message(
        id: entry.key,
        text: entry.value,
        timestamp: baseTime.add(Duration(seconds: offset++)),
      ));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted.map((m) => m.id), ['split-cedilla', 'partial']);
    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });

  test('an author ban also matches messages that only carry the name',
      () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    final timestamp = DateTime.utc(2026, 5, 9, 12);
    source.add(ChatMessage(
      platform: Platform.kick,
      id: 'chat',
      author: const ChatAuthor(name: 'Some_User', channelId: 'some-user'),
      items: const [MessageItem.text('hola')],
      timestamp: timestamp,
    ));
    source.add(ChatMessage(
      platform: Platform.kick,
      id: 'subscription',
      author: const ChatAuthor(name: 'Some_User', channelId: 'Some_User'),
      items: const [MessageItem.text('subscribed')],
      isMembershipEvent: true,
      timestamp: timestamp,
    ));
    source.add(ChatMessage(
      platform: Platform.kick,
      id: 'other',
      author: const ChatAuthor(name: 'Other', channelId: 'other'),
      items: const [MessageItem.text('hi')],
      timestamp: timestamp,
    ));
    await Future<void>.delayed(Duration.zero);

    final changed = pipeline.applyModeration(const ChatModerationEvent.author(
      platform: Platform.kick,
      authorChannelId: 'some-user',
      authorName: 'some_user',
    ));

    expect(changed, isTrue);
    expect(pipeline.buffer.map((m) => m.id), ['other']);
    await source.close();
    pipeline.dispose();
  });

  test('settings that do not filter leave the buffer alone', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 10));
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    source.add(ChatMessage(
      platform: Platform.twitch,
      id: 'kept',
      author: const ChatAuthor(name: 'viewer', channelId: 'viewer'),
      items: const [MessageItem.text('hola')],
      timestamp: DateTime.utc(2026, 5, 9, 12),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(
      pipeline.updateSettings(
        const SettingsModel(maxMessages: 10, fontSize: 30),
      ),
      isFalse,
    );
    expect(pipeline.buffer.map((m) => m.id), ['kept']);
    expect(
      pipeline.updateSettings(
        const SettingsModel(
            maxMessages: 10, fontSize: 30, blockedUsers: ['viewer']),
      ),
      isTrue,
    );
    expect(pipeline.buffer, isEmpty);
    await source.close();
    pipeline.dispose();
  });

  test('marks each viewer first message since the chat started', () async {
    final pipeline = MessagePipeline(const SettingsModel(maxMessages: 50))
      ..startSession();
    final source = StreamController<ChatMessage>();
    pipeline.addSource(source.stream);
    var next = 0;
    ChatMessage message(
      String author, {
      Platform platform = Platform.twitch,
      bool owner = false,
    }) =>
        ChatMessage(
          platform: platform,
          id: 'm${next++}',
          author: ChatAuthor(name: author, channelId: author),
          items: const [MessageItem.text('hola')],
          isOwner: owner,
          timestamp: DateTime.utc(2026, 11, 15),
        );

    source
      ..add(message('Ana'))
      ..add(message('ana'))
      ..add(message('Beto'))
      ..add(message('Ana', platform: Platform.kick))
      ..add(message('Streamer', owner: true));
    await Future<void>.delayed(Duration.zero);
    expect(
      pipeline.buffer.map((m) => m.isFirstInSession),
      [true, false, true, true, false],
      reason: 'per viewer and platform, never the streamer',
    );

    pipeline.clear();
    source.add(message('Ana'));
    await Future<void>.delayed(Duration.zero);
    expect(pipeline.buffer.single.isFirstInSession, isFalse,
        reason: 'clearing the display keeps the current session');

    pipeline
      ..endSession()
      ..startSession();
    source.add(message('Ana'));
    await Future<void>.delayed(Duration.zero);
    expect(pipeline.buffer.last.isFirstInSession, isTrue,
        reason: 'a new chat session starts over');

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

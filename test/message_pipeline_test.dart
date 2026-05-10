import 'dart:async';

import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/pipeline/message_pipeline.dart';
import 'package:airchat_flutter/settings/settings_model.dart';
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

    expect(emitted.map((msg) => msg.id).toList(), ['abc', 'ghi']);
    expect(pipeline.buffer.map((msg) => msg.id).toList(), ['abc', 'ghi']);

    await sub.cancel();
    await source.close();
    pipeline.dispose();
  });
}

ChatMessage _message({
  required String id,
  required String text,
  required DateTime timestamp,
}) {
  return ChatMessage(
    platform: Platform.youtube,
    id: id,
    author: const ChatAuthor(
      name: 'Tester',
      channelId: 'tester-channel',
    ),
    items: [MessageItem.text(text)],
    timestamp: timestamp,
  );
}

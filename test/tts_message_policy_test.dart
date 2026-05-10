import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/tts_message_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects backlog messages that are older than the current TTS session',
      () {
    final sessionStartedAt = DateTime.utc(2026, 5, 9, 12, 0, 10);

    expect(
      isTtsMessageFresh(
        _message(DateTime.utc(2026, 5, 9, 12, 0, 7)),
        sessionStartedAt,
      ),
      isFalse,
    );

    expect(
      isTtsMessageFresh(
        _message(DateTime.utc(2026, 5, 9, 12, 0, 11)),
        sessionStartedAt,
      ),
      isTrue,
    );
  });

  test('allows a small timestamp tolerance around session start', () {
    final sessionStartedAt = DateTime.utc(2026, 5, 9, 12, 0, 10);

    expect(
      isTtsMessageFresh(
        _message(DateTime.utc(2026, 5, 9, 12, 0, 9)),
        sessionStartedAt,
      ),
      isTrue,
    );
  });

  test('sanitizes author names for TTS', () {
    expect(sanitizeTtsAuthorName('@xqc123'), 'xqc');
    expect(sanitizeTtsAuthorName('player_99-test'), 'player test');
    expect(sanitizeTtsAuthorName('@@123'), isEmpty);
  });
}

ChatMessage _message(DateTime timestamp) {
  return ChatMessage(
    platform: Platform.kick,
    id: 'msg-${timestamp.millisecondsSinceEpoch}',
    author: const ChatAuthor(
      name: 'Tester',
      channelId: 'tester-channel',
    ),
    items: const [MessageItem.text('hola')],
    timestamp: timestamp,
  );
}

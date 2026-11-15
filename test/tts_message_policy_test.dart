import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/tts_message_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TTS command parsing', () {
    test('accepts an exact command followed by whitespace', () {
      expect(
        extractTtsCommandText(
          '!v hola mundo',
          prefix: '!v',
          ignoreCase: true,
        ),
        'hola mundo',
      );
      expect(
        extractTtsCommandText(
          '!v\t hola',
          prefix: '!v',
          ignoreCase: true,
        ),
        'hola',
      );
    });

    test('rejects words that merely start with the command prefix', () {
      for (final message in ['!video mira esto', '!vamos todos', '!voz hola']) {
        expect(
          extractTtsCommandText(
            message,
            prefix: '!v',
            ignoreCase: true,
          ),
          isNull,
          reason: message,
        );
      }
    });

    test('rejects a command without spoken content', () {
      expect(
        extractTtsCommandText('!v', prefix: '!v', ignoreCase: true),
        isNull,
      );
      expect(
        extractTtsCommandText('!v   ', prefix: '!v', ignoreCase: true),
        isNull,
      );
    });

    test('honors command case sensitivity', () {
      expect(
        extractTtsCommandText('!V hola', prefix: '!v', ignoreCase: true),
        'hola',
      );
      expect(
        extractTtsCommandText('!V hola', prefix: '!v', ignoreCase: false),
        isNull,
      );
    });
  });

  test('rejects backlog messages that are older than the current TTS session',
      () {
    final sessionStartedAt = DateTime.utc(2026, 5, 9, 12, 0, 10);

    expect(
      isTtsMessageFresh(
        _message(DateTime.utc(2026, 5, 9, 12, 0, 7)),
        sessionStartedAt,
        now: sessionStartedAt.add(const Duration(seconds: 2)),
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

  test('a computer clock running ahead does not mute live chat for long', () {
    // The PC clock is a minute ahead of the platform's clock.
    final sessionStartedAt = DateTime.utc(2026, 5, 9, 12, 1, 0);
    final liveMessage = _message(DateTime.utc(2026, 5, 9, 12, 0, 5));

    expect(
      isTtsMessageFresh(
        liveMessage,
        sessionStartedAt,
        now: sessionStartedAt.add(const Duration(seconds: 3)),
      ),
      isFalse,
      reason: 'right after connecting it may be backlog',
    );
    expect(
      isTtsMessageFresh(
        liveMessage,
        sessionStartedAt,
        now: sessionStartedAt.add(const Duration(seconds: 12)),
      ),
      isTrue,
      reason: 'history never arrives this long after connecting',
    );
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

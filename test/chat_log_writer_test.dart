import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/chat_log_writer.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _message(String author, String text, {SuperChat? superChat}) =>
    ChatMessage(
      platform: Platform.twitch,
      id: '$author-$text',
      author: ChatAuthor(name: author, channelId: author),
      items: [MessageItem.text(text)],
      superChat: superChat,
      timestamp: DateTime(2026, 11, 15, 21, 5, 13),
    );

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('airstream-chat-log-');
  });
  tearDown(() => root.delete(recursive: true));

  ChatLogWriter writer() => ChatLogWriter(
        directory: () async => Directory('${root.path}/Chat'),
        clock: () => DateTime(2026, 11, 15, 21, 0, 0),
      );

  test('formats one readable line per message', () {
    expect(
      ChatLogWriter.formatLine(_message('Ana', 'hola  a\ntodos')),
      '[21:05:13] [Twitch] Ana: hola a todos',
    );
    expect(
      ChatLogWriter.formatLine(_message('Donador', 'gracias',
          superChat: const SuperChat(amount: r'$5.00', color: '#fff'))),
      r'[21:05:13] [Twitch] Donador: ($5.00) gracias',
    );
  });

  test('writes the session chat to a dated file', () async {
    final log = writer();
    await log.startSession(enabled: true);
    log.write(_message('Ana', 'hola'));
    log.write(_message('Beto', 'qué tal'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await log.endSession();

    final file = log.currentFile!;
    expect(file.path, endsWith('airstream-chat-2026-11-15_21-00-00.txt'));
    expect(await file.readAsLines(), [
      '[21:05:13] [Twitch] Ana: hola',
      '[21:05:13] [Twitch] Beto: qué tal',
    ]);
  });

  test('writes nothing while it is off', () async {
    final log = writer();
    await log.startSession(enabled: false);
    log.write(_message('Ana', 'hola'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await log.endSession();
    expect(log.currentFile, isNull);
    expect(Directory('${root.path}/Chat').existsSync(), isFalse);
  });

  test('turning it off mid-session closes the file', () async {
    final log = writer();
    await log.startSession(enabled: true);
    log.write(_message('Ana', 'antes'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await log.setEnabled(false);
    log.write(_message('Ana', 'después'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await log.currentFile!.readAsLines(),
        ['[21:05:13] [Twitch] Ana: antes']);
  });
}

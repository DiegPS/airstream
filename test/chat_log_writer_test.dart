import 'dart:async';
import 'dart:convert';
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

  test('the next message opens the log again after a failed file open',
      () async {
    final log = writer();
    final blocked = await Directory(
            '${root.path}/Chat/airstream-chat-2026-11-15_21-00-00.txt')
        .create(recursive: true);
    await log.startSession(enabled: true);
    log.write(_message('Ana', 'before recovery'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(log.currentFile, isNull);

    await blocked.delete();
    log.write(_message('Ana', 'after recovery'));
    await log.endSession();
    expect(await log.currentFile!.readAsLines(),
        ['[21:05:13] [Twitch] Ana: after recovery']);
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

  test('a failed log flush still closes the sink without escaping', () async {
    final sink = _FailingSink();
    await IOOverrides.runZoned(() async {
      final log = writer();
      await log.startSession(enabled: true);
      log.write(_message('Ana', 'hola'));
      await log.endSession();
    }, createFile: (path) => _SinkFile(path, () => sink));
    expect(sink.flushed, isTrue);
    expect(sink.closed, isTrue);
  });

  test(
      'a failed open sink is closed without flushing and the next line reopens it',
      () async {
    late final _FailingSink failed;
    late final _FailingSink replacement;
    final paths = <String>[];
    var now = DateTime(2026, 11, 15, 21);
    await IOOverrides.runZoned(() async {
      failed = _FailingSink();
      replacement = _FailingSink();
      final log = ChatLogWriter(
        directory: () async => Directory(root.path),
        clock: () => now,
      );
      await log.startSession(enabled: true);
      log.write(_message('Ana', 'hola'));
      await failed.written.future;
      failed.completion.completeError(const FileSystemException('Disk full'));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 1));
      log.write(_message('Beto', 'after recovery'));
      await log.endSession();
    },
        createFile: (path) => _SinkFile(path, () {
              paths.add(path);
              return paths.length == 1 ? failed : replacement;
            }));
    expect(failed.closed, isTrue);
    expect(failed.flushed, isFalse);
    expect(paths, [paths.first, paths.first]);
    expect(replacement.written.isCompleted, isTrue);
    expect(replacement.closed, isTrue);
  });

  test('a sink error releases an already pending log flush', () async {
    late final _FailingSink sink;
    await IOOverrides.runZoned(() async {
      sink = _FailingSink(flushBlock: Completer<void>().future);
      final log = writer();
      await log.startSession(enabled: true);
      log.write(_message('Ana', 'hola'));
      await sink.written.future;
      final closing = log.endSession();
      await sink.flushing.future;
      sink.completion.completeError(const FileSystemException('Disk full'));
      await closing.timeout(const Duration(seconds: 1));
      expect(sink.closed, isTrue);
    }, createFile: (path) => _SinkFile(path, () => sink));
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

class _SinkFile extends Fake implements File {
  _SinkFile(this.path, this.createSink);

  @override
  final String path;
  final IOSink Function() createSink;

  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding? encoding}) =>
      createSink();
}

class _FailingSink extends Fake implements IOSink {
  _FailingSink({this.flushBlock});

  final Future<void>? flushBlock;
  final flushing = Completer<void>();
  final completion = Completer<void>();
  final written = Completer<void>();
  bool flushed = false;
  bool closed = false;

  @override
  Future<void> get done => completion.future;

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  void writeln([Object? object = '']) => written.complete();

  @override
  Future<void> flush() async {
    flushed = true;
    flushing.complete();
    if (flushBlock != null) return flushBlock;
    throw const FileSystemException('Disk full');
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!completion.isCompleted) completion.complete();
    throw const FileSystemException('Disk full');
  }
}

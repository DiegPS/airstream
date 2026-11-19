import 'dart:async';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef _LogFile = ({
  File file,
  IOSink sink,
  Completer<void> failed,
  Future<void> Function() close,
});

/// Writes the chat of each session to a text file, one message per line.
class ChatLogWriter {
  ChatLogWriter({
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
  })  : _directory = directory ?? defaultDirectory,
        _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  Future<_LogFile>? _opening;
  Future<void> _closing = Future.value();
  File? _file;
  File? _sessionFile;
  bool _enabled = false;

  /// Documents\Airstream\Chat, where people look for their files.
  static Future<Directory> defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'Airstream', 'Chat'));
  }

  File? get currentFile => _file;

  /// Starts a new file at the next message while [enabled].
  Future<void> startSession({required bool enabled}) {
    final closing = endSession();
    _enabled = enabled;
    return closing;
  }

  /// Turning logging on mid-session starts a file; off closes it.
  Future<void> setEnabled(bool enabled) async {
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (!enabled) await _close();
  }

  Future<void> endSession() async {
    _enabled = false;
    await _close();
  }

  void write(ChatMessage message) {
    if (!_enabled) return;
    unawaited(_append(formatLine(message)));
  }

  Future<void> _append(String line) async {
    final opening = _opening ??= _open();
    final _LogFile opened;
    try {
      opened = await opening;
    } catch (error, stack) {
      if (identical(_opening, opening)) _opening = null;
      AppLogger.warning('Chat log open failed',
          error: error, stackTrace: stack);
      return;
    }
    if (opened.failed.isCompleted) return;
    if (identical(_opening, opening)) _sessionFile = opened.file;
    if (identical(_opening, opening) || _opening == null) {
      _file = opened.file;
    }
    try {
      opened.sink.writeln(line);
    } catch (error, stack) {
      AppLogger.warning('Chat log write failed',
          error: error, stackTrace: stack);
    }
  }

  Future<_LogFile> _open() {
    late final Future<_LogFile> opening;
    opening = _openFile(_sessionFile, () {
      if (identical(_opening, opening)) _opening = null;
    });
    return opening;
  }

  Future<File> _newFile() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final now = _clock();
    String two(int value) => value.toString().padLeft(2, '0');
    final stem = 'airstream-chat-${now.year}-${two(now.month)}-${two(now.day)}'
        '_${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    for (var number = 1;; number++) {
      final name = number == 1 ? '$stem.txt' : '$stem-$number.txt';
      final file = File(p.join(directory.path, name));
      try {
        return await file.create(exclusive: true);
      } on FileSystemException {
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file) {
          rethrow;
        }
      }
    }
  }

  Future<_LogFile> _openFile(File? existing, void Function() invalidate) async {
    final file = existing ?? await _newFile();
    final sink = file.openWrite(mode: FileMode.append);
    final failed = Completer<void>();
    Future<void>? closing;
    Future<void> close() => closing ??= _closeSink(sink);
    // An asynchronous write can fail before a caller asks to end the session.
    unawaited(
        sink.done.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      failed.complete();
      invalidate();
      AppLogger.warning('Chat log sink failed',
          error: error, stackTrace: stack);
      unawaited(close());
    }));
    // IOSink opens asynchronously. Wait for its open before caching it.
    await sink.addStream(const Stream<List<int>>.empty());
    return (file: file, sink: sink, failed: failed, close: close);
  }

  Future<void> _close() {
    final opening = _opening;
    _opening = null;
    _sessionFile = null;
    if (opening != null) {
      _closing = Future.wait([_closing, _closeFile(opening)]);
    }
    return _closing;
  }

  Future<void> _closeFile(Future<_LogFile> opening) async {
    final _LogFile opened;
    try {
      opened = await opening;
    } catch (_) {
      // The failure was logged when the first line was written.
      return;
    }
    if (opened.failed.isCompleted) return;
    try {
      await Future.any([opened.sink.flush(), opened.failed.future]);
    } catch (error, stack) {
      AppLogger.warning('Chat log flush failed',
          error: error, stackTrace: stack);
    } finally {
      if (!opened.failed.isCompleted) await opened.close();
    }
  }

  Future<void> _closeSink(IOSink sink) async {
    try {
      await sink.close();
    } catch (error, stack) {
      AppLogger.warning('Chat log close failed',
          error: error, stackTrace: stack);
    }
  }

  /// `[21:05:13] [Twitch] Ana: hola`, in local time.
  static String formatLine(ChatMessage message) {
    final time = message.timestamp.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final platform = switch (message.platform) {
      Platform.youtube => 'YouTube',
      Platform.twitch => 'Twitch',
      Platform.kick => 'Kick',
    };
    final text = message.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final amount = message.superChat?.amount;
    return '[${two(time.hour)}:${two(time.minute)}:${two(time.second)}] '
        '[$platform] ${message.author.name}: '
        '${amount == null ? '' : '($amount) '}$text';
  }
}

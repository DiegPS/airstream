import 'dart:async';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes the chat of each session to a text file, one message per line.
class ChatLogWriter {
  ChatLogWriter({
    Future<Directory> Function()? directory,
    DateTime Function()? clock,
  })  : _directory = directory ?? defaultDirectory,
        _clock = clock ?? DateTime.now;

  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;
  IOSink? _sink;
  Future<IOSink?>? _opening;
  File? _file;
  bool _enabled = false;

  /// Documents\Airstream\Chat, where people look for their files.
  static Future<Directory> defaultDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'Airstream', 'Chat'));
  }

  File? get currentFile => _file;

  /// Starts a new file at the next message while [enabled].
  Future<void> startSession({required bool enabled}) async {
    await endSession();
    _enabled = enabled;
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
    try {
      final sink = await (_opening ??= _open());
      sink?.writeln(line);
    } catch (error, stack) {
      AppLogger.warning('Chat log write failed',
          error: error, stackTrace: stack);
    }
  }

  Future<IOSink?> _open() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final now = _clock();
    String two(int value) => value.toString().padLeft(2, '0');
    final name = 'airstream-chat-${now.year}-${two(now.month)}-${two(now.day)}'
        '_${two(now.hour)}-${two(now.minute)}-${two(now.second)}.txt';
    final file = File(p.join(directory.path, name));
    _file = file;
    return _sink = file.openWrite(mode: FileMode.append);
  }

  Future<void> _close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // The failure was logged when the first line was written.
      }
    }
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
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

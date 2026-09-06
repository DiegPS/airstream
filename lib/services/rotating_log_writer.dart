import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RotatingLogWriter {
  RotatingLogWriter({
    required this.directory,
    this.baseName = 'airstream.log',
    this.maxBytes = 2 * 1024 * 1024,
    this.maxBackups = 3,
  });

  final Directory directory;
  final String baseName;
  final int maxBytes;
  final int maxBackups;
  Future<void> _queue = Future<void>.value();

  File get currentFile =>
      File('${directory.path}${Platform.pathSeparator}$baseName');

  Future<void> write(String line) {
    final operation = _queue.then((_) => _write(line));
    _queue = operation.catchError((_) {});
    return operation;
  }

  Future<void> flush() => _queue;

  Future<void> _write(String line) async {
    await directory.create(recursive: true);
    final bytes = utf8.encode('$line\n');
    if (await currentFile.exists() &&
        await currentFile.length() + bytes.length > maxBytes) {
      await _rotate();
    }
    await currentFile.writeAsBytes(bytes, mode: FileMode.append, flush: true);
  }

  Future<void> _rotate() async {
    if (maxBackups <= 0) {
      if (await currentFile.exists()) await currentFile.delete();
      return;
    }
    final oldest = File('${currentFile.path}.$maxBackups');
    if (await oldest.exists()) await oldest.delete();
    for (var index = maxBackups - 1; index >= 1; index--) {
      final source = File('${currentFile.path}.$index');
      if (await source.exists()) {
        await source.rename('${currentFile.path}.${index + 1}');
      }
    }
    if (await currentFile.exists()) {
      await currentFile.rename('${currentFile.path}.1');
    }
  }
}

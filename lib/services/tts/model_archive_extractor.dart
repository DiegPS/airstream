import 'dart:async';
import 'dart:isolate';

import 'package:archive/archive_io.dart';

import 'tts_installation.dart';

class TtsModelArchiveExtractor {
  const TtsModelArchiveExtractor();

  Future<void> extract(
    String archivePath,
    String outputPath,
    TtsDownloadCancellation cancellation,
  ) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final completion = Completer<void>();
    final isolate = await Isolate.spawn(
      _extractWorker,
      {
        'archive': archivePath,
        'output': outputPath,
        'reply': messages.sendPort
      },
      onError: errors.sendPort,
      errorsAreFatal: true,
    );
    final messageSubscription = messages.listen((dynamic message) {
      if (completion.isCompleted) return;
      message is String
          ? completion.completeError(StateError(message))
          : completion.complete();
    });
    final errorSubscription = errors.listen((dynamic error) {
      if (!completion.isCompleted) {
        completion.completeError(StateError('Model extraction failed: $error'));
      }
    });
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (cancellation.isCancelled && !completion.isCompleted) {
        isolate.kill(priority: Isolate.immediate);
        completion.completeError(const TtsDownloadCancelledException());
      }
    });
    try {
      await completion.future;
    } finally {
      timer.cancel();
      isolate.kill(priority: Isolate.immediate);
      await messageSubscription.cancel();
      await errorSubscription.cancel();
      messages.close();
      errors.close();
    }
  }

  static Future<void> _extractWorker(Map<String, Object> message) async {
    final reply = message['reply']! as SendPort;
    try {
      await extractFileToDisk(
        message['archive']! as String,
        message['output']! as String,
      );
      reply.send(true);
    } catch (error, stack) {
      reply.send('$error\n$stack');
    }
  }
}

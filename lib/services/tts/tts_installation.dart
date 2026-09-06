import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tts_model_catalog.dart';

enum TtsInstallPhase {
  idle,
  checking,
  downloading,
  verifying,
  extracting,
  installed,
  error
}

class TtsInstallProgress {
  const TtsInstallProgress({
    required this.phase,
    required this.message,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.path,
  });
  final TtsInstallPhase phase;
  final String message;
  final int receivedBytes;
  final int totalBytes;
  final String? path;
  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : null;
}

class TtsDownloadCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  final _cancelledCompleter = Completer<void>();
  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _cancelledCompleter.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_cancelledCompleter.isCompleted) _cancelledCompleter.complete();
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  void Function() addListener(void Function() listener) {
    if (_cancelled) {
      listener();
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const TtsDownloadCancelledException();
  }
}

class TtsDownloadCancelledException implements Exception {
  const TtsDownloadCancelledException();
  @override
  String toString() => 'TTS model download cancelled.';
}

class TtsModelInstallation {
  const TtsModelInstallation(this.model, this.directory);
  final TtsModelDefinition model;
  final Directory directory;
  String file(String relativePath) =>
      p.joinAll([directory.path, ...relativePath.split('/')]);
}

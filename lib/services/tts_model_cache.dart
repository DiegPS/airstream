import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tts/tts_model_catalog.dart';

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
  final TtsInstallPhase phase;
  final String message;
  final int receivedBytes;
  final int totalBytes;
  final String? path;
  const TtsInstallProgress(
      {required this.phase,
      required this.message,
      this.receivedBytes = 0,
      this.totalBytes = 0,
      this.path});
  double? get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0, 1) : null;
}

class TtsDownloadCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
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
  final TtsModelDefinition model;
  final Directory directory;
  const TtsModelInstallation(this.model, this.directory);
  String file(String relativePath) =>
      p.joinAll([directory.path, ...relativePath.split('/')]);
}

class TtsModelCache {
  final http.Client _client;
  final Directory? _rootOverride;
  final bool _ownsClient;
  TtsModelCache({http.Client? client, Directory? rootDirectory})
      : _client = client ?? http.Client(),
        _rootOverride = rootDirectory,
        _ownsClient = client == null;

  Future<Directory> get rootDirectory async {
    if (_rootOverride != null) return _rootOverride!;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'tts', 'models'));
  }

  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    final root = await rootDirectory;
    final directory = Directory(p.join(root.path, model.storageKey));
    final marker = File(p.join(directory.path, '.airstream-model.json'));
    if (!await marker.exists()) return null;
    try {
      final metadata = jsonDecode(await marker.readAsString());
      if (metadata is! Map ||
          metadata['id'] != model.id ||
          metadata['version'] != model.version ||
          metadata['sha256'] != model.sha256) {
        return null;
      }
      for (final relativePath in model.requiredFiles) {
        final path = p.joinAll([directory.path, ...relativePath.split('/')]);
        if (!await FileSystemEntity.isFile(path) &&
            !await FileSystemEntity.isDirectory(path)) {
          return null;
        }
      }
      return TtsModelInstallation(model, directory);
    } catch (_) {
      return null;
    }
  }

  Future<TtsModelInstallation> ensureAvailable(
    TtsModelDefinition model, {
    void Function(TtsInstallProgress progress)? onProgress,
    TtsDownloadCancellation? cancellation,
  }) async {
    cancellation ??= TtsDownloadCancellation();
    onProgress?.call(const TtsInstallProgress(
        phase: TtsInstallPhase.checking, message: 'Checking installed model…'));
    final existing = await installed(model);
    if (existing != null) {
      onProgress?.call(TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is installed.',
          receivedBytes: model.archiveBytes,
          totalBytes: model.archiveBytes,
          path: existing.directory.path));
      return existing;
    }
    final root = await rootDirectory;
    await root.create(recursive: true);
    final downloads = Directory(p.join(root.path, '.downloads'));
    await downloads.create(recursive: true);
    final partial =
        File(p.join(downloads.path, '${model.storageKey}.tar.bz2.part'));
    await _download(model, partial, onProgress, cancellation);
    cancellation.throwIfCancelled();
    onProgress?.call(TtsInstallProgress(
        phase: TtsInstallPhase.verifying,
        message: 'Verifying SHA-256 integrity…',
        receivedBytes: model.archiveBytes,
        totalBytes: model.archiveBytes));
    final digest = await sha256.bind(partial.openRead()).first;
    if (digest.toString() != model.sha256) {
      if (await partial.exists()) await partial.delete();
      throw StateError('The downloaded model failed its SHA-256 check.');
    }
    cancellation.throwIfCancelled();
    final verifiedArchive =
        File(partial.path.substring(0, partial.path.length - '.part'.length));
    if (await verifiedArchive.exists()) await verifiedArchive.delete();
    await partial.rename(verifiedArchive.path);
    final staging =
        Directory(p.join(root.path, '.${model.storageKey}.staging'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    onProgress?.call(TtsInstallProgress(
        phase: TtsInstallPhase.extracting,
        message: 'Installing ${model.name}…',
        receivedBytes: model.archiveBytes,
        totalBytes: model.archiveBytes));
    try {
      await _extractArchive(
        verifiedArchive.path,
        staging.path,
        cancellation,
      );
      cancellation.throwIfCancelled();
      final extracted = Directory(p.join(staging.path, model.archiveRoot));
      if (!await extracted.exists()) {
        throw StateError('The model archive has an unexpected structure.');
      }
      for (final relativePath in model.requiredFiles) {
        final path = p.joinAll([extracted.path, ...relativePath.split('/')]);
        if (!await FileSystemEntity.isFile(path) &&
            !await FileSystemEntity.isDirectory(path)) {
          throw StateError('The model archive is missing $relativePath.');
        }
      }
      await File(p.join(extracted.path, '.airstream-model.json')).writeAsString(
          jsonEncode({
            'id': model.id,
            'version': model.version,
            'sha256': model.sha256,
            'installedAt': DateTime.now().toUtc().toIso8601String()
          }),
          flush: true);
      final target = Directory(p.join(root.path, model.storageKey));
      if (await target.exists()) await target.delete(recursive: true);
      await extracted.rename(target.path);
      await staging.delete(recursive: true);
      await verifiedArchive.delete();
      onProgress?.call(TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is ready.',
          receivedBytes: model.archiveBytes,
          totalBytes: model.archiveBytes,
          path: target.path));
      return TtsModelInstallation(model, target);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await verifiedArchive.exists() && !await partial.exists()) {
        await verifiedArchive.rename(partial.path);
      }
      rethrow;
    }
  }

  Future<void> _extractArchive(
    String archivePath,
    String outputPath,
    TtsDownloadCancellation cancellation,
  ) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final completion = Completer<void>();
    late final StreamSubscription<dynamic> messageSubscription;
    late final StreamSubscription<dynamic> errorSubscription;
    final isolate = await Isolate.spawn(
      _extractWorker,
      {
        'archive': archivePath,
        'output': outputPath,
        'reply': messages.sendPort,
      },
      onError: errors.sendPort,
      errorsAreFatal: true,
    );
    messageSubscription = messages.listen((dynamic message) {
      if (completion.isCompleted) return;
      if (message is String) {
        completion.completeError(StateError(message));
      } else {
        completion.complete();
      }
    });
    errorSubscription = errors.listen((dynamic error) {
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

  Future<void> _download(
      TtsModelDefinition model,
      File partial,
      void Function(TtsInstallProgress progress)? onProgress,
      TtsDownloadCancellation cancellation) async {
    var offset = await partial.exists() ? await partial.length() : 0;
    if (offset > model.archiveBytes) {
      await partial.delete();
      offset = 0;
    }
    final request = http.Request('GET', model.archiveUri);
    if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
          'Model download failed (HTTP ${response.statusCode}).',
          uri: model.archiveUri);
    }
    if (offset > 0 && response.statusCode != HttpStatus.partialContent) {
      await partial.delete();
      offset = 0;
    }
    final sink =
        partial.openWrite(mode: offset > 0 ? FileMode.append : FileMode.write);
    var received = offset;
    try {
      await for (final chunk in response.stream) {
        cancellation.throwIfCancelled();
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(TtsInstallProgress(
            phase: TtsInstallPhase.downloading,
            message: 'Downloading ${model.name}…',
            receivedBytes: received,
            totalBytes: model.archiveBytes,
            path: partial.path));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (received != model.archiveBytes) {
      throw StateError(
          'Incomplete model download: $received of ${model.archiveBytes} bytes.');
    }
  }

  Future<void> remove(TtsModelDefinition model) async {
    final root = await rootDirectory;
    final target = Directory(p.join(root.path, model.storageKey));
    if (await target.exists()) await target.delete(recursive: true);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

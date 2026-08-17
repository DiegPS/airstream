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
  final int _segmentedDownloadThreshold;
  TtsModelCache({
    http.Client? client,
    Directory? rootDirectory,
    int segmentedDownloadThreshold = 32 * 1024 * 1024,
  })  : _client = client ?? http.Client(),
        _rootOverride = rootDirectory,
        _segmentedDownloadThreshold = segmentedDownloadThreshold,
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
          metadata['integrity'] != model.integrityKey) {
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
    final activeCancellation = cancellation ?? TtsDownloadCancellation();
    onProgress?.call(const TtsInstallProgress(
        phase: TtsInstallPhase.checking, message: 'Checking installed model…'));
    final existing = await installed(model);
    if (existing != null) {
      onProgress?.call(TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is installed.',
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
          path: existing.directory.path));
      return existing;
    }
    final root = await rootDirectory;
    await root.create(recursive: true);
    final downloads = Directory(p.join(root.path, '.downloads'));
    await downloads.create(recursive: true);
    final receivedByFile = <String, int>{};
    final partials = <TtsModelDownload, File>{};
    await Future.wait(model.downloads.map((download) async {
      final partial = _partialFile(downloads, model, download);
      partials[download] = partial;
      await _download(
        download,
        partial,
        (received) {
          receivedByFile[download.fileName] = received;
          final totalReceived = receivedByFile.values.fold(0, (a, b) => a + b);
          onProgress?.call(TtsInstallProgress(
            phase: TtsInstallPhase.downloading,
            message: 'Downloading ${download.fileName}…',
            receivedBytes: totalReceived,
            totalBytes: model.downloadBytes,
            path: partial.path,
          ));
        },
        activeCancellation,
      );
    }));
    activeCancellation.throwIfCancelled();
    var verifiedBytes = 0;
    for (final download in model.downloads) {
      onProgress?.call(TtsInstallProgress(
        phase: TtsInstallPhase.verifying,
        message: 'Verifying ${download.fileName}…',
        receivedBytes: verifiedBytes,
        totalBytes: model.downloadBytes,
      ));
      final partial = partials[download]!;
      final digest = await sha256.bind(partial.openRead()).first;
      if (digest.toString() != download.sha256) {
        if (await partial.exists()) await partial.delete();
        throw StateError('${download.fileName} failed its SHA-256 check.');
      }
      verifiedBytes += download.bytes;
      activeCancellation.throwIfCancelled();
    }
    final archiveDownload = model.downloads.singleWhere(
      (download) => download.isArchive,
    );
    final verifiedArchive = partials[archiveDownload]!;
    // `archive_io` selects the decoder from the filename extension. Keep the
    // resumable `.part` file untouched and extract from a verified copy whose
    // name retains the real archive extension.
    final extractionArchive = File(
      p.join(downloads.path, '${model.storageKey}.verified.tar.bz2'),
    );
    if (await extractionArchive.exists()) await extractionArchive.delete();
    await verifiedArchive.copy(extractionArchive.path);
    final staging =
        Directory(p.join(root.path, '.${model.storageKey}.staging'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    onProgress?.call(TtsInstallProgress(
        phase: TtsInstallPhase.extracting,
        message: 'Installing ${model.name}…',
        receivedBytes: model.downloadBytes,
        totalBytes: model.downloadBytes));
    try {
      await _extractArchive(
        extractionArchive.path,
        staging.path,
        activeCancellation,
      );
      activeCancellation.throwIfCancelled();
      final extracted = Directory(p.join(staging.path, model.archiveRoot));
      if (!await extracted.exists()) {
        throw StateError('The model archive has an unexpected structure.');
      }
      for (final download in model.downloads.where((item) => !item.isArchive)) {
        final targetPath = download.targetPath;
        if (targetPath == null || targetPath.isEmpty) {
          throw StateError('${download.fileName} has no installation path.');
        }
        final target = File(
          p.joinAll([extracted.path, ...targetPath.split('/')]),
        );
        await target.parent.create(recursive: true);
        await partials[download]!.copy(target.path);
      }
      for (final relativePath in model.removeAfterExtract) {
        final entityPath =
            p.joinAll([extracted.path, ...relativePath.split('/')]);
        final type = await FileSystemEntity.type(entityPath);
        if (type == FileSystemEntityType.file) {
          await File(entityPath).delete();
        } else if (type == FileSystemEntityType.directory) {
          await Directory(entityPath).delete(recursive: true);
        }
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
            'integrity': model.integrityKey,
            'installedAt': DateTime.now().toUtc().toIso8601String()
          }),
          flush: true);
      final target = Directory(p.join(root.path, model.storageKey));
      if (await target.exists()) await target.delete(recursive: true);
      await extracted.rename(target.path);
      await staging.delete(recursive: true);
      if (await extractionArchive.exists()) await extractionArchive.delete();
      for (final partial in partials.values) {
        if (await partial.exists()) await partial.delete();
      }
      onProgress?.call(TtsInstallProgress(
          phase: TtsInstallPhase.installed,
          message: '${model.name} is ready.',
          receivedBytes: model.downloadBytes,
          totalBytes: model.downloadBytes,
          path: target.path));
      return TtsModelInstallation(model, target);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      if (await extractionArchive.exists()) await extractionArchive.delete();
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

  File _partialFile(
    Directory downloads,
    TtsModelDefinition model,
    TtsModelDownload download,
  ) {
    final suffix = download.isArchive
        ? 'tar.bz2'
        : download.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File(p.join(downloads.path, '${model.storageKey}.$suffix.part'));
  }

  Future<void> _download(
      TtsModelDownload download,
      File partial,
      void Function(int received) onProgress,
      TtsDownloadCancellation cancellation) async {
    var offset = await partial.exists() ? await partial.length() : 0;
    if (offset > download.bytes) {
      await partial.delete();
      offset = 0;
    }
    onProgress(offset);
    if (offset == download.bytes) return;
    if (offset == 0 && download.bytes >= _segmentedDownloadThreshold) {
      final supportsRanges = await _supportsRanges(download, cancellation);
      if (supportsRanges) {
        await _downloadSegmented(
          download,
          partial,
          onProgress,
          cancellation,
        );
        return;
      }
    }
    final request = http.Request('GET', download.uri);
    if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
    final response = await _client.send(request);
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
          '${download.fileName} download failed (HTTP ${response.statusCode}).',
          uri: download.uri);
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
        onProgress(received);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (received != download.bytes) {
      throw StateError('Incomplete ${download.fileName} download: '
          '$received of ${download.bytes} bytes.');
    }
  }

  Future<bool> _supportsRanges(
    TtsModelDownload download,
    TtsDownloadCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final request = http.Request('GET', download.uri)
      ..headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
    final response = await _client.send(request);
    try {
      return response.statusCode == HttpStatus.partialContent &&
          response.headers[HttpHeaders.contentRangeHeader]
                  ?.startsWith('bytes 0-0/') ==
              true;
    } finally {
      final subscription = response.stream.listen((_) {});
      await subscription.cancel();
    }
  }

  Future<void> _downloadSegmented(
    TtsModelDownload download,
    File partial,
    void Function(int received) onProgress,
    TtsDownloadCancellation cancellation,
  ) async {
    const segmentCount = 4;
    final baseSize = download.bytes ~/ segmentCount;
    final receivedBySegment = List<int>.filled(segmentCount, 0);
    final segments = List.generate(
      segmentCount,
      (index) => File('${partial.path}.segment.$index'),
    );

    await Future.wait(List.generate(segmentCount, (index) async {
      final start = index * baseSize;
      final end = index == segmentCount - 1
          ? download.bytes - 1
          : (index + 1) * baseSize - 1;
      final expected = end - start + 1;
      final segment = segments[index];
      var existing = await segment.exists() ? await segment.length() : 0;
      if (existing > expected) {
        await segment.delete();
        existing = 0;
      }
      receivedBySegment[index] = existing;
      onProgress(receivedBySegment.fold(0, (sum, value) => sum + value));
      if (existing == expected) return;

      final request = http.Request('GET', download.uri)
        ..headers[HttpHeaders.rangeHeader] = 'bytes=${start + existing}-$end';
      final response = await _client.send(request);
      if (response.statusCode != HttpStatus.partialContent) {
        throw HttpException(
          '${download.fileName} server stopped supporting ranged downloads.',
          uri: download.uri,
        );
      }
      final sink = segment.openWrite(
        mode: existing == 0 ? FileMode.write : FileMode.append,
      );
      try {
        await for (final chunk in response.stream) {
          cancellation.throwIfCancelled();
          sink.add(chunk);
          existing += chunk.length;
          receivedBySegment[index] = existing;
          onProgress(receivedBySegment.fold(0, (sum, value) => sum + value));
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (existing != expected) {
        throw StateError('Incomplete ${download.fileName} segment: '
            '$existing of $expected bytes.');
      }
    }));

    cancellation.throwIfCancelled();
    final sink = partial.openWrite();
    try {
      for (final segment in segments) {
        await sink.addStream(segment.openRead());
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    for (final segment in segments) {
      if (await segment.exists()) await segment.delete();
    }
    final received = await partial.length();
    onProgress(received);
    if (received != download.bytes) {
      throw StateError('Incomplete ${download.fileName} download: '
          '$received of ${download.bytes} bytes.');
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

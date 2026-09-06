import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'tts_installation.dart';
import 'tts_model_catalog.dart';

class TtsModelDownloader {
  TtsModelDownloader({
    http.Client? client,
    this.segmentedDownloadThreshold = 32 * 1024 * 1024,
    this.connectionTimeout = const Duration(seconds: 20),
    this.inactivityTimeout = const Duration(seconds: 30),
    int downloadAttempts = 3,
  })  : _sharedClient = client,
        downloadAttempts = downloadAttempts.clamp(1, 5);

  final http.Client? _sharedClient;
  final int segmentedDownloadThreshold;
  final Duration connectionTimeout;
  final Duration inactivityTimeout;
  final int downloadAttempts;

  File partialFile(
    Directory downloads,
    TtsModelDefinition model,
    TtsModelDownload download,
  ) {
    final suffix = download.isArchive
        ? 'tar.bz2'
        : download.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File(p.join(downloads.path, '${model.storageKey}.$suffix.part'));
  }

  Future<void> download(
    TtsModelDownload download,
    File partial,
    void Function(int received) onProgress,
    TtsDownloadCancellation cancellation,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= downloadAttempts; attempt++) {
      cancellation.throwIfCancelled();
      try {
        await _downloadOnce(download, partial, onProgress, cancellation);
        return;
      } on TtsDownloadCancelledException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
        if (attempt == downloadAttempts || !_isRetryable(error)) rethrow;
        await _cancellableDelay(
          Duration(milliseconds: 300 * attempt),
          cancellation,
        );
      }
    }
    throw StateError('Download failed: $lastError');
  }

  Future<void> _downloadOnce(
    TtsModelDownload download,
    File partial,
    void Function(int received) onProgress,
    TtsDownloadCancellation cancellation,
  ) async {
    await partial.parent.create(recursive: true);
    if (!await partial.exists()) await partial.create();
    var offset = await partial.length();
    if (offset > download.bytes) {
      await partial.delete();
      offset = 0;
    }
    onProgress(offset);
    if (offset == download.bytes) return;
    if (offset == 0 && download.bytes >= segmentedDownloadThreshold) {
      if (await _supportsRanges(download, cancellation)) {
        await _downloadSegmented(download, partial, onProgress, cancellation);
        return;
      }
    }
    final request = http.Request('GET', download.uri);
    if (offset > 0) request.headers[HttpHeaders.rangeHeader] = 'bytes=$offset-';
    final lease = await _send(request, cancellation);
    final response = lease.response;
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      lease.close();
      throw HttpException(
        '${download.fileName} download failed (HTTP ${response.statusCode}).',
        uri: download.uri,
      );
    }
    if (offset > 0 && response.statusCode != HttpStatus.partialContent) {
      await partial.delete();
      offset = 0;
    }
    final sink = partial.openWrite(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    var received = offset;
    var lastReported = DateTime.now();
    try {
      await _consumeResponse(response, cancellation, (chunk) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastReported).inMilliseconds >= 50 ||
            received == download.bytes) {
          lastReported = now;
          onProgress(received);
        }
      });
    } finally {
      await sink.flush();
      await sink.close();
      lease.close();
    }
    if (received != download.bytes) {
      throw StateError(
        'Incomplete ${download.fileName} download: $received of ${download.bytes} bytes.',
      );
    }
  }

  Future<bool> _supportsRanges(
    TtsModelDownload download,
    TtsDownloadCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final request = http.Request('GET', download.uri)
      ..headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
    final lease = await _send(request, cancellation);
    try {
      return lease.response.statusCode == HttpStatus.partialContent &&
          lease.response.headers[HttpHeaders.contentRangeHeader]
                  ?.startsWith('bytes 0-0/') ==
              true;
    } finally {
      final subscription = lease.response.stream.listen((_) {});
      await subscription.cancel();
      lease.close();
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
    var lastReported = DateTime.now();
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
      final lease = await _send(request, cancellation);
      final response = lease.response;
      if (response.statusCode != HttpStatus.partialContent) {
        lease.close();
        throw HttpException(
          '${download.fileName} server stopped supporting ranged downloads.',
          uri: download.uri,
        );
      }
      final sink = segment.openWrite(
        mode: existing == 0 ? FileMode.write : FileMode.append,
      );
      try {
        await _consumeResponse(response, cancellation, (chunk) {
          sink.add(chunk);
          existing += chunk.length;
          receivedBySegment[index] = existing;
          final total = receivedBySegment.fold(0, (sum, value) => sum + value);
          final now = DateTime.now();
          if (now.difference(lastReported).inMilliseconds >= 50 ||
              total == download.bytes) {
            lastReported = now;
            onProgress(total);
          }
        });
      } finally {
        await sink.flush();
        await sink.close();
        lease.close();
      }
      if (existing != expected) {
        throw StateError(
          'Incomplete ${download.fileName} segment: $existing of $expected bytes.',
        );
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
      throw StateError(
        'Incomplete ${download.fileName} download: $received of ${download.bytes} bytes.',
      );
    }
  }

  Future<_HttpResponseLease> _send(
    http.BaseRequest request,
    TtsDownloadCancellation cancellation,
  ) async {
    cancellation.throwIfCancelled();
    final client = _sharedClient ?? http.Client();
    final ownsClient = _sharedClient == null;
    var completed = false;
    final removeListener = cancellation.addListener(() {
      if (!completed && ownsClient) client.close();
    });
    try {
      final response = await Future.any<http.StreamedResponse>([
        client.send(request),
        cancellation.whenCancelled.then<http.StreamedResponse>(
          (_) => throw const TtsDownloadCancelledException(),
        ),
      ]).timeout(
        connectionTimeout,
        onTimeout: () {
          if (ownsClient) client.close();
          throw TimeoutException(
            'Connection timed out for ${request.url}.',
            connectionTimeout,
          );
        },
      );
      completed = true;
      return _HttpResponseLease(response, ownsClient ? client : null);
    } finally {
      removeListener();
      if (!completed && ownsClient) client.close();
    }
  }

  Future<void> _consumeResponse(
    http.StreamedResponse response,
    TtsDownloadCancellation cancellation,
    void Function(List<int> chunk) onChunk,
  ) async {
    cancellation.throwIfCancelled();
    final completion = Completer<void>();
    Timer? inactivityTimer;
    StreamSubscription<List<int>>? subscription;
    void armTimeout() {
      inactivityTimer?.cancel();
      inactivityTimer = Timer(inactivityTimeout, () {
        if (!completion.isCompleted) {
          completion.completeError(
            TimeoutException(
                'Download stalled while waiting for data.', inactivityTimeout),
          );
          unawaited(subscription?.cancel());
        }
      });
    }

    final removeCancellationListener = cancellation.addListener(() {
      if (!completion.isCompleted) {
        completion.completeError(const TtsDownloadCancelledException());
        unawaited(subscription?.cancel());
      }
    });
    subscription = response.stream.listen(
      (chunk) {
        if (completion.isCompleted) return;
        armTimeout();
        onChunk(chunk);
      },
      onError: (Object error, StackTrace stack) {
        if (!completion.isCompleted) completion.completeError(error, stack);
      },
      onDone: () {
        if (!completion.isCompleted) completion.complete();
      },
      cancelOnError: true,
    );
    armTimeout();
    try {
      await completion.future;
    } finally {
      inactivityTimer?.cancel();
      removeCancellationListener();
      await subscription.cancel();
    }
  }

  static bool _isRetryable(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException;

  static Future<void> _cancellableDelay(
    Duration duration,
    TtsDownloadCancellation cancellation,
  ) async {
    await Future.any<void>([
      Future<void>.delayed(duration),
      cancellation.whenCancelled.then<void>(
        (_) => throw const TtsDownloadCancelledException(),
      ),
    ]);
  }
}

class _HttpResponseLease {
  const _HttpResponseLease(this.response, this._ownedClient);
  final http.StreamedResponse response;
  final http.Client? _ownedClient;
  void close() => _ownedClient?.close();
}

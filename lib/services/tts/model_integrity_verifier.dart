import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'tts_installation.dart';
import 'tts_model_catalog.dart';

class TtsModelIntegrityVerifier {
  const TtsModelIntegrityVerifier();

  Future<List<Map<String, Object>>> build(
    String directoryPath,
    List<String> requiredPaths,
  ) async {
    final result = await _runWorker({
      'type': 'build',
      'directory': directoryPath,
      'requiredPaths': List<String>.from(requiredPaths),
    });
    return (result as List)
        .map((entry) => Map<String, Object>.from(entry as Map))
        .toList(growable: false);
  }

  Future<bool> verify(
    String directoryPath,
    List<Map<String, dynamic>> entries,
  ) async =>
      await _runWorker({
        'type': 'verify',
        'directory': directoryPath,
        'entries': entries,
      }) ==
      true;

  static Future<Object?> _runWorker(Map<String, Object> job) async {
    final messages = ReceivePort();
    final errors = ReceivePort();
    final isolate = await Isolate.spawn(
      _worker,
      {...job, 'reply': messages.sendPort},
      errorsAreFatal: true,
      onError: errors.sendPort,
    );
    try {
      final result = await Future.any<Object?>([
        messages.first,
        errors.first.then<Object?>(
          (error) => throw StateError('Integrity worker failed: $error'),
        ),
      ]);
      if (result is Map && result['error'] != null) {
        throw StateError(result['error'] as String);
      }
      return result;
    } finally {
      isolate.kill(priority: Isolate.immediate);
      messages.close();
      errors.close();
    }
  }

  static Future<void> _worker(Map<String, Object> job) async {
    final reply = job['reply']! as SendPort;
    try {
      final directory = job['directory']! as String;
      if (job['type'] == 'build') {
        reply.send(await _buildManifest(
          directory,
          List<String>.from(job['requiredPaths']! as List),
        ));
      } else {
        reply.send(await _verifyManifest(
          directory,
          (job['entries']! as List)
              .map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList(growable: false),
        ));
      }
    } catch (error, stack) {
      reply.send({'error': '$error\n$stack'});
    }
  }

  static Future<List<Map<String, Object>>> _buildManifest(
    String directoryPath,
    List<String> requiredPaths,
  ) async {
    final directory = Directory(directoryPath);
    final files = <String, File>{};
    for (final requiredPath in requiredPaths) {
      final entityPath =
          p.joinAll([directory.path, ...requiredPath.split('/')]);
      final type = FileSystemEntity.typeSync(entityPath);
      if (type == FileSystemEntityType.file) {
        final file = File(entityPath);
        files[p.relative(file.path, from: directory.path)] = file;
      } else if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(entityPath).listSync(recursive: true)) {
          if (entity is File) {
            files[p.relative(entity.path, from: directory.path)] = entity;
          }
        }
      }
    }
    final entries = <Map<String, Object>>[];
    final paths = files.keys.toList()..sort();
    for (final relativePath in paths) {
      final file = files[relativePath]!;
      final digest = await sha256.bind(file.openRead()).first;
      entries.add({
        'path': relativePath.replaceAll('\\', '/'),
        'bytes': await file.length(),
        'sha256': digest.toString(),
      });
    }
    return entries;
  }

  static Future<bool> _verifyManifest(
    String directoryPath,
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return false;
    final root = p.canonicalize(directoryPath);
    for (final entry in entries) {
      final relativePath = entry['path'];
      final expectedBytes = entry['bytes'];
      final expectedDigest = entry['sha256'];
      if (relativePath is! String ||
          expectedBytes is! int ||
          expectedDigest is! String) {
        return false;
      }
      final filePath = p.canonicalize(
        p.joinAll([directoryPath, ...relativePath.split('/')]),
      );
      if (!p.isWithin(root, filePath)) return false;
      final file = File(filePath);
      if (!await file.exists() || await file.length() != expectedBytes) {
        return false;
      }
      if ((await sha256.bind(file.openRead()).first).toString() !=
          expectedDigest) {
        return false;
      }
    }
    return true;
  }

  Future<void> verifyDownloads(
    Iterable<TtsModelDownload> downloads,
    Map<TtsModelDownload, File> files, {
    required TtsDownloadCancellation cancellation,
    void Function(TtsModelDownload download, int verifiedBytes)? onVerifying,
    void Function(TtsModelDownload download, int verifiedBytes)? onVerified,
  }) async {
    var verifiedBytes = 0;
    for (final download in downloads) {
      onVerifying?.call(download, verifiedBytes);
      final file = files[download]!;
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != download.sha256) {
        if (await file.exists()) await file.delete();
        throw StateError('${download.fileName} failed its SHA-256 check.');
      }
      verifiedBytes += download.bytes;
      onVerified?.call(download, verifiedBytes);
      cancellation.throwIfCancelled();
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'model_archive_extractor.dart';
import 'model_integrity_verifier.dart';
import 'tts_installation.dart';
import 'tts_model_catalog.dart';

class TtsModelInstaller {
  const TtsModelInstaller({
    this.extractor = const TtsModelArchiveExtractor(),
    this.integrityVerifier = const TtsModelIntegrityVerifier(),
  });

  static const integrityManifestName = '.airstream-integrity.json';
  final TtsModelArchiveExtractor extractor;
  final TtsModelIntegrityVerifier integrityVerifier;

  Future<void> recoverInterruptedInstall(
    Directory root,
    TtsModelDefinition model,
  ) async {
    final target = Directory(p.join(root.path, model.storageKey));
    final previous =
        Directory(p.join(root.path, '.${model.storageKey}.previous'));
    if (!await previous.exists()) return;
    if (await target.exists()) {
      await previous.delete(recursive: true);
    } else {
      await previous.rename(target.path);
    }
  }

  Future<TtsModelInstallation> install({
    required Directory root,
    required Directory downloadsDirectory,
    required TtsModelDefinition model,
    required Map<TtsModelDownload, File> verifiedDownloads,
    required TtsDownloadCancellation cancellation,
  }) async {
    await recoverInterruptedInstall(root, model);
    final archiveDownload = model.downloads.singleWhere(
      (download) => download.isArchive,
    );
    final extractionArchive = File(
      p.join(downloadsDirectory.path, '${model.storageKey}.verified.tar.bz2'),
    );
    if (await extractionArchive.exists()) await extractionArchive.delete();
    await verifiedDownloads[archiveDownload]!.copy(extractionArchive.path);
    final staging =
        Directory(p.join(root.path, '.${model.storageKey}.staging'));
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    try {
      await extractor.extract(
          extractionArchive.path, staging.path, cancellation);
      cancellation.throwIfCancelled();
      final extracted = Directory(p.join(staging.path, model.archiveRoot));
      if (!await extracted.exists()) {
        throw StateError('The model archive has an unexpected structure.');
      }
      await _installSupplementaryFiles(model, verifiedDownloads, extracted);
      await _removeReplacedArtifacts(model, extracted);
      await _validateRequiredFiles(model, extracted);
      final integrityEntries = await integrityVerifier.build(
        extracted.path,
        model.requiredFiles,
      );
      await File(p.join(extracted.path, integrityManifestName)).writeAsString(
        jsonEncode({'files': integrityEntries}),
        flush: true,
      );
      await File(p.join(extracted.path, '.airstream-model.json')).writeAsString(
        jsonEncode({
          'id': model.id,
          'version': model.version,
          'integrity': model.integrityKey,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      final target = Directory(p.join(root.path, model.storageKey));
      final previous =
          Directory(p.join(root.path, '.${model.storageKey}.previous'));
      if (await previous.exists()) await previous.delete(recursive: true);
      if (await target.exists()) await target.rename(previous.path);
      try {
        await extracted.rename(target.path);
      } catch (_) {
        if (await previous.exists() && !await target.exists()) {
          await previous.rename(target.path);
        }
        rethrow;
      }
      if (await previous.exists()) await previous.delete(recursive: true);
      await staging.delete(recursive: true);
      await _deleteIfExists(extractionArchive);
      for (final partial in verifiedDownloads.values) {
        await _deleteIfExists(partial);
      }
      return TtsModelInstallation(model, target);
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      await _deleteIfExists(extractionArchive);
      rethrow;
    }
  }

  Future<void> _installSupplementaryFiles(
    TtsModelDefinition model,
    Map<TtsModelDownload, File> downloads,
    Directory extracted,
  ) async {
    for (final download in model.downloads.where((item) => !item.isArchive)) {
      final targetPath = download.targetPath;
      if (targetPath == null || targetPath.isEmpty) {
        throw StateError('${download.fileName} has no installation path.');
      }
      final target =
          File(p.joinAll([extracted.path, ...targetPath.split('/')]));
      await target.parent.create(recursive: true);
      await downloads[download]!.copy(target.path);
    }
  }

  Future<void> _removeReplacedArtifacts(
    TtsModelDefinition model,
    Directory extracted,
  ) async {
    for (final relativePath in model.removeAfterExtract) {
      final path = p.joinAll([extracted.path, ...relativePath.split('/')]);
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.file) {
        await File(path).delete();
      } else if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      }
    }
  }

  Future<void> _validateRequiredFiles(
    TtsModelDefinition model,
    Directory extracted,
  ) async {
    for (final relativePath in model.requiredFiles) {
      final path = p.joinAll([extracted.path, ...relativePath.split('/')]);
      if (!await FileSystemEntity.isFile(path) &&
          !await FileSystemEntity.isDirectory(path)) {
        throw StateError('The model archive is missing $relativePath.');
      }
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}

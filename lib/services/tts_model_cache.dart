import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';
import 'tts/model_downloader.dart';
import 'tts/model_integrity_verifier.dart';
import 'tts/model_installer.dart';
import 'tts/tts_model_catalog.dart';
import 'tts/tts_installation.dart';

export 'tts/tts_installation.dart';

class TtsModelCache {
  final Directory? _rootOverride;
  final TtsModelDownloader _downloader;
  final TtsModelInstaller _installer;
  final _verifiedInstallations = <String>{};
  TtsModelCache({
    http.Client? client,
    Directory? rootDirectory,
    int segmentedDownloadThreshold = 32 * 1024 * 1024,
    Duration connectionTimeout = const Duration(seconds: 20),
    Duration inactivityTimeout = const Duration(seconds: 30),
    int downloadAttempts = 3,
    TtsModelIntegrityVerifier integrityVerifier =
        const TtsModelIntegrityVerifier(),
  })  : _rootOverride = rootDirectory,
        _downloader = TtsModelDownloader(
          client: client,
          segmentedDownloadThreshold: segmentedDownloadThreshold,
          connectionTimeout: connectionTimeout,
          inactivityTimeout: inactivityTimeout,
          downloadAttempts: downloadAttempts,
        ),
        _installer = TtsModelInstaller(integrityVerifier: integrityVerifier);

  Future<Directory> get rootDirectory async {
    if (_rootOverride != null) return _rootOverride!;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'tts', 'models'));
  }

  Future<TtsModelInstallation?> installed(TtsModelDefinition model) async {
    final root = await rootDirectory;
    await _installer.recoverInterruptedInstall(root, model);
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
      final verificationKey = '${directory.path}|${model.integrityKey}';
      if (!_verifiedInstallations.contains(verificationKey)) {
        final manifest = File(
          p.join(directory.path, TtsModelInstaller.integrityManifestName),
        );
        if (!await manifest.exists()) return null;
        final decoded = jsonDecode(await manifest.readAsString());
        if (decoded is! Map || decoded['files'] is! List) return null;
        final entries = (decoded['files'] as List)
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
        final valid =
            await _installer.integrityVerifier.verify(directory.path, entries);
        if (!valid) return null;
        _verifiedInstallations.add(verificationKey);
      }
      return TtsModelInstallation(model, directory);
    } catch (error, stack) {
      AppLogger.warning(
        'Ignoring an invalid installed TTS model at ${directory.path}',
        error: error,
        stackTrace: stack,
      );
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
      final partial = _downloader.partialFile(downloads, model, download);
      partials[download] = partial;
      await _downloader.download(
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
    await _installer.integrityVerifier.verifyDownloads(
      model.downloads,
      partials,
      cancellation: activeCancellation,
      onVerifying: (download, verifiedBytes) {
        onProgress?.call(TtsInstallProgress(
          phase: TtsInstallPhase.verifying,
          message: 'Verifying ${download.fileName}…',
          receivedBytes: verifiedBytes,
          totalBytes: model.downloadBytes,
        ));
      },
    );
    onProgress?.call(TtsInstallProgress(
      phase: TtsInstallPhase.extracting,
      message: 'Installing ${model.name}…',
      receivedBytes: model.downloadBytes,
      totalBytes: model.downloadBytes,
    ));
    final installation = await _installer.install(
      root: root,
      downloadsDirectory: downloads,
      model: model,
      verifiedDownloads: partials,
      cancellation: activeCancellation,
    );
    _verifiedInstallations.add(
      '${installation.directory.path}|${model.integrityKey}',
    );
    onProgress?.call(TtsInstallProgress(
      phase: TtsInstallPhase.installed,
      message: '${model.name} is ready.',
      receivedBytes: model.downloadBytes,
      totalBytes: model.downloadBytes,
      path: installation.directory.path,
    ));
    return installation;
  }

  Future<void> remove(TtsModelDefinition model) async {
    final root = await rootDirectory;
    final target = Directory(p.join(root.path, model.storageKey));
    if (await target.exists()) await target.delete(recursive: true);
    _verifiedInstallations.removeWhere(
      (key) => key.startsWith('${target.path}|'),
    );
  }

  void dispose() {}
}

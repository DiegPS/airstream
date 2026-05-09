import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsModelAsset {
  final String relativePath;
  final int sizeBytes;

  const TtsModelAsset({
    required this.relativePath,
    required this.sizeBytes,
  });

  String get fileName => relativePath.split('/').last;
  Uri get downloadUri => Uri.parse(
        'https://huggingface.co/Supertone/supertonic-3/resolve/main/$relativePath',
      );
}

class TtsDownloadProgress {
  final String message;
  final String? currentFile;
  final int downloadedFiles;
  final int totalFiles;
  final int downloadedBytes;
  final int totalBytes;
  final String cacheDirectory;

  const TtsDownloadProgress({
    required this.message,
    required this.currentFile,
    required this.downloadedFiles,
    required this.totalFiles,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.cacheDirectory,
  });
}

class TtsModelPaths {
  final Directory cacheDirectory;
  final Directory onnxDirectory;
  final Directory voiceStylesDirectory;

  const TtsModelPaths({
    required this.cacheDirectory,
    required this.onnxDirectory,
    required this.voiceStylesDirectory,
  });

  String voiceStylePath(String voice) =>
      '${voiceStylesDirectory.path}${Platform.pathSeparator}$voice.json';
}

class TtsModelCache {
  static const List<TtsModelAsset> manifest = [
    TtsModelAsset(relativePath: 'onnx/tts.json', sizeBytes: 8253),
    TtsModelAsset(
      relativePath: 'onnx/duration_predictor.onnx',
      sizeBytes: 3700147,
    ),
    TtsModelAsset(
      relativePath: 'onnx/text_encoder.onnx',
      sizeBytes: 36416150,
    ),
    TtsModelAsset(
      relativePath: 'onnx/vector_estimator.onnx',
      sizeBytes: 256534781,
    ),
    TtsModelAsset(
      relativePath: 'onnx/vocoder.onnx',
      sizeBytes: 101424195,
    ),
    TtsModelAsset(
      relativePath: 'onnx/unicode_indexer.json',
      sizeBytes: 277676,
    ),
    TtsModelAsset(relativePath: 'voice_styles/F1.json', sizeBytes: 292046),
    TtsModelAsset(relativePath: 'voice_styles/F2.json', sizeBytes: 292423),
    TtsModelAsset(relativePath: 'voice_styles/F3.json', sizeBytes: 290794),
    TtsModelAsset(relativePath: 'voice_styles/F4.json', sizeBytes: 291808),
    TtsModelAsset(relativePath: 'voice_styles/F5.json', sizeBytes: 291479),
    TtsModelAsset(relativePath: 'voice_styles/M1.json', sizeBytes: 291748),
    TtsModelAsset(relativePath: 'voice_styles/M2.json', sizeBytes: 292055),
    TtsModelAsset(relativePath: 'voice_styles/M3.json', sizeBytes: 290198),
    TtsModelAsset(relativePath: 'voice_styles/M4.json', sizeBytes: 291522),
    TtsModelAsset(relativePath: 'voice_styles/M5.json', sizeBytes: 291469),
  ];

  final http.Client _client;

  TtsModelCache({http.Client? client}) : _client = client ?? http.Client();

  static int get totalBytes =>
      manifest.fold(0, (sum, asset) => sum + asset.sizeBytes);

  static int get totalFiles => manifest.length;

  Future<TtsModelPaths> ensureAvailable({
    void Function(TtsDownloadProgress progress)? onProgress,
  }) async {
    final root = await getApplicationCacheDirectory();
    final cacheDirectory = Directory(
      '${root.path}${Platform.pathSeparator}supertonic-3',
    );
    final onnxDirectory = Directory(
      '${cacheDirectory.path}${Platform.pathSeparator}onnx',
    );
    final voiceStylesDirectory = Directory(
      '${cacheDirectory.path}${Platform.pathSeparator}voice_styles',
    );

    await onnxDirectory.create(recursive: true);
    await voiceStylesDirectory.create(recursive: true);

    final existing = await _collectExistingAssets(cacheDirectory);
    final missing = manifest
        .where((asset) =>
            !existing.any((entry) => entry.relativePath == asset.relativePath))
        .toList();

    if (missing.isEmpty) {
      onProgress?.call(
        TtsDownloadProgress(
          message: 'Using cached Supertonic models.',
          currentFile: null,
          downloadedFiles: totalFiles,
          totalFiles: totalFiles,
          downloadedBytes: totalBytes,
          totalBytes: totalBytes,
          cacheDirectory: cacheDirectory.path,
        ),
      );
      return TtsModelPaths(
        cacheDirectory: cacheDirectory,
        onnxDirectory: onnxDirectory,
        voiceStylesDirectory: voiceStylesDirectory,
      );
    }

    var downloadedFiles = existing.length;
    var downloadedBytes =
        existing.fold(0, (sum, asset) => sum + asset.sizeBytes);

    onProgress?.call(
      TtsDownloadProgress(
        message: 'Downloading Supertonic models to system cache...',
        currentFile: null,
        downloadedFiles: downloadedFiles,
        totalFiles: totalFiles,
        downloadedBytes: downloadedBytes,
        totalBytes: totalBytes,
        cacheDirectory: cacheDirectory.path,
      ),
    );

    for (final asset in missing) {
      final targetFile = File(
        '${cacheDirectory.path}${Platform.pathSeparator}${asset.relativePath.replaceAll('/', Platform.pathSeparator)}',
      );
      await targetFile.parent.create(recursive: true);
      final tempFile = File('${targetFile.path}.part');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final request = http.Request('GET', asset.downloadUri);
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Failed to download ${asset.relativePath} (HTTP ${response.statusCode})',
          uri: asset.downloadUri,
        );
      }

      final sink = tempFile.openWrite();
      var fileBytes = 0;
      try {
        await for (final chunk in response.stream) {
          fileBytes += chunk.length;
          downloadedBytes += chunk.length;
          sink.add(chunk);
          onProgress?.call(
            TtsDownloadProgress(
              message: 'Downloading ${asset.fileName}...',
              currentFile: asset.relativePath,
              downloadedFiles: downloadedFiles,
              totalFiles: totalFiles,
              downloadedBytes: downloadedBytes,
              totalBytes: totalBytes,
              cacheDirectory: cacheDirectory.path,
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (fileBytes != asset.sizeBytes) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        throw StateError(
          'Unexpected size for ${asset.relativePath}. Expected ${asset.sizeBytes}, got $fileBytes.',
        );
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
      downloadedFiles++;
      onProgress?.call(
        TtsDownloadProgress(
          message: '${asset.fileName} downloaded.',
          currentFile: asset.relativePath,
          downloadedFiles: downloadedFiles,
          totalFiles: totalFiles,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          cacheDirectory: cacheDirectory.path,
        ),
      );
    }

    onProgress?.call(
      TtsDownloadProgress(
        message: 'All Supertonic files are cached.',
        currentFile: null,
        downloadedFiles: totalFiles,
        totalFiles: totalFiles,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        cacheDirectory: cacheDirectory.path,
      ),
    );

    return TtsModelPaths(
      cacheDirectory: cacheDirectory,
      onnxDirectory: onnxDirectory,
      voiceStylesDirectory: voiceStylesDirectory,
    );
  }

  Future<List<TtsModelAsset>> _collectExistingAssets(
      Directory cacheDirectory) async {
    final existing = <TtsModelAsset>[];
    for (final asset in manifest) {
      final file = File(
        '${cacheDirectory.path}${Platform.pathSeparator}${asset.relativePath.replaceAll('/', Platform.pathSeparator)}',
      );
      if (!await file.exists()) {
        continue;
      }
      final length = await file.length();
      if (length != asset.sizeBytes) {
        await file.delete();
        continue;
      }
      existing.add(asset);
    }
    return existing;
  }

  void dispose() {
    _client.close();
  }
}

import 'dart:io';

import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_model_cache.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory root;
  late List<int> archiveBytes;
  late TtsModelDefinition model;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('airstream-tts-cache-test-');
    final archive = Archive()
      ..addFile(ArchiveFile('fixture/model.onnx', 5, [1, 2, 3, 4, 5]));
    archiveBytes = BZip2Encoder().encode(TarEncoder().encode(archive));
    model = TtsModelDefinition(
      id: 'fixture',
      version: '1',
      name: 'Fixture',
      description: 'Test model',
      family: TtsModelFamily.piper,
      archiveUri: Uri.parse('https://example.test/model.tar.bz2'),
      archiveBytes: archiveBytes.length,
      installedBytes: 5,
      sha256: sha256.convert(archiveBytes).toString(),
      archiveRoot: 'fixture',
      requiredFiles: const ['model.onnx'],
      languages: const [TtsLanguageOption('es', 'Español')],
      voices: const [TtsVoiceOption('voice', 'Voice', 0)],
      licenseName: 'Test',
      licenseUri: Uri.parse('https://example.test/license'),
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('installs only after hash verification and extraction', () async {
    final client = MockClient(
        (request) async => http.Response.bytes(archiveBytes, HttpStatus.ok));
    final cache = TtsModelCache(client: client, rootDirectory: root);

    final installation = await cache.ensureAvailable(model);

    expect(await File(installation.file('model.onnx')).readAsBytes(),
        [1, 2, 3, 4, 5]);
    expect(await cache.installed(model), isNotNull);
  });

  test('resumes a partial archive with an HTTP range request', () async {
    final split = archiveBytes.length ~/ 2;
    final downloads =
        Directory('${root.path}${Platform.pathSeparator}.downloads');
    await downloads.create(recursive: true);
    await File(
            '${downloads.path}${Platform.pathSeparator}${model.storageKey}.tar.bz2.part')
        .writeAsBytes(archiveBytes.take(split).toList());
    final client = MockClient((request) async {
      expect(request.headers[HttpHeaders.rangeHeader], 'bytes=$split-');
      return http.Response.bytes(
          archiveBytes.skip(split).toList(), HttpStatus.partialContent);
    });

    final installation = await TtsModelCache(
      client: client,
      rootDirectory: root,
    ).ensureAvailable(model);

    expect(await File(installation.file('model.onnx')).exists(), isTrue);
  });

  test('rejects and removes an archive with the wrong digest', () async {
    final corrupt = [...archiveBytes]..[archiveBytes.length ~/ 2] ^= 0xff;
    final client = MockClient(
        (request) async => http.Response.bytes(corrupt, HttpStatus.ok));
    final cache = TtsModelCache(client: client, rootDirectory: root);

    await expectLater(cache.ensureAvailable(model), throwsStateError);

    expect(await cache.installed(model), isNull);
    expect(
      await File(
              '${root.path}${Platform.pathSeparator}.downloads${Platform.pathSeparator}'
              '${model.storageKey}.tar.bz2.part')
          .exists(),
      isFalse,
    );
  });

  test('cancels safely while preserving resumable partial data', () async {
    final cancellation = TtsDownloadCancellation();
    final client = MockClient(
      (request) async => http.Response.bytes(archiveBytes, HttpStatus.ok),
    );
    final cache = TtsModelCache(client: client, rootDirectory: root);

    await expectLater(
      cache.ensureAvailable(
        model,
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.phase == TtsInstallPhase.downloading) {
            cancellation.cancel();
          }
        },
      ),
      throwsA(isA<TtsDownloadCancelledException>()),
    );

    final partial = File(
      '${root.path}${Platform.pathSeparator}.downloads${Platform.pathSeparator}'
      '${model.storageKey}.tar.bz2.part',
    );
    expect(await partial.exists(), isTrue);
  });
}

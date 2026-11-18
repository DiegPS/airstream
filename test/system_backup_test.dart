import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/services/system_backup.dart';
import 'package:airstream/services/templates/template_archive.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/settings/secure_settings_store.dart';
import 'package:airstream/settings/settings_document.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'package:airstream/settings/settings_repository.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _mediaId = '0123456789abcdef';
const _png = [137, 80, 78, 71, 13, 10, 26, 10];

void main() {
  late Directory temp, support;
  late TemplateLibrary templates;
  late MediaLibrary media;
  late _TestSettings settings;
  late _SettingsRepository repository;
  late _SecureStore secure;
  late SystemBackup backup;

  final portable = SettingsModel(
    fontSize: 26,
    obsPassword: 'exported-obs-secret',
    rulesWebhookToken: '0123456789abcdef0123456789abcdef',
    rulesWebhookEnabled: true,
    rules: [
      {
        ...RuleSchema.newRule('manual', id: 'stable'),
        'actions': [
          {
            'id': 'notify',
            'type': 'http.request',
            'method': 'post',
            'contentType': 'json',
            'body': '{}',
            'url': 'https://example.invalid/private-exported-endpoint',
          },
          {
            'id': 'sound',
            'type': 'sound.play',
            'source': 'library',
            'name': 'coin',
            'mediaId': _mediaId,
          },
        ],
      },
    ],
    ruleCounters: {'wins': 19},
    mediaLibrary: const {
      _mediaId: {
        'name': 'Imagen.png',
        'kind': 'image',
        'ext': 'png',
        'bytes': 8,
        'addedAt': 101,
      },
    },
    profiles: const {
      'Profile': {
        'fontSize': 24,
        'obsPassword': 'nested-obs',
        'rulesWebhookToken': 'nested-token',
      },
    },
  );
  final local = SettingsModel(
    fontSize: 12,
    obsPassword: 'local-obs',
    rulesWebhookToken: 'abcdef0123456789abcdef0123456789',
    rules: [
      {
        ...portable.rules.single,
        'actions': [
          {
            ...(portable.rules.single['actions'] as List).first,
            'url': 'https://example.invalid/private-local-endpoint',
          },
        ],
      },
    ],
    ruleCounters: const {'wins': 2},
  );

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('system-backup-test-');
    support = Directory(p.join(temp.path, 'support'));
    templates = TemplateLibrary(Directory(p.join(temp.path, 'templates')));
    repository = _SettingsRepository(SettingsDocumentCodec.encode(local));
    secure = _SecureStore(local.obsPassword);
    settings = _TestSettings(
      settingsRepository: repository,
      secureStore: secure,
      systemLanguageCode: () => 'en',
    );
    await settings.ready;
    media = MediaLibrary(Directory(p.join(support.path, 'media')),
        () => settings.current.mediaLibrary);
    backup = SystemBackup(
        support: support,
        templates: templates,
        media: media,
        appVersion: 'test');
  });
  tearDown(() async {
    settings.dispose();
    await templates.dispose();
    await temp.delete(recursive: true);
  });

  Future<File> write(
      Directory root, List<String> parts, String contents) async {
    final file = File(p.join(root.path, p.joinAll(parts)));
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  test('backup validation lists only templates requesting Internet access',
      () async {
    for (final (id, manifest) in [
      ('online', '{"name":"Online Clock","network":true}'),
      ('offline', '{"name":"Offline Clock","network":false}'),
      ('implicit', '{"name":"Implicit Clock"}'),
      ('wrong-type', '{"name":"Wrong Type","network":"true"}'),
      ('fallback', '{"network":true}'),
      ('invalid', '{"network":true'),
    ]) {
      await write(templates.root, [id, 'template.json'], manifest);
      await write(templates.root, [id, 'index.html'], '<p>Sample</p>');
    }
    final path = p.join(temp.path, 'permissions.airstream-backup');
    await backup.export(path, const SettingsModel());
    final validated = await backup.validate(path);
    addTearDown(validated.dispose);
    expect(validated.templates, 6);
    expect(validated.networkTemplateNames, ['fallback', 'Online Clock']);
  });

  Future<String> makePortable() async {
    await write(
        templates.root, ['original', 'index.html'], '<h1>Original</h1>');
    await write(templates.root, ['original', 'values.json'], '{"name":"test"}');
    await write(
        templates.root, ['original', 'assets', 'fólder file.dat'], 'asset');
    await Directory(p.join(templates.rootPath, 'empty')).create();
    await media.directory.create(recursive: true);
    final asset = File(p.join(media.directory.path, '$_mediaId.png'));
    await asset.writeAsBytes(_png);
    final path = p.join(temp.path, 'portable.airstream-backup');
    await backup.export(path, portable);
    await asset.delete();
    await Directory(p.join(templates.rootPath, 'original'))
        .delete(recursive: true);
    await Directory(p.join(templates.rootPath, 'empty')).delete();
    return path;
  }

  test(
      'restores settings, rule counters, templates and media, preserving local credentials',
      () async {
    final path = await makePortable();
    final zip = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final document = utf8.decode(zip.findFile('settings.json')!.content);
    expect(document, isNot(contains('obsPassword')));
    expect(document, isNot(contains('rulesWebhookToken')));
    expect(document, isNot(contains('private-exported-endpoint')));
    expect(jsonDecode(utf8.decode(zip.findFile('manifest.json')!.content)),
        containsPair('appVersion', 'test'));
    final current =
        await write(templates.root, ['current', 'index.html'], 'local');
    final guide = await write(templates.root, ['AGENTS.md'], 'guide');

    final validated = await backup.validate(path);
    addTearDown(validated.dispose);
    expect((validated.rules, validated.templates, validated.media), (1, 2, 1));
    // Confirmation uses the validated snapshot even if the selected ZIP changes.
    await File(path).writeAsString('replacement');
    await backup.restore(validated, settings);
    expect(settings.current.fontSize, 26);
    expect(settings.current.ruleCounters, {'wins': 19});
    expect(settings.current.obsPassword, 'local-obs');
    expect(settings.current.rulesWebhookEnabled, isFalse);
    expect(settings.current.rulesWebhookToken, local.rulesWebhookToken);
    expect(secure.writes, 0);
    final actions = settings.current.rules.single['actions'] as List;
    expect(
        actions.first['url'], 'https://example.invalid/private-local-endpoint');
    expect(actions.last['mediaId'], _mediaId);
    expect(settings.current.mediaLibrary, portable.mediaLibrary);
    expect(settings.current.profiles['Profile'], {'fontSize': 24});
    expect(
        await File(p.join(media.directory.path, '$_mediaId.png')).readAsBytes(),
        _png);
    expect(await current.exists(), isFalse);
    expect(await guide.readAsString(), 'guide');
    expect(
        await File(p.join(
                templates.rootPath, 'original', 'assets', 'fólder file.dat'))
            .readAsString(),
        'asset');
    expect(
        await Directory(p.join(templates.rootPath, 'empty')).exists(), isTrue);
    expect(
        SettingsDocumentCodec.decode(repository.source).settings.ruleCounters,
        {'wins': 19});

    final safety =
        Directory(p.join(support.path, 'safety-backups')).listSync().single;
    final original = await backup.validate(safety.path);
    addTearDown(original.dispose);
    expect((original.rules, original.templates, original.media), (1, 1, 0));
  });

  test('missing media is skipped in portable and safety backups', () async {
    final incoming = await makePortable();
    const missingId = 'fedcba9876543210';
    await File(p.join(media.directory.path, '$_mediaId.png'))
        .writeAsBytes(_png);
    await settings.update(local.copyWith(mediaLibrary: {
      ...portable.mediaLibrary,
      missingId: portable.mediaLibrary[_mediaId]!,
    }));
    final exported = p.join(temp.path, 'without-missing.airstream-backup');
    await backup.export(exported, settings.current);
    final archive = await backup.validate(exported);
    addTearDown(archive.dispose);
    expect(archive.media, 1);
    final validated = await backup.validate(incoming);
    addTearDown(validated.dispose);
    await backup.restore(validated, settings);
    expect(settings.current.mediaLibrary.keys, [_mediaId]);
    final safety =
        Directory(p.join(support.path, 'safety-backups')).listSync().single;
    final saved = await backup.validate(safety.path);
    addTearDown(saved.dispose);
    expect(saved.media, 1);
  });

  test(
      'automatic safety copy omits endpoints and restores removed rules with empty URLs',
      () async {
    final exported = p.join(temp.path, 'empty.airstream-backup');
    await backup.export(exported, const SettingsModel());
    final replacement = await backup.validate(exported);
    addTearDown(replacement.dispose);
    await backup.restore(replacement, settings);
    expect(settings.current.rules, isEmpty);

    final safety =
        Directory(p.join(support.path, 'safety-backups')).listSync().single;
    final zip = ZipDecoder().decodeBytes(await File(safety.path).readAsBytes());
    final document = utf8.decode(zip.findFile('settings.json')!.content);
    expect(document, isNot(contains('private-local-endpoint')));
    expect(document, isNot(contains('obsPassword')));
    expect(document, isNot(contains('rulesWebhookToken')));
    final saved = await backup.validate(safety.path);
    addTearDown(saved.dispose);
    expect(saved.rulesMissingHttpUrls(settings.current), hasLength(1));
    await backup.restore(saved, settings);
    expect(
        (settings.current.rules.single['actions'] as List).single['url'], '');
  });

  test('settings persistence failure rolls back both library replacements',
      () async {
    final path = await makePortable();
    final original =
        await write(templates.root, ['local', 'index.html'], 'keep');
    final validated = await backup.validate(path);
    addTearDown(validated.dispose);
    final document = repository.source;
    repository.beforeWrite = () async {
      expect(await original.exists(), isFalse);
      expect(await File(p.join(media.directory.path, '$_mediaId.png')).exists(),
          isTrue);
      throw StateError('simulated settings write failure');
    };
    await expectLater(backup.restore(validated, settings), throwsStateError);
    expect(repository.source, document);
    expect(settings.current.ruleCounters, local.ruleCounters);
    expect(await original.readAsString(), 'keep');
    expect(await media.directory.list().toList(), isEmpty);
  });

  test(
      'keeps the latest three safety backups with the most recent current settings',
      () async {
    final path = await makePortable();
    final validated = await backup.validate(path);
    addTearDown(validated.dispose);
    for (var value = 13; value <= 17; value++) {
      await settings
          .update(settings.current.copyWith(fontSize: value.toDouble()));
      await backup.restore(validated, settings);
    }
    final safety = Directory(p.join(support.path, 'safety-backups'));
    final files = safety.listSync()..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(3));
    final sizes = [
      for (final file in files)
        SettingsDocumentCodec.decode(utf8.decode(ZipDecoder()
                .decodeBytes(await File(file.path).readAsBytes())
                .findFile('settings.json')!
                .content))
            .settings
            .fontSize,
    ];
    expect(sizes, [15, 16, 17]);
  });

  const validManifest = {
    'format': 'airstream-backup',
    'version': 1,
    'createdAt': '2026-01-01T00:00:00Z',
    'counts': {'rules': 0, 'templates': 0, 'media': 0},
  };
  for (final (label, manifest, unsafePath, limits, reason) in [
    (
      'bad manifest',
      {...validManifest, 'format': 'other'},
      null,
      null,
      'invalid'
    ),
    ('future version', {...validManifest, 'version': 2}, null, null, 'version'),
    (
      'incorrect counts',
      {...validManifest, 'counts': {}},
      null,
      null,
      'invalid'
    ),
    ('parent traversal', validManifest, '../outside', null, 'path'),
    ('absolute Unix path', validManifest, '/outside', null, 'path'),
    ('absolute Windows path', validManifest, 'C:/outside', null, 'path'),
    ('Windows alternate stream', validManifest, 'temp:outside', null, 'path'),
    (
      'oversize file',
      validManifest,
      null,
      const TemplateArchiveLimits(file: 80),
      'size'
    ),
    (
      'oversize total',
      validManifest,
      null,
      const TemplateArchiveLimits(total: 100),
      'size'
    ),
    (
      'oversize ZIP',
      validManifest,
      null,
      const TemplateArchiveLimits(zip: 3),
      'size'
    ),
  ]) {
    test('rejects $label before changing state', () async {
      final original =
          await write(templates.root, ['local', 'index.html'], 'keep');
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
        ..addFile(ArchiveFile.string(
            'settings.json', SettingsProfiles.export(const SettingsModel())));
      if (unsafePath != null) {
        archive.addFile(ArchiveFile.string(unsafePath, 'bad'));
      }
      final path = p.join(temp.path, 'invalid.zip');
      await File(path).writeAsBytes(ZipEncoder().encode(archive));
      final service = limits == null
          ? backup
          : SystemBackup(
              support: support,
              templates: templates,
              media: media,
              limits: limits);
      final document = repository.source;
      await expectLater(
          service.validate(path),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'reason', reason)));
      expect(await original.readAsString(), 'keep');
      expect(await media.directory.exists(), isFalse);
      expect(repository.source, document);
      expect(settings.current.ruleCounters, local.ruleCounters);
      expect(await support.list().toList(), isEmpty);
    });
  }

  test('restore ignores archive URLs and preserves only matching local URLs',
      () async {
    final matching = portable.rules.single;
    final incoming = SettingsModel(rules: [
      {...matching, 'enabled': true},
      {
        ...matching,
        'id': 'foreign',
        'name': 'Foreign endpoint',
        'enabled': true
      },
    ]);
    final archive = Archive()
      ..addFile(ArchiveFile.string(
          'manifest.json',
          jsonEncode({
            ...validManifest,
            'counts': {'rules': 2, 'templates': 0, 'media': 0},
          })))
      ..addFile(ArchiveFile.string(
          'settings.json', SettingsDocumentCodec.encode(incoming)));
    final file = File(p.join(temp.path, 'foreign.airstream-backup'));
    await file.writeAsBytes(ZipEncoder().encode(archive));
    final validated = await backup.validate(file.path);
    addTearDown(validated.dispose);
    await backup.restore(validated, settings);

    String url(Map rule) => (rule['actions'] as List).first['url'] as String;
    expect(settings.current.rules.map(url), [
      'https://example.invalid/private-local-endpoint',
      '',
    ]);
    expect(validated.rulesMissingHttpUrls(local), ['Foreign endpoint']);
    expect(
        SettingsProfiles.import(SettingsDocumentCodec.encode(incoming), local)
            .rules
            .map(url),
        settings.current.rules.map(url));
  });

  test('ignores an unknown entry and rejects mismatched local path and CRC',
      () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('future.txt', 'unused'))
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode(validManifest)))
      ..addFile(ArchiveFile.string(
          'settings.json', SettingsProfiles.export(const SettingsModel())));
    final file = File(p.join(temp.path, 'versioned.zip'));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    await file.writeAsBytes(bytes);
    final validated = await backup.validate(file.path);
    await validated.dispose();
    final data = ByteData.sublistView(bytes);
    final filename = utf8.encode('future.txt');
    bytes.setAll(30, utf8.encode('../bad.txt'));
    await file.writeAsBytes(bytes);
    await expectLater(backup.validate(file.path), throwsFormatException);
    bytes.setAll(30, filename);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50 &&
          bytes[i + 46] == 'm'.codeUnitAt(0)) {
        data.setUint32(i + 16, 0, Endian.little);
        break;
      }
    }
    await file.writeAsBytes(bytes);
    await expectLater(backup.validate(file.path), throwsFormatException);
    expect(await support.list().toList(), isEmpty);
  });
}

class _SettingsRepository implements SettingsRepository {
  _SettingsRepository(this.source);
  String source;
  Future<void> Function()? beforeWrite;

  @override
  Future<String> read() async => source;

  @override
  Future<void> write(String json) async {
    await beforeWrite?.call();
    source = json;
  }
}

class _SecureStore implements SecureSettingsStore {
  _SecureStore(this.password);
  final String password;
  int writes = 0;

  @override
  Future<void> deleteObsPassword() async => writes++;

  @override
  Future<String> readObsPassword() async => password;

  @override
  Future<void> writeObsPassword(String password) async => writes++;
}

class _TestSettings extends SettingsNotifier {
  _TestSettings(
      {super.settingsRepository, super.secureStore, super.systemLanguageCode});

  SettingsModel get current => state;
}

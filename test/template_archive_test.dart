import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:airstream/services/templates/template_archive.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late TemplateLibrary library;
  const service = TemplateArchive();
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('archives-');
    library = TemplateLibrary(Directory(p.join(temp.path, 'templates')));
  });
  tearDown(() async {
    await library.dispose();
    await temp.delete(recursive: true);
  });
  Future<String> zip(Map<String, List<int>> files, {ArchiveFile? extra}) async {
    final archive = Archive();
    for (final e in files.entries) {
      archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    }
    if (extra != null) archive.addFile(extra);
    final file = File(p.join(temp.path, 'source.zip'));
    final bytes = ZipEncoder().encode(archive);
    // ZipEncoder normalizes backslashes; restore the hostile raw name in both headers.
    if (files.keys.any((k) => k.contains(r''))) {
      for (var i = 0; i < bytes.length - 6; i++) {
        if (bytes[i] == 97 &&
            bytes[i + 1] == 47 &&
            bytes[i + 2] == 98 &&
            bytes[i + 3] == 46 &&
            bytes[i + 4] == 106 &&
            bytes[i + 5] == 115) {
          bytes[i + 1] = 92;
        }
      }
    }
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> reject(Map<String, List<int>> files,
      {TemplateArchive archive = service, ArchiveFile? extra}) async {
    final path = await zip(files, extra: extra);
    await expectLater(archive.validate(path), throwsFormatException);
    expect(await library.root.exists(), isFalse);
  }

  test('limits the total installed template size before importing', () async {
    final existing = File(p.join(library.rootPath, 'installed', 'asset.png'));
    await existing.parent.create(recursive: true);
    final handle = await existing.open(mode: FileMode.write);
    try {
      await handle.truncate(100 * 1024 * 1024);
    } finally {
      await handle.close();
    }
    final archive = await service.validate(await zip({
      'index.html': utf8.encode('<html>hi</html>'),
    }));
    await expectLater(service.import(library, archive), throwsFormatException);
    expect(
        library.root
            .listSync()
            .whereType<Directory>()
            .map((entry) => p.basename(entry.path)),
        ['installed']);
  });

  for (final prefix in ['', 'my-chat/']) {
    test('imports valid $prefix and round trips identical files', () async {
      final source = {
        '${prefix}index.html': utf8.encode('<html>hi</html>'),
        '${prefix}template.json': utf8.encode('{"name":"Chat","network":true}'),
        '${prefix}values.json': utf8.encode('{"color":"#ff0000"}'),
        '${prefix}assets/a.png': [1, 2, 3]
      };
      final validated = await service.validate(await zip(source));
      expect(validated.network, isTrue);
      final id = await service.import(library, validated);
      expect((await library.list()).single.problems, isEmpty);
      final dest = p.join(temp.path, 'out.zip');
      await service.export(library, id, dest);
      final again = await service.import(library, await service.validate(dest));
      expect(again, '$id-2');
      for (final name in [
        'index.html',
        'template.json',
        'values.json',
        'assets/a.png'
      ]) {
        expect(await File(p.join(library.rootPath, id, name)).readAsBytes(),
            await File(p.join(library.rootPath, again, name)).readAsBytes());
      }
      expect(
          library.root
              .listSync()
              .where((f) => p.basename(f.path).startsWith('.import-')),
          isEmpty);
    });
  }
  for (final name in [
    '../evil.js',
    '/abs.js',
    'C:/x.js',
    r'a\b.js',
    '.hidden/x.js',
    'a/./b.js',
    'a//b.js',
    'a/b/c/d/e/f/g.js',
    'bad.exe'
  ]) {
    test(
        'rejects $name without writing',
        () => reject({
              'index.html': [1],
              name: [2]
            }));
  }
  test(
      'rejects two top folders',
      () => reject({
            'a/index.html': [1],
            'b/test.js': [1]
          }));
  test(
      'rejects missing index',
      () => reject({
            'hello.js': [1]
          }));
  test(
      'rejects symlink',
      () => reject({
            'index.html': [1]
          },
              extra: ArchiveFile('link.js', 1, [1])
                ..symbolicLink = 'index.html'
                ..mode = 0xa1ff));
  test(
      'rejects 501 files',
      () => reject({
            'index.html': [1],
            for (var i = 0; i < 500; i++) 'f$i.js': [1]
          }));
  test(
      'rejects declared total before decode',
      () => reject({
            'index.html': [1, 2],
            'a.js': [3, 4]
          },
              archive: const TemplateArchive(
                  limits: TemplateArchiveLimits(total: 3))));
  test(
      'rejects file size before decode',
      () => reject({
            'index.html': [1, 2]
          },
              archive: const TemplateArchive(
                  limits: TemplateArchiveLimits(file: 1))));
  test(
      'rejects zip size',
      () => reject({
            'index.html': [1]
          },
              archive: const TemplateArchive(
                  limits: TemplateArchiveLimits(zip: 1))));
  test('rejects real inflation past declared size', () async {
    final path = await zip({'index.html': List.filled(10000, 65)});
    final bytes = await File(path).readAsBytes();
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 24, 1, Endian.little);
      }
    }
    await File(path).writeAsBytes(bytes);
    await expectLater(service.validate(path), throwsFormatException);
    expect(await library.root.exists(), isFalse);
  });
  test('rejects a declared total over 100 MB without allocating it', () async {
    final path = await zip({
      'index.html': [1],
      'a.js': [1],
      'b.js': [1]
    });
    final bytes = await File(path).readAsBytes();
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 24, 40 * 1024 * 1024, Endian.little);
      }
    }
    await File(path).writeAsBytes(bytes);
    await expectLater(
        service.validate(path),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'reason', 'total')));
    expect(await library.root.exists(), isFalse);
  });
  test('failed extraction deletes its staging folder', () async {
    final validated = await service.validate(await zip({
      'index.html': [1],
      'a.js': [1],
      'a.js/b.js': [2]
    }));
    await expectLater(service.import(library, validated),
        throwsA(isA<FileSystemException>()));
    expect(
        library.root
            .listSync()
            .where((f) => p.basename(f.path).startsWith('.import-')),
        isEmpty);
    expect(await library.list(), isEmpty);
  });
  test('skips OS metadata', () async {
    final a = await service.validate(await zip({
      'index.html': [1],
      '__MACOSX/._index.html': [1],
      '.DS_Store': [1],
      'Thumbs.db': [1],
      'desktop.ini': [1]
    }));
    expect(a.count, 1);
  });
  test('duplicate renames, handles collisions and skips dotfiles and links',
      () async {
    final id = await service.import(
        library,
        await service.validate(await zip({
          'index.html': [1],
          'template.json': utf8.encode('{"name":"Chat","extra":7}')
        })));
    await File(p.join(library.rootPath, id, '.secret')).writeAsString('secret');
    await File(p.join(library.rootPath, id, 'bad.exe')).writeAsString('bad');
    try {
      await Link(p.join(library.rootPath, id, 'linked.js'))
          .create(p.join(library.rootPath, id, 'index.html'));
    } on FileSystemException {/* Windows without symlink privilege. */}
    final copy = await service.duplicate(library, id, 'copy');
    expect(copy, '$id-copy');
    final raw = jsonDecode(
        await File(p.join(library.rootPath, copy, 'template.json'))
            .readAsString()) as Map;
    expect(raw['name'], 'Chat (copy)');
    expect(raw['extra'], 7);
    expect(Directory(p.join(library.rootPath, copy)).listSync().length, 2);
    expect(await service.duplicate(library, id, 'copia'), '$id-copy-2');
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:airstream/services/templates/template_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late TemplateLibrary library;
  Future<File> put(String path, String value) async {
    final file = File('${library.rootPath}/$path');
    await file.parent.create(recursive: true);
    return file.writeAsString(value);
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('airstream-library-');
    library = TemplateLibrary(Directory('${temp.path}/templates'));
  });
  tearDown(() async {
    await library.dispose();
    await temp.delete(recursive: true);
  });
  test('root stays absent until ensureRoot and ids are strict', () async {
    expect(await library.exists(), false);
    expect(await library.list(), isEmpty);
    await library.watch();
    expect(await library.exists(), false);
    for (final id in ['a', '1-test', 'a' * 40]) {
      expect(TemplateLibrary.validId(id), true);
    }
    for (final id in ['', '.hidden', 'A', '-a', 'a_b', 'a' * 41, '../a']) {
      expect(TemplateLibrary.validId(id), false);
      expect(await library.get(id), null);
    }
    await library.ensureRoot();
    expect(await library.exists(), true);
  });
  test('retains valid gallery versions and ignores malformed metadata',
      () async {
    final variants = <Object?, bool>{
      {'id': 'recent-support', 'version': 1}: true,
      {'id': '-' * 40, 'version': 1000}: true,
      {'id': 'recent-support', 'version': 0}: false,
      {'id': 'recent-support', 'version': 1001}: false,
      {'id': 'recent-support', 'version': 1.0}: false,
      {'id': 'recent-support', 'version': '1'}: false,
      {'id': 'recent-support'}: false,
      {'id': 'Recent-Support', 'version': 1}: false,
      {'id': 'a' * 41, 'version': 1}: false,
      {'id': '../recent-support', 'version': 1}: false,
      ['recent-support', 1]: false,
      null: false,
    };
    for (final (i, entry) in variants.entries.indexed) {
      await put('item-$i/index.html', '<h1>Widget</h1>');
      await put('item-$i/template.json', jsonEncode({'gallery': entry.key}));
      final info = (await library.get('item-$i'))!;
      expect(info.usable, true);
      expect(info.problems, isEmpty);
      final raw = entry.key;
      expect(
          info.manifest.gallery,
          entry.value && raw is Map
              ? (id: raw['id'], version: raw['version'])
              : null);
    }
  });

  test('lists incomplete templates and ignores invalid folders', () async {
    await put('good/style.css', '');
    await put('.hidden/index.html', '');
    await put('Invalid/index.html', '');
    final list = await library.list();
    expect(list.map((v) => v.id), ['good']);
    expect(list.single.problems, ['missingIndex']);
    await put('good/index.html', 'hello');
    expect((await library.get('good'))!.usable, true);
    await put('good/index.html', 'x' * (2 * 1024 * 1024 + 1));
    expect((await library.get('good'))!.problems, contains('oversizedIndex'));
  });
  test('manifest sanitizes every field type and values use sanitized defaults',
      () async {
    await put('one/index.html', '');
    await put(
        'one/template.json',
        jsonEncode({
          'name': ' ${'n' * 80} ',
          'description': 'd' * 220,
          'author': 'a' * 70,
          'width': 1,
          'height': 9999,
          'network': true,
          'sdk': 2,
          'fields': [
            {
              'key': 'title',
              'type': 'text',
              'maxLength': 4,
              'default': ' abcdef '
            },
            {'key': 'color', 'type': 'color', 'default': '#AB12FF88'},
            {
              'key': 'count',
              'type': 'number',
              'min': 2,
              'max': 10,
              'step': 0.5,
              'default': 100
            },
            {'key': 'flag', 'type': 'boolean', 'default': true},
            {
              'key': 'choice',
              'type': 'select',
              'options': ['A', 'B'],
              'default': 'bad'
            },
            {
              'key': 'media',
              'type': 'media',
              'kind': 'video',
              'default': '0123456789abcdef'
            },
            {'key': 'title', 'type': 'text'},
            {'key': '_bad', 'type': 'text'},
            {'key': 'bad', 'type': 'select', 'options': []},
            {'key': 'bad2', 'type': 'number', 'min': 5, 'max': 1},
            {'key': 'bad3', 'type': 'media', 'kind': 'exe'},
            {'key': 'bad4', 'type': 'unknown'}
          ]
        }));
    final info = (await library.get('one'))!;
    final m = info.manifest;
    expect(info.problems, ['unsupportedSdk']);
    expect(m.name.length, 60);
    expect(m.description.length, 200);
    expect(m.author.length, 60);
    expect(m.width, 100);
    expect(m.height, 2160);
    expect(m.network, true);
    expect(m.fields.length, 6);
    expect(await library.resolvedValues('one'), {
      'title': 'abcd',
      'color': '#ab12ff88',
      'count': 10,
      'flag': true,
      'choice': 'A',
      'media': '0123456789abcdef'
    });
    await put(
        'one/values.json',
        jsonEncode({
          'title': ' xyzzy ',
          'color': 'javascript:bad',
          'count': -5,
          'flag': 'true',
          'choice': 'B',
          'media': 'bad',
          'unknown': 10
        }));
    expect(await library.resolvedValues('one'), {
      'title': 'xyzz',
      'color': '#ab12ff88',
      'count': 2,
      'flag': true,
      'choice': 'B',
      'media': '0123456789abcdef'
    });
    await library.writeValues(
        'one', {'title': ' safe text ', 'count': 999, 'unknown': 'discard'});
    final saved = jsonDecode(
            await File('${library.rootPath}/one/values.json').readAsString())
        as Map;
    expect(saved['title'], 'safe');
    expect(saved['count'], 10);
    expect(saved.containsKey('unknown'), false);
    expect(
        await Directory('${library.rootPath}/one')
            .list()
            .where((v) => v.path.endsWith('.tmp'))
            .length,
        0);
  });
  test(
      'changed field types resolve identically for editor, delivery and writes',
      () async {
    await put('one/index.html', '');
    await put(
        'one/template.json',
        jsonEncode({
          'fields': [
            {'key': 'count', 'type': 'number', 'default': 7},
            {'key': 'enabled', 'type': 'boolean', 'default': true},
            {'key': 'title', 'type': 'text', 'default': 'Default title'},
            {
              'key': 'choice',
              'type': 'select',
              'options': ['A', 'B'],
              'default': 'B'
            },
            {'key': 'media', 'type': 'media', 'default': '0123456789abcdef'},
          ],
        }));
    const old = {
      'count': 'old text',
      'enabled': 2,
      'title': false,
      'choice': 'old text',
      'media': ''
    };
    const expected = {
      'count': 7,
      'enabled': true,
      'title': 'Default title',
      'choice': 'B',
      'media': ''
    };
    final file = await put('one/values.json', jsonEncode(old));
    expect(await library.editorValues((await library.get('one'))!), expected);
    expect(await library.resolvedValues('one'), expected);
    await library.writeValues('one', old);
    expect(jsonDecode(await file.readAsString()), expected);
  });
  test('invalid and oversized JSON fall back and unchanged manifest is cached',
      () async {
    await put('one/index.html', '');
    final f = await put('one/template.json', '{bad');
    expect((await library.get('one'))!.problems, ['invalidManifest']);
    await f.writeAsString('{"name":"One"}');
    final first = (await library.get('one'))!.manifest;
    expect(identical(first, (await library.get('one'))!.manifest), true);
    await put('one/values.json', 'bad');
    expect(await library.resolvedValues('one'), isEmpty);
    await f.writeAsString(' ' * 65537);
    expect((await library.get('one'))!.problems, ['invalidManifest']);
  });
  test('field list and text limits are enforced', () async {
    await put('one/index.html', '');
    await put(
        'one/template.json',
        jsonEncode({
          'fields': List.generate(
              45,
              (i) => {
                    'key': 'f$i',
                    'type': 'text',
                    'maxLength': 999,
                    'default': 'x' * 600
                  })
        }));
    final m = (await library.get('one'))!.manifest;
    expect(m.fields.length, 40);
    expect((m.fields.first.defaultValue as String).length, 500);
  });
  test(
      'watch debounces files, separates values/list and ignores dot/temp paths',
      () async {
    await put('one/index.html', '');
    await library.watch();
    final changes = <TemplateChange>[];
    final sub = library.changes.listen(changes.add);
    await put('one/style.css', 'a');
    await put('one/script.js', 'b');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(changes.length, 1);
    expect(changes.single.id, 'one');
    expect(changes.single.kind, TemplateChangeKind.files);
    changes.clear();
    await library.writeValues('one', {});
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(changes.map((v) => v.kind), [TemplateChangeKind.values]);
    changes.clear();
    await Directory('${library.rootPath}/two').create();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(changes.single.kind, TemplateChangeKind.list);
    changes.clear();
    await put('one/.ignore', 'x');
    await put('one/a.tmp', 'x');
    await put('.hidden/index.html', 'x');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(changes, isEmpty);
    await sub.cancel();
  });
}

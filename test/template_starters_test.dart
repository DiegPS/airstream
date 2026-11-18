import 'dart:convert';
import 'dart:io';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/templates/template_starters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late TemplateLibrary library;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('starters-');
    library = TemplateLibrary(Directory(p.join(temp.path, 'templates')));
  });
  tearDown(() async {
    await library.dispose();
    await temp.delete(recursive: true);
  });
  for (final starter in TemplateStarter.values) {
    test('${starter.name} is usable with sanitized defaults and local assets',
        () async {
      final files = templateStarterFiles(starter, 'Example');
      final id = await library.createTemplate('Example', files);
      final info = (await library.list()).single;
      expect(info.id, id);
      expect(info.problems, isEmpty);
      final declared =
          (jsonDecode(files['template.json']!) as Map)['fields'] as List;
      expect(await library.resolvedValues(id),
          {for (final f in declared) f['key']: f['default']});
      expect(files['index.html'], contains('href="style.css"'));
      expect(files['index.html'], contains('src="script.js"'));
      expect(files['script.js'], isNot(contains('innerHTML')));
    });
  }
  test('the Chat starter moderates only the targeted YouTube orientation',
      () async {
    final files = templateStarterFiles(TemplateStarter.chat, 'Example');
    final script = File(p.join(temp.path, 'chat-check.js'));
    await script.writeAsString(
        'const starter = ${jsonEncode(files['script.js'])};\n$_chatChecks');
    final result = await Process.run('node', [script.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('ids normalize accents symbols empty names collisions and long names',
      () async {
    expect(templateId('Mi Chat ñ'), 'mi-chat-n');
    expect(templateId('Český țară Việt'), 'cesky-tara-viet');
    expect(templateId('ÁÉÍÓÚ ü'), 'aeiou-u');
    expect(templateId('***'), 'template');
    expect(templateId('hello !!! world'), 'hello-world');
    expect(templateId('x' * 70).length, 40);
    final files = templateStarterFiles(TemplateStarter.blank, 'A');
    expect(await library.createTemplate('A', files), 'a');
    expect(await library.createTemplate('A', files), 'a-2');
    expect(await library.createTemplate('A', files), 'a-3');
    final long = 'b' * 60;
    expect((await library.createTemplate(long, files)).length, 40);
    expect((await library.createTemplate(long, files)).length, 40);
  });
  test('guarded editor writes atomically and only to small approved files',
      () async {
    final id = await library.createTemplate(
        'A', templateStarterFiles(TemplateStarter.blank, 'A'));
    final before = await library.readTemplateFile(id, 'index.html');
    await library.writeTemplateFile(id, 'style.css', 'body { color: red; }');
    expect(await library.readTemplateFile(id, 'style.css'),
        'body { color: red; }');
    expect(await library.readTemplateFile(id, 'index.html'), before);
    expect(
        await Directory(p.join(library.rootPath, id))
            .list()
            .where((f) => p.basename(f.path).startsWith('.edit-'))
            .toList(),
        isEmpty);
    await expectLater(
        library.writeTemplateFile(id, '../outside', 'x'), throwsArgumentError);
    await expectLater(library.readTemplateFile('../outside', 'index.html'),
        throwsArgumentError);
    await expectLater(
        library.writeTemplateFile(
            id, 'script.js', 'x' * (TemplateLibrary.editorLimit + 1)),
        throwsFormatException);
    await File(p.join(library.rootPath, id, 'script.js'))
        .writeAsString('x' * (TemplateLibrary.editorLimit + 1));
    await expectLater(
        library.readTemplateFile(id, 'script.js'), throwsFormatException);
    await expectLater(library.writeTemplateFile(id, 'script.js', 'small'),
        throwsFormatException);
    await File(p.join(library.rootPath, id, 'style.css')).delete();
    expect(await library.readTemplateFile(id, 'style.css'), isNull);
  });
  test('deletion refuses invalid ids outside paths and links', () async {
    final id = await library.createTemplate(
        'A', templateStarterFiles(TemplateStarter.blank, 'A'));
    for (final invalid in ['../outside', temp.path, '', 'A', 'a/b']) {
      await expectLater(library.deleteTemplate(invalid), throwsArgumentError);
    }
    final outside = await Directory(p.join(temp.path, 'outside')).create();
    final link = Link(p.join(library.rootPath, 'linked'));
    await link.create(outside.path);
    await expectLater(library.deleteTemplate('linked'), throwsArgumentError);
    await expectLater(library.writeTemplateFile('linked', 'index.html', 'bad'),
        throwsArgumentError);
    await File(p.join(library.rootPath, id, 'style.css')).delete();
    await File(p.join(outside.path, 'outside.css')).writeAsString('safe');
    await Link(p.join(library.rootPath, id, 'style.css'))
        .create(p.join(outside.path, 'outside.css'));
    await expectLater(library.writeTemplateFile(id, 'style.css', 'bad'),
        throwsA(isA<FileSystemException>()));
    await expectLater(library.readTemplateFile(id, 'style.css'),
        throwsA(isA<FileSystemException>()));
    expect(await outside.exists(), isTrue);
    await library.deleteTemplate(id);
    expect(await library.get(id), isNull);
  });
}

const _chatChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const handlers = new Map();
const rows = [];
const content = {appendChild: node => rows.push(node)};
const context = vm.createContext({
  document: {
    querySelector: () => content,
    createElement: () => ({
      classList: {add() {}}, style: {}, appendChild() {},
      remove() { rows.splice(rows.indexOf(this), 1); },
    }),
  },
  Airstream: {
    on: (name, callback) => handlers.set(name, callback),
    platformColor: () => '#fff', renderMessage: () => ({}),
  },
  setInterval() {},
});
vm.runInContext(starter, context);
const send = (name, data) => handlers.get(name)(data);
const platform = 'youtube';
const youtubeStreamOrientation = 'vertical';
for (const criteria of [{scope: 'platform'},
                        {scope: 'message', messageId: 'same'},
                        {scope: 'author', authorChannelId: 'same'}]) {
  for (const orientation of ['horizontal', 'vertical']) {
    send('chat', {platform, id: 'same', authorChannelId: 'same',
      youtubeStreamOrientation: orientation});
  }
  const horizontal = rows[0];
  send('delete', {platform, youtubeStreamOrientation, ...criteria});
  assert.deepEqual(rows, [horizontal]);
  send('delete', {platform, scope: 'platform'});
  assert.deepEqual(rows, []);
}
''';

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
  test('the Alerts starter moderates visible and queued payloads', () async {
    final files = templateStarterFiles(TemplateStarter.alerts, 'Example');
    final script = File(p.join(temp.path, 'alerts-check.js'));
    await script.writeAsString(
        'const starter = ${jsonEncode(files['script.js'])};\n$_alertChecks');
    final result = await Process.run('node', [script.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
  test('the Alerts starter stops each sound and labels hosts and gifts',
      () async {
    final files = templateStarterFiles(TemplateStarter.alerts, 'Example');
    final script = File(p.join(temp.path, 'alerts-sound-check.js'));
    await script.writeAsString(
        'const starter = ${jsonEncode(files['script.js'])};\n$_alertSoundChecks');
    final result = await Process.run('node', [script.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
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

const _alertSoundChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const handlers = new Map();
const timers = new Map();
const audios = [];
let nextTimer = 0;
function element() {
  return {
    children: [], classList: {add() {}}, style: {setProperty() {}},
    appendChild(child) { child.parent = this; this.children.push(child); },
    remove() { this.parent.children.splice(this.parent.children.indexOf(this), 1); },
  };
}
class Audio {
  constructor(src) { this.src = src; this.paused = true; audios.push(this); }
  play() { this.paused = false; return Promise.resolve(); }
  pause() { this.paused = true; }
  removeAttribute(name) { if (name === 'src') this.src = ''; }
  load() {}
}
const content = element();
const title = () => content.children[0]?.children[0].textContent;
vm.runInNewContext(starter, {
  document: {querySelector: () => content, createElement: element}, Audio,
  Airstream: {on: (name, callback) => handlers.set(name, callback),
    mediaUrl: id => '/media/' + id},
  setTimeout(fn) { timers.set(++nextTimer, fn); return nextTimer; },
  clearTimeout(id) { timers.delete(id); },
});
const send = (name, data) => handlers.get(name)?.(data);
const fire = () => {
  const [id, fn] = timers.entries().next().value;
  timers.delete(id);
  fn();
};
const finishCard = () => { fire(); fire(); };

// A long clip stops when its card leaves, before the next alert's sound.
send('fields', {sound: 'clip', displaySeconds: 1});
send('alert', {id: '1', kind: 'bits', alertType: 'bits', platform: 'twitch', author: 'A'});
send('alert', {id: '2', kind: 'bits', alertType: 'bits', platform: 'twitch', author: 'B'});
assert.equal(audios.length, 1);
assert.equal(audios[0].paused, false);
finishCard();
assert.equal(audios.length, 2);
assert.equal(audios[0].paused, true);
assert.equal(audios[0].src, '');
assert.equal(audios[1].paused, false);
finishCard();
assert.equal(audios[1].paused, true);

const labels = {
  en: ['Host', 'Gifted memberships', 'Gifted subscriptions', 'Raid'],
  es: ['Host', 'Membresías regaladas', 'Suscripciones regaladas', 'Incursión'],
};
for (const language of ['en', 'es']) {
  send('settings', {appLanguageCode: language});
  const shown = [];
  for (const event of [
    {kind: 'host', alertType: 'raid', platform: 'kick'},
    {kind: 'membership', alertType: 'gift', platform: 'youtube', giftCount: 5},
    {kind: 'membership', alertType: 'gift', platform: 'twitch', giftCount: 5},
    {kind: 'raid', alertType: 'raid', platform: 'twitch'},
  ]) {
    send('alert', {id: language + event.platform + event.kind, author: 'X', ...event});
    shown.push(title());
    finishCard();
  }
  assert.deepEqual(shown, labels[language]);
}
''';

const _alertChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const handlers = new Map();
const timers = new Map();
let nextTimer = 0;
function element() {
  return {
    children: [], classList: {add() {}},
    appendChild(child) { child.parent = this; this.children.push(child); },
    remove() { this.parent.children.splice(this.parent.children.indexOf(this), 1); },
  };
}
const content = element();
const lines = () => content.children[0]?.children.map(node => node.textContent);
vm.runInNewContext(starter, {
  document: {querySelector: () => content, createElement: element},
  Airstream: {on: (name, callback) => handlers.set(name, callback)},
  setTimeout(fn) { timers.set(++nextTimer, fn); return nextTimer; },
  clearTimeout(id) { timers.delete(id); },
});
const send = (name, data) => handlers.get(name)?.(data);
const fire = () => {
  const [id, fn] = timers.entries().next().value;
  timers.delete(id);
  fn();
};
const alert = (id, author, message, extra) =>
  send('alert', {id, kind: 'bits', platform: 'twitch', author, message, amount: 42, ...extra});
const feature = (id, author, message) =>
  send('featured', {id, kind: 'featured', platform: 'twitch', author, message});
const remove = (id, extra) =>
  send('delete', {scope: 'message', platform: 'twitch', messageId: id, ...extra});

alert('live', 'Moderated', 'Deleted text');
alert('waiting', 'BlockedUser', 'Also private');
feature('deleted-feature', 'Someone', 'Queued deleted feature');
feature('blocked-feature', 'Other', 'A HIDDEN—PHRASE here');
feature('live-feature', 'Allowed', 'Live feature');
alert('safe', 'Allowed', 'Visible alert');
const liveCard = content.children[0];
const deadline = [...timers.keys()];
remove('live', {sequence: 12});
assert.ok(lines().includes('Deleted text'));
remove('live');
assert.deepEqual(lines(), ['Bits', 'Moderated', '42']);
assert.equal(content.children[0], liveCard);
assert.deepEqual([...timers.keys()], deadline);
remove('deleted-feature');
send('filters', {users: ['blockeduser'], words: ['hidden phrase']});
fire(); fire();
assert.deepEqual(lines(), ['Bits', '42']);
fire(); fire();
assert.deepEqual(lines(), ['Featured message', 'Allowed', 'Live feature']);
send('filters', {users: ['allowed'], words: []});
assert.deepEqual(lines(), ['Bits', '42']);
assert.equal(timers.size, 1);
''';

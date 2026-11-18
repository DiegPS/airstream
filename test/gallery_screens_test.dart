import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/poll_overlay.dart';
import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/captions_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:airstream/services/overlay/templates/clock_overlay.dart';
import 'package:airstream/services/overlay/templates/giveaway_overlay.dart';
import 'package:airstream/services/overlay/templates/goals_overlay.dart';
import 'package:airstream/services/overlay/templates/timer_overlay.dart';
import 'package:airstream/services/overlay/templates/sdk_v1.dart';
import 'package:airstream/services/templates/gallery/gallery_catalog.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const names = {
    'recent-support': ['Recent support', 'Apoyos recientes'],
    'starting-soon': ['Starting soon', 'Empezamos pronto'],
    'be-right-back': ['Be right back', 'Vuelvo enseguida'],
    'stream-ending': ['Stream ending', 'Fin del directo'],
    'credits': ['Credits', 'Créditos'],
    'ticker': ['Ticker', 'Barra informativa'],
    'latest-support': ['Latest support', 'Último apoyo'],
    'top-supporters': ['Top of the stream', 'Top del directo'],
    'queue-list': ['Queue', 'Lista de turnos'],
    'poll': ['Poll', 'Encuesta'],
    'scoreboard': ['Scoreboard', 'Marcador'],
    'word-cloud': ['Word cloud', 'Nube de palabras'],
    'emote-wall': ['Emote wall', 'Muro de emotes'],
  };
  const widgets = {
    'recent-support': (480, 640),
    'ticker': (1920, 64),
    'latest-support': (640, 160),
    'top-supporters': (560, 480),
    'queue-list': (480, 720),
    'poll': (640, 480),
    'scoreboard': (960, 520),
    'word-cloud': (960, 480),
    'emote-wall': (960, 540),
  };

  test('all gallery items build valid localized manifests and files', () {
    expect(galleryCatalog.keys, orderedEquals(names.keys));
    expect(galleryCatalog.values.map((i) => i.id), orderedEquals(names.keys));
    for (final (i, language) in ['en', 'es'].indexed) {
      for (final item in galleryCatalog.values) {
        final recent = item.id == 'recent-support';
        final widgetSize = widgets[item.id];
        expect(item.kind,
            widgetSize == null ? GalleryKind.screen : GalleryKind.widget);
        final files = item.buildFiles(language);
        expect(
            files.keys,
            unorderedEquals(
                ['template.json', 'index.html', 'style.css', 'script.js']));
        expect(files.values, everyElement(isNotEmpty));
        final raw = jsonDecode(files['template.json']!) as Map;
        final manifest = TemplateManifest(item.id, raw);
        expect(manifest.name, names[item.id]![i]);
        expect(manifest.description, isNotEmpty);
        expect(manifest.sdk, 1);
        expect(manifest.gallery, (id: item.id, version: recent ? 3 : 1));
        expect((item.width, item.height), widgetSize ?? (1920, 1080));
        expect((manifest.width, manifest.height), (item.width, item.height));
        final fields = (raw['fields'] as List).cast<Map>();
        final defaults = {
          for (final field in fields) field['key']: field['default']
        };
        expect(defaults['language'], language);
        expect(manifest.fields, hasLength(fields.length));
        expect(manifest.values({}), defaults);
        expect(manifest.values(defaults), defaults);
        expect(item.defaults(language), defaults);
        expect(defaults.keys, containsAll(['theme', 'font', 'accent', 'logo']));
        if (widgetSize == null || item.id == 'ticker') {
          expect(
              manifest.fields.singleWhere((f) => f.key == 'messages').options,
              containsPair('maxLength', 500));
        }
        if (widgetSize == null) {
          expect(
              manifest.fields
                  .singleWhere((f) => f.key == 'backgroundMedia')
                  .options,
              containsPair('kind', 'visual'));
        }
        if (item.id == 'queue-list') {
          final count = manifest.fields.singleWhere((f) => f.key == 'count');
          expect(count.defaultValue, 10);
          expect(count.sanitize(0), 5);
          expect(count.sanitize(50), 30);
          expect(defaults['hideWhenClosed'], false);
        }
        if (item.id == 'ticker') {
          final speed = manifest.fields.singleWhere((f) => f.key == 'speed');
          expect(speed.defaultValue, 80);
          expect(speed.sanitize(0), 30);
          expect(speed.sanitize(300), 200);
        }
        if (language == 'es') {
          final forbidden =
              RegExp(r'\b(overlay|handle)\b', caseSensitive: false);
          expect(files['template.json'], isNot(matches(forbidden)));
        }
      }
    }
    expect(TemplateManifest('custom', {'height': 64}).height, 64);
    expect(TemplateManifest('custom', {'height': 10}).height, 32);
  });

  test('gallery screens and widgets work with SDK v1 in Node',
      () => runGalleryChecks('gallery'));
  test('word cloud removes message, author and platform token batches',
      () => runGalleryChecks('word cloud'));
  test('goals cancel and rearm celebrations when reset',
      () => runGalleryChecks('goals'));
  test(
      'poll pages, giveaway, timer and queue clear on empty reconnect snapshots',
      () => runGalleryChecks('snapshots'));
  test('built-in browser pages update their language and title from settings',
      () => runGalleryChecks('page language'));
  test(
      'preloaded Credits starts when session data arrives and clears when it leaves',
      () => runGalleryChecks('preloaded credits'));
}

Future<void> runGalleryChecks(String scenario) async {
  final temp = await Directory.systemTemp.createTemp('gallery-screens-');
  try {
    final script = File('${temp.path}/screens.cjs');
    final screens = {
      for (final item in galleryCatalog.values)
        if (item.kind == GalleryKind.screen)
          item.id: {
            'en': item.buildFiles('en'),
            'es': item.buildFiles('es'),
            'fields': item.defaults('en'),
          },
    };
    final widgets = {
      for (final id in [
        'ticker',
        'latest-support',
        'top-supporters',
        'queue-list',
        'poll',
        'scoreboard',
        'word-cloud',
        'emote-wall',
      ])
        id: {
          'en': galleryCatalog[id]!.buildFiles('en'),
          'es': galleryCatalog[id]!.buildFiles('es'),
          'fields': galleryCatalog[id]!.defaults('en'),
        },
    };
    await script.writeAsString('const scenario = ${jsonEncode(scenario)};\n'
        'const sdk = ${jsonEncode(sdkV1())};\n'
        'const screens = ${jsonEncode(screens)};\n'
        'const widgets = ${jsonEncode(widgets)};\n'
        'const alertsPage = ${jsonEncode(alertsOverlayHtml())};\n'
        'const captionsPage = ${jsonEncode(captionsOverlayHtml())};\n'
        'const chatPage = ${jsonEncode(chatOverlayHtml())};\n'
        'const pollPage = ${jsonEncode(pollOverlayHtml())};\n'
        'const clockPage = ${jsonEncode(clockOverlayHtml())};\n'
        'const goalsPage = ${jsonEncode(goalsOverlayHtml())};\n'
        'const timerPage = ${jsonEncode(timerOverlayHtml())};\n'
        'const giveawayPage = ${jsonEncode(giveawayOverlayHtml())};\n'
        '$_nodeChecks');
    final result =
        await Process.run('node', [script.path], environment: {'TZ': 'UTC'});
    stdout.write(result.stdout);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  } finally {
    await temp.delete(recursive: true);
  }
}

const _nodeChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');

class Element extends EventTarget {
  constructor(tag = 'div') {
    super();
    this.tagName = tag.toUpperCase();
    this.children = [];
    this.dataset = {};
    this.attrs = {};
    const classes = new Set();
    this.classList = {
      add: c => classes.add(c), remove: c => classes.delete(c), contains: c => classes.has(c),
      toggle: (c, force = !classes.has(c)) => force ? classes.add(c) : classes.delete(c),
    };
    this.style = {setProperty(k, v) { this[k] = String(v); }, removeProperty(k) { delete this[k]; }};
    this.hidden = false;
    this.offsetHeight = 900;
    this.clientHeight = 700;
    this.clientWidth = 1920;
    this.animations = [];
  }
  set innerHTML(value) { throw Error('Unexpected HTML: ' + value); }
  insertAdjacentHTML() { throw Error('Unexpected HTML insertion'); }
  set textContent(value) { this.replaceChildren(); this.text = String(value); }
  get textContent() { return (this.text || '') + this.children.map(child => child.textContent).join(''); }
  get offsetWidth() {
    if (this.style.width) return parseInt(this.style.width, 10);
    if (this.className === 'ticker-group') return this.children.reduce((width, child) => width + child.offsetWidth, 0);
    return 92 + this.textContent.length * 9;
  }
  getBoundingClientRect() { return {top: this.offsetTop, left: 0, width: 220}; }
  get offsetTop() { return (this.parent?.children.indexOf(this) ?? 0) * 66; }
  append(...children) {
    for (const child of children) this.insertBefore(child, null);
  }
  prepend(child) { this.insertBefore(child, this.children[0] || null); }
  insertBefore(child, reference) {
    if (child.parent) child.parent.children.splice(child.parent.children.indexOf(child), 1);
    child.parent = this;
    const index = reference ? this.children.indexOf(reference) : this.children.length;
    this.children.splice(index, 0, child);
  }
  appendChild(child) { this.append(child); return child; }
  replaceChildren(...children) {
    for (const child of this.children) child.parent = null;
    this.children = [];
    this.text = '';
    this.append(...children);
  }
  remove() {
    if (this.parent) this.parent.children = this.parent.children.filter(child => child !== this);
    this.parent = null;
  }
  animate(frames, options) {
    const animation = {frames, options, cancel() { this.cancelled = true; }};
    this.animations.push(animation);
    return animation;
  }
  setAttribute(k, v) { this.attrs[k] = v; }
  getAttribute(k) { return this.attrs[k] ?? null; }
  removeAttribute(k) { delete this.attrs[k]; if (k === 'src') delete this.src; }
  querySelector(tag) { return this.children.find(c => c.tagName === tag.toUpperCase()) || null; }
  pause() { this.paused = true; }
  load() {}
}

function page(id, lang = 'en', {demo = false, reduced = false, values = {}} = {}) {
  const html = {'/poll': pollPage, '/clock': clockPage, '/giveaway': giveawayPage,
    '/goals': goalsPage, '/timer': timerPage, '/chat': chatPage,
    '/alerts': alertsPage, '/captions': captionsPage}[id];
  const item = (screens[id] || widgets[id]);
  const files = html
    ? {'index.html': html, 'script.js': html.split('<script>')[1].split('</script>')[0]}
    : item[lang];
  const nodes = Object.fromEntries([...files['index.html'].matchAll(/<([a-z0-9]+)\b[^>]*\bid="([^"]+)"([^>]*)>/g)]
    .map(([, tag, key, attributes]) => {
      const node = new Element(tag);
      node.hidden = /\bhidden\b/.test(attributes);
      return [key, node];
    }));
  nodes.messages?.append(new Element('p'), new Element('p'));
  if (id === 'ticker') nodes.stage.clientWidth = 1920;
  const logo = new Element('span');
  let now = new Date('2026-11-17T12:00:00Z').getTime(), nextTimer = 0;
  const timers = new Map();
  const errors = [];
  const motion = new EventTarget();
  motion.matches = reduced;
  const win = new EventTarget();
  let socket;
  const sent = [];
  const context = {
    Date: class extends Date {
      constructor(...args) { super(...(args.length ? args : [now])); }
      static now() { return now; }
    },
    document: {
      documentElement: new Element('html'), head: new Element('head'),
      getElementById: key => nodes[key] || null,
      querySelector: selector => selector === '.gallery-logo' ? logo : null,
      createElement: tag => new Element(tag),
      createDocumentFragment: () => new Element('fragment'),
      createTextNode: text => ({textContent: text})
    },
    location: {pathname: '/' + (demo ? 'gallery' : 'custom') + '/' + id + '/',
      protocol: 'http:', host: 'localhost', search: demo ? '?demo=1' : ''},
    navigator: {language: lang}, URLSearchParams, AbortController,
    fetch: async url => {
      if (url === './template.json') return {ok: true, json: async () => JSON.parse(files['template.json'])};
      if (url === './values.json') return {ok: true, json: async () => values};
      return {ok: url.startsWith('/media/'), headers: {get: () => url.endsWith('a') ? 'video/mp4' : 'image/png'}};
    },
    console: {...console, error: error => errors.push(error), warn: error => errors.push(error)},
    WebSocket: class {
      constructor() { socket = this; }
      send(data) { sent.push(JSON.parse(data)); }
      addEventListener(name, fn) { this[name] = fn; }
    },
    setInterval(fn, ms) { timers.set(++nextTimer, {fn, at: now + ms, repeat: ms}); return nextTimer; },
    setTimeout(fn, ms) { timers.set(++nextTimer, {fn, at: now + ms, repeat: 0}); return nextTimer; },
    clearInterval: key => timers.delete(key), clearTimeout: key => timers.delete(key),
    queueMicrotask
  };
  context.window = Object.assign(win, {innerWidth: 960, innerHeight: 640, matchMedia: () => motion,
    setInterval: context.setInterval, clearInterval: context.clearInterval,
    setTimeout: context.setTimeout, clearTimeout: context.clearTimeout,
    requestAnimationFrame: fn => context.setTimeout(fn, 0),
    cancelAnimationFrame: context.clearTimeout});
  vm.createContext(context);
  if (!html) {
    vm.runInContext(sdk, context);
    context.Airstream = win.Airstream;
  }
  vm.runInContext(files['script.js'], context);
  if (html) (socket.open || socket.onopen)();

  function send(type, data, replay = false) {
    (socket.message || socket.onmessage)({data: JSON.stringify({type, data, replay})});
    assert.deepEqual(errors, []);
  }
  function advance(ms) {
    const end = now + ms;
    while (true) {
      const next = [...timers].filter(([, timer]) => timer.at <= end)
        .sort(([, a], [, b]) => a.at - b.at)[0];
      if (!next) break;
      const [key, timer] = next;
      now = timer.at;
      if (timer.repeat) timer.at += timer.repeat;
      else timers.delete(key);
      timer.fn();
    }
    now = end;
    assert.deepEqual(errors, []);
  }
  return {nodes, win, errors, advance, send, sent, logo,
    reconnect: () => { socket.close(); advance(3000); socket.open(); },
    root: context.document.documentElement,
    title: () => context.document.title,
    fields: values => send('fields', {...item.fields, language: lang, ...values})};
}

const literal = '<img src=x onerror=evil()> 🌙';

function checkPoll() {
  const allNodes = node => [node, ...node.children.flatMap(allNodes)];
  const options = [
    {label: literal, votes: 784, percent: 100},
    {label: 'Other choice', votes: 0, percent: 0},
  ];
  const withResults = [
    ['numbered', {options}, '!1', '784'],
    ['word', {options}, literal, '784'],
    ['yesNo', {options: options.map((o, i) => ({...o, label: i ? 'No' : 'Yes'}))}, '!1', '784'],
    ['rating', {options: [], average: 8.7, distribution: [0, 0, 0, 0, 0, 0, 0, 0, 784, 0]}, '1–10', '784'],
    ['freeAnswer', {options: [], command: '!reply', answers: [{text: literal, votes: 784}], distinct: 951}, '!reply', '784'],
  ];
  for (const [id, name] of [['/poll', 'Built-in /poll'], ['poll', 'Gallery Poll']]) {
    const builtIn = id === '/poll';
    for (const lang of ['en', 'es']) {
      const view = page(id, lang);
      const {nodes} = view;
      const results = builtIn ? nodes.poll : nodes.results;
      const instructions = () => builtIn
        ? allNodes(results).find(n => n.className === 'instructions')?.textContent || results.textContent
        : nodes.instructions.textContent;
      const status = () => builtIn
        ? allNodes(results).find(n => n.className === 'footer').textContent
        : nodes.status.textContent;
      if (builtIn) {
        assert.deepEqual(view.sent, [{type: 'register', view: 'poll'}]);
        view.send('settings', {appLanguageCode: lang});
      } else {
        view.fields({theme: 'warm', font: 'Outfit', accent: '#234567', logo: '0123456789abcdef'});
        assert.equal(view.root.dataset.theme, 'warm');
        assert.equal(view.root.style['--font'], '"Outfit"');
        assert.equal(view.root.style['--custom-accent'], '#234567');
        assert.equal(view.logo.children[0].src, '/media/0123456789abcdef');
      }
      for (const [mode, data, hint, score] of withResults) {
        const state = {mode, question: 'Question ' + literal, total: 17, closed: false, ...data};
        // Even if optional result fields arrive together with a hidden flag,
        // the DOM must never show those results.
        view.send('poll', {...state, hidden: true}, true);
        assert.match(results.textContent, lang === 'es' ? /Resultados al final/ : /Results at the end/);
        assert.match(status(), /17/);
        assert.ok(!results.textContent.includes(score));
        assert.ok(!results.textContent.includes('951'));
        assert.ok(!results.textContent.match(/8[.,]7|100%/));
        assert.equal(allNodes(results).filter(n =>
          /^(bar|count|distribution|average|answers|distinct)$/.test(n.className || '')).length, 0);
        if (mode === 'freeAnswer') {
          assert.ok(!allNodes(results).some(n => n.textContent === literal));
        }
        assert.ok(instructions().includes(hint));

        view.send('poll', mode === 'numbered' ? Object.fromEntries(
          Object.entries(state).filter(([key]) => key !== 'mode')) : state);
        assert.ok(!results.textContent.includes('Results at the end'));
        assert.ok(results.textContent.includes(score));
        if (mode === 'rating') {
          assert.equal(allNodes(results).filter(n => n.className === 'bucket').length, 10);
          assert.match(results.textContent, lang === 'es' ? /8,7/ : /8\.7/);
        }
        if (mode === 'freeAnswer' || mode === 'word' || mode === 'numbered') {
          assert.ok(allNodes(results).some(n => n.tagName === 'BDI' && n.textContent === literal));
        }
        assert.ok(!allNodes(results).some(n => n.tagName === 'IMG'));
        view.send('poll', {...state, hidden: false, closed: true});
        assert.ok(allNodes(results).some(n => n.className?.split(' ').includes('winner')));
      }
      view.send('poll', {question: 'Timed', options, total: 17, closed: false,
        endsAt: new Date('2026-11-17T12:00:03Z').getTime()});
      const before = status();
      view.advance(1000);
      assert.notEqual(status(), before);
      view.send('poll', null);
      assert.equal(builtIn ? nodes.poll.classList.contains('visible') : !nodes.stage.hidden, false);
    }
    console.log(name + ': five modes, legacy shape, hidden results, safe text, timer and winners passed (en/es).');
  }
  for (const lang of ['en', 'es']) {
    const demo = page('poll', lang, {demo: true, reduced: true});
    demo.advance(3000);
    assert.equal(demo.nodes.stage.hidden, false);
    assert.ok(demo.nodes.results.textContent.includes('Adventure'));
  }
}
function checkGoalReset() {
  const view = page('/goals');
  const goal = (current) => [{id: 'one', title: 'Goal', current, target: 10,
    percent: current * 10, reached: current >= 10}];
  view.send('goals', goal(9), true);
  const row = view.nodes.goals.children[0];
  view.send('goals', goal(10));
  assert.equal(row.classList.contains('celebrate'), true);
  view.advance(500);
  view.send('goals', goal(0));
  assert.equal(row.classList.contains('celebrate'), false);
  assert.equal(row.children[3].textContent, '');
  view.send('goals', goal(10));
  assert.equal(row.classList.contains('celebrate'), true);
  view.advance(1500);
  assert.equal(row.classList.contains('celebrate'), true, 'old timer was canceled');
  view.advance(500);
  assert.equal(row.classList.contains('celebrate'), false);
  view.send('goals', goal(0));
  view.send('goals', goal(10), true);
  assert.equal(row.classList.contains('celebrate'), false, 'replay is silent');
}
function checkEmptySnapshots() {
  for (const id of ['/poll', 'poll']) {
    const view = page(id);
    view.send('poll', {question: 'Old poll', options: [], total: 0, closed: true});
    const builtIn = id === '/poll';
    const card = builtIn ? view.nodes.poll : view.nodes.question;
    assert.match(card.textContent, /Old poll/);
    view.reconnect();
    view.send('poll', null, true);
    assert.equal(card.textContent, '');
    assert.equal(builtIn ? card.classList.contains('visible') : !view.nodes.stage.hidden, false);
  }

  const giveaway = page('/giveaway');
  giveaway.send('giveaway', {phase: 'open', keyword: '!old', entrantCount: 4});
  assert.match(giveaway.nodes.giveaway.textContent, /!old/);
  giveaway.reconnect();
  giveaway.send('giveaway', null, true);
  assert.equal(giveaway.nodes.giveaway.hidden, true);

  const timer = page('/timer');
  timer.send('timer', {phase: 'paused', remainingMs: 4000, serverNowMs: 0}, true);
  assert.equal(timer.nodes.timer.hidden, false);
  timer.reconnect();
  timer.send('timer', {phase: 'idle', serverNowMs: 0}, true);
  assert.equal(timer.nodes.timer.hidden, true);

  const queue = page('queue-list');
  queue.fields({});
  const player = {id: '1', platform: 'twitch', name: 'Old player'};
  const state = {status: 'open', entries: [player], playing: [],
    max: 50, command: '!join'};
  queue.send('queue', state, true);
  assert.equal(queue.nodes.waiting.children.length, 1);
  queue.reconnect();
  queue.send('queue', null, true);
  assert.equal(queue.nodes.waiting.children.length, 0);
  assert.equal(queue.nodes.queue.hidden, true);
  assert.equal(queue.win.Airstream.state.queue, null);
  queue.send('queue', {...state, entries: []}, true);
  assert.equal(queue.nodes.queue.hidden, false);

  const scoreboard = page('scoreboard');
  scoreboard.fields({counters: 'home'});
  scoreboard.send('counters', {home: 7}, true);
  assert.match(scoreboard.nodes.scores.textContent, /7/);
  scoreboard.reconnect();
  scoreboard.send('counters', null, true);
  assert.equal(scoreboard.win.Airstream.state.counters, null);
  assert.doesNotMatch(scoreboard.nodes.scores.textContent, /7/);
}

function checkPageLanguage() {
  for (const [id, spanish, english] of [
    ['/poll', 'Encuesta de Airstream', 'Airstream Poll'],
    ['/clock', 'Temporizador', 'Timer'],
    ['/timer', 'Temporizador de Airstream', 'Airstream Timer'],
    ['/chat', 'Chat de Airstream', 'Airstream Overlay'],
    ['/alerts', 'Alertas de Airstream', 'Airstream Alerts'],
    ['/captions', 'Subtítulos de Airstream', 'Airstream Captions'],
  ]) {
    const view = page(id);
    view.send('settings', {appLanguageCode: 'es'});
    assert.equal(view.root.lang, 'es', id);
    assert.equal(view.title(), spanish, id);
    view.send('settings', {appLanguageCode: 'en'});
    assert.equal(view.root.lang, 'en', id);
    assert.equal(view.title(), english, id);
  }
}

function checkPreloadedCredits() {
  const credits = page('credits');
  credits.fields({loop: false});
  credits.send('session', null, true);
  const roll = credits.nodes['credits-roll'];
  assert.equal(roll.hidden, true);
  credits.send('session', {startedAt: '2026-11-18', supporters: []});
  assert.equal(roll.hidden, true);
  credits.send('session', {startedAt: '2026-11-18', supporters: [
    {id: '1', name: 'Ana', type: 'bits', platform: 'twitch'},
  ]});
  assert.equal(roll.hidden, false);
  assert.match(roll.textContent, /Ana/);
  credits.reconnect();
  credits.send('session', null, true);
  assert.equal(credits.win.Airstream.state.session, null);
  assert.equal(roll.hidden, true);
  assert.equal(credits.nodes['credits-page'].textContent, 'Thanks for watching');
}
function checkWordCloudModeration() {
  const view = page('word-cloud');
  view.fields({refresh: 1});
  function message(id, platform, author, channel, text, youtubeStreamOrientation) {
    view.send('message', {id, platform, author, authorChannelId: channel, text, youtubeStreamOrientation});
  }
  message('1', 'youtube', 'Ana', 'ana', 'orchid', 'horizontal');
  message('1', 'youtube', 'Ana', 'ana', 'fern', 'vertical');
  message('2', 'twitch', 'Beto', 'beto', 'moss');
  message('3', 'twitch', 'Beto', 'beto', 'maple');
  message('4', 'youtube', 'Carla', 'carla', 'cedar');
  view.advance(1000);
  const words = () => view.nodes.words.children.map(word => word.textContent);
  assert.deepEqual(words(), ['cedar', 'fern', 'maple', 'moss', 'orchid']);
  view.send('moderation', {scope: 'message', platform: 'youtube', messageId: '1',
    youtubeStreamOrientation: 'horizontal'});
  assert.deepEqual(words(), ['cedar', 'fern', 'maple', 'moss']);
  view.send('moderation', {scope: 'author', platform: 'twitch', authorName: 'BETO'});
  assert.deepEqual(words(), ['cedar', 'fern']);
  view.send('moderation', {scope: 'platform', platform: 'youtube'});
  assert.deepEqual(words(), []);
  assert.equal(view.nodes.stage.hidden, true);
}
const regressions = {
  'word cloud': checkWordCloudModeration,
  goals: checkGoalReset,
  snapshots: checkEmptySnapshots,
  'page language': checkPageLanguage,
  'preloaded credits': checkPreloadedCredits,
};
if (scenario !== 'gallery') {
  regressions[scenario]();
  process.exit(0);
}
checkPoll();

const support = (type, name, day, id = name) =>
  ({type, name, id, platform: 'twitch', at: '2026-11-' + day + 'T10:00:00Z'});
const gift = support('gift', literal, 16);
const payload = {
  startedAt: '2026-11-17T10:00:00Z', endedAt: '2026-11-17T11:11:00Z',
  messages: 803, chatters: 47, supporterCount: 72,
  latest: {gift, raid: null},
  supporters: [gift, support('gift', 'Earlier', 15), support('gift', literal, 14, 'older')],
  top: {gift: [{name: literal, platform: 'twitch', value: 5}]},
  topChatters: [{name: literal, platform: 'kick', messages: 38}]
};

function checkTicker() {
  const ticker = page('ticker');
  const track = ticker.nodes['ticker-track'];
  const superchat = {...support('superchat', literal, 17), amount: '$5.00'};
  ticker.send('session', {...payload, latest: {superchat, gift}}, true);
  ticker.send('goals', [{title: 'Subs goal ' + literal, current: 31, target: 50}], true);
  const now = Date.parse('2026-11-17T12:00:00Z');
  ticker.send('timer', {phase: 'running', endsAtMs: now + 65000, serverNowMs: now}, true);
  ticker.fields({messages: 'First | | ' + literal, speed: 100});
  assert.equal(ticker.nodes.stage.hidden, false);
  assert.equal(track.classList.contains('rolling'), true);
  const first = track.children[0];
  const labels = group => group.children.map(item => item.children[0].textContent);
  assert.deepEqual(labels(first), ['First', literal, 'Latest Super Chat: ' + literal + ' $5.00',
    'Latest gift: ' + literal + ' · Gifted 1 sub', 'Subs goal ' + literal + ' 31/50', 'Subathon · 1:05']);
  assert.deepEqual(labels(track.children[1]), labels(first));
  const duration = first.offsetWidth / 100 + 's';
  assert.equal(track.style['--ticker-duration'], duration);
  assert.equal(track.style['--ticker-distance'], -first.offsetWidth + 'px');
  const timerNode = first.children[5].children[0].children[0];
  ticker.advance(1000);
  assert.equal(timerNode.textContent, '1:04');
  assert.equal(track.children[1].children[5].children[0].children[0].textContent, '1:04');
  assert.equal(track.children[0], first);
  assert.equal(track.style['--ticker-duration'], duration);

  const boundary = () => track.dispatchEvent(Object.assign(new Event('animationiteration'), {animationName: 'ticker-scroll'}));
  ticker.fields({messages: 'Updated', speed: 100, showLatest: false, showGoals: false, showTimer: false});
  assert.equal(track.children[0], first);
  assert.equal(track.style['--ticker-duration'], duration);
  boundary();
  const replacement = track.children[0];
  const tickerSpeed = () => track.style['--ticker-duration'];
  assert.deepEqual(labels(replacement), ['Updated']);
  assert.equal(tickerSpeed(), replacement.offsetWidth / 100 + 's');
  assert.ok(track.children.length * replacement.offsetWidth >= 1920 + replacement.offsetWidth);
  ticker.fields({messages: 'Updated', speed: 200, showLatest: false, showGoals: false, showTimer: false});
  assert.equal(tickerSpeed(), replacement.offsetWidth / 100 + 's');
  boundary();
  assert.equal(track.children[0], replacement);
  assert.equal(tickerSpeed(), replacement.offsetWidth / 200 + 's');
  boundary();
  assert.equal(track.children[0], replacement);
  ticker.fields({showCustom: false, showLatest: false, showGoals: false, showTimer: false});
  assert.equal(ticker.nodes.stage.hidden, false);
  boundary();
  assert.equal(ticker.nodes.stage.hidden, true);
  ticker.fields({showCustom: false, showLatest: false, showGoals: false, showTimer: false, showEmpty: true});
  assert.deepEqual(labels(track.children[0]), ['Ticker']);

  const still = page('ticker', 'es', {reduced: true});
  still.fields({messages: 'Hola | ' + literal});
  const line = still.nodes['ticker-still'];
  assert.equal(still.nodes['ticker-track'].hidden, true);
  assert.equal(line.children.length, 1);
  assert.equal(line.textContent, 'Hola');
  still.advance(4999);
  assert.equal(line.textContent, 'Hola');
  still.advance(1);
  assert.equal(line.children.length, 1);
  assert.equal(line.textContent, literal);
  still.advance(5000);
  assert.equal(line.textContent, 'Hola');
  console.log('PASS: ticker renders literal messages, support, goals and timer; measured speed, seamless copies, boundary updates, empty state and 5s reduced-motion rotation');
}

function checkLatestSupport() {
  const latest = page('latest-support', 'es');
  const display = latest.nodes['support-display'];
  const layers = [latest.nodes['support-a'], latest.nodes['support-b']];
  const active = () => layers.find(layer => layer.classList.contains('active'));
  const animations = () => layers.reduce((count, layer) => count + layer.animations.length, 0);
  latest.fields({showEmpty: false});
  assert.equal(latest.nodes.stage.hidden, true);
  latest.send('session', payload, true);
  assert.equal(active().children[0].children[1].textContent, literal);
  assert.equal(active().children[0].children[0].style['--platform'], '#9146ff');
  assert.equal(active().children[1].textContent, 'Regaló 1 suscripción');
  assert.equal(animations(), 0);
  const raid = {...support('raid', 'Mar 🌙', 17), count: 42};
  const next = {...payload, latest: {gift, bits: null, raid}, supporters: [raid, ...payload.supporters]};
  latest.send('session', next);
  assert.equal(active().textContent, 'Mar 🌙Raid con 42 espectadores');
  assert.equal(animations(), 1);
  latest.send('session', {...next, messages: 1000});
  latest.send('session', next, true);
  latest.fields({accent: '#123456', logo: 'C:\\private\\logo.png'});
  assert.equal(animations(), 1);
  assert.equal(latest.logo.hidden, true);
  latest.fields({mode: 'rotate', seconds: 4, logo: '0123456789abcdef'});
  assert.equal(latest.logo.children[0].src, '/media/0123456789abcdef');
  assert.match(active().textContent, /Regaló/);
  latest.advance(2500);
  latest.send('session', {...next, chatters: 48});
  latest.advance(1500);
  assert.equal(active().textContent, 'Mar 🌙Raid con 42 espectadores');
  assert.equal(display.classList.contains('fading'), true);
  latest.advance(4000);
  assert.match(active().textContent, /Regaló/);
  assert.equal(animations(), 1);
  latest.send('session', null, true);
  assert.equal(latest.nodes.empty.hidden, false);
  assert.equal(latest.nodes.empty.textContent, 'Todavía no hay apoyos');
  console.log('PASS: latest support uses localized descriptions and literal names, animates only on new support, rotates present types and handles empty state and media IDs');
}

function checkTopSupporters() {
  const top = page('top-supporters');
  const ranks = top.nodes.ranks;
  const entry = (name, value, platform = 'twitch') => ({name, value, platform});
  const giftEntries = [entry(literal, 10), entry('Viewer Two', 5, 'kick'),
    ...Array.from({length: 4}, (_, i) => entry('Viewer ' + (i + 3), 4 - i))];
  const session = {...payload, superchatCounts: {'$': 2, 'MX$': 6}, top: {
    superchat: {'$': [entry('Dollar', 11, 'youtube')], 'MX$': [entry(literal, 100.5, 'youtube')]},
    bits: [entry('Cheerer', 1500)], gift: giftEntries, kicks: [entry('Kicker', 300, 'kick')]
  }};
  const rows = () => ranks.children.map(row => row.children.filter((_, index) => index !== 1).map(node => node.textContent));
  top.send('session', session, true);
  for (const [type, name, value, heading] of [
    ['superchat', literal, 'MX$100.50', 'Top Super Chats · MX$'], ['bits', 'Cheerer', '1,500', 'Top bits'],
    ['gift', literal, '10', 'Top gifted subs'], ['kicks', 'Kicker', '300', 'Top kicks'],
    ['chatters', literal, '38', 'Top chatters']
  ]) {
    top.fields({type});
    assert.deepEqual(rows()[0], ['1', name, value]);
    assert.equal(top.nodes.category.textContent, heading);
  }
  top.fields({type: 'superchat', currency: '$'});
  assert.deepEqual(rows()[0], ['1', 'Dollar', '$11']);
  top.fields({type: 'gift'});
  assert.equal(rows().length, 5);
  assert.deepEqual(rows()[4], ['5', 'Viewer 5', '2']);
  const [first, second] = ranks.children;
  const updated = {...session, top: {...session.top, gift: [{...giftEntries[1], value: 12},
    giftEntries[0], ...giftEntries.slice(2)]}};
  top.send('session', updated);
  assert.equal(ranks.children[0], second);
  assert.equal(ranks.children[1], first);
  assert.deepEqual(rows()[0], ['1', 'Viewer Two', '12']);
  assert.equal(first.animations[0].frames[0].transform, 'translateY(-66px)');
  assert.equal(second.animations[0].frames[0].transform, 'translateY(66px)');
  top.send('session', session, true);
  assert.equal(ranks.children[0], first);
  assert.equal(first.animations.length, 1);
  assert.equal(second.animations.length, 1);
  assert.equal(first.animations[0].cancelled, true);
  assert.equal(second.animations[0].cancelled, true);
  top.send('session', session);
  assert.equal(first.animations.length, 1);

  const auto = page('top-supporters', 'es');
  auto.fields({seconds: 4});
  assert.equal(auto.nodes.empty.hidden, false);
  auto.send('session', {...session, top: {gift: [], bits: session.top.bits}, topChatters: session.topChatters}, true);
  assert.equal(auto.nodes.category.textContent, 'Más bits');
  auto.advance(4000);
  assert.equal(auto.nodes.category.textContent, 'Quienes más escribieron');
  auto.advance(4000);
  assert.equal(auto.nodes.category.textContent, 'Más bits');
  console.log('PASS: top renders all five rankings, currencies, literal names, a five-row cap and live rank movement; replay stays still and auto skips empty types');
}

async function checkWidgetDemos() {
  for (const lang of ['en', 'es']) {
    for (const theme of ['neon', 'minimal', 'warm']) {
      const branded = theme !== 'neon';
      const options = {demo: true, values: {theme, logo: branded ? '0123456789abcdef' : ''}};
      const ticker = page('ticker', lang, options);
      const latest = page('latest-support', lang, options);
      const top = page('top-supporters', lang, options);
      await new Promise(setImmediate);
      for (const demo of [ticker, latest, top]) {
        assert.deepEqual(demo.errors, []);
        assert.equal(demo.nodes.stage.hidden, false);
        assert.equal(demo.root.dataset.theme, theme);
        assert.equal(demo.root.lang, lang);
        assert.equal(demo.logo.hidden, !branded);
      }
      const rolling = ticker.nodes['ticker-track'].children[0];
      assert.match(rolling.textContent, lang === 'es' ? /Meta de suscripciones.*Subatón · 15:00/ : /Subs goal.*Subathon · 15:00/);
      ticker.advance(1000);
      assert.match(rolling.textContent, /14:59/);
      const layer = latest.nodes['support-a'];
      const supporter = layer.textContent;
      latest.advance(8000);
      assert.notEqual(layer.textContent, supporter);
      assert.equal(layer.animations.length, 1);
      const category = top.nodes.category.textContent;
      assert.ok(top.nodes.ranks.children.length > 0);
      top.advance(8000);
      assert.notEqual(top.nodes.category.textContent, category);
    }
  }
  console.log('PASS: SDK demo exercises all three widgets in English and Spanish with all themes and optional branding');
}

async function checkQueue() {
  const pageQueue = page('queue-list');
  const {nodes} = pageQueue;
  const player = (id, name = 'Player ' + id, note = '') => ({
    id: String(id), platform: 'twitch', name, note, priority: id === 0,
    joinedAt: '2026-11-17T12:00:00Z'
  });
  const entries = Array.from({length: 12}, (_, i) => player(i));
  entries[0] = player(0, literal, '<b>note</b> 🎮');
  const state = {status: 'open', entries, playing: [player(20)], max: 50, command: '!join'};
  pageQueue.send('queue', state, true);
  pageQueue.fields({});
  assert.equal(nodes.status.textContent, 'Open');
  assert.equal(nodes.join.textContent, 'Type !join to play');
  assert.equal(nodes.waiting.children.length, 10);
  assert.equal(nodes.more.textContent, '+2 more');
  const first = nodes.waiting.children[0];
  assert.equal(first.children[0].textContent, '1');
  assert.equal(first.children[2].textContent, literal);
  assert.equal(first.children[3].textContent, '<b>note</b> 🎮');
  assert.equal(first.dataset.priority, 'true');
  assert.equal(first.classList.contains('enter'), false);
  assert.equal(nodes.playing.children[0].children[2].textContent, 'Player 20');
  assert.equal(pageQueue.win.Airstream.state.queue.status, 'open');
  const added = {...state, entries: [player(21), ...entries.slice(1)]};
  pageQueue.send('queue', added);
  assert.equal(first.classList.contains('leave'), true);
  const newest = nodes.waiting.children[0];
  assert.equal(newest.classList.contains('enter'), true);
  newest.dispatchEvent(new Event('animationend'));
  pageQueue.advance(180);
  assert.ok(!nodes.waiting.children.includes(first));
  pageQueue.send('queue', added, true);
  assert.equal(nodes.waiting.children[0], newest);
  assert.equal(newest.classList.contains('enter'), false);
  pageQueue.fields({language: 'es', hideWhenClosed: true, count: 5});
  assert.equal(nodes.more.textContent, '+7 más');
  pageQueue.send('queue', {...added, status: 'paused'});
  assert.equal(nodes.status.textContent, 'En pausa');
  assert.equal(nodes.queue.hidden, false);
  assert.equal(nodes.join.textContent, 'Cuando abra, escribe !join para jugar');
  pageQueue.send('queue', {...added, status: 'closed'}, true);
  assert.equal(nodes.status.textContent, 'Cerrada');
  assert.equal(nodes.queue.hidden, true);
  pageQueue.fields({language: 'es', hideWhenClosed: false});
  assert.equal(nodes.queue.hidden, false);

  for (const lang of ['en', 'es']) {
    const demo = page('queue-list', lang, {demo: true, reduced: true});
    await new Promise(setImmediate);
    assert.deepEqual(demo.errors, []);
    assert.equal(demo.nodes.join.textContent, lang === 'en'
      ? 'Type !join to play' : 'Escribe !unirme para jugar');
    const before = demo.win.Airstream.state.queue.playing[0].id;
    demo.advance(8000);
    assert.notEqual(demo.win.Airstream.state.queue.playing[0].id, before);
    demo.advance(4000);
    assert.equal(demo.win.Airstream.state.queue.status, 'paused');
  }
  console.log('PASS: Queue renders literal names and notes, keeps keyed rows on replay, animates joins and departures, localizes status and overflow, hides when closed, and evolves in demo');
}



function checkLivePages() {
  const epoch = Date.parse('2026-11-17T12:00:00Z');
  const clock = page('/clock');
  assert.deepEqual(clock.sent, [{type:'register', view:'clock'}]);
  clock.send('settings', {appLanguageCode:'es', chatFontFamily:'Arial'});
  const countdown = {mode:'countdown', phase:'running', style:'ring', label:literal,
    durationSeconds:10, anchorMs:epoch+5000, valueMs:0, serverNowMs:epoch};
  clock.send('clock', countdown, true);
  assert.equal(clock.nodes.label.textContent, literal);
  assert.equal(clock.nodes.value.textContent, '0:05');
  assert.equal(clock.nodes.clock.style['--progress'], '50%');
  clock.advance(5000);
  assert.equal(clock.nodes.value.textContent, '0:00');
  assert.equal(clock.nodes.status.textContent, '¡Se acabó el tiempo!');
  clock.send('clock', {...countdown, mode:'stopwatch', phase:'paused', style:'compact', valueMs:2300,
    serverNowMs:epoch+5000});
  assert.equal(clock.nodes.clock.dataset.style, 'compact');
  assert.equal(clock.nodes.value.textContent, '0:02');
  assert.equal(clock.nodes.status.textContent, 'En pausa');
  clock.send('clock', {...countdown, mode:'clock', phase:'idle', style:'big', serverNowMs:epoch+5000});
  assert.equal(clock.nodes.value.textContent, '12:00:05');

  const giveaway = page('/giveaway');
  const draw = (drawId, name) => ({phase:'drawn', drawId, batchDraw:true, winner:{name, platform:'twitch'}});
  giveaway.send('giveaway', draw(1, 'Ana'));
  giveaway.send('giveaway', draw(2, 'Beto'));
  giveaway.send('giveaway', draw(3, 'Carla'));
  giveaway.advance(2500);
  assert.equal(giveaway.nodes.giveaway.children[0].textContent, 'Ana');
  giveaway.advance(4100);
  assert.equal(giveaway.nodes.giveaway.children[0].textContent, 'Beto');
  giveaway.advance(4100);
  assert.equal(giveaway.nodes.giveaway.children[0].textContent, 'Carla');
  console.log('PASS: /clock renders all three modes and /giveaway reveals each batch winner');
}

async function checkLiveWidgets() {
  for (const lang of ['en', 'es']) {
    const scoreboard = page('scoreboard', lang, {demo: true, values: {layout: 'column'}});
    const cloud = page('word-cloud', lang, {demo: true, values: {refresh: 1, maxWords: 4}});
    const wall = page('emote-wall', lang, {demo: true, values: {maxEmotes: 2, lifetime: 3}});
    await new Promise(setImmediate);
    assert.equal(scoreboard.nodes.stage.hidden, false);
    assert.equal(scoreboard.nodes.scores.dataset.layout, 'column');
    assert.equal(scoreboard.nodes.scores.textContent, lang === 'es' ? 'Local7Visitante4' : 'Home7Away4');
    scoreboard.advance(5000);
    assert.equal(scoreboard.nodes.scores.children[0].children[1].textContent, '8');
    cloud.advance(7500);
    const words = cloud.nodes.words.children.map(word => word.textContent);
    assert.equal(words.length, 4);
    assert.ok(words.includes('equipo'));
    assert.ok(!words.includes('para') && !words.includes('the'));
    wall.advance(2900);
    assert.equal(wall.nodes.emotes.children.length, 1);
    assert.match(wall.nodes.emotes.children[0].src, /^data:image\//);
    wall.advance(6000);
    assert.equal(wall.nodes.emotes.children.length, 2);
  }
  const scoreboard = page('scoreboard');
  scoreboard.fields({counters: 'deaths,missing', labels: literal});
  scoreboard.send('counters', {deaths: -4});
  assert.equal(scoreboard.nodes.scores.textContent, literal + '-4missing0');
  const wall = page('emote-wall');
  wall.fields({lifetime: 1});
  wall.send('message', {items: [
    {kind: 'emoji', url: 'javascript:bad'},
    {kind: 'emoji', url: 'https://example.invalid/emote', alt: 'wave'}
  ]});
  assert.equal(wall.nodes.emotes.children.length, 1);
  assert.equal(wall.nodes.emotes.children[0].alt, 'wave');
  wall.advance(1000);
  assert.equal(wall.nodes.stage.hidden, true);
  console.log('PASS: Scoreboard, Word cloud and Emote wall render live or demo data in both languages');
}

async function main() {
  const starting = page('starting-soon');
  starting.fields({startTime: '12:01'});
  assert.equal(starting.nodes.stage.style['--stage-scale'], '0.5');
  starting.win.innerHeight = 270;
  starting.win.dispatchEvent(new Event('resize'));
  assert.equal(starting.nodes.stage.style['--stage-scale'], '0.25');
  assert.equal(starting.nodes.countdown.textContent, '1:00');
  starting.advance(1000);
  assert.equal(starting.nodes.countdown.textContent, '0:59');
  starting.advance(59000);
  assert.equal(starting.nodes.countdown.textContent, 'Starting now');
  starting.fields({startTime: '11:20'});
  assert.equal(starting.nodes.countdown.textContent, '23:19:00');
  starting.fields({startTime: ''});
  assert.equal(starting.nodes.countdown.hidden, true);
  console.log('PASS: stage letterboxes; Starting soon counts down, rolls time to tomorrow, completes and hides');

  starting.fields({messages: 'First | | ' + literal + ' |'});
  const lines = starting.nodes.messages.children;
  const active = () => lines.find(node => node.classList.contains('active')).textContent;
  assert.equal(active(), 'First');
  starting.advance(8000);
  assert.equal(active(), literal);
  starting.advance(8000);
  assert.equal(active(), 'First');
  starting.fields({messages: ' | | '});
  assert.equal(starting.nodes.messages.hidden, true);
  console.log('PASS: rotating messages split on |, skip blanks, crossfade and hide when empty');

  for (let i = 0; i < 7; i++) {
    starting.send('message', {id: String(i), platform: 'twitch', color: '#aa77cc',
      author: i === 6 ? literal : 'Viewer ' + i, text: literal, authorChannelId: String(i),
      items: [{kind: 'text', text: literal}, {kind: 'emoji', url: 'https://example.invalid/emote.png', alt: '🌙'}]});
  }
  const chat = starting.nodes['chat-messages'];
  const last = chat.children[5];
  assert.equal(chat.children.length, 6);
  assert.equal(chat.children[0].children[0].textContent, 'Viewer 1');
  assert.equal(last.children[0].children[1].textContent, literal);
  assert.match(last.children[0].children[1].style['--author'], /#aa77cc/);
  assert.equal(last.children[1].textContent, literal);
  assert.equal(last.children[1].children[0].children[1].tagName, 'IMG');
  assert.ok(last.classList.contains('chat-enter'));
  starting.send('moderation', {scope: 'message', platform: 'twitch', messageId: '6'});
  assert.equal(chat.children.length, 5);
  assert.ok(!chat.children.includes(last));
  starting.send('moderation', {scope: 'author', platform: 'twitch', authorChannelId: '3'});
  assert.equal(chat.children.length, 4);
  starting.send('moderation', {scope: 'platform', platform: 'twitch'});
  assert.equal(chat.children.length, 0);
  console.log('PASS: chat renders literal names, text and emotes; six-row cap and all delete scopes work');

  const brb = page('be-right-back');
  brb.fields({minutes: 1});
  assert.equal(brb.nodes.latest.hidden, true);
  brb.send('session', payload, true);
  assert.equal(brb.nodes['latest-entries'].children.length, 1);
  assert.ok(brb.nodes.latest.hidden === false);
  assert.ok(brb.nodes['latest-entries'].textContent.includes(literal));
  brb.advance(30000);
  assert.equal(brb.nodes.countdown.textContent, '0:30');
  brb.win.dispatchEvent(new CustomEvent('obsSourceActiveChanged', {detail: {active: false}}));
  assert.equal(brb.nodes.countdown.textContent, '0:30');
  brb.win.dispatchEvent(new CustomEvent('obsSourceActiveChanged', {detail: {active: true}}));
  assert.equal(brb.nodes.countdown.textContent, '1:00');
  brb.advance(60000);
  assert.equal(brb.nodes.countdown.textContent, 'Back any second');
  console.log('PASS: Be right back restarts on OBS activation and shows present support types as text');

  const ending = page('stream-ending');
  ending.send('session', payload, true);
  ending.fields({showTopChatters: true});
  assert.match(ending.nodes.stats.textContent, /Duration1:11:00Messages803Chatters47Supporters72/);
  assert.ok(ending.nodes.rankings.textContent.includes(literal));
  ending.fields({showMessages: false, showTopChatters: false});
  assert.ok(!ending.nodes.stats.textContent.includes('Messages'));
  assert.equal(ending.nodes.rankings.children.length, 1);
  ending.advance(1000);
  assert.match(ending.nodes.stats.textContent, /Duration1:11:00/);
  console.log('PASS: ending stats respect visibility and endedAt; ranking names remain text');

  const credits = page('credits');
  credits.send('session', payload, true);
  credits.fields({speed: 60, loop: true, finalText: literal});
  const roll = credits.nodes['credits-roll'];
  const headings = () => roll.children.map(node => node.children[0].textContent);
  assert.deepEqual(headings(), ['Gifted subs', 'Top gifted subs']);
  assert.deepEqual(roll.children[0].children[1].children.map(node => node.textContent), ['Earlier', literal]);
  assert.equal(roll.style['--roll-duration'], (roll.offsetHeight / 60) + 's');
  const bits = support('bits', 'New viewer', 17);
  credits.send('session', {...payload, supporters: [bits, ...payload.supporters]});
  assert.deepEqual(headings(), ['Gifted subs', 'Top gifted subs']);
  roll.dispatchEvent(Object.assign(new Event('animationend'), {animationName: 'roll-credits'}));
  assert.ok(credits.nodes['credits-page'].textContent.includes(literal));
  credits.advance(2200);
  assert.deepEqual(headings(), ['Bits', 'Gifted subs', 'Top gifted subs']);
  const empty = page('credits');
  empty.fields({finalText: literal});
  assert.equal(empty.nodes['credits-page'].textContent, 'Thanks for watching' + literal);
  empty.send('session', payload);
  assert.equal(empty.nodes['credits-roll'].hidden, false);
  empty.win.dispatchEvent(new CustomEvent('obsSourceActiveChanged', {detail: {active: true}}));
  assert.equal(empty.nodes['credits-roll'].hidden, false);
  const reduced = page('credits', 'es', {reduced: true});
  reduced.send('session', payload, true);
  reduced.fields({});
  assert.equal(reduced.nodes['credits-roll'].hidden, true);
  const tile = reduced.nodes['credits-page'];
  assert.equal(tile.textContent, 'RegalosEarlier' + literal);
  reduced.advance(6000);
  assert.ok(tile.classList.contains('credits-fade'));
  assert.match(tile.textContent, /^Más regalos/);
  reduced.advance(6000);
  assert.equal(tile.textContent, 'Gracias por acompañarnos');
  console.log('PASS: credits deduplicate and order literal names, omit absent types, snapshot each pass, use height/speed, restart in OBS and fade pages every 6s');

  starting.fields({background: 'transparent', backgroundMedia: 'C:\\private\\local.mp4'});
  assert.equal(starting.nodes.stage.dataset.background, 'transparent');
  starting.fields({background: 'media', backgroundMedia: '0123456789abcdef', logo: '0123456789abcdef'});
  await new Promise(setImmediate);
  const image = starting.nodes['background-media'].children[0];
  assert.equal(image.tagName, 'IMG');
  assert.equal(image.src, '/media/0123456789abcdef');
  assert.equal(starting.logo.children[0].src, image.src);
  image.dispatchEvent(new Event('load'));
  assert.equal(starting.nodes.stage.dataset.background, 'media');
  starting.fields({background: 'media', backgroundMedia: '0123456789abcdea'});
  await new Promise(setImmediate);
  const video = starting.nodes['background-media'].children[0];
  assert.ok(video.tagName === 'VIDEO' && video.muted && video.loop && video.autoplay);
  starting.fields({background: 'theme'});
  assert.equal(video.paused, true);
  assert.equal(video.src, undefined);
  console.log('PASS: background selects images/videos by library ID and releases video on mode change');

  for (const lang of ['en', 'es']) {
    for (const id of Object.keys(screens)) {
      const demo = page(id, lang, {demo: true});
      await new Promise(setImmediate);
      assert.deepEqual(demo.errors, []);
      assert.equal(demo.nodes.stage.hidden, false);
      assert.ok(demo.nodes.title.textContent);
      assert.equal(demo.nodes.messages.hidden, false);
      demo.advance(7500);
      if (demo.nodes.chat) {
        assert.ok(demo.nodes['chat-messages'].children.length > 0);
        assert.equal(demo.nodes.countdown.hidden, false);
      }
      if (demo.nodes.latest) assert.equal(demo.nodes['latest-entries'].children.length, 7);
      if (demo.nodes.rankings) assert.equal(demo.nodes.rankings.children.length, 4);
      if (id === 'credits') assert.ok(demo.nodes['credits-roll'].children.length >= 7);
    }
  }
  console.log('PASS: SDK demo renders all four screens with seeded data in English and Spanish');
  checkTicker();
  checkLatestSupport();
  checkTopSupporters();
  await checkWidgetDemos();
  await checkQueue();
  checkLivePages();
  await checkLiveWidgets();
}
main().catch(error => { console.error(error); process.exitCode = 1; });
''';

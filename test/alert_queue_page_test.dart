import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:airstream/services/overlay/templates/featured_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> runPage(String checks, {String view = 'alerts'}) async {
    final dir = await Directory.systemTemp.createTemp('airstream-alert-queue-');
    try {
      final script = File('${dir.path}/test.js');
      final html = switch (view) {
        'chat' => chatOverlayHtml(),
        'featured' => featuredOverlayHtml(),
        _ => alertsOverlayHtml(),
      };
      final js = html.split('<script>').last.split('</script>').first;
      await script.writeAsString('const page = ${jsonEncode(js)};\n'
          'const view = "$view";\n$checks');
      final result = await Process.run('node', [script.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test(
      'alerts queue preserves playing video and its timer across settings broadcasts',
      () => runPage(_queueChecks));
  test('clearing waiting alerts leaves active sound until expiry, skip or hide',
      () => runPage(_harness + _audioChecks));
  test('only alerts that reach a paint frame are acknowledged',
      () => runPage(_harness + _renderedChecks));
  test('alerts advance independently while a featured card is pinned',
      () => runPage(_harness + _featuredChecks));
  test('moderation redacts active and paused paid alerts without retiming',
      () => runPage(_harness + _moderationChecks));
  test(
      'featured page clears only matching moderated or newly blocked cards',
      () =>
          runPage(_pageHarness + _featuredModerationChecks, view: 'featured'));
  test('alerts moderation clears matching timed, pinned and queued features',
      () => runPage(_harness + _alertsFeaturedModerationChecks));
  test('block lists redact active and waiting paid alerts in place',
      () => runPage(_harness + _blockedPaidChecks));
  test('chat disconnect clears existing records before receiving new ones',
      () => runPage(_pageHarness + _chatDisconnectChecks, view: 'chat'));
  test('timed and pinned features follow their own position and font scale',
      () => runPage(_harness + _featuredStyleChecks));
  test('socket close clears timed and pinned featured cards on alerts',
      () => runPage(_harness + _featuredCloseChecks));
  test('socket close discards waiting alerts and releases active playback',
      () => runPage(_harness + _queueCloseChecks));
  test('alerts reports OBS activity on registration and after scene changes',
      () => runPage(_activityChecks));
  test('featured reports OBS activity on registration and after scene changes',
      () => runPage(_activityChecks, view: 'featured'));
  test('font policy switches update live without reloading or clearing cards',
      () => runPage(_harness + _fontChecks));
  for (final pinned in [true, false]) {
    test(
        '${pinned ? 'pinned' : 'timed'} featured text changes language without rebuilding or retiming',
        () => runPage('$_harness\nconst pinned = $pinned;\n$_languageChecks'));
  }
  test('a video error releases and removes the alert media',
      () => runPage(_harness + _videoErrorChecks));

  test('featured page applies settings and sends a paint acknowledgement', () {
    final html = featuredOverlayHtml();
    for (final code in [
      'applyOverlayFont(settings)',
      'settings.featuredPosition',
      'settings.featuredFontScale',
      'settings.featuredSeconds',
      'seconds > 0',
      'data.authorAvatarUrl',
      'data.amount',
      'data.items',
      'item.isZeroWidth',
      "registerSource(connection, 'featured',",
      'requestAnimationFrame(() => requestAnimationFrame',
      "type: 'featuredRendered', deliveryId: data.deliveryId",
      "envelope.type === 'featuredHide'",
    ]) {
      expect(html, contains(code));
    }
  });
}

const _pageHarness = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const frames = [];
const paints = [];
const sounds = [];
const timers = new Map();
const videos = [];
const createdVideos = [];
let timer = 0;
let lastDelay;
let reloads = 0;

class Media {
  stopped = false;
  pause() { this.stopped = true; }
  removeAttribute(name) { assert.equal(name, 'src'); this.released = true; }
  load() { this.reloaded = true; }
  play() { return Promise.resolve(); }
}
class Video extends Media {
  listeners = {};
  addEventListener(type, callback) { this.listeners[type] = callback; }
  remove() { this.removed = true; }
}
class Audio extends Media {
  constructor(url) { super(); this.url = url; sounds.push(this); }
}
const stages = [];
function element() { return {
  style: {
    setProperty(name, value) { this[name] = value; },
    removeProperty(name) { delete this[name]; },
  }, children: [],
  hasChildNodes() { return Boolean(this.textContent || this.children.length); },
  get firstElementChild() { return this.children[0] ?? null; },
  set firstElementChild(child) { this.replaceChildren(...(child ? [child] : [])); },
  appendChild(child) { child.parent = this; this.children.push(child); },
  append(...children) { children.forEach(child => this.appendChild(child)); },
  addEventListener() {},
  remove() { this.parent.children.splice(this.parent.children.indexOf(this), 1); },
  replaceWith(next) {
    this.parent.children[this.parent.children.indexOf(this)] = next;
    next.parent = this.parent;
  },
  querySelector(selector) {
    const [tag, className] = selector.split('.');
    return this.children.flatMap(child =>
      (!tag || child.tagName === tag) && child.className?.split(' ').includes(className)
        ? [child] : [child.querySelector?.(selector)]).find(Boolean) || null;
  },
  querySelectorAll: () => videos.splice(0),
  replaceChildren(...children) { this.children = []; this.append(...children); },
}; }
const root = view === 'alerts'
  ? { className: '', appendChild(child) { stages.push(child); } } : element();
class WebSocket extends EventTarget {
  static OPEN = 1;
  readyState = WebSocket.OPEN;
  send(data) { frames.push(JSON.parse(data)); }
  close() { this.readyState = 3; this.dispatchEvent(new Event('close')); }
  deliver(envelope) {
    this.dispatchEvent(new MessageEvent('message', {data: JSON.stringify(envelope)}));
  }
}
const window = new EventTarget();
window.setTimeout = (fn, delay) => {
  lastDelay = delay;
  timers.set(++timer, fn);
  return timer;
};
window.clearTimeout = (id) => timers.delete(id);
window.setInterval = window.setTimeout;
window.requestAnimationFrame = fn => paints.push(fn);
window.cancelAnimationFrame = () => {};
const document = {
  documentElement: {style: {
    setProperty(name, value) { this[name] = value; },
    removeProperty(name) { delete this[name]; },
  }},
  head: element(),
  getElementById: () => root,
  createElement: (tag) => {
    if (tag !== 'video') return Object.assign(element(), {tagName: tag});
    const video = new Video();
    createdVideos.push(video);
    return video;
  },
};
const context = vm.createContext({
  window, document, WebSocket, Audio, videos, Media, console,
  location: {protocol: 'http:', host: 'localhost:8080', reload() { reloads++; }},
  requestAnimationFrame(fn) { paints.push(fn); },
  setTimeout: window.setTimeout, clearTimeout: window.clearTimeout,
  Date: { now: () => 1000 },
});
vm.runInContext(page, context);
const run = (code) => vm.runInContext(code, context);
''';

const _harness = _pageHarness +
    r'''
const [stage, featuredStage] = stages;
run(`const realRenderAlert = renderAlert;
renderAlert = (alert, target = stage) => {
  target.firstElementChild = {id: alert.id, isConnected: true};
  videos.push(new Media());
};`);
const socket = run('socket');
socket.dispatchEvent(new Event('open'));
const status = (paused, pending, active) =>
  assert.deepEqual(frames.at(-1), {type: 'alertQueue', paused, pending, active});
const op = (op) => socket.deliver({type: 'alertControl', op});
const alert = (id, kind = 'bits', option = {}) =>
  socket.deliver({type: 'alert', data: {id, kind, alertType: 'bits', option}});
const finish = () => timers.get(run('hideTimer'))();
''';

const _featuredModerationChecks = r'''
const socket = run('socket');
const show = (message = 'All good') => socket.deliver({type: 'alert', data: {
  id: 'shared', kind: 'featured', platform: 'youtube',
  youtubeStreamOrientation: 'vertical', author: 'Viewer', authorChannelId: 'viewer',
  message,
}});
const remove = (scope, extra) => socket.deliver({type: 'moderation', data: {
  platform: 'youtube', scope, ...extra,
}});
show();
remove('message', {messageId: 'shared', youtubeStreamOrientation: 'horizontal'});
assert.ok(root.firstElementChild);
remove('message', {messageId: 'shared', youtubeStreamOrientation: 'vertical'});
assert.equal(root.firstElementChild, null);
show('A forbidden, phrase!');
socket.deliver({type: 'filters', data: {users: [], words: ['forbidden phrase']}});
assert.equal(root.firstElementChild, null);
show();
socket.deliver({type: 'filters', data: {users: ['viewer'], words: []}});
assert.equal(root.firstElementChild, null);
''';

const _alertsFeaturedModerationChecks = r'''
const show = () => socket.deliver({type: 'alert', data: {
  id: 'feature', kind: 'featured', platform: 'youtube',
  youtubeStreamOrientation: 'horizontal', author: 'Viewer', authorChannelId: 'viewer',
}});
const remove = (extra) => socket.deliver({type: 'moderation', data: {
  platform: 'youtube', scope: 'message', messageId: 'feature',
  youtubeStreamOrientation: 'horizontal', ...extra,
}});
op('resume');
alert('paid');
show();
remove({youtubeStreamOrientation: 'vertical'});
assert.equal(run('queue.length'), 1);
remove({sequence: 123});
assert.equal(run('queue.length'), 0);
assert.equal(stage.firstElementChild.id, 'paid');

finish();
show();
remove({scope: 'platform'});
assert.equal(stage.firstElementChild, null);
socket.deliver({type: 'settings', data: {featuredSeconds: 0}});
show();
assert.ok(featuredStage.firstElementChild);
socket.deliver({type: 'filters', data: {users: ['viewer'], words: []}});
assert.equal(featuredStage.firstElementChild, null);
''';

const _blockedPaidChecks = r'''
run('renderAlert = realRenderAlert');
const pay = (id, author, message) => socket.deliver({type: 'alert', data: {
  id, kind: 'superchat', author, authorChannelId: id, message, amount: '$5',
}});
op('resume');
pay('blocked-id', 'Personal Name', 'Thanks');
const card = stage.firstElementChild;
const timerBefore = run('hideTimer');
op('pause');
pay('waiting', 'Kept Name', 'A Bad, Phrase!');
pay('safe', 'Another Viewer', 'bad phrases');
socket.deliver({type: 'filters', data: {users: ['blocked-id'], words: ['bad phrase']}});
assert.equal(stage.firstElementChild, card);
assert.equal(run('hideTimer'), timerBefore);
assert.equal(stage.querySelector('.alert-message'), null);
assert.equal(stage.querySelector('.alert-title').textContent, 'Someone sent $5');
assert.equal(stage.querySelector('.alert-avatar-fallback').textContent, 'SO');
finish();
op('resume');
assert.equal(stage.querySelector('.alert-message'), null);
assert.equal(stage.querySelector('.alert-title').textContent, 'Kept Name sent $5');
finish();
assert.equal(stage.querySelector('.alert-message').textContent, 'bad phrases');
''';

const _chatDisconnectChecks = r'''
run('createMessageBubble = (message) => Object.assign(document.createElement("div"), {id: message.id})');
const show = (id) => run('socket').deliver({type: 'message', sequence: 1,
  data: {id, platform: 'youtube'}});
const chat = run('chatOverlay');
show('before restart');
assert.equal(chat.firstElementChild.id, 'before restart');
run('socket').close();
assert.equal(run('records.length'), 0);
assert.equal(chat.firstElementChild, null);
timers.get(run('retryTimer'))();
show('after restart');
assert.deepEqual(chat.children.map(row => row.id), ['after restart']);
''';

const _featuredStyleChecks = r'''
run('renderAlert = realRenderAlert');
op('resume');
const configure = data => socket.deliver({type: 'settings', data});
configure({alertPosition: 'bottom', alertFontSize: 20, featuredPosition: 'top',
  featuredFontScale: 150});
alert('timed', 'featured');
assert.equal(stage.style.alignItems, 'flex-start');
assert.equal(stage.style.fontSize, '30px');
const card = stage.firstElementChild;
const timerBefore = run('hideTimer');
configure({featuredPosition: 'center', featuredFontScale: 125});
assert.equal(stage.style.alignItems, 'center');
assert.equal(stage.style.fontSize, '25px');
assert.equal(stage.firstElementChild, card);
assert.equal(run('hideTimer'), timerBefore);
configure({featuredSeconds: 0, featuredPosition: 'bottom'});
assert.equal(featuredStage.style.alignItems, 'flex-end');
assert.equal(featuredStage.style.fontSize, '25px');
assert.equal(stage.style.fontSize, '20px');
alert('paid');
assert.equal(stage.style.alignItems, 'flex-end');
configure({featuredPosition: 'center'});
assert.match(root.className, /featured-centered alerts-below-featured/);
assert.equal(featuredStage.style.alignItems, 'center');
configure({featuredPosition: 'top', featuredFontScale: 180});
assert.match(featuredStage.className, /above-alerts/);
assert.equal(featuredStage.style.alignItems, 'flex-start');
assert.equal(featuredStage.style.fontSize, '36px');
assert.equal(stage.style.fontSize, '20px');
''';

const _moderationChecks = r'''
run('renderAlert = realRenderAlert');
const pay = (id, orientation) => socket.deliver({type: 'alert', data: {
  id, kind: 'superchat', platform: 'youtube', youtubeStreamOrientation: orientation,
  author: 'Viewer', authorChannelId: 'viewer', message: 'Paid message', amount: '$5',
}});
const remove = (data) => socket.deliver({type: 'moderation', data: {
  platform: 'youtube', youtubeStreamOrientation: 'horizontal', ...data,
}});
op('resume');
pay('active', 'horizontal');
const timerBefore = run('hideTimer');
assert.equal(stage.querySelector('.alert-message').textContent, 'Paid message');
op('pause');
pay('waiting', 'horizontal');
pay('waiting', 'vertical');
remove({scope: 'message', messageId: 'active'});
remove({scope: 'author', authorChannelId: 'viewer'});
assert.equal(stage.querySelector('.alert-message'), null);
assert.match(stage.querySelector('.alert-title').textContent, /Viewer/);
assert.match(stage.querySelector('.alert-title').textContent, /\$5/);
assert.equal(run('hideTimer'), timerBefore);
finish();
op('resume');
assert.equal(stage.querySelector('.alert-message'), null);
finish();
assert.equal(stage.querySelector('.alert-message').textContent, 'Paid message');
''';

const _queueCloseChecks = r'''
op('resume');
alert('playing', 'bits', {sound: 'coin'});
const oldVideo = videos[0];
alert('waiting');
assert.equal(stage.firstElementChild.id, 'playing');
assert.equal(run('queue.length'), 1);
socket.close();
assert.equal(run('queue.length'), 0);
assert.equal(stage.firstElementChild, null);
assert.ok(sounds[0].released);
assert.ok(oldVideo.released);
assert.equal(run('hideTimer'), 0);
run('connect()');
const next = run('socket');
next.dispatchEvent(new Event('open'));
next.deliver({type: 'alertControl', op: 'resume'});
assert.equal(stage.firstElementChild, null);
status(false, 0, false);
next.deliver({type: 'alert', data: {id: 'new', kind: 'bits'}});
assert.equal(stage.firstElementChild.id, 'new');
''';

const _activityChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
function setup(inObs) {
  const window = new EventTarget();
  if (inObs) window.obsstudio = {};
  const node = {style: {setProperty() {}, removeProperty() {}}, appendChild() {}};
  const document = {
    visibilityState: 'hidden',
    documentElement: node,
    getElementById: () => node,
    head: node,
    createElement: () => node,
  };
  const sockets = [];
  class WebSocket extends EventTarget {
    static OPEN = 1;
    readyState = 0;
    frames = [];
    constructor() { super(); sockets.push(this); }
    send(data) { this.frames.push(JSON.parse(data)); }
    open() { this.readyState = 1; this.dispatchEvent(new Event('open')); }
  }
  const context = vm.createContext({window, document, WebSocket, console,
    location: {protocol: 'http:', host: 'localhost'}});
  vm.runInContext(page, context);
  return {window, sockets, reconnect: () => vm.runInContext('connect()', context)};
}
const capabilities = view === 'alerts' ? {alertDisplayAck: true} : {};
const browser = setup(false);
browser.sockets[0].open();
assert.deepEqual(browser.sockets[0].frames, [{type:'register', view, active:true, inObs:false, ...capabilities}]);

const obs = setup(true);
const first = obs.sockets[0];
first.open();
assert.deepEqual(first.frames, [{type:'register', view, active:false, inObs:true, ...capabilities}]);
obs.window.dispatchEvent(new CustomEvent('obsSourceActiveChanged', {detail:{active:true}}));
assert.deepEqual(first.frames.at(-1), {type:'sourceActivity', active:true});
obs.window.obsstudio.onActiveChange(false);
assert.deepEqual(first.frames.at(-1), {type:'sourceActivity', active:false});
obs.window.dispatchEvent(new CustomEvent('obsSourceActiveChanged', {detail:{active:false}}));
assert.equal(first.frames.length, 3);
first.readyState = 3;
obs.window.obsstudio.onActiveChange(true);
assert.equal(first.frames.length, 3);
obs.reconnect();
obs.sockets[1].open();
assert.deepEqual(obs.sockets[1].frames, [{type:'register', view, active:true, inObs:true, ...capabilities}]);
''';

const _queueChecks = _harness +
    r'''
assert.deepEqual(frames[0], {type: 'register', view: 'alerts', active: true, inObs: false, alertDisplayAck: true});
alert('before-sync');
assert.equal(stage.firstElementChild, null);
op('pause');
status(true, 1, false);
alert('second', 'bits', {sound: 'coin'});
status(true, 2, false);
op('resume');
status(false, 1, true);
assert.equal(stage.firstElementChild.id, 'before-sync');
op('pause');
status(true, 1, true);
finish();
status(true, 1, false);
assert.equal(stage.firstElementChild, null);
op('resume');
status(false, 0, true);
assert.equal(stage.firstElementChild.id, 'second');
assert.equal(sounds[0].url, '/sounds/coin.wav');
const playingVideo = videos[0];
const activeCard = stage.firstElementChild;
const activeTimer = run('hideTimer');
socket.deliver({type: 'settings', data: {alertPosition: 'top', alertDisplaySeconds: 20}});
assert.equal(stage.style.alignItems, 'flex-start');
assert.equal(stage.firstElementChild, activeCard);
assert.deepEqual(videos, [playingVideo]);
assert.equal(playingVideo.stopped, false);
assert.equal(run('hideTimer'), activeTimer);
assert.equal(timers.has(activeTimer), true);
alert('third', 'bits', {sound: 'custom', soundKey: 'abc'});
op('skip');
assert.equal(sounds[0].stopped, true);
assert.equal(playingVideo.stopped, true);
assert.equal(stage.firstElementChild.id, 'third');
assert.equal(lastDelay, 20000);
assert.equal(sounds[1].url, '/sounds/custom/bits?tier=abc');
for (let i = 0; i < 30; i++) alert('waiting-' + i);
status(false, 20, true);
op('clear');
status(false, 0, true);
assert.equal(stage.firstElementChild.id, 'third');
alert('featured', 'featured');
alert('regular');
finish();
assert.equal(stage.firstElementChild.id, 'featured');
socket.deliver({type: 'featuredHide'});
assert.equal(stage.firstElementChild.id, 'regular');
status(false, 0, true);
// Pausing holds alerts but never a message the streamer chose to feature.
op('pause');
alert('held');
alert('picked', 'featured');
finish();
assert.equal(stage.firstElementChild.id, 'picked');
finish();
assert.equal(stage.firstElementChild, null);
status(true, 1, false);
''';

const _audioChecks = r'''
op('resume');
alert('first', 'bits', {sound: 'coin'});
alert('second', 'bits', {sound: 'coin'});
finish();
assert.equal(stage.firstElementChild.id, 'second');
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[0][key], true);
}
op('skip');
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[1][key], true);
}
alert('third', 'bits', {sound: 'coin'});
alert('waiting');
op('clear');
assert.equal(stage.firstElementChild.id, 'third');
status(false, 0, true);
assert.equal(sounds[2].stopped, false);
assert.equal(sounds[2].released, undefined);
finish();
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[2][key], true);
}
alert('fourth', 'bits', {sound: 'coin'});
window.dispatchEvent(new Event('beforeunload'));
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[3][key], true);
}
''';

const _renderedChecks = r'''
const automatic = id => socket.deliver({type: 'alert', alertDeliveryId: id,
  data: {id: String(id), kind: 'bits'}});
const rendered = () => frames.filter(frame => frame.type === 'alertRendered')
  .map(frame => frame.deliveryId);
const discarded = () => frames.filter(frame => frame.type === 'alertDiscarded')
  .map(frame => frame.deliveryId);
const paint = () => paints.splice(0).forEach(frame => frame());
op('pause');
automatic(1);
op('clear');
op('resume');
paint();
paint();
assert.deepEqual(rendered(), []);

automatic(2);
op('skip');
automatic(3);
paint();
assert.deepEqual(rendered(), []);
paint();
assert.deepEqual(rendered(), [3]);
assert.deepEqual(discarded(), [1, 2]);
finish();
alert('test-or-replay');
paint();
paint();
assert.deepEqual(rendered(), [3]);
op('pause');
for (let id = 4; id <= 24; id++) automatic(id);
assert.deepEqual(discarded(), [1, 2, 4]);
''';

const _featuredChecks = r'''
op('resume');
socket.deliver({type: 'settings', data: {alertDisplaySeconds: 20, featuredSeconds: 11}});
alert('timed', 'featured');
assert.equal(lastDelay, 11000);
finish();
socket.deliver({type: 'settings', data: {featuredSeconds: 0}});
socket.deliver({type: 'alert', data: {
  id: 'pinned', kind: 'featured', deliveryId: 'pinned-delivery',
}});
assert.equal(timers.size, 0);
alert('regular');
assert.equal(stage.firstElementChild.id, 'regular');
assert.equal(featuredStage.firstElementChild.id, 'pinned');
paints.shift()();
paints.shift()();
assert.deepEqual(frames.at(-1), {
  type: 'featuredRendered', deliveryId: 'pinned-delivery',
});
alert('next');
op('skip');
assert.equal(stage.firstElementChild.id, 'next');
assert.equal(featuredStage.firstElementChild.id, 'pinned');
alert('after-skip');
finish();
assert.equal(stage.firstElementChild.id, 'after-skip');
assert.equal(featuredStage.firstElementChild.id, 'pinned');
alert('replacement', 'featured');
assert.equal(featuredStage.firstElementChild.id, 'replacement');
assert.equal(stage.firstElementChild.id, 'after-skip');
socket.deliver({type: 'featuredHide'});
assert.equal(featuredStage.firstElementChild, null);
assert.equal(stage.firstElementChild.id, 'after-skip');
finish();
alert('duration-changed', 'featured');
socket.deliver({type: 'settings', data: {featuredSeconds: 8}});
assert.equal(lastDelay, 8000);
[...timers.values()][0]();
assert.equal(featuredStage.firstElementChild, null);
assert.equal(stage.firstElementChild, null);
''';

const _featuredCloseChecks = r'''
op('resume');
alert('timed', 'featured');
alert('waiting');
socket.close();
assert.equal(stage.firstElementChild, null);
assert.equal(run('queue.length'), 0);
const reconnect = timers.get(run('retryTimer'));
reconnect();
const nextSocket = run('socket');
nextSocket.deliver({type: 'alertControl', op: 'resume'});
assert.equal(stage.firstElementChild, null);
nextSocket.deliver({type: 'settings', data: {featuredSeconds: 0}});
nextSocket.deliver({type: 'alert', data: {id: 'pinned', kind: 'featured'}});
assert.equal(featuredStage.firstElementChild.id, 'pinned');
nextSocket.close();
assert.equal(featuredStage.firstElementChild, null);
assert.equal(stage.firstElementChild, null);
''';

const _fontChecks = r'''
op('resume');
socket.deliver({type: 'settings', data: {
  featuredSeconds: 0, chatFontFamily: 'Arial', googleFontStylesheet: null,
}});
assert.equal(document.head.children.length, 0);
alert('pinned', 'featured');
alert('active');
alert('waiting');
const pinned = featuredStage.firstElementChild;
const active = stage.firstElementChild;
const timerBefore = run('hideTimer');
const stylesheet = 'https://fonts.googleapis.com/css2?family=Inter';
socket.deliver({type: 'settings', data: {
  chatFontFamily: 'Inter', googleFontStylesheet: stylesheet,
}});
assert.equal(document.head.children.length, 1);
assert.equal(document.head.children[0].href, stylesheet);
assert.match(document.documentElement.style['--overlay-font-family'], /Inter/);
socket.deliver({type: 'settings', data: {
  chatFontFamily: 'Inter', googleFontStylesheet: null,
}});
assert.equal(document.head.children.length, 0);
assert.equal(reloads, 0);
assert.equal(stage.firstElementChild, active);
assert.equal(featuredStage.firstElementChild, pinned);
assert.equal(run('hideTimer'), timerBefore);
assert.equal(run('queue[0].id'), 'waiting');
''';

const _languageChecks = r'''
run('renderAlert = realRenderAlert');
op('resume');
socket.deliver({type: 'settings', data: {featuredSeconds: pinned ? 0 : 7, appLanguageCode: 'en'}});
socket.deliver({type: 'alert', data: {
  id: 'pinned', kind: 'featured', platform: 'youtube',
  stickerUrl: 'https://example.invalid/sticker.png', deliveryId: 'delivery',
}});
const target = pinned ? featuredStage : stage;
const card = target.firstElementChild;
const sticker = target.querySelector('.alert-sticker');
const avatar = target.querySelector('.alert-avatar-fallback');
const title = target.querySelector('.alert-title');
const kicker = target.querySelector('.alert-kicker');
assert.ok(sticker);
assert.equal(avatar.textContent, 'SO');
assert.equal(title.textContent, 'Someone');
assert.equal(kicker.textContent, 'YouTube · From chat');
const shownAtName = pinned ? 'pinnedShownAt' : 'featuredShownAt';
const hideTimerName = pinned ? 'pinnedHideTimer' : 'hideTimer';
const shownAt = run(shownAtName);
const hideTimer = run(hideTimerName);
if (!pinned) assert.ok(timers.has(hideTimer));
const paintCount = paints.length;

socket.deliver({type: 'settings', data: {appLanguageCode: 'es'}});
assert.equal(target.firstElementChild, card);
assert.equal(target.querySelector('.alert-sticker'), sticker);
assert.equal(target.querySelector('.alert-title'), title);
assert.equal(target.querySelector('.alert-kicker'), kicker);
assert.equal(target.querySelector('.alert-avatar-fallback'), avatar);
assert.equal(avatar.textContent, 'AL');
assert.equal(title.textContent, 'Alguien');
assert.equal(kicker.textContent, 'YouTube · Del chat');
assert.equal(run(shownAtName), shownAt);
assert.equal(run(hideTimerName), hideTimer);
assert.equal(paints.length, paintCount);
''';

const _videoErrorChecks = r'''
run('renderAlert = realRenderAlert');
op('resume');
alert('video', 'bits', { mediaKind: 'video', media: 'my-video' });
const video = createdVideos.at(-1);
assert.ok(video);
assert.doesNotThrow(() => video.listeners.error());
for (const key of ['stopped', 'released', 'reloaded', 'removed']) {
  assert.equal(video[key], true);
}
''';

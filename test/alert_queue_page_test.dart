import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/featured_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> runPage(String checks) async {
    final dir = await Directory.systemTemp.createTemp('airstream-alert-queue-');
    try {
      final script = File('${dir.path}/test.js');
      final html = alertsOverlayHtml();
      final js = html.split('<script>').last.split('</script>').first;
      await script.writeAsString('const page = ${jsonEncode(js)};\n$checks');
      final result = await Process.run('node', [script.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test(
      'alerts queue preserves playing video and its timer across settings broadcasts',
      () => runPage(_queueChecks));
  test('expiry, skip, clear and hide release the active alert sound',
      () => runPage(_harness + _audioChecks));
  test('alerts fallback uses featured duration and replaces pinned cards',
      () => runPage(_harness + _featuredChecks));

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
      "type: 'register', view: 'featured'",
      'requestAnimationFrame(() => requestAnimationFrame',
      "type: 'featuredRendered', deliveryId: data.deliveryId",
      "envelope.type === 'featuredHide'",
    ]) {
      expect(html, contains(code));
    }
  });
}

const _harness = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const frames = [];
const sounds = [];
const timers = new Map();
const videos = [];
let timer = 0;
let lastDelay;

class Media {
  stopped = false;
  pause() { this.stopped = true; }
  removeAttribute(name) { assert.equal(name, 'src'); this.released = true; }
  load() { this.reloaded = true; }
  play() { return Promise.resolve(); }
}
class Audio extends Media {
  constructor(url) { super(); this.url = url; sounds.push(this); }
}
const stage = {
  style: {}, firstElementChild: null,
  querySelectorAll: () => videos.splice(0),
  replaceChildren() { this.firstElementChild = null; },
};
class WebSocket extends EventTarget {
  static OPEN = 1;
  readyState = WebSocket.OPEN;
  send(data) { frames.push(JSON.parse(data)); }
  close() { this.dispatchEvent(new Event('close')); }
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
const document = {
  documentElement: {},
  getElementById: () => ({ appendChild() {} }),
  createElement: () => stage,
};
const context = vm.createContext({
  window, document, WebSocket, Audio, stage, videos, Media, console,
  location: {protocol: 'http:', host: 'localhost:8080'},
  requestAnimationFrame() {},
  Date: { now: () => 1000 },
});
vm.runInContext(page, context);
const run = (code) => vm.runInContext(code, context);
run(`renderAlert = (alert) => {
  stage.firstElementChild = {id: alert.id};
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

const _queueChecks = _harness +
    r'''
assert.deepEqual(frames[0], {type: 'register', view: 'alerts'});
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
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[2][key], true);
}
finish();
alert('fourth', 'bits', {sound: 'coin'});
window.dispatchEvent(new Event('beforeunload'));
for (const key of ['stopped', 'released', 'reloaded']) {
  assert.equal(sounds[3][key], true);
}
''';

const _featuredChecks = r'''
op('resume');
socket.deliver({type: 'settings', data: {alertDisplaySeconds: 20, featuredSeconds: 11}});
alert('timed', 'featured');
assert.equal(lastDelay, 11000);
finish();
socket.deliver({type: 'settings', data: {featuredSeconds: 0}});
alert('pinned', 'featured');
assert.equal(timers.size, 0);
alert('regular');
op('skip');
assert.equal(stage.firstElementChild.id, 'pinned');
status(false, 1, true);
alert('replacement', 'featured');
assert.equal(stage.firstElementChild.id, 'replacement');
assert.equal(timers.size, 0);
socket.deliver({type: 'featuredHide'});
assert.equal(stage.firstElementChild.id, 'regular');
assert.equal(lastDelay, 20000);
alert('older', 'featured');
alert('newest', 'featured');
status(false, 1, true);
finish();
assert.equal(stage.firstElementChild.id, 'newest');
assert.equal(timers.size, 0);
socket.deliver({type: 'settings', data: {featuredSeconds: 8}});
assert.equal(lastDelay, 8000);
finish();
assert.equal(stage.firstElementChild, null);
''';

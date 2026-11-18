import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/featured_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alerts queue pauses, drains, skips media and reports page state',
      () async {
    final dir = await Directory.systemTemp.createTemp('airstream-alert-queue-');
    try {
      final script = File('${dir.path}/test.js');
      final html = alertsOverlayHtml();
      final js = html.split('<script>').last.split('</script>').first;
      await script
          .writeAsString('const page = ${jsonEncode(js)};\n$_queueChecks');
      final result = await Process.run('node', [script.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await dir.delete(recursive: true);
    }
  });

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

const _queueChecks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const frames = [];
const sounds = [];
const timers = new Map();
const videos = [];
let timer = 0;

class Media {
  stopped = false;
  pause() { this.stopped = true; }
  removeAttribute(name) { assert.equal(name, 'src'); }
  load() {}
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
  deliver(envelope) {
    this.dispatchEvent(new MessageEvent('message', {data: JSON.stringify(envelope)}));
  }
}
const window = new EventTarget();
window.setTimeout = (fn) => { timers.set(++timer, fn); return timer; };
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
alert('third', 'bits', {sound: 'custom', soundKey: 'abc'});
op('skip');
assert.equal(sounds[0].stopped, true);
assert.equal(playingVideo.stopped, true);
assert.equal(stage.firstElementChild.id, 'third');
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
''';

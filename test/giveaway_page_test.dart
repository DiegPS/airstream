import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/giveaway_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giveaway page drops blocked displayed and queued draws', () async {
    final temp = await Directory.systemTemp.createTemp('giveaway-page-');
    try {
      final script = File('${temp.path}/test.js');
      final page =
          giveawayOverlayHtml().split('<script>').last.split('</script>').first;
      await script.writeAsString('const page = ${jsonEncode(page)};\n$_checks');
      final result = await Process.run('node', [script.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await temp.delete(recursive: true);
    }
  });
}

const _checks = r'''
const assert = require('node:assert/strict');
const vm = require('node:vm');
const timers = new Map();
const sockets = [];
let nextTimer = 0;
function element() {
  return {
    children: [], style: {}, textContent: '',
    append(...children) { this.children.push(...children); },
    replaceChildren(...children) { this.children = children; },
  };
}
const card = element();
const document = {
  documentElement: element(), createElement: element,
  getElementById: () => card, createTextNode: text => ({textContent: text}),
};
class WebSocket extends EventTarget {
  constructor() { super(); sockets.push(this); }
}
const window = new EventTarget();
window.setInterval = () => ++nextTimer;
window.clearInterval = () => {};
window.setTimeout = (fn, delay) => { timers.set(++nextTimer, {fn, delay}); return nextTimer; };
window.clearTimeout = id => timers.delete(id);
vm.runInNewContext(page, {document, window, WebSocket, console,
  location: {protocol: 'http:', host: 'localhost'}});
const send = (drawId, name, hiddenDrawIds = [], replay = false) => {
  sockets.at(-1).dispatchEvent(new MessageEvent('message', {data: JSON.stringify({
    type: 'giveaway', replay, data: {phase: 'drawn', keyword: 'go',
      entrantCount: 1, drawId, hiddenDrawIds,
      winner: name ? {name, platform: 'twitch'} : null},
  })}));
};
const tick = delay => {
  const [id, timer] = [...timers].find(([, timer]) => timer.delay === delay);
  timers.delete(id);
  timer.fn();
};
const heading = () => card.children[0].textContent;

send(1, 'Ana');
send(2, 'Beto');
send(3, 'Carla');
send(3, 'Carla', [2]);
tick(2500);
assert.equal(heading(), 'Ana');
tick(1600);
tick(2500);
assert.equal(heading(), 'Carla');
assert.equal(timers.size, 0);

send(3, null, [2, 3]);
assert.equal(heading(), 'go');
sockets.at(-1).dispatchEvent(new Event('close'));
tick(3000);
send(3, null, [2, 3], true);
assert.equal(heading(), 'go');

send(4, 'Dani');
send(5, 'Eva');
send(5, 'Eva', [4]);
tick(2500);
assert.equal(heading(), 'Eva');
''';

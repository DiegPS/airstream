import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/captions_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:airstream/services/overlay/templates/clock_overlay.dart';
import 'package:airstream/services/overlay/templates/featured_overlay.dart';
import 'package:airstream/services/overlay/templates/giveaway_overlay.dart';
import 'package:airstream/services/overlay/templates/goals_overlay.dart';
import 'package:airstream/services/overlay/templates/poll_overlay.dart';
import 'package:airstream/services/overlay/templates/sdk_v1.dart';
import 'package:airstream/services/overlay/templates/timer_overlay.dart';
import 'package:airstream/services/templates/gallery/gallery_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every page OBS loads must at least parse: a single syntax error leaves a
/// browser source blank with no sign in the app.
void main() {
  test('every built-in page and gallery script parses in JavaScript', () async {
    await _runNode(_pageScripts(), r'''
const vm = require('node:vm');
const failures = [];
for (const [name, source] of Object.entries(sources)) {
  try { new vm.Script(source, {filename: name}); }
  catch (error) { failures.push(name + ': ' + error.message); }
}
if (failures.length) { console.error(failures.join('\n')); process.exit(1); }
''');
  });

  test('every built-in page and gallery script declares its bare calls',
      () async {
    expect(await _undeclaredCalls(_pageScripts()), isEmpty);
  });

  test('the bare-call safeguard catches releaseVideo in the alerts handler',
      () async {
    final alerts = _pageScripts()['alerts#0']!;
    final regressed =
        alerts.replaceFirst('releaseMedia(medium)', 'releaseVideo(medium)');
    expect(regressed, isNot(alerts));
    expect(await _undeclaredCalls({'alerts': regressed}), {
      'alerts': ['releaseVideo'],
    });
  });

  test('every gallery widget has a slot for the logo field', () {
    for (final item in galleryCatalog.values) {
      expect(item.buildFiles('en')['index.html'], contains('gallery-logo'),
          reason: item.id);
    }
  });
}

Map<String, String> _pageScripts() {
  final sources = <String, String>{'sdk/v1.js': sdkV1()};
  final inline = RegExp(r'<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)</script>');
  final pages = {
    'alerts': alertsOverlayHtml(),
    'captions': captionsOverlayHtml(),
    'chat': chatOverlayHtml(),
    'clock': clockOverlayHtml(),
    'featured': featuredOverlayHtml(),
    'giveaway': giveawayOverlayHtml(),
    'goals': goalsOverlayHtml(),
    'poll': pollOverlayHtml(),
    'timer': timerOverlayHtml(),
  };
  for (final page in pages.entries) {
    final scripts = inline.allMatches(page.value).toList();
    expect(scripts, isNotEmpty, reason: page.key);
    for (var i = 0; i < scripts.length; i++) {
      sources['${page.key}#$i'] = scripts[i][1]!;
    }
  }
  for (final item in galleryCatalog.values) {
    for (final language in ['en', 'es']) {
      sources['gallery/${item.id}/$language'] =
          item.buildFiles(language)['script.js']!;
    }
  }
  return sources;
}

Future<String> _runNode(Map<String, String> sources, String checks) async {
  final dir = await Directory.systemTemp.createTemp('airstream-page-scripts-');
  try {
    final script = File('${dir.path}/check.js');
    await script
        .writeAsString('const sources = ${jsonEncode(sources)};\n$checks');
    final result = await Process.run('node', [script.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return result.stdout as String;
  } finally {
    await dir.delete(recursive: true);
  }
}

Future<Map<String, dynamic>> _undeclaredCalls(
        Map<String, String> sources) async =>
    jsonDecode(await _runNode(sources, _bareCallCheck)) as Map<String, dynamic>;

// A script-wide check for misspelled calls. The parse test handles syntax.
const _bareCallCheck = r'''
const globals = new Set([
  'setTimeout', 'clearTimeout', 'setInterval', 'clearInterval',
  'requestAnimationFrame', 'cancelAnimationFrame', 'queueMicrotask',
  'Number', 'String', 'Boolean', 'Array', 'Object', 'Math', 'JSON', 'Date',
  'Map', 'Set', 'WeakMap', 'WeakSet', 'Promise', 'RegExp', 'BigInt', 'Symbol',
  'encodeURI', 'decodeURI', 'encodeURIComponent', 'decodeURIComponent',
  'parseInt', 'parseFloat', 'isNaN', 'isFinite', 'Intl',
  'Error', 'TypeError', 'RangeError', 'structuredClone',
  'fetch', 'AbortController', 'URL', 'URLSearchParams', 'WebSocket', 'Audio', 'Image',
  'Event', 'CustomEvent', 'DOMParser', 'MutationObserver', 'ResizeObserver',
  'getComputedStyle', 'matchMedia', 'alert', 'atob', 'btoa', 'Airstream',
]);
const keywords = new Set([
  'if', 'else', 'for', 'while', 'switch', 'catch', 'with', 'do', 'return',
  'throw', 'typeof', 'void', 'delete', 'await', 'yield', 'function', 'import',
  'in', 'of', 'case', 'super',
]);
const identifier = /^[A-Za-z_$][\w$]*$/;
const groups = {'(': ')', '[': ']', '{': '}'};

function tokenize(source) {
  const tokens = [];
  const ignored = /\s+|\/\/[^\r\n]*|\/\*[\s\S]*?\*\//y;
  const string = /'(?:\\[\s\S]|[^'\\])*'|"(?:\\[\s\S]|[^"\\])*"/y;
  const regex = /\/(?:\\.|\[(?:\\.|[^\]\\])*\]|[^/[\r\n\\])+\/[a-z]*/iy;
  const word = /[A-Za-z_$][\w$]*|\d+(?:\.\d+)?|=>|\?\.|\.\.\.|[^\s]/y;
  const beforeRegex = new Set([
    undefined, '=', '(', '[', '{', ',', ':', '?', ';', '!', '&', '|',
    'return', 'throw', '=>',
  ]);
  let offset = 0;
  function consume(pattern) {
    pattern.lastIndex = offset;
    const match = pattern.exec(source);
    if (!match) return null;
    offset = pattern.lastIndex;
    return match[0];
  }
  function template() {
    offset++;
    while (offset < source.length) {
      const char = source[offset++];
      if (char.charCodeAt(0) === 96) return;
      if (char === '\\') offset++;
      if (char === '$' && source[offset] === '{') {
        offset++;
        tokens.push('{');
        code(true);
      }
    }
  }
  function code(inTemplate = false) {
    let depth = 0;
    while (offset < source.length) {
      if (consume(ignored)) continue;
      if (source.charCodeAt(offset) === 96) {
        template();
        tokens.push('<literal>');
        continue;
      }
      if (consume(string) ||
          (beforeRegex.has(tokens.at(-1)) && consume(regex))) {
        tokens.push('<literal>');
        continue;
      }
      const token = consume(word);
      tokens.push(token);
      if (token === '{') depth++;
      if (token === '}' && depth-- === 0 && inTemplate) return;
    }
  }
  code();
  return tokens;
}

function undeclaredCalls(source) {
  const tokens = tokenize(source);
  const ends = new Map();
  const stack = [];
  for (const [i, token] of tokens.entries()) {
    if (Object.hasOwn(groups, token)) stack.push(i);
    else if (groups[tokens[stack.at(-1)]] === token) ends.set(stack.pop(), i);
  }

  const declared = new Set(globals);
  const add = (token) => { if (identifier.test(token ?? '')) declared.add(token); };
  function skipExpression(start, limit, stops) {
    let i = start;
    while (i < limit && !stops.has(tokens[i])) i = (ends.get(i) ?? i) + 1;
    return i;
  }
  function binding(start) {
    if (tokens[start] === '...') return binding(start + 1);
    const end = ends.get(start);
    if (end !== undefined && ['{', '['].includes(tokens[start])) {
      parameters(start + 1, end);
      return end + 1;
    }
    add(tokens[start]);
    return start + 1;
  }
  const commas = new Set([',']);
  function parameters(start, end) {
    let i = start;
    while (i < end) {
      if (tokens[i] !== ',') {
        // A destructuring property can name its binding after a colon.
        const target = tokens[i + 1] === ':' ? i + 2 : i;
        i = skipExpression(binding(target), end, commas);
      }
      i++;
    }
  }
  const declarationStops = new Set([',', ';', ')', '}', 'in', 'of']);
  for (const [i, token] of tokens.entries()) {
    if (['const', 'let', 'var'].includes(token)) {
      let next = i + 1;
      do {
        next = binding(next);
        if (tokens[next] === '=') {
          next = skipExpression(next + 1, tokens.length, declarationStops);
        }
      } while (tokens[next++] === ',');
    } else if (token === 'class') {
      add(tokens[i + 1]);
    } else if (token === 'function') {
      let name = i + 1;
      if (tokens[name] === '*') name++;
      if (tokens[name] !== '(') add(tokens[name++]);
      if (ends.has(name)) parameters(name + 1, ends.get(name));
    } else if (tokens[i + 1] === '=>') {
      add(token);
    }
    if (token !== '(' || !ends.has(i)) continue;
    const end = ends.get(i);
    const name = tokens[i - 1];
    const method = tokens[end + 1] === '{' && identifier.test(name ?? '') &&
      !keywords.has(name) && ['{', ',', '}', 'async', 'static'].includes(tokens[i - 2]);
    if (tokens[end + 1] === '=>' || name === 'catch' || method) {
      parameters(i + 1, end);
    }
    // An object or class method name is a property, not a bare call.
    if (method) tokens[i - 1] = '<method>';
  }

  return [...new Set(tokens.filter((name, i) =>
    tokens[i + 1] === '(' && identifier.test(name) &&
    !['.', '?.'].includes(tokens[i - 1]) && !keywords.has(name) &&
    !declared.has(name)))].sort();
}

const failures = {};
for (const [name, source] of Object.entries(sources)) {
  const unknown = undeclaredCalls(source);
  if (unknown.length) failures[name] = unknown;
}
console.log(JSON.stringify(failures));
''';

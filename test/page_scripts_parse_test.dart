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
    final sources = <String, String>{'sdk/v1.js': sdkV1()};
    for (final google in [false, true]) {
      final pages = {
        'alerts': alertsOverlayHtml(googleFontsAllowed: google),
        'captions': captionsOverlayHtml(googleFontsAllowed: google),
        'chat': chatOverlayHtml(googleFontsAllowed: google),
        'clock': clockOverlayHtml(googleFontsAllowed: google),
        'featured': featuredOverlayHtml(googleFontsAllowed: google),
        'giveaway': giveawayOverlayHtml(googleFontsAllowed: google),
        'goals': goalsOverlayHtml(googleFontsAllowed: google),
        'poll': pollOverlayHtml(googleFontsAllowed: google),
        'timer': timerOverlayHtml(googleFontsAllowed: google),
      };
      final inline = RegExp(r'<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)</script>');
      for (final page in pages.entries) {
        final scripts = inline.allMatches(page.value).toList();
        expect(scripts, isNotEmpty, reason: page.key);
        for (var i = 0; i < scripts.length; i++) {
          sources['${page.key}${google ? '+google' : ''}#$i'] = scripts[i][1]!;
        }
      }
    }
    for (final item in galleryCatalog.values) {
      for (final language in ['en', 'es']) {
        sources['gallery/${item.id}/$language'] =
            item.buildFiles(language)['script.js']!;
      }
    }

    final dir = await Directory.systemTemp.createTemp('airstream-parse-');
    try {
      final script = File('${dir.path}/parse.js');
      await script.writeAsString('''
const vm = require('node:vm');
const sources = ${jsonEncode(sources)};
const failures = [];
for (const [name, source] of Object.entries(sources)) {
  try { new vm.Script(source, {filename: name}); }
  catch (error) { failures.push(name + ': ' + error.message); }
}
if (failures.length) { console.error(failures.join('\\n')); process.exit(1); }
''');
      final result = await Process.run('node', [script.path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('every gallery widget has a slot for the logo field', () {
    for (final item in galleryCatalog.values) {
      expect(item.buildFiles('en')['index.html'], contains('gallery-logo'),
          reason: item.id);
    }
  });
}

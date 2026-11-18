import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  late Directory root;
  late TemplateLibrary library;
  late OverlayServer server;
  late HttpClient client;
  Future<File> put(String path, String value) async {
    final f = File('${root.path}/$path');
    await f.parent.create(recursive: true);
    return f.writeAsString(value);
  }

  Future<(HttpClientResponse, String)> get(String path,
      {String method = 'GET', String? range}) async {
    final req = await client.openUrl(
        method, Uri.parse('http://127.0.0.1:${server.port}$path'));
    req.followRedirects = false;
    if (range != null) req.headers.set('range', range);
    final res = await req.close();
    return (res, await utf8.decoder.bind(res).join());
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('airstream-routes-');
    library = TemplateLibrary(root);
    await put('one/index.html',
        '<html><HEAD lang="en"><title>One</title></HEAD><body>Hello</body></html>');
    server = OverlayServer(templateLibrary: library);
    await server.start(
        messages: const Stream<ChatMessage>.empty(),
        settings: const SettingsModel(),
        port: 0);
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.dispose();
    await root.delete(recursive: true);
  });
  test('gallery routes serve memory only, with template security headers',
      () async {
    final docs = await Directory.systemTemp.createTemp('gallery-documents-');
    addTearDown(() => docs.delete(recursive: true));
    final templates = Directory('${docs.path}/Airstream/Templates');
    var diskLookups = 0;
    final handler = buildOverlayRoutes(
      (_) => Response.notFound(''),
      galleryLanguage: () => 'es',
      templates: () async {
        diskLookups++;
        throw StateError('Gallery must never request the disk library');
      },
    );
    Future<Response> fetch(String path, {String method = 'GET'}) =>
        Future.sync(() =>
            handler(Request(method, Uri.parse('http://localhost:8080$path'))));
    final response = await fetch('/gallery/recent-support/?demo=1');
    expect(response.statusCode, 200);
    expect(response.headers['content-security-policy'], templateCsp(8080));
    expect(response.headers['x-content-type-options'], 'nosniff');
    final html = await response.readAsString();
    expect(RegExp('/sdk/v1.js').allMatches(html), hasLength(1));
    expect(html.indexOf('/sdk/v1.js'), lessThan(html.indexOf('script.js')));
    final manifest = await fetch('/gallery/recent-support/template.json');
    final data = jsonDecode(await manifest.readAsString()) as Map;
    expect(data['name'], 'Apoyos recientes');
    expect(data['fields'], contains(containsPair('default', 'es')));
    expect(
        (await fetch('/gallery/recent-support/script.js'))
            .headers['content-type'],
        'application/javascript; charset=utf-8');
    expect((await fetch('/gallery/recent-support/style.css')).statusCode, 200);
    expect((await fetch('/gallery/recent-support/', method: 'HEAD')).statusCode,
        200);
    for (final path in [
      '/gallery/unknown/',
      '/gallery/recent-support/unknown.js',
      '/gallery/recent-support/sub/script.js'
    ]) {
      final missing = await fetch(path);
      expect(missing.statusCode, 404);
      expect(await missing.readAsString(), isEmpty);
    }
    expect(diskLookups, 0);
    expect(await templates.exists(), false);
  });

  test('server startup generates guides for existing root', () async {
    for (final name in ['AGENTS.md', 'CLAUDE.md', 'airstream.d.ts']) {
      expect(await File('${root.path}/$name').exists(), isTrue);
    }
  });

  test(
      'values.json defaults missing and incompatible values and clamps compatible ones',
      () async {
    await put('one/template.json',
        '{"fields":[{"key":"title","type":"text","default":"Hello","maxLength":8}]}');
    final (response, body) = await get('/custom/one/values.json');
    expect(response.statusCode, 200);
    expect(jsonDecode(body), {'title': 'Hello'});
    expect(response.headers.value('content-type'),
        'application/json; charset=utf-8');
    expect(response.headers.value('cache-control'), 'no-store');
    expect(response.headers.value('x-content-type-options'), 'nosniff');
    await put('one/values.json', '{"title":42,"extra":"ignored"}');
    expect(jsonDecode((await get('/custom/one/values.json')).$2),
        {'title': 'Hello'});
    await put('one/values.json', '{"title":"Goodbye! for now"}');
    expect(jsonDecode((await get('/custom/one/values.json')).$2),
        {'title': 'Goodbye!'});
    final (head, empty) = await get('/custom/one/values.json', method: 'HEAD');
    expect(head.statusCode, 200);
    expect(empty, isEmpty);
  });

  test(
      'redirect preserves demo and SDK injection handles head, html and fragment',
      () async {
    final (redirect, _) = await get('/custom/one?demo=1');
    expect(redirect.statusCode, 302);
    expect(redirect.headers.value('location'), '/custom/one/?demo=1');
    for (final html in [
      '<html><HEAD lang="en">Hello</HEAD></html>',
      '<html lang="en">Hello</html>',
      '<b>Hello</b>',
      '<head><script src="/sdk/v1.js"></script></head>'
    ]) {
      await put('one/index.html', html);
      final (res, body) = await get('/custom/one/');
      expect(res.statusCode, 200);
      expect('/sdk/v1.js'.allMatches(body).length, 1);
      if (html.startsWith('<b>')) {
        expect(body, startsWith('<!DOCTYPE html>'));
        expect(body, contains('<body><b>Hello</b>'));
        expect(body, isNot(contains('style.css')));
      }
    }
    await put('one/index.html', 'fragment');
    await put('one/style.css', 'body{}');
    await put('one/script.js', '');
    final (_, body) = await get('/custom/one/');
    expect(body, contains('<link rel="stylesheet" href="style.css">'));
    expect(body, contains('<script src="script.js"></script>'));
  });
  test('content types, exact CSP variants, cache headers, HEAD and ranges',
      () async {
    for (final e in templateContentTypes.entries) {
      await put('one/file.${e.key}', '0123456789');
      final (res, body) = await get('/custom/one/file.${e.key}');
      expect(res.statusCode, 200, reason: e.key);
      expect(body, '0123456789');
      expect(res.headers.value('content-type'), e.value);
      expect(res.headers.value('x-content-type-options'), 'nosniff');
      expect(res.headers.value('accept-ranges'), 'bytes');
      expect(res.headers.value('referrer-policy'), 'no-referrer');
      expect(
          res.headers.value('cache-control'),
          ['html', 'css', 'js', 'mjs', 'json', 'txt', 'svg'].contains(e.key)
              ? 'no-store'
              : 'no-cache');
      expect(res.headers.value('content-security-policy'),
          templateCsp(server.port));
    }
    final (partial, text) =
        await get('/custom/one/file.txt', range: 'bytes=2-5');
    expect(partial.statusCode, 206);
    expect(text, '2345');
    expect(partial.headers.value('content-range'), 'bytes 2-5/10');
    for (final r in [
      'bytes=20-',
      'bytes=5-1',
      'bytes=-2',
      'bytes=0-1,3-4',
      'bad'
    ]) {
      expect((await get('/custom/one/file.txt', range: r)).$1.statusCode, 416);
    }
    expect((await get('/custom/one/file.txt', method: 'HEAD')).$2, '');
    await put('one/template.json', '{"network":true}');
    final (res, _) = await get('/custom/one/');
    expect(res.headers.value('content-security-policy'),
        templateCsp(server.port, network: true));
    const assets = "'self' data: blob: https://yt3.ggpht.com "
        'https://yt4.ggpht.com https://*.ytimg.com '
        'https://*.googleusercontent.com https://static-cdn.jtvnw.net '
        'https://files.kick.com https://images.kick.com '
        'https://cdn.7tv.app https://cdn.betterttv.net '
        'https://cdn.frankerfacez.com';
    const cdns =
        'https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com';
    const localConnect = "'self' ws://localhost:9 ws://127.0.0.1:9";
    String expectedCsp(
            String images, String media, String network, String frame) =>
        "default-src 'none'; script-src 'self' 'unsafe-inline' $cdns${network.isEmpty ? '' : ' https:'}; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com $cdns; "
        "font-src 'self' data: https://fonts.gstatic.com $cdns; "
        'img-src $images; media-src $media; connect-src $localConnect$network; '
        "worker-src 'self' blob:; object-src 'none'; frame-src $frame; "
        "base-uri 'self'; form-action 'none'";
    expect(templateCsp(9), expectedCsp(assets, assets, '', "'none'"));
    expect(
        templateCsp(9, network: true),
        expectedCsp("'self' data: blob: http: https:",
            "'self' data: blob: https:", ' https: wss:', 'https:'));
  });
  test('reserved paths fail closed and do not return chat', () async {
    await put('empty/file.txt', 'missing index');
    await put('one/private.exe', 'bad');
    await Directory('${root.path}/one/dir').create();
    for (final path in [
      '/custom',
      '/custom/missing/',
      '/custom/INVALID/',
      '/custom/empty/',
      '/custom/one/../secret.txt',
      '/custom/one/%2e%2e/secret.txt',
      '/custom/one/a%5Cb.txt',
      '/custom/one/.secret',
      '/custom/one/private.exe',
      '/custom/one/a.dart',
      '/custom/one/a.bat',
      '/custom/one/dir',
      '/custom/one/a/b/c/d/e/f/g.txt',
      '/sdk/v2.js',
      '/sdk/'
    ]) {
      final (res, body) = await get(path);
      expect(res.statusCode, 404, reason: path);
      expect(body, '', reason: path);
      if (path.startsWith('/custom')) {
        expect(res.headers.value('content-security-policy'), isNotNull);
      }
    }
    expect((await get('/custom/one/', method: 'POST')).$1.statusCode, 404);
    expect((await get('/sdk/v1.js', method: 'POST')).$1.statusCode, 404);
    final (sdk, script) = await get('/sdk/v1.js');
    expect(sdk.headers.value('content-type'),
        'application/javascript; charset=utf-8');
    expect(script, contains('window.Airstream'));
    expect(sdk.headers.value('cache-control'), 'no-cache');
    final (chat, body) = await get('/');
    expect(chat.statusCode, 200);
    expect(body, isNotEmpty);
    expect(chat.headers.value('content-security-policy'),
        isNot(contains("form-action")));
  });
  test('rejects external symbolic file and directory links', () async {
    final outside = await Directory.systemTemp.createTemp('airstream-outside-');
    addTearDown(() => outside.delete(recursive: true));
    await File('${outside.path}/secret.txt').writeAsString('secret');
    try {
      await Link('${root.path}/one/link.txt')
          .create('${outside.path}/secret.txt');
      await Link('${root.path}/one/external').create(outside.path);
    } on FileSystemException catch (e) {
      markTestSkipped(
          'OS does not allow symbolic links: ${e.osError?.message}');
      return;
    }
    expect((await get('/custom/one/link.txt')).$1.statusCode, 404);
    expect((await get('/custom/one/external/secret.txt')).$1.statusCode, 404);
  });
  test('large files fail closed and six levels and uppercase extensions work',
      () async {
    final large =
        await File('${root.path}/one/large.mp4').open(mode: FileMode.write);
    await large.truncate(50 * 1024 * 1024 + 1);
    await large.close();
    expect((await get('/custom/one/large.mp4')).$1.statusCode, 404);
    await put('one/a/b/c/d/e/FILE.CSS', 'six levels');
    final (response, body) = await get('/custom/one/a/b/c/d/e/FILE.CSS');
    expect(response.statusCode, 200);
    expect(response.headers.value('content-type'), 'text/css; charset=utf-8');
    expect(body, 'six levels');
  });
  test('raw encoded separators and traversal cannot escape using shelf handler',
      () async {
    final handler = buildOverlayRoutes((_) => Response.ok('ws'),
        templates: () async => library);
    for (final path in [
      'custom/one/%2e%2e/secret.txt',
      'custom/one/%2Fsecret.txt',
      'custom/one/%5csecret.txt'
    ]) {
      final res = await handler(
          Request('GET', Uri.parse('http://localhost:${server.port}/$path')));
      expect(res.statusCode, 404);
      expect(await res.readAsString(), '');
    }
  });
}

import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/overlay/templates/sdk_v1.dart';
import 'package:airstream/services/overlay/templates/timer_overlay.dart';
import 'dart:io';
import 'package:airstream/services/media_library.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/captions_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:airstream/services/overlay/templates/poll_overlay.dart';
import 'package:airstream/services/overlay/templates/giveaway_overlay.dart';
import 'package:airstream/services/overlay/templates/goals_overlay.dart';
import 'package:shelf/shelf.dart';

Handler buildOverlayRoutes(Handler webSocketHandler,
    {File? Function(String alertType)? customSound,
    Future<MediaLibrary> Function()? mediaLibrary,
    Future<TemplateLibrary> Function()? templates}) {
  return const Pipeline().addHandler((Request request) async {
    final path = request.url.path;
    if (path == 'sdk' || path.startsWith('sdk/')) {
      if (!['GET', 'HEAD'].contains(request.method) || path != 'sdk/v1.js') {
        return Response.notFound('');
      }
      return Response.ok(request.method == 'HEAD' ? null : sdkV1(), headers: {
        'content-type': 'application/javascript; charset=utf-8',
        'x-content-type-options': 'nosniff',
        'cache-control': 'no-cache'
      });
    }
    if (path == 'custom' || path.startsWith('custom/')) {
      return serveTemplate(request, templates);
    }
    if (path == 'media' || path.startsWith('media/')) {
      return serveLibraryMedia(request, mediaLibrary);
    }
    if (path == 'sounds' || path.startsWith('sounds/')) {
      const headers = {
        'x-content-type-options': 'nosniff',
        'cache-control': 'no-store'
      };
      if (request.method != 'GET') {
        return Response.notFound('', headers: headers);
      }
      for (final name in AlertSounds.builtIn) {
        if (path == 'sounds/$name.wav') {
          return Response.ok(AlertSounds.wav(name),
              headers: {...headers, 'content-type': 'audio/wav'});
        }
      }
      for (final type in alertTypeIds) {
        if (path != 'sounds/custom/$type') continue;
        final configured = customSound?.call(type);
        final file =
            configured == null ? null : AlertSounds.customFile(configured.path);
        if (file == null) return Response.notFound('', headers: headers);
        try {
          final bytes = await file.readAsBytes();
          if (bytes.length > 5 * 1024 * 1024) {
            return Response.notFound('', headers: headers);
          }
          return Response.ok(bytes, headers: {
            ...headers,
            'content-type': AlertSounds.contentType(file.path)
          });
        } on FileSystemException {
          return Response.notFound('', headers: headers);
        }
      }
      return Response.notFound('', headers: headers);
    }
    if (request.url.path == 'ws') {
      if (!isTrustedOverlayOrigin(request)) {
        return Response.forbidden('Origin not allowed');
      }
      return webSocketHandler(request);
    }
    if (request.url.path == 'alerts') {
      return _htmlResponse(alertsOverlayHtml(), alerts: true);
    }
    if (request.url.path == 'captions') {
      return _htmlResponse(captionsOverlayHtml());
    }
    if (request.url.path == 'timer') return _htmlResponse(timerOverlayHtml());
    if (request.url.path == 'goals') return _htmlResponse(goalsOverlayHtml());
    if (request.url.path == 'giveaway') {
      return _htmlResponse(giveawayOverlayHtml());
    }
    if (request.url.path == 'poll') {
      return _htmlResponse(pollOverlayHtml());
    }
    return _htmlResponse(chatOverlayHtml());
  });
}

Response _htmlResponse(String html, {bool alerts = false}) => Response.ok(
      html,
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
        'referrer-policy': 'no-referrer',
        'x-content-type-options': 'nosniff',
        'content-security-policy':
            "default-src 'none'; img-src data: http: https:; connect-src ws: wss:; style-src 'unsafe-inline'; script-src 'unsafe-inline'${alerts ? "; media-src 'self'" : ''}",
      },
    );

const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

/// Whether a WebSocket handshake may receive the overlay feed.
///
/// Browsers do not apply CORS to WebSockets, so without this check any web
/// page open on this computer could connect to the overlay and read the chat.
/// Browsers always send an `Origin` header on the handshake: only pages served
/// by this overlay (a loopback host on the same port) are accepted. Clients
/// that send no `Origin` are not browsers and cannot be driven by a web page.
bool isTrustedOverlayOrigin(Request request) {
  final origin = request.headers['origin'];
  if (origin == null || origin.isEmpty) return true;
  final uri = Uri.tryParse(origin);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false; // includes the opaque "null" origin
  }
  return _loopbackHosts.contains(uri.host) &&
      uri.port == request.requestedUri.port;
}

Future<Response> serveLibraryMedia(
    Request request, Future<MediaLibrary> Function()? library) async {
  const headers = {
    'x-content-type-options': 'nosniff',
    'cache-control': 'private, max-age=86400',
    'accept-ranges': 'bytes'
  };
  final match = RegExp(r'^media/([0-9a-f]{16})$').firstMatch(request.url.path);
  if (request.method != 'GET' || match == null || library == null) {
    return Response.notFound('', headers: headers);
  }
  try {
    final service = await library();
    final id = match[1]!;
    final entry = MediaLibraryEntries.sanitize(service.entries())[id];
    if (entry == null) return Response.notFound('', headers: headers);
    final file = await service.fileFor(MapEntry(id, entry));
    if (file == null) return Response.notFound('', headers: headers);
    final size = await file.length();
    final responseHeaders = {
      ...headers,
      'content-type': MediaLibraryEntries.types[entry['ext']]!.$2
    };
    final range = request.headers['range'];
    if (range == null) {
      return Response.ok(file.openRead(),
          headers: {...responseHeaders, 'content-length': '$size'});
    }
    final parts = RegExp(r'^bytes=([0-9]+)-([0-9]*)$').firstMatch(range);
    final start = parts == null ? null : int.tryParse(parts[1]!);
    final end =
        parts == null || parts[2]!.isEmpty ? size - 1 : int.tryParse(parts[2]!);
    if (start == null || end == null || start >= size || end < start) {
      return Response(416,
          headers: {...responseHeaders, 'content-range': 'bytes */$size'});
    }
    final last = end.clamp(0, size - 1);
    return Response(206, body: file.openRead(start, last + 1), headers: {
      ...responseHeaders,
      'content-length': '${last - start + 1}',
      'content-range': 'bytes $start-$last/$size'
    });
  } on FileSystemException {
    return Response.notFound('', headers: headers);
  }
}

String templateCsp(int port, {bool network = false}) {
  const cdn =
      'https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com';
  return "default-src 'none'; script-src 'self' 'unsafe-inline' $cdn${network ? ' https:' : ''}; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com $cdn; font-src 'self' data: https://fonts.gstatic.com $cdn; img-src 'self' data: blob: http: https:; media-src 'self' data: blob:${network ? ' https:' : ''}; connect-src 'self' ws://localhost:$port ws://127.0.0.1:$port${network ? ' https: wss:' : ''}; worker-src 'self' blob:; object-src 'none'; frame-src ${network ? 'https:' : "'none'"}; base-uri 'self'; form-action 'none'";
}

const templateContentTypes = {
  'html': 'text/html; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'js': 'application/javascript; charset=utf-8',
  'mjs': 'application/javascript; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'txt': 'text/plain; charset=utf-8',
  'svg': 'image/svg+xml',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'avif': 'image/avif',
  'ico': 'image/x-icon',
  'woff': 'font/woff',
  'woff2': 'font/woff2',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'mp4': 'video/mp4',
  'webm': 'video/webm'
};
Future<Response> serveTemplate(
    Request request, Future<TemplateLibrary> Function()? library) async {
  var headers = <String, String>{
    'content-security-policy': templateCsp(request.requestedUri.port),
    'referrer-policy': 'no-referrer',
    'x-content-type-options': 'nosniff',
    'cache-control': 'no-store',
    'accept-ranges': 'bytes'
  };
  Response missing() => Response.notFound('', headers: headers);
  if (!['GET', 'HEAD'].contains(request.method) || library == null) {
    return missing();
  }
  try {
    final segments = request.url.path.split('/');
    if (segments.length < 2 || !TemplateLibrary.validId(segments[1])) {
      return missing();
    }
    final id = segments[1];
    final service = await library();
    final info = await service.get(id);
    if (info == null || !info.usable) return missing();
    headers['content-security-policy'] =
        templateCsp(request.requestedUri.port, network: info.manifest.network);
    if (segments.length == 2) {
      return Response(302, headers: {
        ...headers,
        'location':
            '/custom/$id/${request.url.hasQuery ? '?${request.url.query}' : ''}'
      });
    }
    final index = segments.length == 3 && segments.last.isEmpty;
    final files = index ? ['index.html'] : segments.skip(2).toList();
    if (files.isEmpty ||
        files.length > 6 ||
        files.any((s) =>
            !RegExp(r'^[A-Za-z0-9_][A-Za-z0-9._-]{0,99}$').hasMatch(s))) {
      return missing();
    }
    final ext = p.extension(files.last).substring(1).toLowerCase();
    final mime = templateContentTypes[ext];
    if (mime == null) return missing();
    if (files.length == 1 && files.single == 'values.json') {
      final bytes = utf8.encode(jsonEncode(await service.resolvedValues(id)));
      return Response.ok(request.method == 'HEAD' ? null : bytes, headers: {
        ...headers,
        'content-type': mime,
        'content-length': '${bytes.length}'
      });
    }
    final file = await service.safeFile(id, p.joinAll(files));
    if (file == null || await file.length() > 50 * 1024 * 1024) {
      return missing();
    }
    headers = {
      ...headers,
      'content-type': mime,
      'cache-control':
          ['html', 'css', 'js', 'mjs', 'json', 'txt', 'svg'].contains(ext)
              ? 'no-store'
              : 'no-cache'
    };
    List<int>? bytes;
    if (index) {
      var html = await file.readAsString();
      const sdk = '<script src="/sdk/v1.js"></script>';
      // An explicitly included SDK is moved to the head so it appears once.
      html = html.replaceAll(
          RegExp(
              r'<script\b[^>]*\bsrc\s*=\s*["\x27]/sdk/v1\.js["\x27][^>]*>\s*</script\s*>',
              caseSensitive: false),
          '');
      final head =
          RegExp(r'<head\b[^>]*>', caseSensitive: false).firstMatch(html);
      final root =
          RegExp(r'<html\b[^>]*>', caseSensitive: false).firstMatch(html);
      final tag = head ?? root;
      if (tag != null) {
        html = html.replaceRange(tag.end, tag.end, sdk);
      } else {
        final style = await service.safeFile(id, 'style.css') != null
            ? '<link rel="stylesheet" href="style.css">'
            : '';
        final script = await service.safeFile(id, 'script.js') != null
            ? '<script src="script.js"></script>'
            : '';
        html =
            '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">$sdk$style</head><body>$html$script</body></html>';
      }
      bytes = utf8.encode(html);
    }
    final size = bytes?.length ?? await file.length();
    final range = request.headers['range'];
    var start = 0, last = size - 1, status = 200;
    if (range != null) {
      final match = RegExp(r'^bytes=([0-9]+)-([0-9]*)$').firstMatch(range);
      final a = match == null ? null : int.tryParse(match[1]!);
      final b = match == null || match[2]!.isEmpty
          ? size - 1
          : int.tryParse(match[2]!);
      if (a == null || b == null || a >= size || b < a) {
        return Response(416,
            headers: {...headers, 'content-range': 'bytes */$size'});
      }
      start = a;
      last = b.clamp(0, size - 1);
      status = 206;
      headers['content-range'] = 'bytes $start-$last/$size';
    }
    headers['content-length'] = '${last - start + 1}';
    return Response(status,
        headers: headers,
        body: request.method == 'HEAD'
            ? null
            : bytes != null
                ? bytes.sublist(start, last + 1)
                : file.openRead(start, last + 1));
  } on FileSystemException {
    return missing();
  } on FormatException {
    return missing();
  } on RangeError {
    return missing();
  } catch (_) {
    // For example, the Documents folder cannot be resolved.
    return missing();
  }
}

import 'package:airstream/services/overlay/templates/timer_overlay.dart';
import 'dart:io';
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
    {File? Function(String alertType)? customSound}) {
  return const Pipeline().addHandler((Request request) async {
    final path = request.url.path;
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

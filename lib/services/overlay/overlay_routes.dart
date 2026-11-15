import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/captions_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:airstream/services/overlay/templates/poll_overlay.dart';
import 'package:shelf/shelf.dart';

Handler buildOverlayRoutes(Handler webSocketHandler) {
  return const Pipeline().addHandler((Request request) async {
    if (request.url.path == 'ws') {
      if (!isTrustedOverlayOrigin(request)) {
        return Response.forbidden('Origin not allowed');
      }
      return webSocketHandler(request);
    }
    if (request.url.path == 'alerts') {
      return _htmlResponse(alertsOverlayHtml());
    }
    if (request.url.path == 'captions') {
      return _htmlResponse(captionsOverlayHtml());
    }
    if (request.url.path == 'poll') {
      return _htmlResponse(pollOverlayHtml());
    }
    return _htmlResponse(chatOverlayHtml());
  });
}

Response _htmlResponse(String html) => Response.ok(
      html,
      headers: const {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
        'referrer-policy': 'no-referrer',
        'x-content-type-options': 'nosniff',
        'content-security-policy':
            "default-src 'none'; img-src data: http: https:; connect-src ws: wss:; style-src 'unsafe-inline'; script-src 'unsafe-inline'",
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

import 'package:airstream/services/overlay/templates/alerts_overlay.dart';
import 'package:airstream/services/overlay/templates/captions_overlay.dart';
import 'package:airstream/services/overlay/templates/chat_overlay.dart';
import 'package:shelf/shelf.dart';

Handler buildOverlayRoutes(Handler webSocketHandler) {
  return const Pipeline().addHandler((Request request) async {
    if (request.url.path == 'ws') {
      return webSocketHandler(request);
    }
    if (request.url.path == 'alerts') {
      return _htmlResponse(alertsOverlayHtml());
    }
    if (request.url.path == 'captions') {
      return _htmlResponse(captionsOverlayHtml());
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

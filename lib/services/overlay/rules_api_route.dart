import 'dart:convert';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rules_webhook.dart';
import 'package:airstream/settings/settings_model.dart';
import 'overlay_routes.dart';

/// One limiter per server, shared by every API path and caller.
class RulesApiRoute {
  RulesApiRoute(
      {required this.settings,
      required this.engine,
      DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final SettingsModel Function() settings;
  final RuleEngine? Function() engine;
  final DateTime Function() clock;
  final _requests = <DateTime>[];
  Future<Response> call(Request request) async {
    try {
      return await _handle(request);
    } catch (_) {
      // Never let Shelf's error logger print a URL containing the secret.
      return Response(500, body: '', headers: {'cache-control': 'no-store'});
    }
  }

  Future<Response> _handle(Request request) async {
    const headers = {
      'content-type': 'application/json',
      'cache-control': 'no-store',
      'referrer-policy': 'no-referrer'
    };
    Response status(int code) => Response(code, body: '', headers: headers);
    final s = settings();
    if (!s.rulesWebhookEnabled) return status(404);
    final now = clock();
    _requests
        .removeWhere((t) => now.difference(t) >= const Duration(seconds: 10));
    if (_requests.length >= 10) return status(429);
    _requests.add(now);
    final match =
        RegExp(r'^api/rules/([a-z0-9-]{1,40})$').firstMatch(request.url.path);
    if (match == null) return status(404);
    if (!isTrustedOverlayOrigin(request)) return status(403);
    final token = request.headers['x-airstream-token'] ??
        request.url.queryParameters['token'] ??
        '';
    if (!constantTimeTokenEquals(s.rulesWebhookToken, token)) {
      return status(401);
    }
    if (!const ['GET', 'POST'].contains(request.method)) return status(405);
    var size = 0;
    final bodyAllowed = Completer<bool>();
    request.read().listen((chunk) {
      size += chunk.length;
      if (size > 4096 && !bodyAllowed.isCompleted) bodyAllowed.complete(false);
    }, onDone: () {
      if (!bodyAllowed.isCompleted) bodyAllowed.complete(true);
    }, onError: (Object _) {
      if (!bodyAllowed.isCompleted) bodyAllowed.complete(false);
    });
    // Continue draining without retaining bytes; cancelling an HttpRequest
    // stream destroys its socket before the 413 response can be delivered.
    if (!await bodyAllowed.future) return status(413);
    // Recheck after reading an asynchronous body: disabling or regenerating
    // while a request is in flight revokes that request too.
    final current = settings();
    if (!current.rulesWebhookEnabled) return status(404);
    if (!constantTimeTokenEquals(current.rulesWebhookToken, token)) {
      return status(401);
    }
    final e = engine();
    final rule = e?.rules
        .where((r) =>
            r['enabled'] == true &&
            r['trigger']['type'] == 'manual' &&
            r['trigger']['webhook'] == match[1])
        .firstOrNull;
    if (rule == null) return status(404);
    final reason = e!.fireManual(rule['id'] as String);
    return Response(202,
        headers: headers,
        body: jsonEncode({
          'accepted': reason == null,
          if (reason != null) 'reason': reason
        }));
  }
}

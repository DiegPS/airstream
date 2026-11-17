import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/overlay/rules_api_route.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rule_sharing.dart';
import 'package:airstream/application/rules/rules_webhook.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_profiles.dart';
import 'rules_test_target.dart';

void main() {
  late SettingsModel settings;
  late RuleEngine engine;
  late HttpServer server;
  late HttpClient client;
  Map<String, dynamic> rule(String id,
          {bool enabled = true, String type = 'manual'}) =>
      {
        ...RuleSchema.newRule(type, id: id),
        'enabled': enabled,
        'trigger': {'type': type, if (type == 'manual') 'webhook': id},
      };
  setUp(() async {
    settings = enableRulesWebhook(const SettingsModel(), true);
    engine = RuleEngine(target: RulesTestTarget());
    engine.updateSettings(enabled: true, rules: [
      rule('go'),
      rule('off', enabled: false),
      rule('chat', type: 'chat.firstMessage')
    ]);
    final api = RulesApiRoute(settings: () => settings, engine: () => engine);
    server = await io.serve(
        buildOverlayRoutes((_) => Response.ok('ws'), rulesApi: api.call),
        InternetAddress.loopbackIPv4,
        0);
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
    await engine.dispose();
  });
  Future<(int, String)> request(
      {String path = 'api/rules/go',
      String method = 'GET',
      String? token,
      bool query = false,
      String? origin,
      String? body}) async {
    final uri = Uri.parse('http://127.0.0.1:${server.port}/$path').replace(
        queryParameters:
            query ? {'token': token ?? settings.rulesWebhookToken} : null);
    final req = await client.openUrl(method, uri);
    req.persistentConnection = false;
    if (body == null) req.contentLength = 0;
    if (!query) {
      req.headers.set('X-Airstream-Token', token ?? settings.rulesWebhookToken);
    }
    if (origin != null) req.headers.set('Origin', origin);
    if (body != null) req.write(body);
    final res = await req.close();
    res.headers.forEach(
        (name, _) => expect(name.startsWith('access-control-'), false));
    return (res.statusCode, await utf8.decoder.bind(res).join());
  }

  test('disabled API paths never fall through', () async {
    settings = settings.copyWith(rulesWebhookEnabled: false);
    for (final p in ['api/rules/go', 'api/anything-else', 'api']) {
      expect((await request(path: p)).$1, 404);
    }
  });
  test('tokens authenticate exactly and regenerate immediately', () async {
    expect((await request(token: '')).$1, 401);
    expect((await request(token: 'wrong')).$1, 401);
    expect((await request()).$1, 202);
    expect((await request(query: true)).$1, 202);
    final old = settings.rulesWebhookToken;
    settings = settings.copyWith(rulesWebhookToken: newRulesWebhookToken());
    expect((await request(token: old)).$1, 401);
  });
  test('missing token header and query are unauthorized', () async {
    final req = await client
        .getUrl(Uri.parse('http://127.0.0.1:${server.port}/api/rules/go'));
    final response = await req.close();
    expect(response.statusCode, 401);
    expect(await utf8.decoder.bind(response).join(), isEmpty);
  });

  test('header wins over query', () async {
    final req = await client.getUrl(Uri.parse(
        'http://127.0.0.1:${server.port}/api/rules/go?token=${settings.rulesWebhookToken}'));
    req.headers.set('X-Airstream-Token', 'wrong');
    final res = await req.close();
    expect(res.statusCode, 401);
    await res.drain<void>();
  });
  test('only enabled named manual rules can run', () async {
    for (final p in [
      'api/rules/missing',
      'api/rules/off',
      'api/rules/chat',
      'api/anything-else'
    ]) {
      expect((await request(path: p)).$1, 404);
    }
    final result = await request();
    expect(result, (202, '{"accepted":true}'));
    expect(engine.history.length, 1);
    expect(engine.history.single.event.type, 'manual');
  });
  test('engine refusal is acceptance response without waiting', () async {
    engine.updateSettings(enabled: false, rules: engine.rules);
    expect(
        await request(), (202, '{"accepted":false,"reason":"automationOff"}'));
  });
  test('global 10 requests per 10 seconds', () async {
    for (var i = 0; i < 10; i++) {
      expect((await request()).$1, 202);
    }
    expect((await request()).$1, 429);
  });
  test('method, size and origin restrictions', () async {
    expect((await request(method: 'PUT')).$1, 405);
    expect((await request(method: 'POST', body: 'x' * 4097)).$1, 413);
    expect((await request(origin: 'https://evil.example')).$1, 403);
    expect((await request(origin: 'http://localhost:${server.port}')).$1, 202);
  });
  test('constant time helper handles mismatches at every position', () {
    const token = '0123456789abcdef0123456789abcdef';
    expect(constantTimeTokenEquals(token, token), true);
    expect(constantTimeTokenEquals('', ''), false);
    for (var i = 0; i < token.length; i++) {
      expect(constantTimeTokenEquals(token, token.replaceRange(i, i + 1, 'X')),
          false);
    }
    expect(constantTimeTokenEquals(token, '${token}a'), false);
    expect(constantTimeTokenEquals(token, token.substring(1)), false);
  });
  test('settings defaults, token generation and sharing exclusions', () {
    expect(const SettingsModel().rulesWebhookEnabled, false);
    expect(settings.rulesWebhookToken, matches(r'^[a-f0-9]{32,}$'));
    expect(enableRulesWebhook(settings, true).rulesWebhookToken,
        settings.rulesWebhookToken);
    expect(SettingsProfiles.capture(settings).containsKey('rulesWebhookToken'),
        false);
    expect(SettingsProfiles.export(settings),
        isNot(contains(settings.rulesWebhookToken)));
    expect(SettingsProfiles.export(settings),
        isNot(contains('rulesWebhookToken')));
    expect(
        SettingsProfiles.import(SettingsProfiles.export(settings), settings)
            .rulesWebhookToken,
        settings.rulesWebhookToken);
  });
  test('roundtrip definitions are preserved with fresh ids and disabled', () {
    final original = RuleSchema.sanitize([rule('go')]);
    final review =
        RuleSharing.import(RuleSharing.export(original), existing: []);
    final imported = review.rules.single;
    expect(imported['id'], isNot('go'));
    expect(imported['enabled'], false);
    expect(
        {...imported}
          ..remove('id')
          ..remove('enabled'),
        {...original.single}
          ..remove('id')
          ..remove('enabled'));
  });
  test('format, version and malformed JSON reject', () {
    for (final source in [
      '{',
      '{"format":"no","version":1}',
      '{"format":"airstream-rules","version":2,"rules":[]}'
    ]) {
      expect(() => RuleSharing.import(source, existing: []),
          throwsFormatException);
    }
  });
  test('capacity, collisions, missing media and external names are reviewed',
      () {
    final original = rule('go')
      ..['actions'] = [
        {
          'id': 'a',
          'type': 'obs.source',
          'scene': 'Game',
          'source': 'Cam',
          'visible': 'show'
        },
        {
          'id': 'b',
          'type': 'alert.show',
          'title': '',
          'text': '',
          'seconds': 5,
          'mediaId': '0123456789abcdef'
        },
        {'id': 'c', 'type': 'template.trigger', 'name': 'celebrate', 'data': ''}
      ];
    final review = RuleSharing.import(
        RuleSharing.export([original, rule('extra')]),
        existing: List.generate(49, (i) => rule(i == 0 ? 'go' : 'r$i')));
    expect(review.rules.length, 1);
    expect(review.skipped, 1);
    expect(review.rules.single['trigger']['webhook'], '');
    expect(
        review.warnings.values.single.map((w) => w.$1),
        containsAll(
            ['obsNames', 'missingMedia', 'templateName', 'webhookCollision']));
  });
}

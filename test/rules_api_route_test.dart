import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_model.dart';
import 'package:airstream/application/rules/rules_webhook.dart';
import 'package:airstream/services/overlay/rules_api_route.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'rules_test_target.dart';

void main() {
  test(
      'rejected webhook requests leave the authenticated execution quota intact',
      () async {
    final settings = enableRulesWebhook(const SettingsModel(), true);
    final engine = RuleEngine(target: RulesTestTarget());
    addTearDown(engine.dispose);
    engine.updateSettings(enabled: true, rules: [
      {
        ...RuleSchema.newRule('manual', id: 'go'),
        'enabled': true,
        'trigger': {'type': 'manual', 'webhook': 'go'},
      },
    ]);
    final route = RulesApiRoute(
      settings: () => settings,
      engine: () => engine,
      clock: () => DateTime.utc(2026),
    );
    Future<int> request(
        {String path = 'api/rules/go', String? origin, String? token}) async {
      final response = await route(Request(
        'POST',
        Uri.parse('http://localhost/$path'),
        headers: {
          'x-airstream-token': token ?? settings.rulesWebhookToken,
          if (origin != null) 'origin': origin,
        },
      ));
      return response.statusCode;
    }

    for (var i = 0; i < 5; i++) {
      expect(await request(path: 'api/not-rules'), 404);
      expect(await request(token: 'incorrect'), 401);
      expect(await request(origin: 'https://other.invalid'), 403);
    }
    for (var i = 0; i < 10; i++) {
      expect(await request(), 202);
    }
    expect(await request(), 429);
  });
}

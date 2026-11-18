import 'dart:async';
import 'dart:convert';

import 'package:airstream/application/audio_coordinator.dart';
import 'package:airstream/application/chat_giveaway.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/obs_coordinator.dart';
import 'package:airstream/application/rules/rule_actions.dart';
import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/rules/rule_events.dart';
import 'package:airstream/settings/settings_model.dart';
// Flutter's existing test dependency supplies deterministic timers.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'application/coordinator_fakes.dart';
import 'rule_engine_test.dart' show rule;

void main() {
  const url = 'https://example.invalid/hooks/secret/{user}?check={message}';
  const event = RuleEvent(
    type: 'manual',
    author: RuleAuthor(name: 'Mía "Q" \\ 🎮 {message}', id: 'user'),
    text: 'First line\nsecond line\t雪',
  );
  const action = {
    'id': 'http',
    'type': 'http.request',
    'method': 'post',
    'url': url,
    'contentType': 'json',
    'body': '{"content":"{user} dice {message}"}',
  };
  late RuleEngine engine;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;

  setUp(() {
    requests = [];
    respond = (_) async => http.Response('', 204);
    final client = MockClient((request) {
      requests.add(request);
      return respond(request);
    });
    final obs = ObsCoordinator(obs: FakeObsClient());
    final audio =
        AudioCoordinator(tts: FakeTtsClient(), captions: FakeCaptionsClient());
    final giveaway = ChatGiveawayController();
    final queue = ChatQueueController();
    final target = RuleActions(
      settings: () => const SettingsModel(),
      writeSettings: (_, __) async {},
      obs: obs,
      audio: audio,
      giveaway: giveaway,
      queue: queue,
      server: () => null,
      feature: (_) {},
      draw: (_) {},
      httpClient: client,
    );
    engine = RuleEngine(target: target);
    addTearDown(() async {
      await engine.dispose();
      await target.sounds.dispose();
      await obs.dispose();
      await audio.dispose();
      await giveaway.dispose();
      await queue.dispose();
      client.close();
    });
  });

  Future<(String, String?)> run(Map<String, dynamic> action) async {
    engine.updateSettings(enabled: true, rules: [
      rule(actions: [action])
    ]);
    final finished =
        engine.historyStream.firstWhere((runs) => runs.first.completed);
    expect(engine.runNow('r', event), isNull);
    final result = (await finished).first.results.single;
    return (result.status, result.reason);
  }

  test('POST escapes each JSON value once and leaves URL tokens literal',
      () async {
    final simulation = engine.simulate(rule(actions: [action]), event);
    expect(simulation.actions.single['url'], '');
    expect(requests, isEmpty);
    expect(await run(action), ('done', null));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url, Uri.parse(url));
    expect(request.headers, {
      'User-Agent': 'Airstream',
      'Content-Type': 'application/json',
    });
    final body = utf8.decode(request.bodyBytes);
    expect(jsonDecode(body),
        {'content': '${event.author.name} dice ${event.text}'});
    expect(simulation.actions.single['body'], body);
    expect(engine.history.single.rule['actions'].single['url'], '');
  });

  test('POST sends UTF-8 plain text and GET sends an empty body', () async {
    expect(await run({...action, 'contentType': 'text', 'body': '{message}'}),
        ('done', null));
    final post = requests.single;
    expect(post.headers['content-type'], 'text/plain');
    expect(utf8.decode(post.bodyBytes), event.text);

    expect(await run({...action, 'method': 'get'}), ('done', null));
    final get = requests.last;
    expect(get.method, 'GET');
    expect(get.headers, {'User-Agent': 'Airstream'});
    expect(get.bodyBytes, isEmpty);
  });

  test('non-2xx and client exceptions expose only stable failure codes',
      () async {
    respond = (_) async => http.Response('Private content $url', 404);
    expect(await run(action), ('failed', 'httpStatus'));
    final printed = <String>[];
    await runZoned(() async {
      respond = (request) async =>
          throw http.ClientException('Private request URL $url', request.url);
      expect(await run(action), ('failed', 'httpError'));
    },
        zoneSpecification: ZoneSpecification(
          print: (_, __, ___, line) => printed.add(line),
        ));
    expect(printed.join('\n'), isNot(contains('/hooks/secret')));
    expect(engine.history.map((r) => jsonEncode(r.rule)).join(),
        isNot(contains('/hooks/secret')));
  });

  test('deadline reports an HTTP failure after five seconds', () {
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    engine.updateSettings(enabled: true, rules: [
      rule(actions: [action])
    ]);
    fakeAsync((time) {
      expect(engine.runNow('r', event), isNull);
      time.elapse(const Duration(milliseconds: 4999));
      expect(requests, hasLength(1));
      expect(engine.history.single.completed, isFalse);
      time.elapse(const Duration(milliseconds: 1));
      final result = engine.history.single.results.single;
      expect((result.status, result.reason), ('failed', 'httpError'));
      expect(engine.history.single.completed, isTrue);
      pending.complete(http.Response('', 200));
      time.flushMicrotasks();
      expect(engine.history.single.results, [result]);
    });
  });

  test('empty and invalid URLs skip without calling the client', () async {
    for (final url in [
      '',
      'relative/path',
      'ftp://example.invalid',
      'http://',
      'https://bad host.invalid/hook',
      'https://example.invalid:65536/',
      'https://example.invalid:1234567890123456789012345/',
    ]) {
      expect(await run({...action, 'url': url}), ('skipped', 'noUrl'));
    }
    expect(requests, isEmpty);
  });
}

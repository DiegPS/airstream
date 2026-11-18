import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:shelf/shelf.dart';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  ChatMessage paid(String id, YoutubeStreamOrientation orientation) =>
      ChatMessage(
        platform: Platform.youtube,
        youtubeStreamOrientation: orientation,
        id: id,
        author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
        items: const [MessageItem.text('Paid message')],
        superChat: const SuperChat(amount: r'$5', color: ''),
        timestamp: DateTime.utc(2026),
      );

  test('moderation redacts recent alert snapshots and replay by source',
      () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    const horizontal = YoutubeStreamOrientation.horizontal;
    server.broadcastChatSupport(paid('delete-me', horizontal));
    server.broadcastChatSupport(
        paid('keep-me', YoutubeStreamOrientation.vertical));
    final change = server.recentAlerts.skip(1).first;
    server.broadcastModeration(const ChatModerationEvent.author(
      platform: Platform.youtube,
      youtubeStreamOrientation: horizontal,
      authorChannelId: 'viewer',
    ));
    final recent = server.recentAlertsSnapshot;
    expect(recent.map((alert) => alert['message']), ['Paid message', '']);
    expect(await change, recent);
    expect(server.replayRecentAlert('delete-me'), isTrue);
    final replay = alerts.sink.frames.last['data'] as Map;
    expect(replay, containsPair('message', ''));
    expect(replay, containsPair('amount', r'$5'));
    expect(replay, containsPair('author', 'Viewer'));
  });

  test('block lists sanitize recent paid alerts and every replay', () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    const horizontal = YoutubeStreamOrientation.horizontal;
    server.broadcastChatSupport(paid('words', horizontal));
    server.broadcastProviderEvent(ChatProviderEvent(
      platform: Platform.kick,
      kind: ChatProviderEventKind.support,
      id: 'user',
      authorName: 'Other Viewer',
      authorChannelId: 'blocked-id',
      text: 'Thank you',
      count: 100,
      timestamp: DateTime.utc(2026),
    ));
    final updated = server.recentAlerts.skip(1).first;
    server.setSettings(const SettingsModel(
      blockedWords: ['paid, message'],
      blockedUsers: ['@Blocked-ID'],
    ));
    final recent = server.recentAlertsSnapshot;
    expect(recent.map((alert) => alert['message']), ['', '']);
    expect(recent.map((alert) => alert['author']), ['', 'Viewer']);
    expect(recent.first['authorChannelId'], '');
    expect(recent.first['count'], 100);
    expect(recent.last['amount'], r'$5');
    expect(await updated, recent);

    server.setSettings(const SettingsModel());
    for (final alert in recent) {
      expect(server.replayRecentAlert(alert['id'] as String), isTrue);
      expect(alerts.sink.frames.last['data'], alert);
    }
  });

  test('installed and gallery templates receive live and replayed filters',
      () async {
    final root = await Directory.systemTemp.createTemp('custom-filters-');
    addTearDown(() => root.delete(recursive: true));
    final server = OverlayServer(templateLibrary: TemplateLibrary(root));
    addTearDown(server.dispose);
    const settings = SettingsModel(blockedWords: ['hello there']);
    server.setSettings(settings);
    final installed = _Socket(server)
      ..register('custom', template: 'word-cloud');
    final other = _Socket(server)..register('gallery', template: 'credits');
    for (final page in [installed, other]) {
      expect(page.snapshot('filters')['data'], {
        'users': [],
        'words': ['hello there']
      });
    }
    server.setSettings(settings.copyWith(blockedUsers: [' @Bad Viewer ']));
    for (final page in [installed, other]) {
      final live = page.sink.frames.singleWhere(
          (frame) => frame['type'] == 'filters' && frame['replay'] != true);
      expect(live['data'], {
        'users': ['badviewer'],
        'words': ['hello there']
      });
    }
  });

  test('active OBS then inactive OBS outrank browser previews', () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final browser = _Socket(server)..register('featured', inObs: false);
    final hidden = _Socket(server)
      ..register('featured', active: false, inObs: true);
    final alerts = _Socket(server)..register('alerts', inObs: true);

    Future<void> checkRecipient(_Socket recipient) async {
      final delivery = server.broadcastFeaturedMessage(
          paid('featured', YoutubeStreamOrientation.horizontal));
      expect(recipient.sink.frames.last['data']['deliveryId'], delivery.id);
      recipient.acknowledgeFeatured(delivery.id);
      expect(await delivery.completed, FeaturedMessageStatus.rendered);
    }

    await checkRecipient(alerts);
    alerts.reportActivity(false);
    await checkRecipient(hidden);
    await alerts.disconnect();
    await hidden.disconnect();
    await checkRecipient(browser);
  });

  test('featured replacement clears the pinned card on inactive alerts',
      () async {
    final server = OverlayServer()
      ..setSettings(const SettingsModel(featuredSeconds: 0));
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    final featured = _Socket(server)..register('featured', active: false);
    const horizontal = YoutubeStreamOrientation.horizontal;
    final old = server.broadcastFeaturedMessage(paid('old', horizontal));
    expect(alerts.sink.frames.last['type'], 'alert');
    alerts.acknowledgeFeatured(old.id);
    expect(await old.completed, FeaturedMessageStatus.rendered);
    alerts.reportActivity(false);
    featured.reportActivity(true);
    server.broadcastFeaturedMessage(paid('new', horizontal));
    expect(featured.sink.frames.last['data']['id'], 'new');
    expect(alerts.sink.frames.last, {'type': 'featuredHide'});
  });

  test('block-list updates send a normalized filter signal to the word cloud',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final cloud = _Socket(server)..register('gallery', template: 'word-cloud');
    cloud.sink.frames.clear();
    server.setSettings(const SettingsModel(
        blockedWords: [' BAD, phrase! '], blockedUsers: [' @Bad Viewer ']));
    final filtered = {
      'type': 'filters',
      'data': {
        'words': ['bad phrase'],
        'users': ['badviewer'],
      }
    };
    expect(cloud.sink.frames.where((frame) => frame['type'] == 'filters'),
        [filtered]);
    final reconnected = _Socket(server)
      ..register('gallery', template: 'word-cloud');
    expect(reconnected.snapshot('filters'), {...filtered, 'replay': true});
  });

  test(
      'custom index redirects with its query and injects the SDK at the target',
      () async {
    final root = await Directory.systemTemp.createTemp('custom-index-');
    addTearDown(() => root.delete(recursive: true));
    final dir = await Directory('${root.path}/sample').create();
    await File('${dir.path}/index.html').writeAsString('<h1>Sample</h1>');
    final library = TemplateLibrary(root);
    addTearDown(library.dispose);
    final route = buildOverlayRoutes((_) => Response.notFound(''),
        templates: () async => library);
    Future<Response> get(String path) async =>
        await route(Request('GET', Uri.parse('http://localhost$path')));
    const query = '?demo=1&name=a%2Bb';
    final response = await get('/custom/sample/index.html$query');
    expect(response.statusCode, 302);
    expect(response.headers['location'], '/custom/sample/$query');
    expect(await (await get(response.headers['location']!)).readAsString(),
        contains('<script src="/sdk/v1.js"></script>'));
    final gallery = await get('/gallery/credits/index.html$query');
    expect(gallery.statusCode, 200);
    expect(await gallery.readAsString(),
        contains('<script src="/sdk/v1.js"></script>'));
  });

  test('font policy changes send settings without a reload envelope', () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    alerts.sink.frames.clear();
    server.setSettings(const SettingsModel(chatFontFamily: 'Inter'));
    server.setSettings(const SettingsModel(
        chatFontFamily: 'Inter', chatFontInstalledOnly: true));
    final frames = alerts.sink.frames;
    expect(frames.map((event) => event['type']), ['settings', 'settings']);
    expect(frames.first['data']['googleFontStylesheet'],
        startsWith('https://fonts.googleapis.com/'));
    expect(frames.last['data']['googleFontStylesheet'], isNull);
  });

  test(
      'recent alerts require a successful alerts delivery while SDK still receives them',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final chat = _Socket(server)..register('chat');
    final gallery = _Socket(server)..register('gallery', template: 'credits');
    final failing = _Socket(server)..register('alerts');
    failing.sink.fail = true;

    void sendRaid(String id) => server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: id,
        timestamp: DateTime.utc(2026),
        count: 5));

    sendRaid('first');
    expect(gallery.sink.frames.where((frame) => frame['type'] == 'alert'),
        hasLength(1));
    expect(chat.sink.frames.where((frame) => frame['type'] == 'alert'),
        hasLength(1));
    expect(server.recentAlertsSnapshot, isEmpty);

    final alerts = _Socket(server)..register('alerts');
    sendRaid('second');
    final delivered = alerts.sink.frames
        .singleWhere((frame) => frame['type'] == 'alert')['data'];
    expect(server.recentAlertsSnapshot, [delivered]);
  });

  test(
      'fresh server replays empty poll, giveaway, goals, timer and queue snapshots',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final poll = _Socket(server)..register('poll');
    final giveaway = _Socket(server)..register('giveaway');
    final goals = _Socket(server)..register('goals');
    final timer = _Socket(server)..register('timer');
    final clock = _Socket(server)..register('clock');
    final widget = _Socket(server)..register('gallery', template: 'poll');
    final queue = _Socket(server)..register('gallery', template: 'queue-list');

    expect(poll.snapshot('poll')['data'], isNull);
    expect(giveaway.snapshot('giveaway')['data'], isNull);
    expect(goals.snapshot('goals')['data'], isEmpty);
    expect(timer.snapshot('timer')['data'], containsPair('phase', 'idle'));
    expect(clock.snapshot('clock')['data'], isA<Map>());
    expect(widget.snapshot('poll')['data'], isNull);
    expect(queue.snapshot('queue')['data'], containsPair('entries', isEmpty));
  });

  test(
      'template registration and session updates explicitly clear stale session state',
      () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    Map<String, Object?>? current = {'startedAt': '2026-11-18'};
    server.sessionState = () => current;
    final first = _Socket(server)..register('gallery', template: 'credits');
    expect(first.snapshot('session')['data'], current);

    current = null;
    final cleared = first.sink.nextFrame('session');
    server.sessionChanged();
    expect(await cleared, {'type': 'session', 'data': null, 'replay': false});

    final reconnected = _Socket(server)
      ..register('gallery', template: 'credits');
    expect(reconnected.snapshot('session')['data'], isNull);
    expect(reconnected.snapshot('counters')['data'], isEmpty);
    expect(reconnected.snapshot('queue')['data'],
        containsPair('entries', isEmpty));
    expect(reconnected.snapshot('poll')['data'], isNull);
  });

  test('stopping while template startup waits prevents a server bind',
      () async {
    final root = await Directory.systemTemp.createTemp('cancel-overlay-start-');
    addTearDown(() => root.delete(recursive: true));
    final library = _SlowTemplateLibrary(root);
    final server = OverlayServer(templateLibrary: library);
    addTearDown(server.dispose);
    var subscribed = false;
    final messages = StreamController<ChatMessage>.broadcast(
      onListen: () => subscribed = true,
    );
    addTearDown(messages.close);
    final starting = server.start(
        messages: messages.stream, settings: const SettingsModel(), port: 0);
    await library.enteredWatch.future;
    final stopping = server.stop();
    library.finishWatch.complete();
    await Future.wait([starting, stopping]);
    expect(server.port, 0);
    expect(subscribed, isFalse);
  });

  test('featured delivery follows source activity and falls back by view',
      () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final hidden = _Socket(server)..register('featured', active: false);
    final alerts = _Socket(server)..register('alerts');
    final featured = _Socket(server)..register('featured');
    final pages = [hidden, alerts, featured];

    void expectDelivery(List<_Socket> expected) {
      for (final page in pages) {
        page.sink.frames.clear();
      }
      final delivery = server.broadcastFeaturedMessage(ChatMessage(
        platform: Platform.twitch,
        id: 'featured',
        author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
        items: const [MessageItem.text('Featured text')],
        timestamp: DateTime.utc(2026),
      ));
      expect(delivery.status, FeaturedMessageStatus.sent);
      for (final page in pages) {
        expect(page.sink.frames.where((frame) => frame['type'] == 'alert'),
            hasLength(expected.contains(page) ? 1 : 0));
      }
      server.removeFeaturedMessage();
    }

    expectDelivery([featured]);
    featured.reportActivity(false);
    expectDelivery([alerts]);
    alerts.reportActivity(false);
    expectDelivery([hidden, featured]);
    hidden.reportActivity(true);
    expectDelivery([hidden]);
    await featured.disconnect();
    await hidden.disconnect();
    expectDelivery([alerts]);
  });

  test('unrelated gallery and custom pages do not count as featured receivers',
      () async {
    final root = await Directory.systemTemp.createTemp('featured-receivers-');
    addTearDown(() => root.delete(recursive: true));
    final server = OverlayServer(templateLibrary: TemplateLibrary(root));
    addTearDown(server.dispose);
    final page = _Socket(server)..register('gallery', template: 'credits');
    final custom = _Socket(server)..register('custom', template: 'unrelated');
    await custom.sink.nextFrame('fields');
    final delivery = server.broadcastFeaturedMessage(ChatMessage(
      platform: Platform.twitch,
      id: 'featured',
      author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
      items: const [MessageItem.text('Featured text')],
      timestamp: DateTime.utc(2026),
    ));
    final frame =
        page.sink.frames.singleWhere((frame) => frame['type'] == 'featured');
    expect(frame['data'], containsPair('message', 'Featured text'));
    expect(
        custom.sink.frames.singleWhere((frame) => frame['type'] == 'featured'),
        frame);
    expect(delivery.status, FeaturedMessageStatus.noReceiver);
    expect(await delivery.completed, FeaturedMessageStatus.noReceiver);
  });

  test(
      'connected gallery pages receive localized defaults when language changes',
      () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final ticker = _Socket(server)..register('gallery', template: 'ticker');
    final credits = _Socket(server)..register('gallery', template: 'credits');
    expect(ticker.snapshot('fields')['data'], containsPair('language', 'en'));
    expect(credits.snapshot('fields')['data'], containsPair('language', 'en'));
    server.setSettings(const SettingsModel(appLanguageCode: 'es'));
    for (final page in [ticker, credits]) {
      final fields = page.sink.frames.where((f) => f['type'] == 'fields');
      expect(fields, hasLength(2));
      expect(fields.last['data'], containsPair('language', 'es'));
      expect(fields.last['replay'], isTrue);
    }
  });

  test('a redacted support alert publishes no chat message', () {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final alerts = _Socket(server)..register('alerts');
    server.broadcastChatSupport(ChatMessage(
      platform: Platform.twitch,
      id: 'bits',
      author: const ChatAuthor(name: 'Viewer', channelId: 'viewer'),
      items: const [],
      timestamp: DateTime.utc(2026),
      superChat: const SuperChat(amount: '500 Bits', color: '#fff'),
    ));
    final frames = alerts.sink.frames;
    expect(frames.where((frame) => frame['type'] == 'message'), isEmpty);
    final alert = frames.singleWhere((frame) => frame['type'] == 'alert');
    expect(alert['data'], containsPair('message', ''));
    expect(alert['data'], containsPair('amount', '500 Bits'));
  });

  test(
      'test and replay require successful delivery to a registered alerts page',
      () async {
    final server = OverlayServer();
    addTearDown(server.dispose);
    final chat = _Socket(server)..register('chat');
    final unregistered = _Socket(server);
    final initialAlerts = _Socket(server)..register('alerts');
    server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid',
        timestamp: DateTime.utc(2026),
        authorName: 'Viewer',
        count: 42));
    final recent = server.recentAlertsSnapshot.single;
    await initialAlerts.disconnect();
    chat.sink.frames.clear();
    unregistered.sink.frames.clear();

    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    final alerts = _Socket(server)..register('alerts');
    expect(server.broadcastTestAlert('bits'), isTrue);
    expect(server.replayRecentAlert('raid'), isTrue);
    final received =
        alerts.sink.frames.where((frame) => frame['type'] == 'alert').toList();
    expect(received, hasLength(2));
    expect(received.first['data']['id'], startsWith('test-bits-'));
    expect(received.last['data']['id'], 'raid');
    expect(received.last['data'], recent);
    expect(chat.sink.frames, isEmpty);
    expect(unregistered.sink.frames, isEmpty);

    alerts.sink.fail = true;
    expect(server.broadcastTestAlert('bits'), isFalse);
    expect(server.replayRecentAlert('raid'), isFalse);
  });
}

class _SlowTemplateLibrary extends TemplateLibrary {
  _SlowTemplateLibrary(super.root);

  final enteredWatch = Completer<void>();
  final finishWatch = Completer<void>();

  @override
  Future<bool> exists() async => false;

  @override
  Future<void> watch() {
    enteredWatch.complete();
    return finishWatch.future;
  }
}

class _Socket implements WebSocketChannel {
  _Socket(OverlayServer server) {
    server.attachClient(this);
    addTearDown(_incoming.close);
  }

  final _incoming = StreamController<String>(sync: true);

  @override
  final _Sink sink = _Sink();

  @override
  Stream<String> get stream => _incoming.stream;

  Future<void> disconnect() => _incoming.close();

  void reportActivity(bool active) =>
      _incoming.add(jsonEncode({'type': 'sourceActivity', 'active': active}));

  void acknowledgeFeatured(String? id) =>
      _incoming.add(jsonEncode({'type': 'featuredRendered', 'deliveryId': id}));

  void register(String view, {String? template, bool? active, bool? inObs}) {
    _incoming.add(jsonEncode({
      'type': 'register',
      'view': view,
      if (active != null) 'active': active,
      if (inObs != null) 'inObs': inObs,
      if (template != null) 'template': template,
    }));
    expect(sink.frames.singleWhere((frame) => frame['type'] == 'registered'),
        {'type': 'registered', 'view': view});
  }

  Map<String, dynamic> snapshot(String type) {
    final frame = sink.frames.singleWhere((frame) => frame['type'] == type);
    expect(frame['replay'], isTrue);
    return frame;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  final frames = <Map<String, dynamic>>[];
  bool fail = false;
  final _waiters = <String, Completer<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> nextFrame(String type) =>
      (_waiters[type] = Completer<Map<String, dynamic>>())
          .future
          .timeout(const Duration(seconds: 3));

  @override
  void add(dynamic event) {
    if (fail) throw StateError('Closed socket');
    final frame = jsonDecode(event as String) as Map<String, dynamic>;
    frames.add(frame);
    _waiters.remove(frame['type'])?.complete(frame);
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

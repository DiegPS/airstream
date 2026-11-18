import 'support/empty_template_library.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

void main() {
  test('registered view counts follow registration and disconnect', () async {
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final messages = StreamController<ChatMessage>.broadcast();
    await server.start(
        messages: messages.stream, settings: const SettingsModel(), port: 0);
    final counts = StreamIterator(server.viewCountsStream);
    expect(await counts.moveNext(), isTrue);
    expect(counts.current, {
      'chat': 0,
      'alerts': 0,
      'featured': 0,
      'poll': 0,
      'captions': 0,
      'giveaway': 0,
      'goals': 0,
      'timer': 0,
      'custom': 0
    });
    Future<void> until(bool Function(Map<String, int>) matches) async {
      while (await counts.moveNext().timeout(const Duration(seconds: 5))) {
        if (matches(counts.current)) return;
      }
      fail('View counts stream closed');
    }

    final alerts =
        IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
    final poll = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
    final aSub = alerts.stream.listen((_) {});
    final pSub = poll.stream.listen((_) {});
    try {
      await Future.wait([alerts.ready, poll.ready]);
      alerts.sink.add(jsonEncode({'type': 'register', 'view': 'alerts'}));
      poll.sink.add(jsonEncode({'type': 'register', 'view': 'poll'}));
      await until((v) => v['alerts'] == 1 && v['poll'] == 1);
      expect(server.viewCounts, {
        'chat': 0,
        'alerts': 1,
        'featured': 0,
        'poll': 1,
        'captions': 0,
        'giveaway': 0,
        'goals': 0,
        'timer': 0,
        'custom': 0
      });
      await alerts.sink.close();
      await until((v) => v['alerts'] == 0 && v['poll'] == 1);
      await poll.sink.close();
      await until((v) => v.values.every((n) => n == 0));
    } finally {
      await aSub.cancel();
      await pSub.cancel();
      await counts.cancel();
      await server.dispose();
      await messages.close();
    }
  });

  test('publishes the operating-system assigned overlay port', () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    try {
      await server.start(
        messages: messages.stream,
        settings: const SettingsModel(),
        port: 0,
      );

      expect(server.port, inInclusiveRange(1, 65535));
      expect(server.overlayUrl, isNot(contains(':0')));
      expect(server.boundAddress, InternetAddress.loopbackIPv4);
    } finally {
      await server.dispose();
      await messages.close();
    }
  });

  test('rejects overlay ports outside the TCP range', () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    try {
      await expectLater(
        server.start(
          messages: messages.stream,
          settings: const SettingsModel(),
          port: 65536,
        ),
        throwsRangeError,
      );
    } finally {
      await server.dispose();
      await messages.close();
    }
  });

  test('serves self-contained native browser sources', () async {
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();
    final messages = StreamController<ChatMessage>();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final client = http.Client();
    try {
      await server.start(
        messages: messages.stream,
        settings: const SettingsModel(appLanguageCode: 'es'),
        port: port,
      );

      final response = await client.get(
        Uri.parse('http://127.0.0.1:$port/captions'),
        headers: const {HttpHeaders.connectionHeader: 'close'},
      );
      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, contains('Airstream Captions'));
      expect(response.body, contains("envelope.type !== 'caption'"));
      expect(response.body, contains('caption.textContent'));

      final overlayResponse = await client.get(
        Uri.parse('http://127.0.0.1:$port'),
        headers: const {HttpHeaders.connectionHeader: 'close'},
      );
      final alertsResponse = await client.get(
        Uri.parse('http://127.0.0.1:$port/alerts'),
        headers: const {HttpHeaders.connectionHeader: 'close'},
      );

      for (final browserSource in [
        response,
        overlayResponse,
        alertsResponse,
      ]) {
        expect(browserSource.statusCode, HttpStatus.ok);
        expect(
          browserSource.body,
          isNot(matches(RegExp(
            r'<script\b[^>]*\bsrc\s*=',
            caseSensitive: false,
          ))),
        );
        expect(browserSource.body, isNot(contains('unpkg.com')));
        expect(browserSource.body, isNot(contains('React')));
        expect(browserSource.body, isNot(contains('Babel')));
        expect(browserSource.body, isNot(contains('text/babel')));
        expect(
          browserSource.headers['content-security-policy'],
          contains("script-src 'unsafe-inline'"),
        );
      }

      expect(overlayResponse.body, contains('document.createElement'));
      expect(overlayResponse.body, contains("new WebSocket(protocol"));
      expect(overlayResponse.body, contains("owner: 'OWNER'"));
      expect(overlayResponse.body, contains("owner: 'DUEÑO'"));
      expect(overlayResponse.body, contains("envelope.type === 'moderation'"));
      expect(
          overlayResponse.body, contains("envelope.type === 'providerEvent'"));
      expect(alertsResponse.body, contains('document.createElement'));
      expect(alertsResponse.body, contains("membership: 'Membresía'"));

      final socket = IOWebSocketChannel.connect('ws://127.0.0.1:$port/ws');
      await socket.ready;
      final events = StreamIterator(socket.stream);
      expect(await events.moveNext(), isTrue);
      final envelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(envelope['type'], 'settings');
      expect(
        (envelope['data'] as Map<String, dynamic>)['appLanguageCode'],
        'es',
      );
      expect(
        (envelope['data'] as Map<String, dynamic>)['showYoutubeStreamBadges'],
        isTrue,
      );

      messages.add(ChatMessage(
        platform: Platform.youtube,
        id: 'vertical-message',
        author: const ChatAuthor(name: 'Ana', channelId: 'ana'),
        items: const [MessageItem.text('Hola')],
        youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
        timestamp: DateTime.utc(2026, 8, 26),
      ));
      expect(await events.moveNext(), isTrue);
      final messageEnvelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(messageEnvelope['type'], 'message');
      expect(
        (messageEnvelope['data']
            as Map<String, dynamic>)['youtubeStreamOrientation'],
        'vertical',
      );

      server.broadcastModeration(const ChatModerationEvent.message(
        platform: Platform.youtube,
        messageId: 'vertical-message',
        youtubeStreamOrientation: YoutubeStreamOrientation.vertical,
      ));
      expect(await events.moveNext(), isTrue);
      final moderationEnvelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(moderationEnvelope['type'], 'moderation');
      expect(
        (moderationEnvelope['data'] as Map)['messageId'],
        'vertical-message',
      );

      server.broadcastProviderEvent(ChatProviderEvent(
        platform: Platform.twitch,
        kind: ChatProviderEventKind.raid,
        id: 'raid-1',
        timestamp: DateTime.utc(2026, 9, 7),
        count: 50,
      ));
      expect(await events.moveNext(), isTrue);
      final providerEnvelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(providerEnvelope['type'], 'providerEvent');
      expect((providerEnvelope['data'] as Map)['count'], 50);
      await events.cancel();
      await socket.sink.close();
    } finally {
      client.close();
      await server.dispose();
      await messages.close();
    }
  });

  test('tracks WebSocket clients and broadcasts live setting changes',
      () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    IOWebSocketChannel? socket;
    StreamIterator<dynamic>? events;
    final clientCounts = StreamIterator(server.clientCountStream);
    try {
      expect(await clientCounts.moveNext(), isTrue);
      expect(clientCounts.current, 0);
      await server.start(
        messages: messages.stream,
        settings: const SettingsModel(appLanguageCode: 'en'),
        port: 0,
      );

      final connectedCount = clientCounts.moveNext();
      socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
      await socket.ready;
      events = StreamIterator(socket.stream);
      expect(await connectedCount, isTrue);
      expect(clientCounts.current, 1);
      expect(await events.moveNext(), isTrue);
      expect(
        (jsonDecode(events.current as String) as Map<String, dynamic>)['type'],
        'settings',
      );

      server.setSettings(
        const SettingsModel(appLanguageCode: 'es', overlayFontSize: 31),
      );
      expect(await events.moveNext(), isTrue);
      final settingsEnvelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(settingsEnvelope['type'], 'settings');
      expect(
        (settingsEnvelope['data'] as Map<String, dynamic>)['fontSize'],
        31,
      );

      server.broadcastCaption('Texto en vivo');
      expect(await events.moveNext(), isTrue);
      final captionEnvelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(captionEnvelope['type'], 'caption');
      expect(
        (captionEnvelope['data'] as Map<String, dynamic>)['text'],
        'Texto en vivo',
      );

      await events.cancel();
      events = null;
      await socket.sink.close();
      socket = null;
      await server.stop();
      expect(server.clientCount, 0);
    } finally {
      await events?.cancel();
      await socket?.sink.close();
      await clientCounts.cancel();
      await server.dispose();
      await messages.close();
    }
  });

  test('serves the poll overlay and replays the current poll', () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final client = http.Client();
    IOWebSocketChannel? socket;
    StreamIterator<dynamic>? events;
    try {
      await server.start(
        messages: messages.stream,
        settings: const SettingsModel(),
        port: 0,
      );
      final page = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/poll'),
      );
      expect(page.statusCode, 200);
      expect(page.body, contains('Airstream Poll'));

      // A poll started before OBS connects is sent when it connects.
      server.broadcastPoll({'question': '¿Qué juego?', 'total': 2});
      socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
      await socket.ready;
      events = StreamIterator(socket.stream);
      expect(await events.moveNext(), isTrue);
      expect(
        (jsonDecode(events.current as String) as Map)['type'],
        'settings',
      );
      expect(await events.moveNext(), isTrue);
      final envelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(envelope['type'], 'poll');
      expect((envelope['data'] as Map)['question'], '¿Qué juego?');

      server.broadcastPoll(null);
      expect(await events.moveNext(), isTrue);
      expect(
        (jsonDecode(events.current as String) as Map)['data'],
        isNull,
      );
    } finally {
      await events?.cancel();
      await socket?.sink.close();
      client.close();
      await server.dispose();
      await messages.close();
    }
  });
  test('goals page replays current progress to a late connection', () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final client = http.Client();
    IOWebSocketChannel? socket;
    StreamIterator<dynamic>? events;
    try {
      const settings = SettingsModel(goals: {
        'g': {'title': 'Support', 'type': 'subs', 'target': 10, 'current': 12}
      });
      await server.start(
          messages: messages.stream, settings: settings, port: 0);
      final page =
          await client.get(Uri.parse('http://127.0.0.1:${server.port}/goals'));
      expect(page.statusCode, 200);
      expect(page.body, contains('Airstream Goals'));
      socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
      await socket.ready;
      events = StreamIterator(socket.stream);
      await events.moveNext();
      expect((jsonDecode(events.current as String) as Map)['type'], 'settings');
      await events.moveNext();
      final replay = jsonDecode(events.current as String) as Map;
      expect(replay['type'], 'goals');
      expect(replay['replay'], true);
      expect(replay['data'], [
        {
          'id': 'g',
          'title': 'Support',
          'type': 'subs',
          'target': 10,
          'current': 12,
          'percent': 100,
          'reached': true
        }
      ]);
      socket.sink.add(jsonEncode({'type': 'register', 'view': 'goals'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    } finally {
      await events?.cancel();
      await socket?.sink.close();
      client.close();
      await server.dispose();
      await messages.close();
    }
  });

  test('serves the giveaway overlay and replays the current giveaway',
      () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final client = http.Client();
    IOWebSocketChannel? socket;
    StreamIterator<dynamic>? events;
    try {
      await server.start(
        messages: messages.stream,
        settings: const SettingsModel(),
        port: 0,
      );
      final page = await client.get(
        Uri.parse('http://127.0.0.1:${server.port}/giveaway'),
      );
      expect(page.statusCode, 200);
      expect(page.body, contains('Airstream Giveaway'));

      // A giveaway started before OBS connects is sent when it connects.
      final data = <String, Object?>{
        'keyword': '!sorteo',
        'phase': 'drawn',
        'entrantCount': 2,
        'winner': {'name': 'Ana', 'platform': 'twitch'},
        'drawId': 1
      };
      server.broadcastGiveaway(data);
      socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
      await socket.ready;
      events = StreamIterator(socket.stream);
      expect(await events.moveNext(), isTrue);
      expect(
        (jsonDecode(events.current as String) as Map)['type'],
        'settings',
      );
      expect(await events.moveNext(), isTrue);
      final envelope =
          jsonDecode(events.current as String) as Map<String, dynamic>;
      expect(envelope['type'], 'giveaway');
      expect(envelope['replay'], isTrue);
      expect(envelope['data'], data);

      server.broadcastGiveaway(null);
      expect(await events.moveNext(), isTrue);
      expect(
        (jsonDecode(events.current as String) as Map)['data'],
        isNull,
      );
    } finally {
      await events?.cancel();
      await socket?.sink.close();
      client.close();
      await server.dispose();
      await messages.close();
    }
  });
}

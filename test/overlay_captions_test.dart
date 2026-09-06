import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

void main() {
  test('publishes the operating-system assigned overlay port', () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer();
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
    final server = OverlayServer();
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
    final server = OverlayServer();
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
    final server = OverlayServer();
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
}

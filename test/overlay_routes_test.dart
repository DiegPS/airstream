import 'support/empty_template_library.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/name_color_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  final handler = buildOverlayRoutes((_) => Response.ok('socket'));

  Future<Response> handshake({String? origin, int port = 8080}) async =>
      await handler(Request(
        'GET',
        Uri.parse('http://localhost:$port/ws'),
        headers: {if (origin != null) 'origin': origin},
      ));

  test('accepts the overlay pages served on the same loopback port', () async {
    for (final origin in [
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://[::1]:8080',
    ]) {
      final response = await handshake(origin: origin);
      expect(response.statusCode, 200, reason: origin);
      expect(await response.readAsString(), 'socket');
    }
  });

  test('accepts clients that are not browsers (no Origin)', () async {
    expect((await handshake()).statusCode, 200);
  });

  test('rejects web pages from other sites, ports or opaque origins', () async {
    for (final origin in [
      'https://evil.example',
      'http://localhost:3000',
      'http://192.168.1.20:8080',
      'null',
      'file://',
    ]) {
      expect((await handshake(origin: origin)).statusCode, 403, reason: origin);
    }
  });

  test('pages are still served to any client', () async {
    final page = await handler(Request(
      'GET',
      Uri.parse('http://localhost:8080/alerts'),
      headers: {'origin': 'https://evil.example'},
    ));
    expect(page.statusCode, 200);
  });

  test('the running server refuses a foreign page and serves its own',
      () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    addTearDown(() async {
      await server.dispose();
      await messages.close();
    });
    await server.start(
      messages: messages.stream,
      settings: const SettingsModel(),
      port: 0,
    );
    final url = 'ws://127.0.0.1:${server.port}/ws';

    await expectLater(
      WebSocket.connect(url, headers: {'Origin': 'https://evil.example'}),
      throwsA(isA<WebSocketException>()),
    );

    final own = await WebSocket.connect(
      url,
      headers: {'Origin': 'http://127.0.0.1:${server.port}'},
    );
    final firstFrame = await own.first.timeout(const Duration(seconds: 5));
    expect(firstFrame, contains('"settings"'));
    await own.close();
  });

  test('chat clients receive current name colors for visible and new messages',
      () async {
    final messages = StreamController<ChatMessage>();
    final server = OverlayServer(templateLibrary: emptyTemplateLibrary());
    const settings = SettingsModel();
    addTearDown(() async {
      await server.dispose();
      await messages.close();
    });
    await server.start(messages: messages.stream, settings: settings, port: 0);
    final socket = await WebSocket.connect('ws://127.0.0.1:${server.port}/ws');
    final frames = StreamIterator<dynamic>(socket);
    addTearDown(() async {
      await frames.cancel();
      await socket.close();
    });

    Future<Map<String, dynamic>> nextFrame(String type) async {
      expect(
          await frames.moveNext().timeout(const Duration(seconds: 5)), isTrue);
      final frame =
          jsonDecode(frames.current as String) as Map<String, dynamic>;
      expect(frame['type'], type);
      return frame;
    }

    await nextFrame('settings');
    socket.add(jsonEncode({'type': 'register', 'view': 'chat'}));
    await nextFrame('registered');
    final message = ChatMessage(
      id: 'message',
      author: const ChatAuthor(name: 'Viewer', channelId: ''),
      platform: Platform.youtube,
      items: const [MessageItem.text('Hello')],
      timestamp: DateTime.utc(2026),
    );
    messages.add(message);
    final first = await nextFrame('message');
    expect(first['data']['nameColor'], '#FFFFFF');

    server.setSettings(settings.copyWith(nameColorMode: NameColorMode.brand));
    final updatedColors = await nextFrame('nameColors');
    expect(updatedColors['data'], {'${first['sequence']}': '#FF4E45'});
    await nextFrame('settings');
    messages.add(message);
    expect((await nextFrame('message'))['data']['nameColor'], '#FF4E45');
  });
}

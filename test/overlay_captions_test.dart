import 'dart:async';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('serves a dedicated transparent captions browser source', () async {
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
        settings: const SettingsModel(),
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
    } finally {
      client.close();
      await server.dispose();
      await messages.close();
    }
  });
}

import 'support/empty_template_library.dart';
import 'dart:async';
import 'dart:convert';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay_server.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

void main() {
  test(
      'timer serves registers broadcasts additions and replays without a badge',
      () async {
    final messages = StreamController<ChatMessage>.broadcast();
    final server = OverlayServer(
      templateLibrary: emptyTemplateLibrary(),
    );
    final client = http.Client();
    IOWebSocketChannel? socket;
    StreamIterator<dynamic>? events;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final settings = SettingsModel(
          subathonPhase: 'running', subathonEndsAtMs: now + 600000);
      await server.start(
          messages: messages.stream, settings: settings, port: 0);
      final page =
          await client.get(Uri.parse('http://127.0.0.1:${server.port}/timer'));
      expect(page.statusCode, 200);
      expect(page.body, contains('Airstream Timer'));
      // A live addition happened before this page connected.
      server.setSettings(settings.copyWith(subathonEndsAtMs: now + 900000));
      socket = IOWebSocketChannel.connect('ws://127.0.0.1:${server.port}/ws');
      await socket.ready;
      events = StreamIterator(socket.stream);
      expect(await events.moveNext(), true);
      expect((jsonDecode(events.current as String) as Map)['type'], 'settings');
      expect(await events.moveNext(), true);
      final replay = jsonDecode(events.current as String) as Map;
      expect(replay['type'], 'timer');
      expect(replay['replay'], true);
      expect(replay['data']['addedMs'], 0);
      expect(replay['data']['endsAtMs'], now + 900000);
      server.setSettings(settings.copyWith(subathonEndsAtMs: now + 1200000));
      // setSettings sends timer before settings.
      expect(await events.moveNext(), true);
      final live = jsonDecode(events.current as String) as Map;
      expect(live['type'], 'timer');
      expect(live['data']['addedMs'], 300000);
      socket.sink.add(jsonEncode({'type': 'register', 'view': 'timer'}));
      while (await events.moveNext()) {
        if ((jsonDecode(events.current as String) as Map)['type'] ==
            'registered') {
          break;
        }
      }
      expect(server.viewCounts['timer'], 1);
    } finally {
      await events?.cancel();
      await socket?.sink.close();
      client.close();
      await server.dispose();
      await messages.close();
    }
  });
}

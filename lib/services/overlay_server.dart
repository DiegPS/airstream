import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  static bool isValidPort(int port) => port >= 0 && port <= 65535;

  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _clientCountController = StreamController<int>.broadcast();
  StreamSubscription? _msgSub;
  SettingsModel _settings = const SettingsModel();

  int _port = 8080;
  int _lifecycleGeneration = 0;
  int get port => _port;
  InternetAddress? get boundAddress => _server?.address;

  int get clientCount => _clients.length;
  Stream<int> get clientCountStream async* {
    yield _clients.length;
    yield* _clientCountController.stream;
  }

  String get overlayUrl => 'http://localhost:$_port';

  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) async {
    if (!isValidPort(port)) {
      throw RangeError.range(port, 0, 65535, 'port');
    }
    await stop();
    final lifecycleGeneration = ++_lifecycleGeneration;
    _settings = settings;
    _port = port;
    final wsHandler = webSocketHandler((WebSocketChannel ws, _) {
      _clients.add(ws);
      _emitClientCount();
      _sendSettingsToClient(ws);
      ws.stream.listen(null, onDone: () {
        _clients.remove(ws);
        _emitClientCount();
      });
    });

    final handler = buildOverlayRoutes(wsHandler);

    final server =
        await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
    _port = server.port;
    if (lifecycleGeneration != _lifecycleGeneration) {
      await server.close(force: true);
      return;
    }
    _server = server;
    _msgSub = messages.listen(_broadcastMessage);
  }

  void setSettings(SettingsModel settings) {
    _settings = settings;
    _broadcastSettings();
  }

  bool reloadClients() {
    if (_clients.isEmpty) return false;
    _broadcastEnvelope({'type': 'reload'});
    return true;
  }

  bool broadcastTestAlert(String kind) {
    if (_clients.isEmpty) return false;
    final now = DateTime.now().toIso8601String();
    final spanish = _settings.appLanguageCode == 'es';
    final donorName = spanish ? 'Donante de prueba' : 'Test donor';
    final memberName = spanish ? 'Miembro de prueba' : 'Test member';
    const donorAvatar = null;
    const memberAvatar = null;
    final data = switch (kind) {
      'superchat-empty' => {
          'platform': 'youtube',
          'kind': 'superchat',
          'id': 'test-superchat-empty-$now',
          'author': donorName,
          'authorAvatarUrl': donorAvatar,
          'authorChannelId': 'test-donor',
          'badgeImageUrl': null,
          'badgeLabel': null,
          'message': '',
          'amount': r'MX$100.00',
          'color': '#E91E63',
          'stickerUrl': null,
          'timestamp': now,
        },
      'membership' => {
          'platform': 'youtube',
          'kind': 'membership',
          'id': 'test-membership-$now',
          'author': memberName,
          'authorAvatarUrl': memberAvatar,
          'authorChannelId': 'test-member',
          'badgeImageUrl': null,
          'badgeLabel': spanish ? 'Nuevo miembro' : 'New member',
          'message': spanish
              ? '¡Te damos la bienvenida a la membresía del canal!'
              : 'Welcome to the channel membership!',
          'amount': null,
          'color': '#0F9D58',
          'stickerUrl': null,
          'timestamp': now,
        },
      _ => {
          'platform': 'youtube',
          'kind': 'superchat',
          'id': 'test-superchat-$now',
          'author': donorName,
          'authorAvatarUrl': donorAvatar,
          'authorChannelId': 'test-donor',
          'badgeImageUrl': null,
          'badgeLabel': null,
          'message': spanish
              ? 'Este es un mensaje de prueba de Super Chat.'
              : 'This is a test Super Chat message.',
          'amount': r'MX$50.00',
          'color': '#FFD600',
          'stickerUrl': null,
          'timestamp': now,
        },
    };
    _broadcastEnvelope({'type': 'alert', 'data': data});
    return true;
  }

  void broadcastCaption(String text) {
    final caption = text.trim();
    if (caption.isEmpty) return;
    _broadcastEnvelope({
      'type': 'caption',
      'data': {'text': caption}
    });
  }

  Future<void> stop() async {
    _lifecycleGeneration++;
    await _msgSub?.cancel();
    _msgSub = null;
    await _server?.close(force: true);
    _server = null;
    _clients.clear();
    _emitClientCount();
  }

  Future<void> dispose() async {
    await stop();
    await _clientCountController.close();
  }

  void _broadcastMessage(ChatMessage msg) {
    _broadcastEnvelope({
      'type': 'message',
      'data': OverlayPayloadEncoder.message(msg),
    });
    _broadcastAlert(msg);
  }

  void _broadcastAlert(ChatMessage msg) {
    if (msg.platform != Platform.youtube) return;
    final kind = msg.superChat != null
        ? 'superchat'
        : msg.isMembershipEvent
            ? 'membership'
            : null;
    if (kind == null) return;

    _broadcastEnvelope({
      'type': 'alert',
      'data': {
        'platform': msg.platform.name,
        'kind': kind,
        'id': msg.id,
        'author': msg.author.name,
        'authorAvatarUrl': msg.author.avatarUrl,
        'authorChannelId': msg.author.channelId,
        'badgeImageUrl': msg.author.badge?.imageUrl,
        'badgeLabel': msg.author.badge?.label,
        'message': msg.plainText.trim(),
        'amount': msg.superChat?.amount,
        'color': msg.superChat?.color,
        'stickerUrl': msg.superChat?.stickerUrl,
        'timestamp': msg.timestamp.toIso8601String(),
      },
    });
  }

  void _broadcastSettings() {
    _broadcastEnvelope({
      'type': 'settings',
      'data': OverlayPayloadEncoder.settings(_settings),
    });
  }

  void _sendSettingsToClient(WebSocketChannel client) {
    try {
      client.sink.add(jsonEncode({
        'type': 'settings',
        'data': OverlayPayloadEncoder.settings(_settings),
      }));
    } catch (_) {
      _clients.remove(client);
    }
  }

  void _broadcastEnvelope(Map<String, dynamic> envelope) {
    if (_clients.isEmpty) return;
    final json = jsonEncode(envelope);
    for (final client in List.of(_clients)) {
      try {
        client.sink.add(json);
      } catch (_) {
        _clients.remove(client);
        _emitClientCount();
      }
    }
  }

  void _emitClientCount() {
    if (!_clientCountController.isClosed) {
      _clientCountController.add(_clients.length);
    }
  }
}

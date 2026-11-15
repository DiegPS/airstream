import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  OverlayServer({
    this.featuredAcknowledgementTimeout = const Duration(seconds: 30),
  });

  static bool isValidPort(int port) => port >= 0 && port <= 65535;

  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _views = <WebSocketChannel, String>{};
  final _featured = <String, _PendingFeaturedMessage>{};
  int _nextDelivery = 0;

  final Duration featuredAcknowledgementTimeout;
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
      ws.stream.listen(
        (dynamic data) => _handleClientMessage(ws, data),
        onError: (Object _) => _removeClient(ws),
        onDone: () => _removeClient(ws),
      );
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
    _msgSub = messages.listen(
      _broadcastMessage,
      onError: (Object error, StackTrace stack) {
        AppLogger.warning(
          'Overlay message stream reported an error',
          error: error,
          stackTrace: stack,
        );
      },
    );
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

  void broadcastModeration(ChatModerationEvent event) {
    _broadcastEnvelope({
      'type': 'moderation',
      'data': OverlayPayloadEncoder.moderation(event),
    });
  }

  Map<String, Object?>? _poll;

  /// Shows [poll] on the poll overlay; null hides it. Overlays that connect
  /// later receive the current poll.
  void broadcastPoll(Map<String, Object?>? poll) {
    _poll = poll;
    _broadcastEnvelope({'type': 'poll', 'data': poll});
  }

  void broadcastProviderEvent(ChatProviderEvent event) {
    _broadcastEnvelope({
      'type': 'providerEvent',
      'data': OverlayPayloadEncoder.providerEvent(event),
    });
  }

  Future<void> stop() async {
    _lifecycleGeneration++;
    await _msgSub?.cancel();
    _msgSub = null;
    final clients = List<WebSocketChannel>.from(_clients);
    _clients.clear();
    _views.clear();
    for (final pending in _featured.values) {
      pending.finish(FeaturedMessageStatus.disconnected);
    }
    _featured.clear();
    for (final client in clients) {
      try {
        await client.sink.close().timeout(const Duration(seconds: 1));
      } catch (_) {
        // A browser may already have closed or may not acknowledge shutdown.
      }
    }
    await _server?.close(force: true);
    _server = null;
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

  FeaturedMessageDelivery broadcastFeaturedMessage(ChatMessage msg) {
    final recipients = _views.entries
        .where((entry) => entry.value == 'alerts')
        .map((entry) => entry.key)
        .toSet();
    if (recipients.isEmpty) return FeaturedMessageDelivery.noReceiver();
    final id = '$_lifecycleGeneration-${++_nextDelivery}';
    final pending =
        _PendingFeaturedMessage(Set<WebSocketChannel>.from(recipients));
    _featured[id] = pending;
    pending.timer = Timer(featuredAcknowledgementTimeout, () {
      _featured.remove(id)?.finish(FeaturedMessageStatus.sent);
    });
    final envelope = jsonEncode({
      'type': 'alert',
      'data': {..._alertData(msg, 'featured'), 'deliveryId': id},
    });
    for (final client in recipients) {
      try {
        client.sink.add(envelope);
      } catch (_) {
        _removeClient(client);
      }
    }
    return FeaturedMessageDelivery(
      id,
      pending.recipients.isEmpty
          ? FeaturedMessageStatus.noReceiver
          : FeaturedMessageStatus.sent,
      pending.completion.future,
    );
  }

  void _handleClientMessage(WebSocketChannel client, dynamic data) {
    if (!_clients.contains(client) || data is! String || data.length > 1024) {
      return;
    }
    try {
      final envelope = jsonDecode(data);
      if (envelope is! Map) return;
      if (envelope['type'] == 'register') {
        final view = envelope['view'];
        if (view is String &&
            const {'chat', 'alerts', 'poll', 'captions'}.contains(view) &&
            !_views.containsKey(client)) {
          _views[client] = view;
          client.sink.add(jsonEncode({'type': 'registered', 'view': view}));
        }
      } else if (envelope['type'] == 'featuredRendered' &&
          _views[client] == 'alerts') {
        final id = envelope['deliveryId'];
        final pending = _featured[id];
        if (pending != null && pending.recipients.contains(client)) {
          _featured.remove(id);
          pending.finish(FeaturedMessageStatus.rendered);
        }
      }
    } catch (_) {
      // Ignore malformed input and acknowledgements for expired deliveries.
    }
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
      'data': _alertData(msg, kind),
    });
  }

  static Map<String, Object?> _alertData(ChatMessage msg, String kind) => {
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
      };

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
      if (_poll != null) {
        client.sink.add(jsonEncode({'type': 'poll', 'data': _poll}));
      }
    } catch (_) {
      // A failed send means the browser disconnected before its close event.
      _removeClient(client);
    }
  }

  void _broadcastEnvelope(Map<String, dynamic> envelope) {
    if (_clients.isEmpty) return;
    final json = jsonEncode(envelope);
    for (final client in List.of(_clients)) {
      try {
        client.sink.add(json);
      } catch (_) {
        // A failed send means the browser disconnected before its close event.
        _removeClient(client);
      }
    }
  }

  void _emitClientCount() {
    if (!_clientCountController.isClosed) {
      _clientCountController.add(_clients.length);
    }
  }

  void _removeClient(WebSocketChannel client) {
    _views.remove(client);
    for (final entry in _featured.entries.toList()) {
      entry.value.recipients.remove(client);
      if (entry.value.recipients.isEmpty) {
        _featured.remove(entry.key);
        entry.value.finish(FeaturedMessageStatus.disconnected);
      }
    }
    if (_clients.remove(client)) _emitClientCount();
  }
}

class _PendingFeaturedMessage {
  _PendingFeaturedMessage(this.recipients);

  final Set<WebSocketChannel> recipients;
  final completion = Completer<FeaturedMessageStatus>();
  Timer? timer;

  void finish(FeaturedMessageStatus status) {
    timer?.cancel();
    if (!completion.isCompleted) completion.complete(status);
  }
}

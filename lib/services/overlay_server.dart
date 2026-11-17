import 'package:airstream/application/subathon_timer.dart';
import 'dart:async';
import 'package:airstream/settings/goals.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:airstream/services/media_library.dart';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:airstream/settings/alert_type_options.dart';
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
    this.giftGroupingWindow = const Duration(seconds: 2),
  });

  static bool isValidPort(int port) => port >= 0 && port <= 65535;

  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _views = <WebSocketChannel, String>{};
  final _featured = <String, _PendingFeaturedMessage>{};
  int _nextDelivery = 0;
  final _giftGroups = <String, _PendingGiftGroup>{};
  final _providerAlertIds = <Platform, Set<String>>{};
  final Duration giftGroupingWindow;

  final Duration featuredAcknowledgementTimeout;
  final _clientCountController = StreamController<int>.broadcast();
  StreamSubscription? _msgSub;
  SettingsModel _settings = const SettingsModel();

  int _port = 8080;
  int _lifecycleGeneration = 0;
  int get port => _port;
  InternetAddress? get boundAddress => _server?.address;

  Map<String, int> get viewCounts => Map.unmodifiable({
        for (final view in const [
          'chat',
          'alerts',
          'poll',
          'captions',
          'giveaway',
          'goals',
          'timer'
        ])
          view: _views.values.where((value) => value == view).length,
      });
  final _viewCountsController = StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get viewCountsStream => Stream.multi((listener) {
        final subscription = _viewCountsController.stream
            .listen(listener.addSync, onDone: listener.closeSync);
        listener.addSync(viewCounts);
        listener.onCancel = subscription.cancel;
      }, isBroadcast: true);

  int get clientCount => _clients.length;
  Stream<int> get clientCountStream async* {
    yield _clients.length;
    yield* _clientCountController.stream;
  }

  final _recentAlerts = <Map<String, Object?>>[];
  final _recentAlertsController =
      StreamController<List<Map<String, Object?>>>.broadcast(sync: true);

  List<Map<String, Object?>> get recentAlertsSnapshot =>
      List.unmodifiable(_recentAlerts);

  Stream<List<Map<String, Object?>>> get recentAlerts =>
      Stream.multi((listener) {
        final subscription = _recentAlertsController.stream.listen(
          listener.addSync,
          onDone: listener.closeSync,
        );
        listener.addSync(recentAlertsSnapshot);
        listener.onCancel = subscription.cancel;
      }, isBroadcast: true);

  void clearRecentAlerts() {
    _recentAlerts.clear();
    _recentAlertsController.add(recentAlertsSnapshot);
  }

  bool replayRecentAlert(String id) {
    for (final alert in _recentAlerts) {
      if (alert['id'] == id) {
        return _broadcastEnvelope({'type': 'alert', 'data': alert});
      }
    }
    return false;
  }

  void _sendAutomaticAlert(Map<String, Object?> data) {
    final sent = _broadcastEnvelope({'type': 'alert', 'data': data});
    if (!sent) return;
    _recentAlerts.insert(0, Map.unmodifiable(data));
    if (_recentAlerts.length > 30) _recentAlerts.removeLast();
    _recentAlertsController.add(recentAlertsSnapshot);
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
    _updateGoals(settings);
    _updateTimer(settings);
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

    final handler = buildOverlayRoutes(wsHandler,
        mediaLibrary: () async => MediaLibrary(
            Directory(
                p.join((await getApplicationSupportDirectory()).path, 'media')),
            () => _settings.mediaLibrary),
        customSound: (type) {
          final option = AlertTypeOptions.of(_settings, type);
          return option.sound == 'custom'
              ? AlertSounds.customFile(option.soundPath)
              : null;
        });

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
    _updateGoals(settings);
    _updateTimer(settings);
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
    final viewerName = spanish ? 'Espectador de prueba' : 'Test viewer';
    final data = switch (kind) {
      'bits' || 'subscription' || 'gift' => _alertData(
          ChatMessage(
            platform: kind == 'subscription' ? Platform.kick : Platform.twitch,
            id: 'test-$kind-$now',
            author: ChatAuthor(name: viewerName, channelId: 'test-viewer'),
            items: const [],
            timestamp: DateTime.parse(now),
            superChat: kind == 'bits'
                ? const SuperChat(amount: '100 Bits', color: '#9146FF')
                : null,
            isMembershipEvent: kind != 'bits',
            membershipEventKind: switch (kind) {
              'subscription' => MembershipEventKind.resubscription,
              'gift' => MembershipEventKind.gift,
              _ => null,
            },
            membershipMonths: kind == 'subscription' ? 6 : null,
            membershipGiftCount: kind == 'gift' ? 5 : null,
          ),
          kind == 'bits' ? 'bits' : 'membership',
        ),
      'raid' || 'kicks' => _providerAlertData(
          ChatProviderEvent(
            platform: kind == 'raid' ? Platform.twitch : Platform.kick,
            kind: kind == 'raid'
                ? ChatProviderEventKind.raid
                : ChatProviderEventKind.support,
            id: 'test-$kind-$now',
            timestamp: DateTime.parse(now),
            authorName: viewerName,
            count: kind == 'raid' ? 42 : 100,
            text: kind == 'kicks'
                ? (spanish ? '¡Buen directo!' : 'Great stream!')
                : '',
          ),
          kind,
        ),
      'superchat-empty' => {
          'platform': 'youtube',
          'kind': 'superchat',
          'alertType': 'superchat',
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
          'alertType': 'membership',
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
          'alertType': 'superchat',
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

  Map<String, Object?>? _timer;
  void _updateTimer(SettingsModel settings) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = SubathonTimer.payload(settings, now);
    final previous = _timer;
    if (previous == null && next['phase'] == 'idle') return;
    if (previous != null &&
        ['phase', 'endsAtMs'].every((k) => previous[k] == next[k]) &&
        (next['phase'] != 'paused' ||
            previous['remainingMs'] == next['remainingMs'])) {
      return;
    }
    var added = 0;
    if (previous != null && previous['phase'] == next['phase']) {
      if (next['phase'] == 'running') {
        added = (next['endsAtMs'] as int) - (previous['endsAtMs'] as int);
      }
      if (next['phase'] == 'paused') {
        added = (next['remainingMs'] as int) - (previous['remainingMs'] as int);
      }
    }
    next['addedMs'] = added > 0 ? added : 0;
    _timer = next;
    _broadcastEnvelope({'type': 'timer', 'data': next});
  }

  List<Map<String, Object?>> _goals = const [];
  Timer? _goalsTimer;
  void _updateGoals(SettingsModel settings) {
    broadcastGoals(Goals.payload(settings.goals));
  }

  void broadcastGoals(List<Map<String, Object?>> goals) {
    final next = [
      for (final goal in goals) Map<String, Object?>.unmodifiable(goal)
    ];
    if (jsonEncode(next) == jsonEncode(_goals)) return;
    _goals = next;
    _goalsTimer ??= Timer(const Duration(milliseconds: 250), () {
      _goalsTimer = null;
      _broadcastEnvelope({'type': 'goals', 'data': _goals});
    });
  }

  Map<String, Object?>? _giveaway;
  void broadcastGiveaway(Map<String, Object?>? giveaway) {
    _giveaway = giveaway;
    _broadcastEnvelope({'type': 'giveaway', 'data': giveaway});
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
    final kind = switch ((event.platform, event.kind)) {
      (Platform.twitch, ChatProviderEventKind.raid) => 'raid',
      (Platform.kick, ChatProviderEventKind.host) => 'host',
      (Platform.kick, ChatProviderEventKind.support) => 'kicks',
      _ => null,
    };
    if (kind == null ||
        _settings.alertDisabledTypes
            .contains(_alertType(kind, event.platform, null))) {
      return;
    }
    final ids = _providerAlertIds.putIfAbsent(event.platform, () => <String>{});
    if (!ids.add(event.id)) return;
    if (ids.length > 200) ids.remove(ids.first);
    _sendAutomaticAlert(_providerAlertData(event, kind));
  }

  static Map<String, Object?> _providerAlertData(
          ChatProviderEvent event, String kind) =>
      {
        'platform': event.platform.name,
        'kind': kind,
        'alertType': _alertType(kind, event.platform, null),
        'id': event.id,
        'author': event.authorName,
        'authorAvatarUrl': null,
        'authorChannelId': '',
        'badgeImageUrl': null,
        'badgeLabel': null,
        'message': kind == 'kicks' ? event.text : '',
        'amount': null,
        'color': null,
        'stickerUrl': null,
        'timestamp': event.timestamp.toIso8601String(),
        'membershipKind': null,
        'months': null,
        'giftCount': null,
        'count': event.count,
      };

  Future<void> stop() async {
    clearRecentAlerts();
    _lifecycleGeneration++;
    _providerAlertIds.clear();
    for (final group in _giftGroups.values) {
      group.timer?.cancel();
    }
    _giftGroups.clear();
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
    _goalsTimer?.cancel();
    await _clientCountController.close();
    await _viewCountsController.close();
    await _recentAlertsController.close();
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
            const {
              'chat',
              'alerts',
              'poll',
              'captions',
              'giveaway',
              'goals',
              'timer'
            }.contains(view) &&
            !_views.containsKey(client)) {
          _views[client] = view;
          _emitViewCounts();
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

  static String? _alertType(
    String kind,
    Platform platform,
    MembershipEventKind? membershipKind,
  ) =>
      switch (kind) {
        'superchat' || 'bits' || 'kicks' => kind,
        'raid' || 'host' => 'raid',
        'membership' when membershipKind == MembershipEventKind.gift => 'gift',
        'membership' when platform == Platform.youtube => 'membership',
        'membership'
            when membershipKind == MembershipEventKind.subscription ||
                membershipKind == MembershipEventKind.resubscription =>
          'subscription',
        _ => null,
      };

  void _broadcastAlert(ChatMessage msg) {
    final kind = msg.superChat != null
        ? (msg.platform == Platform.twitch ? 'bits' : 'superchat')
        : msg.isMembershipEvent
            ? 'membership'
            : null;
    if (kind == null ||
        _settings.alertDisabledTypes.contains(
            _alertType(kind, msg.platform, msg.membershipEventKind))) {
      return;
    }
    if (kind == 'membership' &&
        msg.platform == Platform.twitch &&
        msg.membershipEventKind == MembershipEventKind.gift) {
      final key = msg.author.channelId.isNotEmpty
          ? msg.author.channelId
          : msg.author.name.toLowerCase();
      final group = _giftGroups.putIfAbsent(key, () => _PendingGiftGroup(msg));
      group.count++;
      group.timer?.cancel();
      final generation = _lifecycleGeneration;
      group.timer = Timer(giftGroupingWindow, () {
        if (generation != _lifecycleGeneration ||
            !identical(_giftGroups[key], group)) {
          return;
        }
        _giftGroups.remove(key);
        _sendAutomaticAlert({
          ..._alertData(group.first, 'membership'),
          'giftCount': group.count,
          'message': '',
        });
      });
      return;
    }

    _sendAutomaticAlert(_alertData(msg, kind));
  }

  static Map<String, Object?> _alertData(ChatMessage msg, String kind) => {
        'platform': msg.platform.name,
        'kind': kind,
        'alertType': _alertType(kind, msg.platform, msg.membershipEventKind),
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
        'membershipKind': msg.membershipEventKind?.name,
        'months': msg.membershipMonths,
        'giftCount': msg.membershipGiftCount,
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
      if (_timer != null) {
        final data = {
          ..._timer!,
          'addedMs': 0,
          'serverNowMs': DateTime.now().millisecondsSinceEpoch
        };
        if (data['phase'] == 'running') {
          final ms = (data['endsAtMs'] as int) - (data['serverNowMs'] as int);
          data['remainingMs'] = ms > 0 ? ms : 0;
          if (ms <= 0) data['phase'] = 'ended';
        }
        client.sink
            .add(jsonEncode({'type': 'timer', 'data': data, 'replay': true}));
      }
      if (_goals.isNotEmpty) {
        client.sink
            .add(jsonEncode({'type': 'goals', 'data': _goals, 'replay': true}));
      }
      if (_giveaway != null) {
        client.sink.add(jsonEncode(
            {'type': 'giveaway', 'data': _giveaway, 'replay': true}));
      }
      if (_poll != null) {
        client.sink.add(jsonEncode({'type': 'poll', 'data': _poll}));
      }
    } catch (_) {
      // A failed send means the browser disconnected before its close event.
      _removeClient(client);
    }
  }

  bool _broadcastEnvelope(Map<String, dynamic> envelope) {
    if (_clients.isEmpty) return false;
    var sent = false;
    final json = jsonEncode(envelope);
    for (final client in List.of(_clients)) {
      try {
        client.sink.add(json);
        sent = true;
      } catch (_) {
        // A failed send means the browser disconnected before its close event.
        _removeClient(client);
      }
    }
    return sent;
  }

  void _emitViewCounts() {
    if (!_viewCountsController.isClosed) _viewCountsController.add(viewCounts);
  }

  void _emitClientCount() {
    _emitViewCounts();
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

class _PendingGiftGroup {
  _PendingGiftGroup(this.first);

  final ChatMessage first;
  int count = 0;
  Timer? timer;
}

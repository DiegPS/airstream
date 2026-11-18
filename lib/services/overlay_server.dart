import 'package:airstream/application/rules/rule_engine.dart';
import 'package:airstream/application/twitch_gift_groups.dart';
import 'package:airstream/application/name_colors.dart';
import 'package:airstream/services/overlay/rules_api_route.dart';
import 'package:airstream/services/templates/template_library.dart';
import 'package:airstream/services/templates/gallery/gallery_catalog.dart';
import 'package:airstream/application/subathon_timer.dart';
import 'dart:async';
import 'package:airstream/settings/goals.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show mapEquals, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:airstream/services/media_library.dart';

import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/support_alert.dart';
import 'package:airstream/pipeline/chat_filter.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/overlay/featured_message_delivery.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/services/overlay/overlay_payload_encoder.dart';
import 'package:airstream/services/overlay/overlay_routes.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum AlertQueueOperation { pause, resume, skip, clear }

typedef AlertQueueStatus = ({bool paused, int pending, bool active, int pages});

/// Serves the OBS overlay HTML page and broadcasts chat messages over WebSocket.
class OverlayServer {
  OverlayServer({
    TemplateLibrary? templateLibrary,
    this.featuredAcknowledgementTimeout = const Duration(seconds: 30),
    this.giftGroupingWindow = TwitchGiftGroups.defaultWindow,
  }) : _templateLibrary = templateLibrary;

  RuleEngine? rulesEngine;
  late final _rulesApi =
      RulesApiRoute(settings: () => _settings, engine: () => rulesEngine);
  TemplateLibrary? _templateLibrary;
  Future<TemplateLibrary>? _templateLibraryFuture;
  Future<TemplateLibrary> get templateLibrary =>
      _templateLibraryFuture ??= _loadTemplateLibrary();
  // Resolved once: a video played in byte ranges asks for /media many times.
  Future<MediaLibrary>? _mediaLibrary;
  Future<MediaLibrary> _loadMediaLibrary() async {
    try {
      return MediaLibrary(
          Directory(
              p.join((await getApplicationSupportDirectory()).path, 'media')),
          () => _settings.mediaLibrary);
    } catch (_) {
      _mediaLibrary = null;
      rethrow;
    }
  }

  Future<TemplateLibrary> _loadTemplateLibrary() async {
    try {
      return _templateLibrary ??=
          TemplateLibrary(await TemplateLibrary.defaultRoot());
    } catch (_) {
      // Retry on the next use: a failed Documents lookup is often transient
      // (folder redirection or sync still starting).
      _templateLibraryFuture = null;
      rethrow;
    }
  }

  final _templates = <WebSocketChannel, String>{};
  final _galleryViews = <WebSocketChannel, GalleryItem>{};
  final _sessionClients = <WebSocketChannel, String?>{};
  Timer? _sessionTimer;
  String _sessionJson = 'null';
  bool _sessionDirty = true;

  /// Reads the current session only when a template is registered.
  Map<String, Object?>? Function()? sessionState;

  Map<String, Object?> Function()? queueState;

  void broadcastQueue(Map<String, Object?> state) {
    if (_sessionClients.isEmpty) return;
    final json = jsonEncode({'type': 'queue', 'data': state});
    for (final client in _sessionClients.keys.toList()) {
      try {
        client.sink.add(json);
      } catch (_) {
        _removeClient(client);
      }
    }
  }

  void sessionChanged() {
    _sessionDirty = true;
    if (_sessionClients.isEmpty) return;
    _sessionTimer ??= Timer(const Duration(seconds: 1), () {
      _sessionTimer = null;
      for (final client in _sessionClients.keys.toList()) {
        _sendSession(client, replay: false);
      }
    });
  }

  void _sendSession(WebSocketChannel client, {required bool replay}) {
    if (_sessionDirty) {
      final data = sessionState?.call();
      _sessionJson = jsonEncode(data);
      _sessionDirty = false;
    }
    final json = _sessionJson;
    if (!replay && _sessionClients[client] == json) return;
    try {
      client.sink.add('{"type":"session","replay":$replay,"data":$json}');
      _sessionClients[client] = json;
    } catch (_) {
      _removeClient(client);
    }
  }

  final _counterClients = <WebSocketChannel, String>{};
  Timer? _counterTimer;

  void _countersChanged() {
    if (_sessionClients.isEmpty) return;
    _counterTimer ??= Timer(const Duration(seconds: 1), () {
      _counterTimer = null;
      final json = jsonEncode(_settings.ruleCounters);
      for (final client in _sessionClients.keys.toList()) {
        _sendCounters(client, json, replay: false);
      }
    });
  }

  void _sendCounters(WebSocketChannel client, String json,
      {required bool replay}) {
    if (!replay && _counterClients[client] == json) return;
    try {
      client.sink.add('{"type":"counters","replay":$replay,"data":$json}');
      _counterClients[client] = json;
    } catch (_) {
      _removeClient(client);
    }
  }

  void _clearSessionDelivery() {
    _counterTimer?.cancel();
    _counterTimer = null;
    _counterClients.clear();
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionJson = 'null';
    _sessionDirty = true;
  }

  StreamSubscription<TemplateChange>? _templateSub;
  final _templateCounts = StreamController<Map<String, int>>.broadcast();
  final _errorsController =
      StreamController<Map<String, TemplateError>>.broadcast();
  final _errors = <String, TemplateError>{};
  Map<String, TemplateError> get templateErrors => Map.unmodifiable(_errors);
  Stream<Map<String, TemplateError>> get templateErrorsStream =>
      Stream.multi((listener) {
        final sub = _errorsController.stream
            .listen(listener.addSync, onDone: listener.closeSync);
        listener.addSync(templateErrors);
        listener.onCancel = sub.cancel;
      }, isBroadcast: true);
  Map<String, int> get templateViewCounts => Map.unmodifiable({
        for (final id in _templates.values.toSet())
          id: _templates.values.where((v) => v == id).length
      });
  Stream<Map<String, int>> get templateViewCountsStream =>
      Stream.multi((listener) {
        final sub = _templateCounts.stream
            .listen(listener.addSync, onDone: listener.closeSync);
        listener.addSync(templateViewCounts);
        listener.onCancel = sub.cancel;
      }, isBroadcast: true);

  /// Sends a plain-text automation event exclusively to custom templates.
  bool broadcastRuleTrigger(
          {required String name, required String data, required String rule}) =>
      _sendCustom({
        'type': 'trigger',
        'data': {'name': name, 'data': data, 'rule': rule}
      });

  bool _sendCustom(Map<String, Object?> envelope, [String? id]) {
    var sent = false;
    final recipients = [
      for (final entry in _templates.entries)
        if (id == null || entry.value == id) entry.key,
      if (id == null) ..._galleryViews.keys,
    ];
    if (recipients.isEmpty) return false;
    final json = jsonEncode(envelope);
    for (final client in recipients) {
      try {
        client.sink.add(json);
        sent = true;
      } catch (_) {
        _removeClient(client);
      }
    }
    return sent;
  }

  Future<void> _templateChanged(TemplateChange change) async {
    if (change.kind == TemplateChangeKind.values) {
      try {
        final values = await (await templateLibrary).resolvedValues(change.id);
        _sendCustom({'type': 'fields', 'data': values}, change.id);
      } on FileSystemException {/* A template can be removed during a save. */}
    } else {
      _sendCustom({'type': 'reload'}, change.id);
    }
  }

  Future<void> _sendFields(WebSocketChannel client, String id) async {
    try {
      final values = await (await templateLibrary).resolvedValues(id);
      if (_templates[client] == id) {
        client.sink.add(
            jsonEncode({'type': 'fields', 'data': values, 'replay': true}));
      }
    } catch (_) {/* Disconnected or removed template. */}
  }

  void clearTemplateError(String id) {
    _errors.remove(id);
    _errorsController.add(templateErrors);
  }

  bool broadcastTemplateTest() {
    final now = DateTime.now();
    final name = _settings.appLanguageCode == 'es'
        ? 'Espectador de prueba'
        : 'Test viewer';
    final msg = ChatMessage(
        platform: Platform.twitch,
        id: 'template-test-${now.microsecondsSinceEpoch}',
        author: ChatAuthor(name: name, channelId: 'test-viewer'),
        items: [
          MessageItem.text(_settings.appLanguageCode == 'es'
              ? 'Mensaje de prueba'
              : 'Test chat message')
        ],
        timestamp: now);
    final sent = _sendCustom({
      'type': 'message',
      'data': OverlayPayloadEncoder.message(msg, _settings),
      'test': true
    });
    _sendCustom({
      'type': 'alert',
      'data': _providerAlertData(
          ChatProviderEvent(
              platform: Platform.twitch,
              kind: ChatProviderEventKind.raid,
              id: 'template-raid-${now.microsecondsSinceEpoch}',
              timestamp: now,
              authorName: name,
              count: 42),
          'raid'),
      'test': true
    });
    return sent;
  }

  static bool isValidPort(int port) => port >= 0 && port <= 65535;

  HttpServer? _server;
  final _clients = <WebSocketChannel>{};
  final _views = <WebSocketChannel, String>{};
  final _inactiveSources = <WebSocketChannel>{};
  // Built-in chat displays at most 500 messages. Keep their inputs so name
  // colors can also update for messages already on screen.
  final _recentChatMessages = <int, ChatMessage>{};
  final _recentProviderEvents =
      <(Platform, ChatProviderEventKind, String), ChatProviderEvent>{};
  // /chat can retain up to this many visible records.
  static const _recentRecordLimit = 500;
  int _nextChatSequence = 0;
  final _featured = <String, _PendingFeaturedMessage>{};
  int _nextDelivery = 0;
  late final _giftGroups = TwitchGiftGroups(window: giftGroupingWindow);
  final _providerAlertIds = <Platform, Set<String>>{};
  final Duration giftGroupingWindow;

  final Duration featuredAcknowledgementTimeout;
  final _clientCountController = StreamController<int>.broadcast();
  StreamSubscription? _msgSub;
  SettingsModel _settings = const SettingsModel();
  ChatFilter _chatFilter = ChatFilter(const SettingsModel());

  int _port = 8080;
  int _lifecycleGeneration = 0;
  int get port => _port;
  InternetAddress? get boundAddress => _server?.address;

  Map<String, int> get viewCounts => Map.unmodifiable({
        for (final view in const [
          'chat',
          'alerts',
          'featured',
          'poll',
          'captions',
          'giveaway',
          'goals',
          'timer',
          'clock',
          'custom'
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

  bool _alertsPaused = false;
  final _alertQueues = <WebSocketChannel, ({int pending, bool active})>{};
  final _alertQueueController = StreamController<AlertQueueStatus>.broadcast();

  AlertQueueStatus get alertQueueStatus => (
        paused: _alertsPaused,
        pending: _alertQueues.values
            .fold(0, (max, queue) => queue.pending > max ? queue.pending : max),
        active: _alertQueues.values.any((queue) => queue.active),
        pages: _views.values.where((view) => view == 'alerts').length,
      );

  Stream<AlertQueueStatus> get alertQueueStatusStream =>
      Stream.multi((listener) {
        final sub = _alertQueueController.stream
            .listen(listener.addSync, onDone: listener.closeSync);
        listener.addSync(alertQueueStatus);
        listener.onCancel = sub.cancel;
      }, isBroadcast: true);

  Map<String, Object?> _alertControl(AlertQueueOperation op) =>
      {'type': 'alertControl', 'op': op.name};

  void controlAlertQueue(AlertQueueOperation op) {
    switch (op) {
      case AlertQueueOperation.pause:
        _alertsPaused = true;
      case AlertQueueOperation.resume:
        _alertsPaused = false;
      case AlertQueueOperation.skip:
      case AlertQueueOperation.clear:
        break;
    }
    _broadcastEnvelope(_alertControl(op), view: 'alerts');
    _emitAlertQueue();
  }

  void _emitAlertQueue() {
    if (!_alertQueueController.isClosed) {
      _alertQueueController.add(alertQueueStatus);
    }
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
        return _broadcastEnvelope({'type': 'alert', 'data': alert},
            view: 'alerts');
      }
    }
    return false;
  }

  bool broadcastRuleAlert(
      {required String title,
      required String text,
      String mediaId = '',
      required int seconds}) {
    final medium = _settings.mediaLibrary[mediaId];
    return _broadcastEnvelope({
      'type': 'alert',
      'data': {
        'kind': 'custom',
        'title': title,
        'message': text,
        'seconds': seconds,
        if (medium != null && ['image', 'video'].contains(medium['kind']))
          'media': mediaId,
        if (medium != null) 'mediaKind': medium['kind'],
      }
    }, view: 'alerts');
  }

  void _sendAutomaticAlert(Map<String, Object?> data) {
    if (!_settings.alertPlatforms.contains(data['platform'])) return;
    data = _withAlertOption(data);
    final sent = _broadcastEnvelope({'type': 'alert', 'data': data},
        requireDeliveryTo: 'alerts');
    if (!sent) return;
    _recentAlerts.insert(0, Map.unmodifiable(data));
    if (_recentAlerts.length > 30) _recentAlerts.removeLast();
    _recentAlertsController.add(recentAlertsSnapshot);
  }

  Map<String, Object?> _withAlertOption(Map<String, Object?> data) {
    if (!_settings.alertTypeOptions.containsKey(data['alertType'])) return data;
    final option = AlertTypeOptions.sanitize(
        _settings.alertTypeOptions)[data['alertType']];
    if (option == null || AlertTypeOptions.tiers(option).isEmpty) return data;
    final resolved = AlertTypeOptions.resolve(option, supportAlertAmount(data));
    AlertTypeOptions.validateMedia(
        resolved, MediaLibraryEntries.sanitize(_settings.mediaLibrary));
    return {
      ...data,
      'option': OverlayPayloadEncoder.alertOption(resolved, _settings)
    };
  }

  File? _tierSound(String type, String key) {
    final options = AlertTypeOptions.sanitize(_settings.alertTypeOptions)[type];
    for (final option in [
      if (options != null) options,
      ...AlertTypeOptions.tiers(options)
    ]) {
      final path = option['soundPath'] as String?;
      if (path != null && OverlayPayloadEncoder.alertSoundKey(path) == key) {
        return AlertSounds.customFile(path);
      }
    }
    return null;
  }

  String get overlayUrl => 'http://localhost:$_port';

  Future<void>? _lifecycle;
  int _startGeneration = 0;

  // Invalidate startup immediately even when cleanup has to wait its turn.
  void cancelPendingStart() => _startGeneration++;

  Future<void> _enqueueLifecycle(Future<void> Function() operation) {
    final queued = _lifecycle;
    final result = queued == null
        ? operation()
        : queued.then((_) => operation(),
            onError: (Object _, StackTrace __) => operation());
    void release() {
      if (identical(_lifecycle, result)) _lifecycle = null;
    }

    _lifecycle = result;
    unawaited(result.then<void>((_) => release(),
        onError: (Object _, StackTrace __) => release()));
    // A failed request must not keep the next lifecycle operation from running.
    return result;
  }

  Future<void> start({
    required Stream<ChatMessage> messages,
    required SettingsModel settings,
    int port = 8080,
  }) {
    if (!isValidPort(port)) {
      return Future.error(RangeError.range(port, 0, 65535, 'port'));
    }
    final generation = ++_startGeneration;
    return _enqueueLifecycle(
        () => _start(messages, settings, port, generation));
  }

  Future<void> _start(Stream<ChatMessage> messages, SettingsModel settings,
      int port, int generation) async {
    if (generation != _startGeneration) return;
    await _stop();
    if (generation != _startGeneration) return;
    _settings = settings;
    _chatFilter = ChatFilter(settings);
    _updateGoals(settings);
    _updateTimer(settings);
    _port = port;
    try {
      final library = await templateLibrary;
      if (await library.exists()) await library.writeAgentGuide();
      await library.watch();
      _templateSub = library.changes.listen((change) {
        unawaited(_templateChanged(change));
      });
    } catch (error, stack) {
      // Templates are optional: the built-in pages must start regardless.
      AppLogger.warning('Templates folder unavailable',
          error: error, stackTrace: stack);
    }
    if (generation != _startGeneration) return;
    final wsHandler = webSocketHandler((ws, _) => attachClient(ws));

    final handler = buildOverlayRoutes(wsHandler,
        rulesApi: _rulesApi.call,
        templates: () => templateLibrary,
        galleryLanguage: () => _settings.appLanguageCode,
        mediaLibrary: () => _mediaLibrary ??= _loadMediaLibrary(),
        tierSound: _tierSound,
        customSound: (type) {
          final option = AlertTypeOptions.of(_settings, type);
          return option.sound == 'custom'
              ? AlertSounds.customFile(option.soundPath)
              : null;
        });

    final server =
        await shelf_io.serve(handler, InternetAddress.loopbackIPv4, _port);
    if (generation != _startGeneration) {
      await server.close(force: true);
      return;
    }
    _port = server.port;
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

  void _sendGalleryFields(WebSocketChannel client, GalleryItem item) {
    client.sink.add(jsonEncode({
      'type': 'fields',
      'data': item.defaults(_settings.appLanguageCode),
      'replay': true,
    }));
  }

  void setSettings(SettingsModel settings) {
    final previous = _settings;
    _settings = settings;
    if (!ChatFilter.sameBlockLists(previous, settings)) {
      _chatFilter = ChatFilter(settings);
      _removeBlockedRecords();
    }
    if (previous.appLanguageCode != settings.appLanguageCode) {
      for (final entry in _galleryViews.entries.toList()) {
        try {
          _sendGalleryFields(entry.key, entry.value);
        } catch (_) {
          _removeClient(entry.key);
        }
      }
    }
    _updateGoals(settings);
    _updateTimer(settings);
    if (!mapEquals(previous.clock.toJson(), settings.clock.toJson())) {
      _broadcastEnvelope({
        'type': 'clock',
        'data': settings.clock.payload(DateTime.now().millisecondsSinceEpoch),
      }, view: 'clock');
    }
    if (!mapEquals(previous.ruleCounters, settings.ruleCounters)) {
      _countersChanged();
    }
    if (_nameColorOptions(previous) != _nameColorOptions(settings) &&
        _recentChatMessages.isNotEmpty &&
        _views.containsValue('chat')) {
      _broadcastEnvelope({
        'type': 'nameColors',
        'data': {
          for (final entry in _recentChatMessages.entries)
            '${entry.key}':
                nameColorHex(resolveNameColor(entry.value, settings)),
        },
      }, view: 'chat');
    }
    _broadcastSettings();
  }

  static Object _nameColorOptions(SettingsModel s) => (
        s.nameColorMode,
        s.nameColorSingle,
        s.nameRoleColors,
        s.nameReadability,
        s.bgOpacity,
        s.showBubble,
        s.messageOpacity,
        s.overlayChromaMode,
        s.overlayChromaColor,
        s.overlayShowBubble,
        s.overlayMessageOpacity,
        s.overlayTwitchBubbleAccent,
        s.overlayKickBubbleAccent,
      );

  bool reloadClients() {
    if (_clients.isEmpty) return false;
    _broadcastEnvelope({'type': 'reload'});
    return true;
  }

  bool broadcastTestAlert(String kind) {
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
    return _broadcastEnvelope({'type': 'alert', 'data': _withAlertOption(data)},
        view: 'alerts');
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
    _recentChatMessages.removeWhere((_, message) => event.appliesTo(message));
    _broadcastEnvelope({
      'type': 'moderation',
      'data': OverlayPayloadEncoder.moderation(event),
    });
  }

  void _removeBlockedRecords() {
    final chat = _recentChatMessages.entries
        .where((entry) => _chatFilter.blocksMessage(entry.value))
        .toList();
    for (final MapEntry(key: sequence, value: message) in chat) {
      _recentChatMessages.remove(sequence);
      final event = ChatModerationEvent.message(
        platform: message.platform,
        messageId: message.id,
        youtubeStreamOrientation: message.youtubeStreamOrientation,
      );
      _broadcastEnvelope({
        'type': 'moderation',
        'data': {
          ...OverlayPayloadEncoder.moderation(event),
          'sequence': sequence
        },
      });
    }
    final replySequences = <int>[];
    for (final MapEntry(key: sequence, value: message)
        in _recentChatMessages.entries) {
      final redacted = _chatFilter.redactReply(message);
      if (identical(redacted, message)) continue;
      _recentChatMessages[sequence] = redacted;
      replySequences.add(sequence);
    }
    if (replySequences.isNotEmpty) {
      _broadcastEnvelope({
        'type': 'moderation',
        'data': {'scope': 'reply', 'replySequences': replySequences},
      });
    }
    final provider = _recentProviderEvents.entries
        .where((entry) => _chatFilter.blocksProviderEvent(entry.value))
        .toList();
    for (final MapEntry(key: key, value: event) in provider) {
      _recentProviderEvents.remove(key);
      _broadcastEnvelope({
        'type': 'moderation',
        'data': {
          'platform': event.platform.name,
          'scope': 'providerEvent',
          'messageId': event.id,
          'authorChannelId': '',
          'authorName': '',
          'youtubeStreamOrientation': null,
          'providerEventKind': event.kind.name,
        },
      });
    }
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

  void broadcastGoals(List<Map<String, Object?>> goals, {bool replay = false}) {
    final next = [
      for (final goal in goals) Map<String, Object?>.unmodifiable(goal)
    ];
    if (replay) {
      _goalsTimer?.cancel();
      _goalsTimer = null;
      _goals = next;
      _broadcastEnvelope({'type': 'goals', 'data': next, 'replay': true});
      return;
    }
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
    if (_chatFilter.blocksProviderEvent(event)) return;
    if (_clients.isNotEmpty) {
      final key = (event.platform, event.kind, event.id);
      _recentProviderEvents.remove(key);
      _recentProviderEvents[key] = event;
      if (_recentProviderEvents.length > _recentRecordLimit) {
        _recentProviderEvents.remove(_recentProviderEvents.keys.first);
      }
    }
    _broadcastEnvelope({
      'type': 'providerEvent',
      'data': OverlayPayloadEncoder.providerEvent(event),
    });
    final kind = providerAlertKind(event);
    if (kind == null ||
        !_settings.alertPlatforms.contains(event.platform.name) ||
        _settings.alertDisabledTypes
            .contains(supportAlertType(kind, event.platform, null))) {
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
        'alertType': supportAlertType(kind, event.platform, null),
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

  Future<void> stop() {
    cancelPendingStart();
    return _enqueueLifecycle(_stop);
  }

  Future<void> _stop() async {
    await _templateSub?.cancel();
    _templateSub = null;
    // The Templates tab shares this watcher while the HTTP server is stopped.
    // Library disposal owns watcher shutdown.
    _templates.clear();
    _galleryViews.clear();
    _sessionClients.clear();
    _clearSessionDelivery();
    clearRecentAlerts();
    _lifecycleGeneration++;
    _providerAlertIds.clear();
    _giftGroups.clear();
    await _msgSub?.cancel();
    _msgSub = null;
    _recentChatMessages.clear();
    _recentProviderEvents.clear();
    final clients = List<WebSocketChannel>.from(_clients);
    _clients.clear();
    _views.clear();
    _inactiveSources.clear();
    _alertQueues.clear();
    _emitAlertQueue();
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
    await _alertQueueController.close();
    await _templateLibrary?.dispose();
    await _templateCounts.close();
    await _errorsController.close();
  }

  void _broadcastMessage(ChatMessage incoming) {
    if (_chatFilter.blocksMessage(incoming)) return;
    final msg = _chatFilter.redactReply(incoming);
    if (_clients.isNotEmpty) {
      final sequence = ++_nextChatSequence;
      _recentChatMessages[sequence] = msg;
      if (_recentChatMessages.length > _recentRecordLimit) {
        _recentChatMessages.remove(_recentChatMessages.keys.first);
      }
      _broadcastEnvelope({
        'type': 'message',
        'sequence': sequence,
        'data': {
          ...OverlayPayloadEncoder.message(msg, _settings),
          'sequence': sequence,
        },
      });
    }
    broadcastChatSupport(msg);
  }

  FeaturedMessageDelivery broadcastFeaturedMessage(ChatMessage msg) {
    // SDK subscriptions are local to the page. Preserve event delivery,
    // but use only known renderers to determine the delivery status.
    _sendCustom({'type': 'featured', 'data': _alertData(msg, 'featured')});
    final featured = <WebSocketChannel>{};
    final alerts = <WebSocketChannel>{};
    for (final MapEntry(key: client, value: view) in _views.entries) {
      if (view == 'featured') featured.add(client);
      if (view == 'alerts') alerts.add(client);
    }
    final activeFeatured = featured.difference(_inactiveSources);
    final activeAlerts = alerts.difference(_inactiveSources);
    final recipients = [activeFeatured, activeAlerts, featured, alerts]
        .firstWhere((group) => group.isNotEmpty, orElse: () => {});
    if (recipients.isEmpty) {
      return FeaturedMessageDelivery.noReceiver();
    }
    final id = '$_lifecycleGeneration-${++_nextDelivery}';
    final pending =
        _PendingFeaturedMessage(Set<WebSocketChannel>.from(recipients));
    _featured[id] = pending;
    pending.timer = Timer(featuredAcknowledgementTimeout, () {
      _featured.remove(id)?.finish(FeaturedMessageStatus.sent);
    });
    final envelope = jsonEncode({
      'type': 'alert',
      'data': {
        ..._alertData(msg, 'featured'),
        'deliveryId': id,
        if (featured.contains(recipients.first))
          'items': OverlayPayloadEncoder.messageItems(msg),
      },
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
      pending.recipients.isNotEmpty
          ? FeaturedMessageStatus.sent
          : FeaturedMessageStatus.noReceiver,
      pending.completion.future,
    );
  }

  void removeFeaturedMessage() {
    final envelope = {'type': 'featuredHide'};
    _broadcastEnvelope(envelope, view: 'alerts');
    _broadcastEnvelope(envelope, view: 'featured');
    for (final pending in _featured.values) {
      pending.finish(FeaturedMessageStatus.removed);
    }
    _featured.clear();
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
        if ((view == 'custom' || view == 'gallery') &&
            !_views.containsKey(client)) {
          final id = envelope['template'];
          if (id is! String || !TemplateLibrary.validId(id)) return;
          final gallery = view == 'gallery';
          final item = gallery ? galleryCatalog[id] : null;
          if (gallery && item == null) return;
          _views[client] = 'custom';
          if (item != null) {
            _galleryViews[client] = item;
          } else {
            _templates[client] = id;
          }
          _emitViewCounts();
          client.sink.add(jsonEncode({'type': 'registered', 'view': view}));
          for (final type in const ['timer', 'goals', 'giveaway', 'poll']) {
            _sendSnapshot(client, type);
          }
          _sessionClients[client] = null;
          _sendSession(client, replay: true);
          _sendCounters(client, jsonEncode(_settings.ruleCounters),
              replay: true);
          _sendSnapshot(client, 'queue');
          if (item == null) {
            unawaited(_sendFields(client, id));
          } else {
            _sendGalleryFields(client, item);
          }
          return;
        }
        if (view is String &&
            const {
              'chat',
              'alerts',
              'featured',
              'poll',
              'captions',
              'giveaway',
              'goals',
              'timer',
              'clock',
            }.contains(view) &&
            !_views.containsKey(client)) {
          _views[client] = view;
          if ((view == 'featured' || view == 'alerts') &&
              envelope['active'] == false) {
            _inactiveSources.add(client);
          }
          client.sink.add(jsonEncode({'type': 'registered', 'view': view}));
          if (const {'clock', 'timer', 'goals', 'giveaway', 'poll'}
              .contains(view)) {
            _sendSnapshot(client, view);
          }
          if (view == 'alerts') {
            client.sink.add(jsonEncode(_alertControl(_alertsPaused
                ? AlertQueueOperation.pause
                : AlertQueueOperation.resume)));
            _emitAlertQueue();
          }
          _emitViewCounts();
        }
      } else if (envelope['type'] == 'templateError' &&
          _templates.containsKey(client)) {
        final id = _templates[client]!;
        final now = DateTime.now();
        if (_errors[id] != null &&
            now.difference(_errors[id]!.timestamp) <
                const Duration(seconds: 2)) {
          return;
        }
        String clean(Object? value, int max) => value is String
            ? String.fromCharCodes(value
                .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f]'), '')
                .runes
                .take(max))
            : '';
        final source = clean(envelope['source'], 1024)
            .replaceAll('\\', '/')
            .split('/')
            .last
            .split('?')
            .first
            .split('#')
            .first;
        _errors[id] = TemplateError(clean(envelope['message'], 300), source,
            envelope['line'] is int ? envelope['line'] as int : null, now);
        _errorsController.add(templateErrors);
      } else if (envelope['type'] == 'sourceActivity' &&
          const {'featured', 'alerts'}.contains(_views[client])) {
        switch (envelope['active']) {
          case true:
            _inactiveSources.remove(client);
          case false:
            _inactiveSources.add(client);
        }
      } else if (envelope['type'] == 'alertQueue' &&
          _views[client] == 'alerts') {
        final pending = envelope['pending'];
        final active = envelope['active'];
        if (pending is int &&
            pending >= 0 &&
            active is bool &&
            envelope['paused'] is bool) {
          final status = (pending: pending, active: active);
          if (_alertQueues[client] != status) {
            _alertQueues[client] = status;
            _emitAlertQueue();
          }
        }
      } else if (envelope['type'] == 'featuredRendered') {
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

  /// Sends a support alert without publishing the message on the chat feed.
  void broadcastChatSupport(ChatMessage msg) {
    final kind = messageAlertKind(msg);
    if (kind == null ||
        !_settings.alertPlatforms.contains(msg.platform.name) ||
        _settings.alertDisabledTypes.contains(
            supportAlertType(kind, msg.platform, msg.membershipEventKind))) {
      return;
    }
    if (kind == 'membership' && TwitchGiftGroups.includes(msg)) {
      _giftGroups.add(msg, (first, count) {
        _sendAutomaticAlert({
          ..._alertData(first, 'membership'),
          'giftCount': count,
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
        'alertType':
            supportAlertType(kind, msg.platform, msg.membershipEventKind),
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

  @visibleForTesting
  void attachClient(WebSocketChannel client) {
    _clients.add(client);
    _emitClientCount();
    try {
      client.sink.add(jsonEncode({
        'type': 'settings',
        'data': OverlayPayloadEncoder.settings(_settings),
      }));
    } catch (_) {
      _removeClient(client);
      return;
    }
    client.stream.listen(
      (data) => _handleClientMessage(client, data),
      onError: (Object _) => _removeClient(client),
      onDone: () => _removeClient(client),
    );
  }

  void _sendSnapshot(WebSocketChannel client, String type) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final data = switch (type) {
      'clock' => _settings.clock.payload(now),
      'timer' => SubathonTimer.payload(_settings, now),
      'goals' => _goals,
      'giveaway' => _giveaway,
      'poll' => _poll,
      'queue' => queueState?.call() ??
          _settings.queueState.toOverlayJson(
              _settings.queueOptions.max,
              _settings.queueOptions
                  .commandFor(_settings.appLanguageCode)
                  .toLowerCase()),
      _ => throw ArgumentError.value(type),
    };
    client.sink.add(jsonEncode({'type': type, 'data': data, 'replay': true}));
  }

  bool _broadcastEnvelope(Map<String, dynamic> envelope,
      {String? view, String? requireDeliveryTo}) {
    if (_clients.isEmpty) return false;
    var sent = false;
    final json = jsonEncode(envelope);
    for (final client in List.of(_clients)) {
      final clientView = _views[client];
      if (view != null && clientView != view) continue;
      try {
        client.sink.add(json);
        if (requireDeliveryTo == null || clientView == requireDeliveryTo) {
          sent = true;
        }
      } catch (_) {
        // A failed send means the browser disconnected before its close event.
        _removeClient(client);
      }
    }
    return sent;
  }

  void _emitViewCounts() {
    if (!_templateCounts.isClosed) _templateCounts.add(templateViewCounts);
    if (!_viewCountsController.isClosed) _viewCountsController.add(viewCounts);
  }

  void _emitClientCount() {
    _emitViewCounts();
    if (!_clientCountController.isClosed) {
      _clientCountController.add(_clients.length);
    }
  }

  void _removeClient(WebSocketChannel client) {
    _inactiveSources.remove(client);
    if (_views.remove(client) == 'alerts') {
      _alertQueues.remove(client);
      _emitAlertQueue();
    }
    _templates.remove(client);
    _galleryViews.remove(client);
    _counterClients.remove(client);
    if (_sessionClients.containsKey(client)) {
      _sessionClients.remove(client);
      if (_sessionClients.isEmpty) _clearSessionDelivery();
    }
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

class TemplateError {
  const TemplateError(this.message, this.source, this.line, this.timestamp);
  final String message, source;
  final int? line;
  final DateTime timestamp;
}

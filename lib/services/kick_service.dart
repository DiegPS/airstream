import 'dart:async';

import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/chat/kick_transport.dart';

enum ServiceStatus { idle, connecting, connected, error }

class KickService {
  KickService({
    KickChatTransportFactory? transportFactory,
    Duration connectionTimeout = const Duration(seconds: 15),
  })  : _transportFactory = transportFactory ?? DartKickChatTransport.connect,
        _connectionTimeout = connectionTimeout;

  final KickChatTransportFactory _transportFactory;
  final Duration _connectionTimeout;
  KickChatTransport? _client;
  StreamSubscription<kick.ChatMessage>? _sub;
  StreamSubscription<kick.KickEvent>? _eventSub;
  StreamSubscription<Exception>? _errorSub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();
  final _eventController = StreamController<kick.KickEvent>.broadcast();
  final _seenGiftBatches = <String>{};
  int _generation = 0;

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;
  Stream<kick.KickEvent> get events => _eventController.stream;

  /// Connect using the public Kick channel slug.
  Future<void> connect(String slug) async {
    await _connectWithSlug(slug);
  }

  Future<void> _connectWithSlug(String slug) async {
    await disconnect();
    final generation = ++_generation;
    _emit(ServiceStatus.connecting, null);
    try {
      final client = await _transportFactory().timeout(_connectionTimeout);
      if (generation != _generation) {
        await client.close();
        return;
      }
      _client = client;
      _attachListeners(generation);
      await client.joinBySlug(slug).timeout(_connectionTimeout);
      if (generation != _generation) return;
      _emit(ServiceStatus.connected, null);
    } catch (e, stack) {
      if (generation != _generation) return;
      await _sub?.cancel();
      _sub = null;
      await _errorSub?.cancel();
      _errorSub = null;
      await _eventSub?.cancel();
      _eventSub = null;
      await _client?.close();
      _client = null;
      AppLogger.error('Kick connection failed', error: e, stackTrace: stack);
      _emit(ServiceStatus.error, e.toString());
    }
  }

  void _attachListeners(int generation) {
    _sub = _client!.messages.listen(
      (msg) {
        if (generation != _generation) return;
        try {
          if (!_controller.isClosed) {
            _controller.add(_convertMessage(msg));
          }
        } catch (error, stack) {
          AppLogger.warning(
            'Kick returned a malformed chat message',
            error: error,
            stackTrace: stack,
          );
          _emit(ServiceStatus.error, 'Invalid Kick chat response.');
        }
      },
      onError: (Object e, StackTrace stack) {
        if (generation != _generation) return;
        AppLogger.warning(
          'Kick message stream disconnected',
          error: e,
          stackTrace: stack,
        );
        _emit(ServiceStatus.error, e.toString());
      },
    );
    _errorSub = _client!.errors.listen(
      (e) {
        if (generation != _generation) return;
        AppLogger.warning('Kick client reported an error', error: e);
        _emit(ServiceStatus.error, e.toString());
      },
    );
    _eventSub = _client!.events.listen((event) {
      if (generation != _generation) return;
      if (!_eventController.isClosed) _eventController.add(event);
      final message = _convertEvent(event);
      if (message != null && !_controller.isClosed) _controller.add(message);
    });
  }

  Future<void> disconnect() async {
    _generation++;
    _seenGiftBatches.clear();
    await _sub?.cancel();
    _sub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _client?.close();
    _client = null;
    _emit(ServiceStatus.idle, null);
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
    await _statusController.close();
    await _eventController.close();
  }

  void _emit(ServiceStatus status, String? error) {
    if (!_statusController.isClosed) _statusController.add((status, error));
  }

  ChatMessage _convertMessage(kick.ChatMessage msg) {
    final items = msg.parts.map((p) {
      if (p.isEmote) {
        return MessageItem.emoji(
            EmojiItem(url: p.emote!.url, alt: p.emote!.name));
      }
      return MessageItem.text(p.text);
    }).toList();

    final identity = msg.sender.identity;
    final authorBadges = identity.badges
        .map((badge) => AuthorBadge(
              label: badge.text.trim().isEmpty ? badge.type : badge.text,
              kind: badge.type.toLowerCase(),
            ))
        .followedBy(identity.badgesV2.map((badge) => AuthorBadge(
              imageUrl: badge.imageUrl.isEmpty ? null : badge.imageUrl,
              label: badge.name,
              kind: badge.name.toLowerCase(),
            )))
        .toList(growable: false);

    final celebration = msg.metadata.celebration;
    final isRenewal = msg.type == 'celebration' &&
        celebration?.type == 'subscription_renewed';
    return ChatMessage(
      platform: Platform.kick,
      id: msg.id,
      author: ChatAuthor(
        name: msg.sender.username,
        avatarUrl: msg.sender.profilePictureUrl.isEmpty
            ? null
            : msg.sender.profilePictureUrl,
        channelId: msg.sender.slug,
        color: msg.sender.identity.color.isNotEmpty
            ? msg.sender.identity.color
            : null,
        badges: authorBadges,
      ),
      items: items,
      isMembership: identity.isSubscriber || isRenewal,
      isMembershipEvent: isRenewal,
      membershipEventKind:
          isRenewal ? MembershipEventKind.resubscription : null,
      membershipMonths: isRenewal ? celebration!.totalMonths : null,
      isOwner: identity.isBroadcaster,
      isModerator: identity.isModerator,
      isVip: identity.isVip,
      isVerified: identity.isVerified,
      timestamp: msg.createdAt,
    );
  }

  ChatMessage? _convertEvent(kick.KickEvent event) {
    if (event is kick.KickSubscriptionEvent) {
      if (event.months > 1) return null;
      return ChatMessage(
        platform: Platform.kick,
        id: 'subscription:${event.username}:${event.months}',
        author: ChatAuthor(name: event.username, channelId: event.username),
        items: [MessageItem.text(event.customMessage)],
        isMembership: true,
        isMembershipEvent: true,
        membershipEventKind: event.months > 1
            ? MembershipEventKind.resubscription
            : MembershipEventKind.subscription,
        membershipMonths: event.months,
        timestamp: DateTime.now(),
      );
    }
    if (event is kick.KickGiftedSubscriptionsEvent) {
      final correlationId = event.chunk?.correlationId ?? '';
      if (correlationId.isNotEmpty && !_seenGiftBatches.add(correlationId)) {
        return null;
      }
      return ChatMessage(
        platform: Platform.kick,
        id: correlationId.isEmpty
            ? 'gift:${DateTime.now().microsecondsSinceEpoch}'
            : 'gift:$correlationId',
        author: ChatAuthor(
          name: event.gifterUsername,
          channelId: event.gifterUsername,
        ),
        items: const [],
        isMembership: true,
        isMembershipEvent: true,
        membershipEventKind: MembershipEventKind.gift,
        membershipGiftCount: event.giftedTotal,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }
}

import 'dart:async';

import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/services/app_logger.dart';

enum ServiceStatus { idle, connecting, connected, error }

class KickUserRoles {
  const KickUserRoles({
    required this.isOwner,
    required this.isModerator,
    required this.isSubscriber,
    required this.isVip,
  });

  factory KickUserRoles.fromBadges(Iterable<kick.Badge> badges) {
    bool hasRole(Set<String> roles) => badges.any((badge) {
          final type = badge.type.toLowerCase().replaceAll('-', '_');
          final text = badge.text.toLowerCase().replaceAll('-', '_');
          return roles
              .any((role) => type.contains(role) || text.contains(role));
        });
    return KickUserRoles(
      isOwner: hasRole(
          const {'broadcaster', 'channel_owner', 'channel owner', 'owner'}),
      isModerator: hasRole(const {'moderator', 'mod'}),
      isSubscriber: hasRole(const {'subscriber', 'sub', 'founder'}),
      isVip: hasRole(const {'vip'}),
    );
  }

  final bool isOwner;
  final bool isModerator;
  final bool isSubscriber;
  final bool isVip;
}

class KickService {
  kick.KickClient? _client;
  StreamSubscription? _sub;
  StreamSubscription? _errorSub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _statusController =
      StreamController<(ServiceStatus, String?)>.broadcast();
  int _generation = 0;

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;

  /// Connect using the public Kick channel slug.
  Future<void> connect(String slug) async {
    await _connectWithSlug(slug);
  }

  Future<void> _connectWithSlug(String slug) async {
    await disconnect();
    final generation = ++_generation;
    _emit(ServiceStatus.connecting, null);
    try {
      final client = await kick.KickClient.connect();
      if (generation != _generation) {
        await client.close();
        return;
      }
      _client = client;
      _attachListeners(generation);
      await client.joinBySlug(slug);
      if (generation != _generation) return;
      _emit(ServiceStatus.connected, null);
    } catch (e, stack) {
      if (generation != _generation) return;
      await _sub?.cancel();
      _sub = null;
      await _errorSub?.cancel();
      _errorSub = null;
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
        if (!_controller.isClosed) _controller.add(_convertMessage(msg));
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
  }

  Future<void> disconnect() async {
    _generation++;
    await _sub?.cancel();
    _sub = null;
    await _errorSub?.cancel();
    _errorSub = null;
    await _client?.close();
    _client = null;
    _emit(ServiceStatus.idle, null);
  }

  void dispose() {
    disconnect();
    _controller.close();
    _statusController.close();
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

    final badges = msg.sender.identity.badges;
    final authorBadges = badges
        .map((badge) => AuthorBadge(
              label: badge.text.trim().isEmpty ? badge.type : badge.text,
              kind: badge.type.toLowerCase(),
            ))
        .toList(growable: false);
    final roles = KickUserRoles.fromBadges(badges);

    return ChatMessage(
      platform: Platform.kick,
      id: msg.id,
      author: ChatAuthor(
        name: msg.sender.username,
        channelId: msg.sender.slug,
        color: msg.sender.identity.color.isNotEmpty
            ? msg.sender.identity.color
            : null,
        badges: authorBadges,
      ),
      items: items,
      isMembership: roles.isSubscriber,
      isOwner: roles.isOwner,
      isModerator: roles.isModerator,
      isVip: roles.isVip,
      timestamp: msg.createdAt,
    );
  }
}

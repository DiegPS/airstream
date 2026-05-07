import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dart_kick_chat/dart_kick_chat.dart' as kick;
import 'package:airchat_flutter/models/chat_message.dart';

enum ServiceStatus { idle, connecting, connected, error }

class KickService {
  kick.KickClient? _client;
  StreamSubscription? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<(ServiceStatus, String?)>.broadcast();

  Stream<ChatMessage> get messages => _controller.stream;
  Stream<(ServiceStatus, String?)> get statusStream => _statusController.stream;

  /// Connect using [slug] to resolve the chatroom ID via HTTP.
  Future<void> connect(String slug) async {
    await _connectWithSlug(slug);
  }

  /// Connect directly with a known [chatroomId], skipping the HTTP lookup.
  Future<void> connectById(int chatroomId) async {
    await disconnect();
    _emit(ServiceStatus.connecting, null);
    try {
      _client = await kick.KickClient.connect();
      _attachListeners();
      _client!.joinById(chatroomId);
      _emit(ServiceStatus.connected, null);
    } catch (e) {
      debugPrint('KickService.connectById failed: $e');
      _emit(ServiceStatus.error, e.toString());
    }
  }

  Future<void> _connectWithSlug(String slug) async {
    await disconnect();
    _emit(ServiceStatus.connecting, null);
    try {
      _client = await kick.KickClient.connect();
      _attachListeners();
      await _client!.joinBySlug(slug);
      _emit(ServiceStatus.connected, null);
    } catch (e) {
      debugPrint('KickService.connect failed: $e');
      _emit(ServiceStatus.error, e.toString());
    }
  }

  void _attachListeners() {
    _sub = _client!.messages.listen(
      (msg) {
        if (!_controller.isClosed) _controller.add(_convertMessage(msg));
      },
      onError: (e) => debugPrint('KickClient stream error: $e'),
    );
    _client!.errors.listen((e) => debugPrint('KickClient error: $e'));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
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
        return MessageItem.emoji(EmojiItem(url: p.emote!.url, alt: p.emote!.name));
      }
      return MessageItem.text(p.text);
    }).toList();

    final badges = msg.sender.identity.badges;
    AuthorBadge? badge;
    if (badges.isNotEmpty) {
      badge = AuthorBadge(label: badges.first.text);
    }

    return ChatMessage(
      platform: Platform.kick,
      id: msg.id,
      author: ChatAuthor(
        name: msg.sender.username,
        channelId: msg.sender.slug,
        color: msg.sender.identity.color.isNotEmpty
            ? msg.sender.identity.color
            : null,
        badge: badge,
      ),
      items: items,
      timestamp: msg.createdAt,
    );
  }
}

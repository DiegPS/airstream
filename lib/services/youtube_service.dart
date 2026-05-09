import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:airchat_flutter/models/chat_message.dart';

/// Wraps dart_youtube_chat.LiveChat and converts items to [ChatMessage].
class YouTubeService {
  yt.LiveChat? _chat;
  StreamSubscription? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messages => _controller.stream;

  Future<void> connect({
    String handle = '',
    String liveId = '',
    String channelId = '',
  }) async {
    await disconnect();

    final normalized = _normalizeYoutubeId(
      handle: handle,
      liveId: liveId,
      channelId: channelId,
    );

    final ytId = yt.YoutubeId(
      handle: normalized.handle,
      liveId: normalized.liveId,
      channelId: normalized.channelId,
    );

    _chat = yt.LiveChat(id: ytId);
    _sub = _chat!.messages.listen(
      (item) {
        final msg = _convertItem(item);
        if (msg != null && !_controller.isClosed) _controller.add(msg);
      },
      onError: (_) {},
    );
    await _chat!.start();
  }

  ({String handle, String liveId, String channelId}) _normalizeYoutubeId({
    required String handle,
    required String liveId,
    required String channelId,
  }) {
    final explicitLiveId = liveId.trim();
    if (explicitLiveId.isNotEmpty) {
      return (handle: '', liveId: explicitLiveId, channelId: '');
    }

    final explicitChannelId = channelId.trim();
    if (explicitChannelId.isNotEmpty) {
      return (handle: '', liveId: '', channelId: explicitChannelId);
    }

    var value = handle.trim();
    if (value.isEmpty) return (handle: '', liveId: '', channelId: '');

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final videoId = uri.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return (handle: '', liveId: videoId, channelId: '');
      }

      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (uri.host.contains('youtu.be') && segments.isNotEmpty) {
        return (handle: '', liveId: segments.first, channelId: '');
      }
      if (segments.length >= 2 && segments.first == 'channel') {
        return (handle: '', liveId: '', channelId: segments[1]);
      }
      if (segments.isNotEmpty && segments.first.startsWith('@')) {
        return (handle: segments.first, liveId: '', channelId: '');
      }
    }

    value = value
        .replaceFirst(RegExp(r'^https?://(www\.)?youtube\.com/'), '')
        .replaceFirst(RegExp(r'^https?://youtu\.be/'), '');
    if (value.startsWith('watch?')) {
      final parsed = Uri.tryParse('https://youtube.com/$value');
      final videoId = parsed?.queryParameters['v'];
      if (videoId != null && videoId.isNotEmpty) {
        return (handle: '', liveId: videoId, channelId: '');
      }
    }
    if (_looksLikeChannelId(value)) {
      return (handle: '', liveId: '', channelId: value);
    }
    if (value.startsWith('@')) {
      value = value.split('/').first;
    }

    return (handle: value, liveId: '', channelId: '');
  }

  bool _looksLikeChannelId(String value) =>
      RegExp(r'^UC[a-zA-Z0-9_-]{20,}$').hasMatch(value);

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _chat?.stop();
    _chat = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }

  ChatMessage? _convertItem(yt.ChatItem item) {
    final items = item.message.map((m) {
      if (m.isEmoji) {
        return MessageItem.emoji(EmojiItem(
          url: m.emoji!.url,
          alt: m.emoji!.emojiText,
        ));
      }
      return MessageItem.text(m.text);
    }).toList();

    SuperChat? superChat;
    if (item.superChat != null) {
      final sc = item.superChat!;
      superChat = SuperChat(
        amount: sc.amount,
        color: sc.color,
        stickerUrl: sc.sticker?.url,
      );
    }

    AuthorBadge? badge;
    if (item.author.badge != null) {
      badge = AuthorBadge(
        imageUrl: item.author.badge!.thumbnail.url,
        label: item.author.badge!.label,
      );
    }

    return ChatMessage(
      platform: Platform.youtube,
      id: item.id,
      author: ChatAuthor(
        name: item.author.name,
        avatarUrl: item.author.thumbnail?.url,
        channelId: item.author.channelId,
        badge: badge,
      ),
      items: items,
      superChat: superChat,
      isMembership: item.isMembership,
      isOwner: item.isOwner,
      isModerator: item.isModerator,
      isVerified: item.isVerified,
      timestamp: item.timestamp,
    );
  }
}

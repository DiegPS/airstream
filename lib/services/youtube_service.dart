import 'dart:async';

import 'package:dart_youtube_chat/dart_youtube_chat.dart' as yt;
import 'package:airchat_flutter/models/chat_message.dart';

/// Wraps dart_youtube_chat.LiveChat and converts items to [ChatMessage].
class YouTubeService {
  yt.LiveChat? _chat;
  StreamSubscription? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();

  Stream<ChatMessage> get messages => _controller.stream;

  Future<void> connect({String handle = '', String liveId = '', String channelId = ''}) async {
    await disconnect();

    final ytId = yt.YoutubeId(
      handle: handle,
      liveId: liveId,
      channelId: channelId,
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

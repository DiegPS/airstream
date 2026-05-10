/// Unified chat message model used across YouTube, Twitch, and Kick.
library;

enum Platform { youtube, twitch, kick }

class MessageItem {
  final String text;
  final EmojiItem? emoji;

  const MessageItem.text(this.text) : emoji = null;
  const MessageItem.emoji(EmojiItem this.emoji) : text = '';

  bool get isEmoji => emoji != null;
}

class EmojiItem {
  final String url;
  final String alt;
  final bool isAnimated; // GIF or animated WebP

  const EmojiItem(
      {required this.url, required this.alt, this.isAnimated = false});
}

class AuthorBadge {
  final String? imageUrl;
  final String label;

  const AuthorBadge({this.imageUrl, required this.label});
}

class ChatAuthor {
  final String name;
  final String? avatarUrl;
  final String channelId;
  final String? color; // hex #RRGGBB, used by Twitch/Kick
  final AuthorBadge? badge;

  const ChatAuthor({
    required this.name,
    this.avatarUrl,
    required this.channelId,
    this.color,
    this.badge,
  });
}

class SuperChat {
  final String amount;
  final String color; // #RRGGBB
  final String? stickerUrl;

  const SuperChat({required this.amount, required this.color, this.stickerUrl});
}

class ChatMessage {
  final Platform platform;
  final String id;
  final ChatAuthor author;
  final List<MessageItem> items;
  final SuperChat? superChat;
  final bool isMembership;
  final bool isOwner;
  final bool isModerator;
  final bool isVerified;
  final DateTime timestamp;

  const ChatMessage({
    required this.platform,
    required this.id,
    required this.author,
    required this.items,
    this.superChat,
    this.isMembership = false,
    this.isOwner = false,
    this.isModerator = false,
    this.isVerified = false,
    required this.timestamp,
  });

  String get plainText =>
      items.map((i) => i.isEmoji ? i.emoji!.alt : i.text).join();

  String get normalizedPlainText =>
      plainText.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String get dedupeIdKey {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return '';
    return '${platform.name}:id:$normalizedId';
  }

  String get dedupeContentKey {
    final normalizedAuthor = author.channelId.trim().isNotEmpty
        ? author.channelId.trim().toLowerCase()
        : author.name.trim().toLowerCase();
    final secondBucket = timestamp.toUtc().millisecondsSinceEpoch ~/ 1000;
    return '${platform.name}:content:$normalizedAuthor:$normalizedPlainText:$secondBucket';
  }

  String get dedupeKey =>
      dedupeIdKey.isNotEmpty ? dedupeIdKey : dedupeContentKey;
}

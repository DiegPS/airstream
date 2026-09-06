/// Unified chat message model used across YouTube, Twitch, and Kick.
library;

enum Platform { youtube, twitch, kick }

enum YoutubeStreamOrientation { horizontal, vertical }

enum MembershipEventKind { subscription, resubscription, gift }

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
  final bool isCustom;

  const EmojiItem({
    required this.url,
    required this.alt,
    this.isAnimated = false,
    this.isCustom = false,
  });
}

class AuthorBadge {
  final String? imageUrl;
  final String label;
  final String? kind;

  const AuthorBadge({this.imageUrl, required this.label, this.kind});
}

class ChatAuthor {
  final String name;
  final String? avatarUrl;
  final String channelId;
  final String? color; // hex #RRGGBB, used by Twitch/Kick
  final AuthorBadge? badge;
  final List<AuthorBadge> badges;

  const ChatAuthor({
    required this.name,
    this.avatarUrl,
    required this.channelId,
    this.color,
    this.badge,
    this.badges = const [],
  });

  List<AuthorBadge> get allBadges => [
        if (badge != null) badge!,
        ...badges,
      ];
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
  final bool isMembershipEvent;
  final bool isOwner;
  final bool isModerator;
  final bool isVip;
  final bool isVerified;
  final YoutubeStreamOrientation? youtubeStreamOrientation;
  final MembershipEventKind? membershipEventKind;
  final int? membershipMonths;
  final DateTime timestamp;

  const ChatMessage({
    required this.platform,
    required this.id,
    required this.author,
    required this.items,
    this.superChat,
    this.isMembership = false,
    this.isMembershipEvent = false,
    this.isOwner = false,
    this.isModerator = false,
    this.isVip = false,
    this.isVerified = false,
    this.youtubeStreamOrientation,
    this.membershipEventKind,
    this.membershipMonths,
    required this.timestamp,
  });

  String get plainText =>
      items.map((i) => i.isEmoji ? i.emoji!.alt : i.text).join();

  String get ttsText => items.map((i) => i.isEmoji ? '' : i.text).join();

  String get normalizedPlainText =>
      plainText.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String get dedupeIdKey {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return '';
    final stream = youtubeStreamOrientation?.name ?? 'default';
    return '${platform.name}:$stream:id:$normalizedId';
  }

  String get dedupeContentKey {
    final normalizedAuthor = author.channelId.trim().isNotEmpty
        ? author.channelId.trim().toLowerCase()
        : author.name.trim().toLowerCase();
    final secondBucket = timestamp.toUtc().millisecondsSinceEpoch ~/ 1000;
    final stream = youtubeStreamOrientation?.name ?? 'default';
    return '${platform.name}:$stream:content:$normalizedAuthor:$normalizedPlainText:$secondBucket';
  }

  String get dedupeKey =>
      dedupeIdKey.isNotEmpty ? dedupeIdKey : dedupeContentKey;
}

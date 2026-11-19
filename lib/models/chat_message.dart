/// Unified chat message model used across YouTube, Twitch, and Kick.
library;

enum Platform { youtube, twitch, kick }

enum YoutubeStreamOrientation { horizontal, vertical }

enum MembershipEventKind { subscription, resubscription, gift }

enum ChatModerationScope { message, author, platform }

class ChatReplyContext {
  const ChatReplyContext({
    required this.messageId,
    this.authorId = '',
    this.authorName = '',
    this.text = '',
  });

  final String messageId;
  final String authorId;
  final String authorName;
  final String text;

  ChatReplyContext withoutText() => ChatReplyContext(
        messageId: messageId,
        authorId: authorId,
        authorName: authorName,
      );
}

class ChatSharedSource {
  const ChatSharedSource({
    this.messageId = '',
    this.channelId = '',
    this.messageType = '',
    this.badges = const {},
    this.badgeInfo = const {},
    this.sourceOnly = false,
  });

  final String messageId;
  final String channelId;
  final String messageType;
  final Map<String, String> badges;
  final Map<String, String> badgeInfo;
  final bool sourceOnly;
}

class ChatModerationEvent {
  const ChatModerationEvent.message({
    required this.platform,
    required this.messageId,
    this.youtubeStreamOrientation,
  })  : scope = ChatModerationScope.message,
        authorChannelId = '',
        authorName = '';

  const ChatModerationEvent.author({
    required this.platform,
    required this.authorChannelId,
    this.authorName = '',
    this.youtubeStreamOrientation,
  })  : scope = ChatModerationScope.author,
        messageId = '';

  const ChatModerationEvent.platform({
    required this.platform,
    this.youtubeStreamOrientation,
  })  : scope = ChatModerationScope.platform,
        messageId = '',
        authorChannelId = '',
        authorName = '';

  final Platform platform;
  final ChatModerationScope scope;
  final String messageId;
  final String authorChannelId;

  /// Display name of the moderated author, for providers whose system
  /// messages (such as Kick subscriptions) only carry the name.
  final String authorName;
  final YoutubeStreamOrientation? youtubeStreamOrientation;

  /// Whether this event removes [message].
  bool appliesTo(ChatMessage message) => matchesTarget(
        targetPlatform: message.platform,
        orientation: message.youtubeStreamOrientation,
        id: message.id,
        authorId: message.author.channelId,
        name: message.author.name,
      );

  ChatMessage redactReply(ChatMessage message) {
    final reply = message.reply;
    if (reply == null ||
        reply.text.isEmpty ||
        !matchesTarget(
          targetPlatform: message.platform,
          orientation: message.youtubeStreamOrientation,
          id: reply.messageId,
          authorId: reply.authorId,
          name: reply.authorName,
        )) {
      return message;
    }
    return message.copyWith(reply: reply.withoutText());
  }

  bool matchesTarget({
    required Platform? targetPlatform,
    required YoutubeStreamOrientation? orientation,
    required String id,
    required String authorId,
    required String name,
  }) {
    if (targetPlatform != platform || orientation != youtubeStreamOrientation) {
      return false;
    }
    return switch (scope) {
      ChatModerationScope.message => id == messageId,
      ChatModerationScope.author => _matchesAuthor(authorId, name),
      ChatModerationScope.platform => true,
    };
  }

  /// Whether [author] is the author this event moderates.
  bool matchesAuthor(ChatAuthor author) =>
      _matchesAuthor(author.channelId, author.name);

  bool _matchesAuthor(String id, String name) {
    if (authorChannelId.isNotEmpty && id == authorChannelId) {
      return true;
    }
    return authorName.isNotEmpty &&
        name.toLowerCase() == authorName.toLowerCase();
  }
}

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
  final bool isZeroWidth;

  const EmojiItem({
    required this.url,
    required this.alt,
    this.isAnimated = false,
    this.isCustom = false,
    this.isZeroWidth = false,
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

  /// The provider's account ID. May be empty when [channelId] holds a handle.
  final String accountId;
  final String? color; // hex #RRGGBB, used by Twitch/Kick
  final AuthorBadge? badge;
  final List<AuthorBadge> badges;

  const ChatAuthor({
    required this.name,
    this.avatarUrl,
    required this.channelId,
    String? accountId,
    this.color,
    this.badge,
    this.badges = const [],
  }) : accountId = accountId ?? channelId;

  List<AuthorBadge> get allBadges => [
        if (badge != null) badge!,
        ...badges,
      ];

  ChatAuthor copyWith({String? avatarUrl}) => ChatAuthor(
        name: name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        channelId: channelId,
        accountId: accountId,
        color: color,
        badge: badge,
        badges: badges,
      );
}

class ChatAuthorUpdate {
  const ChatAuthorUpdate({
    required this.platform,
    required this.authorName,
    required this.avatarUrl,
    this.authorId = '',
  });

  final Platform platform;
  final String authorName;
  final String authorId;
  final String avatarUrl;
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
  final int? membershipGiftCount;
  final DateTime timestamp;
  final ChatReplyContext? reply;
  final ChatSharedSource? sharedSource;
  final bool isAction;
  final String providerRoomId;
  final bool isFirstMessage;

  /// The author's first message since the chat started (any platform).
  /// Unlike [isFirstMessage], which is Twitch's first message in the channel
  /// ever, this is computed by Airstream for the current session.
  final bool isFirstInSession;
  final bool isReturningChatter;
  final String? rewardId;

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
    this.membershipGiftCount,
    required this.timestamp,
    this.reply,
    this.sharedSource,
    this.isAction = false,
    this.providerRoomId = '',
    this.isFirstMessage = false,
    this.isFirstInSession = false,
    this.isReturningChatter = false,
    this.rewardId,
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

  ChatMessage copyWith(
          {ChatAuthor? author,
          List<MessageItem>? items,
          ChatReplyContext? reply,
          bool? isFirstInSession}) =>
      ChatMessage(
        platform: platform,
        id: id,
        author: author ?? this.author,
        items: items ?? this.items,
        superChat: superChat,
        isMembership: isMembership,
        isMembershipEvent: isMembershipEvent,
        isOwner: isOwner,
        isModerator: isModerator,
        isVip: isVip,
        isVerified: isVerified,
        youtubeStreamOrientation: youtubeStreamOrientation,
        membershipEventKind: membershipEventKind,
        membershipMonths: membershipMonths,
        membershipGiftCount: membershipGiftCount,
        timestamp: timestamp,
        reply: reply ?? this.reply,
        sharedSource: sharedSource,
        isAction: isAction,
        providerRoomId: providerRoomId,
        isFirstMessage: isFirstMessage,
        isFirstInSession: isFirstInSession ?? this.isFirstInSession,
        isReturningChatter: isReturningChatter,
        rewardId: rewardId,
      );
}

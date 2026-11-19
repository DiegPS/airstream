import 'chat_message.dart';

enum ChatProviderEventKind {
  raid,
  unraid,
  pinnedMessage,
  unpinnedMessage,
  poll,
  reward,
  support,
  host,
  goal,
  notice,
  modiversary,
  viewerMilestone,
  watchStreak,
  sharedChat,
  roomState,
  streamOnline,
  streamOffline,
  unknown,
}

/// Lossless, provider-neutral event available to AirStream features.
class ChatProviderEvent {
  const ChatProviderEvent({
    required this.platform,
    required this.kind,
    required this.id,
    required this.timestamp,
    this.authorName = '',
    this.authorChannelId = '',
    String? authorAccountId,
    this.text = '',
    this.viewerName,
    this.viewerText,
    this.count,
    this.data = const {},
  }) : authorAccountId = authorAccountId ?? authorChannelId;

  final Platform platform;
  final ChatProviderEventKind kind;
  final String id;
  final DateTime timestamp;
  final String authorName;
  final String authorChannelId;

  /// The provider's account ID. May be empty when [authorChannelId] is a handle.
  final String authorAccountId;
  final String text;

  /// Moderation inputs when they differ from the displayed author or text.
  final String? viewerName;
  final String? viewerText;
  final int? count;
  final Map<String, Object?> data;
}

class PlatformLiveMetadata {
  const PlatformLiveMetadata({
    required this.platform,
    required this.channel,
    required this.isLive,
    required this.viewerCount,
    required this.title,
    required this.updatedAt,
  });

  final Platform platform;
  final String channel;
  final bool isLive;
  final int? viewerCount;
  final String title;
  final DateTime updatedAt;
}

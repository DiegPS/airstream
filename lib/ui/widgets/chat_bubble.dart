import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/ui/widgets/author_avatar.dart';
import 'package:airchat_flutter/ui/widgets/platform_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatBubble extends ConsumerWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final bubbleOpacity = s.messageOpacity.clamp(0.0, 1.0);
    final isSuperChat = message.superChat != null;
    final isMembershipEvent = message.isMembership && message.items.isEmpty;
    final bubbleColor = _bubbleColor(
      showBubble: s.showBubble,
      platform: message.platform,
      bubbleOpacity: bubbleOpacity,
      superChatColor:
          isSuperChat ? _parseColor(message.superChat!.color) : null,
      isMembershipEvent: isMembershipEvent,
    );

    final bubbleBorder = _bubbleBorder(
      showBubble: s.showBubble,
      bubbleOpacity: bubbleOpacity,
      isSuperChat: isSuperChat,
      superChatColor:
          isSuperChat ? _parseColor(message.superChat!.color) : null,
    );

    final shadow = s.showBubble && s.showBubbleShadow
        ? const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];

    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.82;
    final showPlatformBadge = s.showPlatformIcons;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: s.messageGap / 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Container(
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(s.borderRadius),
              border: bubbleBorder,
              boxShadow: shadow,
            ),
            padding: s.showBubble
                ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
                : const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.showAvatars) ...[
                  AuthorAvatar(
                    name: message.author.name,
                    platform: message.platform,
                    url: message.author.avatarUrl,
                    color: message.author.color,
                    showPlatformBadge: showPlatformBadge,
                  ),
                  const SizedBox(width: 14),
                ],
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AuthorRow(
                        message: message,
                        fontSize: s.fontSize,
                        showPlatformIcons: s.showPlatformIcons,
                        showBadges: s.showBadges,
                        showAvatars: s.showAvatars,
                        showTimestamp: s.showTimestamp,
                      ),
                      if (message.items.isNotEmpty ||
                          isMembershipEvent ||
                          message.superChat?.stickerUrl != null)
                        const SizedBox(height: 4),
                      if (message.items.isNotEmpty)
                        _MessageContent(
                          items: message.items,
                          fontSize: s.fontSize,
                        ),
                      if (isMembershipEvent)
                        Padding(
                          padding: EdgeInsets.only(
                              top: message.items.isNotEmpty ? 6 : 0),
                          child: Text(
                            _membershipFlair(
                                message.platform, message.author.badge?.label),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: s.fontSize * 0.92,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (message.superChat?.stickerUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: message.superChat!.stickerUrl!,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _bubbleColor({
    required bool showBubble,
    required Platform platform,
    required double bubbleOpacity,
    required bool isMembershipEvent,
    Color? superChatColor,
  }) {
    if (!showBubble || bubbleOpacity <= 0) return Colors.transparent;

    Color baseColor = const Color(0xFF000000);
    if (isMembershipEvent) {
      baseColor = const Color(0xFF0F9D58);
    } else if (superChatColor != null) {
      baseColor = Color.alphaBlend(
        superChatColor.withValues(alpha: 0.3),
        const Color(0xFF111111),
      );
    } else {
      baseColor = switch (platform) {
        Platform.youtube => const Color(0xFF111111),
        Platform.twitch => const Color(0xFF17111F),
        Platform.kick => const Color(0xFF10160D),
      };
    }

    return baseColor.withAlpha((255 * bubbleOpacity).round().clamp(0, 255));
  }

  static Border? _bubbleBorder({
    required bool showBubble,
    required double bubbleOpacity,
    required bool isSuperChat,
    required Color? superChatColor,
  }) {
    if (!showBubble) return null;

    final baseSide = BorderSide(
      color: Colors.white.withValues(alpha: 0.1 * bubbleOpacity),
    );

    if (isSuperChat && superChatColor != null) {
      return Border(
        top: baseSide,
        right: baseSide,
        left: baseSide,
        bottom: BorderSide(
          color: superChatColor
              .withAlpha((255 * bubbleOpacity).round().clamp(0, 255)),
          width: 4,
        ),
      );
    }

    return Border.fromBorderSide(baseSide);
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  static String _membershipFlair(Platform platform, String? customLabel) {
    if (customLabel != null && customLabel.trim().isNotEmpty) {
      return customLabel.trim();
    }

    return switch (platform) {
      Platform.twitch => 'New Subscriber!',
      Platform.kick => 'Subscription Update',
      Platform.youtube => 'Membership Update',
    };
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.message,
    required this.fontSize,
    required this.showPlatformIcons,
    required this.showBadges,
    required this.showAvatars,
    required this.showTimestamp,
  });

  final ChatMessage message;
  final double fontSize;
  final bool showPlatformIcons;
  final bool showBadges;
  final bool showAvatars;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final isMembershipEvent = message.isMembership && message.items.isEmpty;
    final authorColor = message.author.color != null
        ? ChatBubble._parseColor(message.author.color!)
        : switch (message.platform) {
            Platform.twitch => const Color(0xFFAF84FF),
            Platform.kick => const Color(0xFFB7FF8D),
            Platform.youtube => Colors.white,
          };

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        if (showPlatformIcons && !showAvatars)
          PlatformBadge(
            platform: message.platform,
            mode: PlatformBadgeMode.inline,
          ),
        Text(
          message.author.name,
          style: TextStyle(
            color: message.isModerator ? const Color(0xFF7EA4FF) : authorColor,
            fontSize: fontSize * 0.95,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (showBadges && message.isOwner)
          const _LabelBadge(
            text: 'OWNER',
            backgroundColor: Color(0xFFFFD700),
            foregroundColor: Color(0xFF111111),
          ),
        if (showBadges && message.isModerator)
          const _LabelBadge(
            text: 'MOD',
            backgroundColor: Color(0xFF5E84F1),
          ),
        if (showBadges && message.isMembership && !isMembershipEvent)
          _LabelBadge(
            text: _membershipBadgeLabel(message.platform),
            backgroundColor: _membershipBadgeColor(message.platform),
            foregroundColor: message.platform == Platform.kick
                ? const Color(0xFF101010)
                : Colors.white,
          ),
        if (showBadges && message.superChat != null)
          _LabelBadge(
            text: message.superChat!.amount,
            backgroundColor: const Color(0xFF0F9D58),
          ),
        if (showBadges && message.author.badge?.imageUrl != null)
          _CustomImageBadge(imageUrl: message.author.badge!.imageUrl!),
        if (showTimestamp)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: fontSize * 0.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  static String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _membershipBadgeLabel(Platform platform) {
    return switch (platform) {
      Platform.youtube => 'MEMBER',
      Platform.twitch => 'SUB',
      Platform.kick => 'SUB',
    };
  }

  static Color _membershipBadgeColor(Platform platform) {
    return switch (platform) {
      Platform.youtube => const Color(0xFF0F9D58),
      Platform.twitch => const Color(0xFF9146FF),
      Platform.kick => const Color(0xFF53FC18),
    };
  }
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({
    required this.text,
    required this.backgroundColor,
    this.foregroundColor = Colors.white,
  });

  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          height: 1,
        ),
      ),
    );
  }
}

class _CustomImageBadge extends StatelessWidget {
  const _CustomImageBadge({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 16,
      height: 16,
      fit: BoxFit.contain,
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.items,
    required this.fontSize,
  });

  final List<MessageItem> items;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          for (final item in items)
            if (item.isEmoji)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _EmojiWidget(
                    emoji: item.emoji!,
                    size: fontSize * 1.5,
                  ),
                ),
              )
            else
              TextSpan(
                text: item.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.5,
                ),
              ),
        ],
      ),
      softWrap: true,
    );
  }
}

class _EmojiWidget extends StatelessWidget {
  const _EmojiWidget({
    required this.emoji,
    required this.size,
  });

  final EmojiItem emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (emoji.url.isEmpty) {
      return Text(
        emoji.alt,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.85,
        ),
      );
    }

    if (emoji.isAnimated && emoji.url.endsWith('.webp')) {
      return ExtendedImage.network(
        emoji.url,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return CachedNetworkImage(
      imageUrl: emoji.url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) => Text(
        emoji.alt,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.85,
        ),
      ),
    );
  }
}

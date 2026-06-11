import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/author_avatar.dart';
import 'package:airstream/ui/widgets/platform_badge.dart';
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
    final isMembershipEvent = message.isMembershipEvent;
    final bubbleColor = _bubbleColor(
      showBubble: s.showBubble,
      platform: message.platform,
      bubbleOpacity: bubbleOpacity,
      superChatColor:
          isSuperChat ? _parseColor(message.superChat!.color) : null,
      isMembershipEvent: isMembershipEvent,
    );
    final superChatAccentColor = isSuperChat
        ? _superChatAccentColor(
            showBubble: s.showBubble,
            bubbleOpacity: bubbleOpacity,
            superChatColor: _parseColor(message.superChat!.color),
          )
        : null;

    final bubbleBorder = _bubbleBorder(
      showBubble: s.showBubble,
      bubbleOpacity: bubbleOpacity,
    );

    final shadow = s.showBubble && s.showBubbleShadow
        ? const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ]
        : const <BoxShadow>[];

    final showPlatformBadge = s.showPlatformIcons;
    final textAlign = _textAlign(s.chatTextAlign);
    final alignment = _bubbleAlignment(s.chatTextAlign);
    final contentCrossAxisAlignment =
        _contentCrossAxisAlignment(s.chatTextAlign);
    final contentTextStyle = _chatTextStyle(
      color: Colors.white,
      fontSize: s.fontSize,
      lineHeight: s.chatLineHeight,
      fontWeight: s.chatFontWeight,
      textShadow: s.chatTextShadow,
    );
    final textStrokeStyle = _strokeTextStyle(
      color: Colors.black,
      fontSize: s.fontSize,
      lineHeight: s.chatLineHeight,
      fontWeight: s.chatFontWeight,
      strokeWidth: s.chatTextStroke,
      textShadow: s.chatTextShadow,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth =
            constraints.maxWidth * s.chatMaxMessageWidth.clamp(0.4, 1);

        return Padding(
          padding: EdgeInsets.symmetric(vertical: s.messageGap / 2),
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(s.borderRadius),
                  border: bubbleBorder,
                  boxShadow: shadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(s.borderRadius),
                  child: Stack(
                    children: [
                      Padding(
                        padding: s.showBubble
                            ? const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              )
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
                                crossAxisAlignment: contentCrossAxisAlignment,
                                children: [
                                  _AuthorRow(
                                    message: message,
                                    fontSize: s.fontSize,
                                    lineHeight: s.chatLineHeight,
                                    fontWeight: s.chatFontWeight,
                                    textShadow: s.chatTextShadow,
                                    textStroke: s.chatTextStroke,
                                    textAlign: textAlign,
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
                                      textAlign: textAlign,
                                      textStyle: contentTextStyle,
                                      strokeStyle: textStrokeStyle,
                                    ),
                                  if (isMembershipEvent)
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top:
                                              message.items.isNotEmpty ? 6 : 0),
                                      child: _OutlinedText(
                                        _membershipFlair(message.platform,
                                            message.author.badge?.label),
                                        textAlign: textAlign,
                                        style: _chatTextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: s.fontSize * 0.92,
                                          lineHeight: s.chatLineHeight,
                                          fontWeight: s.chatFontWeight,
                                          textShadow: s.chatTextShadow,
                                        ).copyWith(fontStyle: FontStyle.italic),
                                        strokeStyle: _strokeTextStyle(
                                          color: Colors.black,
                                          fontSize: s.fontSize * 0.92,
                                          lineHeight: s.chatLineHeight,
                                          fontWeight: s.chatFontWeight,
                                          strokeWidth: s.chatTextStroke,
                                          textShadow: s.chatTextShadow,
                                        )?.copyWith(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (message.superChat?.stickerUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              message.superChat!.stickerUrl!,
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
                      if (superChatAccentColor != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 4,
                            color: superChatAccentColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
  }) {
    if (!showBubble) return null;

    final baseSide = BorderSide(
      color: Colors.white.withValues(alpha: 0.1 * bubbleOpacity),
    );

    return Border.fromBorderSide(baseSide);
  }

  static Color? _superChatAccentColor({
    required bool showBubble,
    required double bubbleOpacity,
    required Color superChatColor,
  }) {
    if (!showBubble) return null;
    return superChatColor
        .withAlpha((255 * bubbleOpacity).round().clamp(0, 255));
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

  static Alignment _bubbleAlignment(String value) {
    return switch (value) {
      'center' => Alignment.center,
      'right' => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };
  }

  static CrossAxisAlignment _contentCrossAxisAlignment(String value) {
    return switch (value) {
      'center' => CrossAxisAlignment.center,
      'right' => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
  }

  static TextAlign _textAlign(String value) {
    return switch (value) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  static FontWeight _fontWeight(double value) {
    final normalized = ((value / 100).round() * 100).clamp(100, 900);
    return FontWeight.values[(normalized ~/ 100) - 1];
  }

  static List<Shadow>? _textShadows(bool enabled) {
    if (!enabled) return null;
    return const [
      Shadow(
        color: Color(0xCC000000),
        blurRadius: 4,
        offset: Offset(1, 1),
      ),
    ];
  }

  static TextStyle _chatTextStyle({
    required Color color,
    required double fontSize,
    required double lineHeight,
    required double fontWeight,
    required bool textShadow,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      fontWeight: _fontWeight(fontWeight),
      height: lineHeight,
      shadows: _textShadows(textShadow),
    );
  }

  static TextStyle? _strokeTextStyle({
    required Color color,
    required double fontSize,
    required double lineHeight,
    required double fontWeight,
    required double strokeWidth,
    required bool textShadow,
  }) {
    if (strokeWidth <= 0) return null;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: _fontWeight(fontWeight),
      height: lineHeight,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
      shadows: _textShadows(textShadow),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.message,
    required this.fontSize,
    required this.lineHeight,
    required this.fontWeight,
    required this.textShadow,
    required this.textStroke,
    required this.textAlign,
    required this.showPlatformIcons,
    required this.showBadges,
    required this.showAvatars,
    required this.showTimestamp,
  });

  final ChatMessage message;
  final double fontSize;
  final double lineHeight;
  final double fontWeight;
  final bool textShadow;
  final double textStroke;
  final TextAlign textAlign;
  final bool showPlatformIcons;
  final bool showBadges;
  final bool showAvatars;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final isMembershipEvent = message.isMembershipEvent;
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
        _OutlinedText(
          message.author.name,
          textAlign: textAlign,
          style: ChatBubble._chatTextStyle(
            color: message.isModerator ? const Color(0xFF7EA4FF) : authorColor,
            fontSize: fontSize * 0.95,
            lineHeight: lineHeight,
            fontWeight: 700,
            textShadow: textShadow,
          ),
          strokeStyle: ChatBubble._strokeTextStyle(
            color: Colors.black,
            fontSize: fontSize * 0.95,
            lineHeight: lineHeight,
            fontWeight: 700,
            strokeWidth: textStroke,
            textShadow: textShadow,
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
            child: _OutlinedText(
              _formatTime(message.timestamp),
              textAlign: textAlign,
              style: ChatBubble._chatTextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: fontSize * 0.8,
                lineHeight: lineHeight,
                fontWeight: fontWeight,
                textShadow: textShadow,
              ),
              strokeStyle: ChatBubble._strokeTextStyle(
                color: Colors.black,
                fontSize: fontSize * 0.8,
                lineHeight: lineHeight,
                fontWeight: fontWeight,
                strokeWidth: textStroke,
                textShadow: textShadow,
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
    required this.textAlign,
    required this.textStyle,
    required this.strokeStyle,
  });

  final List<MessageItem> items;
  final TextAlign textAlign;
  final TextStyle textStyle;
  final TextStyle? strokeStyle;

  @override
  Widget build(BuildContext context) {
    final fill = _buildText(textStyle, renderEmojis: true);
    final stroke = strokeStyle == null
        ? null
        : _buildText(strokeStyle!, renderEmojis: false);

    if (stroke == null) return fill;

    return Stack(
      children: [
        stroke,
        fill,
      ],
    );
  }

  Text _buildText(TextStyle style, {required bool renderEmojis}) {
    final emojiSize = (style.fontSize ?? 14) * 1.5;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final item in items)
            if (item.isEmoji)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: renderEmojis
                      ? _EmojiWidget(
                          emoji: item.emoji!,
                          size: emojiSize,
                        )
                      : SizedBox.square(dimension: emojiSize),
                ),
              )
            else
              TextSpan(text: item.text),
        ],
      ),
      textAlign: textAlign,
      softWrap: true,
    );
  }
}

class _OutlinedText extends StatelessWidget {
  const _OutlinedText(
    this.text, {
    required this.style,
    required this.strokeStyle,
    required this.textAlign,
  });

  final String text;
  final TextStyle style;
  final TextStyle? strokeStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final fill = Text(text, textAlign: textAlign, style: style);
    if (strokeStyle == null) return fill;

    return Stack(
      children: [
        Text(text, textAlign: textAlign, style: strokeStyle),
        fill,
      ],
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airchat_flutter/models/chat_message.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/ui/widgets/author_avatar.dart';
import 'package:airchat_flutter/ui/widgets/platform_badge.dart';

class ChatBubble extends ConsumerWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final bubbleOpacity = s.messageOpacity.clamp(0.0, 1.0);

    final isSuper = message.superChat != null;
    final superColor = isSuper ? _parseColor(message.superChat!.color) : null;

    final bg = isSuper
        ? Color.alphaBlend(
            superColor!.withAlpha(60),
            const Color(0xCC1A1A1A),
          )
        : const Color(0xCC1A1A1A);

    final border = isSuper
        ? Border(
            left: BorderSide(
              color: superColor!.withAlpha(
                ((superColor.a * 255.0) * bubbleOpacity).round().clamp(0, 255),
              ),
              width: 4,
            ),
          )
        : null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: s.messageGap / 2),
      decoration: BoxDecoration(
        color: s.showBubble
            ? bg.withAlpha(
                ((bg.a * 255.0) * bubbleOpacity).round().clamp(0, 255))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(s.borderRadius),
        border: border,
      ),
      padding: s.showBubble
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.showAvatars) ...[
            AuthorAvatar(
              name: message.author.name,
              url: message.author.avatarUrl,
              color: message.author.color,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    if (s.showBadges) PlatformBadge(platform: message.platform),
                    if (message.isOwner) _iconBadge(Icons.star, Colors.amber),
                    if (message.isModerator)
                      _iconBadge(Icons.shield, Colors.green),
                    if (message.isMembership)
                      _iconBadge(Icons.card_membership, Colors.purple),
                    Text(
                      message.author.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: s.fontSize * 0.9,
                        color: message.author.color != null
                            ? _parseColor(message.author.color!)
                            : Colors.white,
                      ),
                    ),
                    if (s.showTimestamp)
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: s.fontSize * 0.75,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                // SuperChat amount
                if (isSuper) ...[
                  Text(
                    message.superChat!.amount,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: s.fontSize,
                      color: superColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                // Sticker
                if (message.superChat?.stickerUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: CachedNetworkImage(
                      imageUrl: message.superChat!.stickerUrl!,
                      height: 48,
                    ),
                  ),
                // Message content
                _MessageContent(items: message.items, fontSize: s.fontSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _iconBadge(IconData icon, Color color) => Icon(
        icon,
        size: 13,
        color: color,
      );

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return Colors.white;
    }
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MessageContent extends StatelessWidget {
  final List<MessageItem> items;
  final double fontSize;

  const _MessageContent({required this.items, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: items.map((item) {
        if (item.isEmoji) {
          return _EmojiWidget(emoji: item.emoji!, size: fontSize + 4);
        }
        return Text(
          item.text,
          style: TextStyle(color: Colors.white, fontSize: fontSize),
        );
      }).toList(),
    );
  }
}

class _EmojiWidget extends StatelessWidget {
  final EmojiItem emoji;
  final double size;

  const _EmojiWidget({required this.emoji, required this.size});

  @override
  Widget build(BuildContext context) {
    if (emoji.url.isEmpty) {
      return Text(emoji.alt,
          style: TextStyle(color: Colors.white, fontSize: size));
    }

    // animated WebP (7TV) needs extended_image
    if (emoji.isAnimated && emoji.url.endsWith('.webp')) {
      return ExtendedImage.network(
        emoji.url,
        width: size + 4,
        height: size + 4,
        fit: BoxFit.contain,
      );
    }

    // PNG / GIF — CachedNetworkImage handles GIF animation natively
    return CachedNetworkImage(
      imageUrl: emoji.url,
      width: size + 4,
      height: size + 4,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) =>
          Text(emoji.alt, style: TextStyle(fontSize: size)),
    );
  }
}

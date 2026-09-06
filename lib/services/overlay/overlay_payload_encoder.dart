import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_model.dart';

abstract final class OverlayPayloadEncoder {
  static Map<String, dynamic> message(ChatMessage msg) => {
        'platform': msg.platform.name,
        'id': msg.id,
        'author': msg.author.name,
        'authorAvatarUrl': msg.author.avatarUrl,
        'authorChannelId': msg.author.channelId,
        'badgeImageUrl': msg.author.badge?.imageUrl,
        'badgeLabel': msg.author.badge?.label,
        'badges': msg.author.allBadges
            .map((badge) => {
                  'imageUrl': badge.imageUrl,
                  'label': badge.label,
                  'kind': badge.kind,
                })
            .toList(),
        'color': msg.author.color,
        'text': msg.plainText,
        'items': msg.items
            .map((item) => item.isEmoji
                ? {
                    'kind': 'emoji',
                    'url': item.emoji!.url,
                    'alt': item.emoji!.alt,
                    'isAnimated': item.emoji!.isAnimated,
                  }
                : {
                    'kind': 'text',
                    'text': item.text,
                  })
            .toList(),
        'isSuperChat': msg.superChat != null,
        'superChatAmount': msg.superChat?.amount,
        'superChatColor': msg.superChat?.color,
        'superChatStickerUrl': msg.superChat?.stickerUrl,
        'isMembership': msg.isMembership,
        'isMembershipEvent': msg.isMembershipEvent,
        'membershipEventKind': msg.membershipEventKind?.name,
        'membershipMonths': msg.membershipMonths,
        'isOwner': msg.isOwner,
        'isModerator': msg.isModerator,
        'isVip': msg.isVip,
        'isVerified': msg.isVerified,
        'youtubeStreamOrientation': msg.youtubeStreamOrientation?.name,
        'timestamp': msg.timestamp.toIso8601String(),
      };

  static Map<String, dynamic> settings(SettingsModel settings) => {
        'appLanguageCode': settings.appLanguageCode,
        'chromaMode': settings.overlayChromaMode,
        'chromaColor': settings.overlayChromaColor,
        'showGrid': settings.overlayShowGrid,
        'hideScrollbar': settings.overlayHideScrollbar,
        'fontSize': settings.overlayFontSize,
        'bgOpacity': settings.overlayBgOpacity,
        'messageOpacity': settings.overlayMessageOpacity,
        'showAvatars': settings.overlayShowAvatars,
        'showPlatformIcons': settings.overlayShowPlatformIcons,
        'showBadges': settings.overlayShowBadges,
        'showYoutubeStreamBadges': settings.overlayShowYoutubeStreamBadges,
        'showTimestamp': settings.overlayShowTimestamp,
        'textStroke': settings.overlayTextStroke,
        'textStrokeColor': settings.overlayTextStrokeColor,
        'lineHeight': settings.overlayLineHeight,
        'messageGap': settings.overlayMessageGap,
        'fontWeight': settings.overlayFontWeight,
        'borderRadius': settings.overlayBorderRadius,
        'textShadow': settings.overlayTextShadow,
        'showBubble': settings.overlayShowBubble,
        'superChatBarEnabled': settings.overlaySuperChatBarEnabled,
        'superChatBarColor': settings.overlaySuperChatBarColor,
        'superChatBarWidth': settings.overlaySuperChatBarWidth,
        'maxMessages': settings.overlayMaxMessages,
        'messageTtlSeconds': settings.overlayMessageTtlSeconds,
        'animation': settings.overlayAnimation,
        'animationDuration': settings.overlayAnimationDuration,
        'textAlign': settings.overlayTextAlign,
        'twitchBubbleAccent': settings.overlayTwitchBubbleAccent,
        'kickBubbleAccent': settings.overlayKickBubbleAccent,
        'threeDEnabled': settings.overlayThreeDEnabled,
        'perspective': settings.overlayPerspective,
        'rotateX': settings.overlayRotateX,
        'rotateY': settings.overlayRotateY,
        'rotateZ': settings.overlayRotateZ,
        'skewX': settings.overlaySkewX,
        'scale': settings.overlayScale,
        'alertFontSize': settings.alertFontSize,
        'alertDisplaySeconds': settings.alertDisplaySeconds,
        'alertShowAvatars': settings.alertShowAvatars,
      };
}

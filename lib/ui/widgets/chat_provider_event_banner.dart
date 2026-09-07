import 'dart:async';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/ui/widgets/chat_network_image.dart';
import 'package:airstream/ui/widgets/platform_badge.dart';
import 'package:flutter/material.dart';

class TransientChatProviderEventBanner extends StatefulWidget {
  const TransientChatProviderEventBanner({
    super.key,
    required this.event,
    this.visibleDuration = const Duration(seconds: 6),
  });

  final ChatProviderEvent? event;
  final Duration visibleDuration;

  @override
  State<TransientChatProviderEventBanner> createState() =>
      _TransientChatProviderEventBannerState();
}

class _TransientChatProviderEventBannerState
    extends State<TransientChatProviderEventBanner> {
  Timer? _hideTimer;
  ChatProviderEvent? _visibleEvent;

  @override
  void initState() {
    super.initState();
    _show(widget.event);
  }

  @override
  void didUpdateWidget(TransientChatProviderEventBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_eventKey(widget.event) != _eventKey(oldWidget.event)) {
      _show(widget.event);
    }
  }

  void _show(ChatProviderEvent? event) {
    _hideTimer?.cancel();
    _visibleEvent = event?.data['duplicatesMessage'] == true ? null : event;
    if (_visibleEvent == null) return;
    _hideTimer = Timer(widget.visibleDuration, () {
      if (mounted) setState(() => _visibleEvent = null);
    });
  }

  static String? _eventKey(ChatProviderEvent? event) => event == null
      ? null
      : '${event.platform.name}:${event.kind.name}:${event.id}';

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _visibleEvent == null
            ? const SizedBox.shrink(key: ValueKey('provider-event-hidden'))
            : ChatProviderEventBanner(
                key: ValueKey(_eventKey(_visibleEvent)),
                event: _visibleEvent!,
              ),
      );
}

class ChatProviderEventBanner extends StatelessWidget {
  const ChatProviderEventBanner({super.key, required this.event});

  final ChatProviderEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final detail = _detail(l);
    final imageUrl = event.data['imageUrl']?.toString() ?? '';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xE6181818),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _platformColor(event.platform)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlatformBadge(
                platform: event.platform,
                mode: PlatformBadgeMode.inline,
              ),
              const SizedBox(width: 8),
              if (imageUrl.isNotEmpty) ...[
                Semantics(
                  image: true,
                  label: event.data['giftName']?.toString() ?? _label(l),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ChatNetworkImage(
                      imageUrl: imageUrl,
                      cacheKey: ChatImageCache.key(
                        kind: 'kick-gift',
                        identity: event.data['giftId']?.toString() ?? event.id,
                        url: imageUrl,
                      ),
                      width: 28,
                      height: 28,
                      placeholder: const SizedBox(width: 28, height: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _label(l),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (detail.isNotEmpty)
                        TextSpan(
                          text: '  $detail',
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                  key: Key('chat-provider-event-${event.platform.name}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(AppLocalizations l) => switch (event.kind) {
        ChatProviderEventKind.raid => l.chatEventRaid,
        ChatProviderEventKind.unraid => l.chatEventUnraid,
        ChatProviderEventKind.pinnedMessage => l.chatEventPinnedMessage,
        ChatProviderEventKind.unpinnedMessage => l.chatEventUnpinnedMessage,
        ChatProviderEventKind.poll => l.chatEventPoll,
        ChatProviderEventKind.reward => l.chatEventReward,
        ChatProviderEventKind.support => l.chatEventSupport,
        ChatProviderEventKind.host => l.chatEventHost,
        ChatProviderEventKind.goal => l.chatEventGoal,
        ChatProviderEventKind.notice => l.chatEventNotice,
        ChatProviderEventKind.modiversary => l.chatEventModiversary,
        ChatProviderEventKind.viewerMilestone => l.chatEventViewerMilestone,
        ChatProviderEventKind.watchStreak => l.chatEventWatchStreak,
        ChatProviderEventKind.sharedChat => l.chatEventSharedChat,
        ChatProviderEventKind.roomState => l.chatEventRoomState,
        ChatProviderEventKind.streamOnline => l.chatEventStreamOnline,
        ChatProviderEventKind.streamOffline => l.chatEventStreamOffline,
        ChatProviderEventKind.unknown => l.chatEventUnknown,
      };

  String _detail(AppLocalizations l) {
    final parts = <String>[
      if (event.authorName.trim().isNotEmpty) event.authorName.trim(),
      if (event.text.trim().isNotEmpty) event.text.trim(),
      if (event.count != null) event.count.toString(),
    ];
    if (event.kind == ChatProviderEventKind.roomState) {
      final followers = event.data['followersOnlyMinutes'];
      final slow = event.data['slowModeSeconds'];
      if (event.data['emoteOnly'] == true) parts.add(l.chatRoomEmoteOnly);
      if (followers is int && followers >= 0) {
        parts.add(l.chatRoomFollowersOnly(followers));
      }
      if (event.data['uniqueChat'] == true) parts.add(l.chatRoomUnique);
      if (slow is int && slow > 0) parts.add(l.chatRoomSlowMode(slow));
      if (event.data['subscribersOnly'] == true) {
        parts.add(l.chatRoomSubscribersOnly);
      }
    }
    if (event.kind == ChatProviderEventKind.poll) {
      final options = event.data['options'];
      if (options is List) {
        for (final option in options.whereType<Map>()) {
          final label = option['label']?.toString().trim() ?? '';
          final votes = option['votes'];
          if (label.isNotEmpty) {
            parts.add(votes is int ? '$label ($votes)' : label);
          }
        }
      }
    }
    if (event.kind == ChatProviderEventKind.goal) {
      final current = event.data['current'];
      final target = event.data['target'];
      if (current is int || target is int) {
        parts.add('${current ?? 0} / ${target ?? '—'}');
      }
    }
    if (event.kind == ChatProviderEventKind.reward) {
      final cost = event.data['cost'];
      if (cost is int) parts.add(cost.toString());
    }
    return parts.join(' · ');
  }

  static Color _platformColor(Platform platform) => switch (platform) {
        Platform.youtube => const Color(0x99FF0033),
        Platform.twitch => const Color(0x999146FF),
        Platform.kick => const Color(0x9953FC18),
      };
}

import 'dart:async';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/pipeline/chat_filter.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart' show chatTextHyphens;
import 'package:airstream/ui/widgets/chat_network_image.dart';
import 'package:airstream/ui/widgets/platform_badge.dart';
import 'package:material_ui/material_ui.dart';

class TransientChatProviderEventBanner extends StatefulWidget {
  const TransientChatProviderEventBanner({
    super.key,
    required this.event,
    this.settings = const SettingsModel(),
    this.visibleDuration = const Duration(seconds: 6),
  });

  final ChatProviderEvent? event;
  final SettingsModel settings;
  final Duration visibleDuration;

  @override
  State<TransientChatProviderEventBanner> createState() =>
      _TransientChatProviderEventBannerState();
}

class _TransientChatProviderEventBannerState
    extends State<TransientChatProviderEventBanner> {
  /// Events waiting while another one is on screen.
  static const _maxPending = 3;

  Timer? _hideTimer;
  ChatProviderEvent? _visibleEvent;
  final _pending = <ChatProviderEvent>[];
  late ChatFilter _filter;
  int _blockRevision = 0;

  @override
  void initState() {
    super.initState();
    _filter = ChatFilter(widget.settings);
    _enqueue(widget.event);
  }

  @override
  void didUpdateWidget(TransientChatProviderEventBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ChatFilter.sameBlockLists(oldWidget.settings, widget.settings)) {
      _filter = ChatFilter(widget.settings);
      _pending.removeWhere(_filter.blocksProviderEvent);
      // Clear outgoing animations too, as they can still show blocked events.
      _blockRevision++;
      final visible = _visibleEvent;
      if (visible != null && _filter.blocksProviderEvent(visible)) {
        _hideTimer?.cancel();
        _advance();
      }
    }
    if (_eventKey(widget.event) != _eventKey(oldWidget.event)) {
      _enqueue(widget.event);
    }
  }

  void _enqueue(ChatProviderEvent? event) {
    if (event == null ||
        event.data['duplicatesMessage'] == true ||
        _filter.blocksProviderEvent(event)) {
      return;
    }
    if (_visibleEvent == null) {
      _display(event);
      return;
    }
    // A burst shows one event after another instead of replacing them.
    _pending.add(event);
    if (_pending.length > _maxPending) _pending.removeAt(0);
  }

  void _display(ChatProviderEvent event) {
    _hideTimer?.cancel();
    _visibleEvent = event;
    _hideTimer = Timer(widget.visibleDuration, () {
      if (!mounted) return;
      setState(_advance);
    });
  }

  void _advance() {
    _visibleEvent = null;
    if (_pending.isNotEmpty) _display(_pending.removeAt(0));
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
        key: ValueKey(_blockRevision),
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
                  hyphens: chatTextHyphens,
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

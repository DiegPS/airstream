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

/// The event the banner shows: the latest one of an enabled kind. An event of
/// a disabled kind keeps the current one, so the banner is not torn down and
/// its visible card and queue survive; turning a kind off drops its event.
/// An unpin always reaches the banner, which takes the old pin away and shows
/// the unpin itself only when its kind is enabled.
ChatProviderEvent? bannerProviderEvent(ChatProviderEvent? latest,
    ChatProviderEvent? shown, List<String> enabledKinds) {
  if (latest != null &&
      (enabledKinds.contains(latest.kind.name) ||
          latest.kind == ChatProviderEventKind.unpinnedMessage)) {
    return latest;
  }
  if (shown != null && enabledKinds.contains(shown.kind.name)) return shown;
  return null;
}

class TransientChatProviderEventBanner extends StatefulWidget {
  const TransientChatProviderEventBanner({
    super.key,
    required this.event,
    this.settings = const SettingsModel(),
    this.visibleDuration = const Duration(seconds: 6),
    this.moderationEvents,
  });

  final ChatProviderEvent? event;
  final SettingsModel settings;
  final Duration visibleDuration;

  /// Deleted messages and banned authors take their pins off the banner.
  final Stream<ChatModerationEvent>? moderationEvents;

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
  StreamSubscription<ChatModerationEvent>? _moderation;

  @override
  void initState() {
    super.initState();
    _filter = ChatFilter(widget.settings);
    _moderation = widget.moderationEvents?.listen(_moderate);
    _enqueue(widget.event);
  }

  void _moderate(ChatModerationEvent moderation) {
    if (!mounted) return;
    setState(() => _removePins((pin) => moderation.matchesTarget(
          targetPlatform: pin.platform,
          orientation: _orientation(pin),
          id: pin.id,
          authorId: pin.authorChannelId,
          name: pin.viewerName ?? pin.authorName,
        )));
  }

  static YoutubeStreamOrientation? _orientation(ChatProviderEvent event) {
    final name = event.data['youtubeStreamOrientation'];
    return YoutubeStreamOrientation.values
        .where((value) => value.name == name)
        .firstOrNull;
  }

  /// Drops matching pins from the queue and from the screen.
  void _removePins(bool Function(ChatProviderEvent pin) matches) {
    bool pinned(ChatProviderEvent event) =>
        event.kind == ChatProviderEventKind.pinnedMessage && matches(event);
    _pending.removeWhere(pinned);
    final visible = _visibleEvent;
    if (visible != null && pinned(visible)) {
      _hideTimer?.cancel();
      _advance();
    }
  }

  /// Kick keeps one pin, so its unpin or a new pin replaces any earlier one.
  /// YouTube names a removed banner by its banner id, per stream orientation.
  bool _replacedBy(ChatProviderEvent event, ChatProviderEvent pin) {
    if (pin.platform != event.platform) return false;
    if (event.kind == ChatProviderEventKind.pinnedMessage) {
      return event.platform == Platform.kick &&
          _eventKey(pin) != _eventKey(event);
    }
    if (event.platform == Platform.kick) return true;
    final bannerId = event.data['bannerId'];
    if (bannerId != null) {
      return pin.data['bannerId'] == bannerId &&
          pin.data['youtubeStreamOrientation'] ==
              event.data['youtubeStreamOrientation'];
    }
    return event.id.isEmpty || pin.id == event.id;
  }

  @override
  void didUpdateWidget(TransientChatProviderEventBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.moderationEvents, oldWidget.moderationEvents)) {
      _moderation?.cancel();
      _moderation = widget.moderationEvents?.listen(_moderate);
    }
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
    // Turning a banner kind off also drops its waiting and visible events.
    final kinds = widget.settings.providerEventBannerKinds;
    if (oldWidget.settings.providerEventBannerKinds.join(',') !=
        kinds.join(',')) {
      bool disabled(ChatProviderEvent event) =>
          !kinds.contains(event.kind.name);
      _pending.removeWhere(disabled);
      final visible = _visibleEvent;
      if (visible != null && disabled(visible)) {
        _hideTimer?.cancel();
        _advance();
      }
    }
    // Kick sends poll updates (new counts, deletion) under the same id, so a
    // new event object counts even when its key did not change.
    if (!identical(widget.event, oldWidget.event)) _enqueue(widget.event);
  }

  void _enqueue(ChatProviderEvent? event) {
    if (event == null ||
        event.data['duplicatesMessage'] == true ||
        _filter.blocksProviderEvent(event)) {
      return;
    }
    if (event.kind == ChatProviderEventKind.pinnedMessage ||
        event.kind == ChatProviderEventKind.unpinnedMessage) {
      _removePins((pin) => _replacedBy(event, pin));
    }
    if (event.kind == ChatProviderEventKind.unpinnedMessage &&
        !widget.settings.providerEventBannerKinds
            .contains(ChatProviderEventKind.unpinnedMessage.name)) {
      return;
    }
    final key = _eventKey(event);
    final deleted = event.data['deleted'] == true;
    if (_visibleEvent != null && _eventKey(_visibleEvent) == key) {
      if (deleted) {
        _hideTimer?.cancel();
        _advance();
      } else {
        // Fresh data in place, keeping the time it has left on screen.
        _visibleEvent = event;
      }
      return;
    }
    final waiting = _pending.indexWhere((e) => _eventKey(e) == key);
    if (waiting != -1) {
      if (deleted) {
        _pending.removeAt(waiting);
      } else {
        _pending[waiting] = event;
      }
      return;
    }
    // A deletion of something not on screen has nothing to show.
    if (deleted) return;
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
    _moderation?.cancel();
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

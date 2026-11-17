import 'widgets/rule_buttons_card.dart';
import 'package:airstream/ui/widgets/rules_card.dart';
import 'package:airstream/ui/widgets/settings_controls.dart';
import 'package:airstream/ui/widgets/templates_card.dart';
import 'package:airstream/ui/widgets/subathon_card.dart';
import 'dart:async';
import 'package:airstream/ui/widgets/media_library_card.dart';
import 'package:airstream/settings/media_library_entries.dart';
import 'package:airstream/services/overlay/alert_sounds.dart';
import 'dart:io' as io;

import 'package:airstream/services/overlay/featured_message_delivery.dart';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/chat_provider_event.dart';
import 'package:airstream/models/chat_view_filter.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/models/chat_message.dart'
    show ChatMessage, Platform, YoutubeStreamOrientation;
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/speech_model_catalog.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_service.dart'
    show TtsLoadPhase, TtsLoadState;
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/settings/settings_input_normalizer.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/preview/sample_messages.dart';
import 'package:airstream/ui/chat/paused_chat_view.dart';
import 'package:airstream/ui/widgets/chat_alignment.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
import 'package:airstream/ui/widgets/chat_provider_event_banner.dart';
import 'package:airstream/ui/widgets/global_shortcuts_card.dart';
import 'package:airstream/ui/widgets/diagnostics_card.dart';
import 'package:airstream/ui/widgets/recent_alerts_card.dart';
import 'package:airstream/ui/widgets/overlay_style_presets_card.dart';
import 'package:airstream/ui/widgets/poll_card.dart';
import 'package:airstream/ui/widgets/giveaway_card.dart';
import 'package:airstream/ui/widgets/queue_card.dart';
import 'package:airstream/ui/widgets/goals_card.dart';
import 'package:airstream/ui/widgets/session_summary_dialog.dart';
import 'package:airstream/ui/widgets/settings_profiles_card.dart';
import 'package:airstream/ui/widgets/sidebar_tab_bar.dart';
import 'package:airstream/ui/widgets/styled_slider_row.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:airstream/ui/widgets/window_control_bar.dart';
import 'package:airstream/ui/widgets/youtube_live_stats.dart';
import 'package:airstream/window/window_state.dart';

part 'chat/connection_status.dart';
part 'chat/desktop_top_bar.dart';
part 'chat/obs_status.dart';
part 'settings/settings_sidebar.dart';
part 'settings/settings_components.dart';
part 'settings/settings_form_controllers.dart';
part 'settings/settings_dialogs.dart';
part 'settings/tabs/obs_settings_tab.dart';
part 'settings/tabs/style_settings_tab.dart';
part 'settings/tabs/audio_settings_tab.dart';
part 'settings/tabs/channels_settings_tab.dart';
part 'settings/tabs/system_settings_tab.dart';

String _formatByteSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '$bytes B';
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _sidebarWidth = 380.0;
  static const _minInlineChatWidth = 360.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  /// The chat as it was when the viewer scrolled up to read; null while the
  /// chat follows new messages.
  List<ChatMessage>? _pausedSnapshot;

  /// Keeps the event banner (and what it queued) when resizing moves the
  /// chat between the inline and drawer layouts.
  final _providerEventBannerKey = GlobalKey();
  bool _sidebarVisible = true;
  bool _topBarVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    FocusManager.instance.addEarlyKeyEventHandler(_handleGlobalKeyEvent);
    unawaited(_connectOnLaunch());
  }

  Future<void> _connectOnLaunch() async {
    try {
      await ref.read(settingsProvider.notifier).ready;
    } catch (_) {
      // Settings fall back to defaults; nothing is set to connect.
    }
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    if (settings.connectChatOnLaunch && hasStartableChat(settings)) {
      ref.read(chatConnectionProvider.notifier).state = true;
    }
    if (settings.obsEnabled && settings.obsConnectOnLaunch) {
      unawaited(ref.read(appControllerProvider).connectObs());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleGlobalKeyEvent);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final atBottom = _scrollController.position.pixels <= 40;
    if (_autoScroll != atBottom) {
      setState(() {
        _autoScroll = atBottom;
        _pausedSnapshot = atBottom
            ? null
            : (ref.read(chatProvider).valueOrNull ?? const <ChatMessage>[]);
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _toggleSidebarVisibility() {
    if (_usesSidebarDrawer(MediaQuery.sizeOf(context).width)) {
      final scaffoldState = _scaffoldKey.currentState;
      if (scaffoldState == null) return;

      if (scaffoldState.isDrawerOpen) {
        Navigator.of(scaffoldState.context).pop();
      } else {
        scaffoldState.openDrawer();
      }
      return;
    }

    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  void _resumeChat() {
    setState(() {
      _autoScroll = true;
      _pausedSnapshot = null;
    });
    _scrollToBottom();
  }

  void _toggleTopBarVisibility() {
    setState(() => _topBarVisible = !_topBarVisible);
  }

  KeyEventResult _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final windowNotifier = ref.read(windowStateProvider.notifier);

    final isToggleSidebarShortcut =
        event.logicalKey == LogicalKeyboardKey.keyB &&
            keyboard.isControlPressed &&
            !keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (isToggleSidebarShortcut) {
      _toggleSidebarVisibility();
      return KeyEventResult.handled;
    }

    final isToggleTopBarShortcut =
        event.logicalKey == LogicalKeyboardKey.keyT &&
            keyboard.isControlPressed &&
            keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (isToggleTopBarShortcut) {
      _toggleTopBarVisibility();
      return KeyEventResult.handled;
    }

    final isToggleAlwaysOnTopShortcut =
        event.logicalKey == LogicalKeyboardKey.keyP &&
            keyboard.isControlPressed &&
            keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (isToggleAlwaysOnTopShortcut) {
      unawaited(windowNotifier.toggleAlwaysOnTop());
      return KeyEventResult.handled;
    }

    // While click-through is on, Windows delivers this shortcut as a global
    // hotkey instead; here it turns click-through on from the window.
    final isToggleClickThroughShortcut =
        event.logicalKey == LogicalKeyboardKey.keyC &&
            keyboard.isControlPressed &&
            keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    final isSearchShortcut = event.logicalKey == LogicalKeyboardKey.keyF &&
        keyboard.isControlPressed &&
        !keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isMetaPressed;

    if (isSearchShortcut) {
      ref.read(chatSearchOpenProvider.notifier).state = true;
      return KeyEventResult.handled;
    }

    if (isToggleClickThroughShortcut) {
      unawaited(windowNotifier.toggleClickThrough());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ref.listen(globalShortcutsProvider, (_, __) {});
    ref.watch(goalTrackingProvider);
    ref.watch(subathonTrackingProvider);
    ref.listen<bool>(chatPreviewProvider, (previous, enabled) {
      final app = ref.read(appControllerProvider);
      if (enabled) {
        app.showOverlayPreview(
          sampleChatMessages(ref.read(settingsProvider).appLanguageCode),
        );
      } else {
        app.hideOverlayPreview();
      }
    });
    // Samples must not stay on screen (or in OBS) once the real chat starts.
    ref.listen<bool>(chatConnectionProvider, (previous, connected) {
      if (connected) ref.read(chatPreviewProvider.notifier).state = false;
    });
    ref.listen<WindowState>(windowStateProvider, (previous, next) {
      final String message;
      if (next.clickThrough && previous?.clickThrough != true) {
        message = l.clickThroughEnabledNotice;
      } else if (next.globalClickThroughHotKeyRegistered == false &&
          previous?.globalClickThroughHotKeyRegistered != false) {
        message = l.globalClickThroughShortcutUnavailable;
      } else {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
    ref.listen<AppNotice?>(
      appNoticeProvider.select((notice) => notice.valueOrNull),
      (previous, next) {
        if (next == null || previous?.id == next.id) return;
        final message = switch (next.code) {
          AppNoticeCode.ttsPlaybackFailed => l.ttsPlaybackFailed,
          AppNoticeCode.voiceCommandFailed => l.voiceCommandFailed,
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: next.severity == AppNoticeSeverity.error
                  ? const Color(0xFF8C1D18)
                  : null,
            ),
          );
      },
    );
    final bgOpacity = ref.watch(settingsProvider.select((s) => s.bgOpacity));
    final scaffoldBg = const Color(0xFF0D0D0D).withValues(alpha: bgOpacity);
    final availableWidth = MediaQuery.sizeOf(context).width;
    final usesSidebarDrawer = _usesSidebarDrawer(availableWidth);
    final scaffold = Focus(
      autofocus: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: scaffoldBg,
        drawer: usesSidebarDrawer
            ? Drawer(
                width: _drawerWidth(availableWidth),
                backgroundColor: const Color(0xFF141414),
                child: const _SettingsSidebar(),
              )
            : null,
        drawerEnableOpenDragGesture: usesSidebarDrawer,
        appBar: _topBarVisible
            ? _DesktopTopBar(
                sidebarVisible: usesSidebarDrawer ? false : _sidebarVisible,
                onToggleSidebar: _toggleSidebarVisibility,
              )
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (_usesSidebarDrawer(constraints.maxWidth)) {
              return _chatList();
            }

            return Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: _sidebarVisible ? _sidebarWidth : 0,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: _sidebarWidth,
                      maxWidth: _sidebarWidth,
                      child: IgnorePointer(
                        ignoring: !_sidebarVisible,
                        child: const SizedBox(
                          width: _sidebarWidth,
                          child: _SettingsSidebar(),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: _sidebarVisible ? 1 : 0,
                  color: const Color(0xFF242424),
                ),
                Expanded(
                  child: _chatList(),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (io.Platform.isWindows || io.Platform.isMacOS || io.Platform.isLinux) {
      return _DesktopResizeFrame(child: scaffold);
    }

    return scaffold;
  }

  static bool _usesSidebarDrawer(double width) {
    return width < _sidebarWidth + _minInlineChatWidth;
  }

  static double _drawerWidth(double availableWidth) {
    return availableWidth < _sidebarWidth ? availableWidth : _sidebarWidth;
  }

  /// The chat pane rebuilds on its own, without the window around it.
  Widget _chatList() => Consumer(
        builder: (context, ref, _) => _chatListContent(context, ref),
      );

  /// Bubbles already built, reused while their message is unchanged so a new
  /// message only builds its own bubble.
  final _bubbles = <String, _ChatMessageEntry>{};

  Widget _bubbleFor(ChatMessage message) {
    final cached = _bubbles[message.dedupeKey];
    if (cached != null && identical(cached.message, message)) return cached;
    return _bubbles[message.dedupeKey] = _ChatMessageEntry(
      key: ValueKey(message.dedupeKey),
      message: message,
    );
  }

  void _forgetRemovedBubbles(List<ChatMessage> messages) {
    if (_bubbles.length <= messages.length) return;
    final keys = {for (final message in messages) message.dedupeKey};
    _bubbles.removeWhere((key, _) => !keys.contains(key));
  }

  Widget _chatListContent(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final chat = ref.watch(chatProvider);
    final settings = ref.watch(settingsProvider);
    final latestProviderEvent =
        ref.watch(chatProviderEventProvider).valueOrNull;
    final providerEvent = latestProviderEvent != null &&
            settings.providerEventBannerKinds
                .contains(latestProviderEvent.kind.name)
        ? latestProviderEvent
        : null;
    final showObsCard = settings.obsEnabled;
    final obsBottomSpacing =
        settings.messageGap < 6 ? 6.0 : settings.messageGap;
    final obsReservedSpace = 56.0 + obsBottomSpacing;

    Widget buildPane(Widget child) {
      Widget pane = child;
      if (showObsCard) {
        pane = Stack(
          children: [
            Positioned.fill(child: pane),
            Positioned(
              left: 24,
              right: 24,
              bottom: obsBottomSpacing,
              child: Align(
                alignment: chatHorizontalAlignment(settings.chatTextAlign),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  // OBS stats update every second: only this card follows.
                  child: Consumer(
                    builder: (context, ref, _) => _ObsStatusCard(
                      state: ref.watch(obsStateProvider).valueOrNull ??
                          const ObsState(),
                      compact: true,
                      styleSettings: settings,
                      displaySettings: settings,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
      // The pane keeps the same place in the tree whether or not a banner
      // shows, so the chat keeps its scroll position when one appears.
      return Stack(
        children: [
          Positioned.fill(child: pane),
          if (providerEvent != null)
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: IgnorePointer(
                child: Align(
                  alignment: chatHorizontalAlignment(settings.chatTextAlign),
                  child: TransientChatProviderEventBanner(
                    key: _providerEventBannerKey,
                    event: providerEvent,
                    visibleDuration: Duration(
                      seconds: settings.providerEventBannerSeconds,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return chat.when(
      loading: () => buildPane(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF53FC18)),
        ),
      ),
      error: (_, __) => buildPane(
        Center(
          child: Text(
            l.chatError,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
      data: (chatMessages) {
        final allMessages =
            chatMessages.isEmpty && ref.watch(chatPreviewProvider)
                ? sampleChatMessages(settings.appLanguageCode)
                : chatMessages;
        final viewFilter = ref.watch(chatViewFilterProvider);
        final liveMessages = viewFilter.apply(
          allMessages,
          ref.watch(chatHighlighterProvider),
        );
        final paused = _pausedSnapshot == null
            ? null
            : pausedChatView(_pausedSnapshot!, liveMessages);
        final messages = paused?.messages ?? liveMessages;
        _forgetRemovedBubbles(messages);
        final positions = <String, int>{
          for (var i = 0; i < messages.length; i++) messages[i].dedupeKey: i,
        };
        final searchOpen = ref.watch(chatSearchOpenProvider);
        final headers = [
          if (searchOpen) const _ChatSearchField(),
          if (viewFilter.isActive) _ChatFilterBar(filter: viewFilter),
        ];
        if (liveMessages.isEmpty && allMessages.isNotEmpty) {
          return buildPane(
            Column(
              children: [
                ...headers,
                Expanded(
                  child: Center(
                    child: Text(
                      l.chatFilterNoMatches,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (liveMessages.isEmpty) {
          final sessionPhase = ref.watch(chatSessionPhaseProvider);
          final hasChannels = hasStartableChat(settings);
          final sidebarShown = _sidebarVisible &&
              !_usesSidebarDrawer(MediaQuery.sizeOf(context).width);
          if (!hasChannels && !sidebarShown) {
            return buildPane(
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.noChannelsConfiguredMenuHidden,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const Key('configure-channels-button'),
                      onPressed: _toggleSidebarVisibility,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(l.configureChannels),
                    ),
                  ],
                ),
              ),
            );
          }
          final youtubeWaiting =
              ref.watch(connectionStatusProvider).valueOrNull?['youtube']?.$2 ==
                  youtubeWaitingForLiveStatus;
          final text = hasChannels
              ? switch (sessionPhase) {
                  ChatSessionPhase.connecting when youtubeWaiting =>
                    l.youtubeWaitingForLive,
                  ChatSessionPhase.connecting ||
                  ChatSessionPhase.connected =>
                    l.listeningForMessages,
                  ChatSessionPhase.partiallyConnected =>
                    l.chatPartiallyConnected,
                  ChatSessionPhase.failed => l.chatConnectionsFailed,
                  ChatSessionPhase.idle => l.channelsSavedStartPrompt,
                }
              : l.noChannelsConfigured;
          return buildPane(
            Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          );
        }

        final list = Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: EdgeInsets.fromLTRB(
                settings.chatHorizontalPadding,
                24,
                settings.chatHorizontalPadding,
                showObsCard ? obsReservedSpace : 20,
              ),
              itemCount: messages.length,
              itemBuilder: (_, i) =>
                  _bubbleFor(messages[messages.length - 1 - i]),
              // New messages enter at index 0 and shift every other one.
              // Finding bubbles by key lets each keep its element (and its
              // loaded avatar) instead of being rebuilt from scratch.
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final position = positions[key.value];
                return position == null ? null : messages.length - 1 - position;
              },
            ),
            if (!_autoScroll)
              Positioned(
                bottom: 12,
                right: 12,
                child: (paused?.newCount ?? 0) > 0
                    ? FloatingActionButton.extended(
                        key: const Key('chat-resume-button'),
                        backgroundColor: const Color(0xFF53FC18),
                        foregroundColor: Colors.black,
                        onPressed: _resumeChat,
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: Text(l.newChatMessages(paused!.newCount)),
                      )
                    : FloatingActionButton.small(
                        key: const Key('chat-resume-button'),
                        backgroundColor: const Color(0xFF53FC18),
                        foregroundColor: Colors.black,
                        onPressed: _resumeChat,
                        child: const Icon(Icons.arrow_downward),
                      ),
              ),
          ],
        );
        return buildPane(
          headers.isEmpty
              ? list
              : Column(children: [...headers, Expanded(child: list)]),
        );
      },
    );
  }
}

/// Says what the chat window is hiding, with a way back to everything.
class _ChatFilterBar extends ConsumerWidget {
  const _ChatFilterBar({required this.filter});

  final ChatViewFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final parts = [
      if (filter.hiddenPlatforms.isNotEmpty)
        [
          for (final platform in Platform.values)
            if (!filter.hiddenPlatforms.contains(platform))
              chatFilterPlatformName(platform),
        ].join(', '),
      if (filter.role != ChatViewRole.all) chatFilterRoleName(l, filter.role),
      if (filter.query.trim().isNotEmpty) '"${filter.query.trim()}"',
    ];
    return Container(
      key: const Key('chat-filter-bar'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B5A1F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              size: 16, color: Color(0xFF53FC18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.chatFilterActive(parts.join(' · ')),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatViewFilterProvider.notifier).state =
                  const ChatViewFilter();
              ref.read(chatSearchOpenProvider.notifier).state = false;
            },
            child: Text(l.chatFilterShowAll),
          ),
        ],
      ),
    );
  }
}

String chatFilterPlatformName(Platform platform) => switch (platform) {
      Platform.youtube => 'YouTube',
      Platform.twitch => 'Twitch',
      Platform.kick => 'Kick',
    };

String chatFilterRoleName(AppLocalizations l, ChatViewRole role) =>
    switch (role) {
      ChatViewRole.all => l.chatFilterAll,
      ChatViewRole.members => l.chatFilterMembers,
      ChatViewRole.moderators => l.chatFilterModerators,
      ChatViewRole.highlighted => l.chatFilterHighlighted,
    };

/// A chat message that opens its actions on click: show it on stream or
/// copy it.
class _ChatMessageEntry extends ConsumerWidget {
  const _ChatMessageEntry({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _showActions(context, ref, details.globalPosition),
      onSecondaryTapUp: (details) =>
          _showActions(context, ref, details.globalPosition),
      child: ChatBubble(message: message),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final l = AppLocalizations.of(context)!;
    final overlayReady =
        ref.read(overlayServerStateProvider).valueOrNull?.phase ==
            OverlayServerPhase.ready;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<String>(
      context: context,
      color: const Color(0xFF1E1E1E),
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          key: const Key('message-show-on-stream'),
          value: 'stream',
          enabled: overlayReady,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cast_rounded, size: 18),
            title: Text(l.messageShowOnStream),
            subtitle:
                overlayReady ? null : Text(l.messageShowOnStreamNeedsOverlay),
          ),
        ),
        PopupMenuItem(
          key: const Key('message-copy'),
          value: 'copy',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_rounded, size: 18),
            title: Text(l.messageCopy),
          ),
        ),
      ],
    );
    if (!context.mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    void notify(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(milliseconds: 1600),
      ));
    switch (action) {
      case 'stream':
        final delivery =
            ref.read(appControllerProvider).featureMessageOnStream(message);
        if (delivery.status == FeaturedMessageStatus.noReceiver) {
          notify(l.messageNoAlertsOverlay);
          return;
        }
        notify(l.messageSentToOverlay);
        final status = await delivery.completed;
        if (!context.mounted) return;
        if (status == FeaturedMessageStatus.rendered) {
          notify(l.messageShownOnStream);
        } else if (status == FeaturedMessageStatus.disconnected) {
          notify(l.messageOverlayDisconnected);
        } else if (status == FeaturedMessageStatus.sent) {
          notify(l.messageOverlayUnconfirmed);
        }
      case 'copy':
        final author = message.author.name.trim();
        final text = message.plainText.trim();
        await Clipboard.setData(
          ClipboardData(text: author.isEmpty ? text : '$author: $text'),
        );
        notify(l.messageCopied);
    }
  }
}

/// Searches the chat window: only messages containing the text stay.
class _ChatSearchField extends ConsumerStatefulWidget {
  const _ChatSearchField();

  @override
  ConsumerState<_ChatSearchField> createState() => _ChatSearchFieldState();
}

class _ChatSearchFieldState extends ConsumerState<_ChatSearchField> {
  late final _controller = TextEditingController(
    text: ref.read(chatViewFilterProvider).query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() {
    final filter = ref.read(chatViewFilterProvider.notifier);
    filter.state = filter.state.withQuery('');
    ref.read(chatSearchOpenProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: TextField(
          key: const Key('chat-search-field'),
          controller: _controller,
          autofocus: true,
          onChanged: (value) {
            final filter = ref.read(chatViewFilterProvider.notifier);
            filter.state = filter.state.withQuery(value);
          },
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: l.chatSearchHint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            suffixIcon: IconButton(
              key: const Key('chat-search-close'),
              tooltip: l.chatSearchClose,
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: _close,
            ),
            filled: true,
            fillColor: const Color(0xEE1A1A1A),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
            ),
          ),
        ),
      ),
    );
  }
}

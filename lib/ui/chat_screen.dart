import 'dart:async';
import 'dart:io' as io;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/app_controller.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/models/youtube_live_metadata.dart';
import 'package:airstream/models/chat_message.dart'
    show Platform, YoutubeStreamOrientation;
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/kick_service.dart' show ServiceStatus;
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/speech_model_catalog.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/services/tts_service.dart'
    show TtsLoadPhase, TtsLoadState;
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_input_normalizer.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/chat_alignment.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
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
  bool _sidebarVisible = true;
  bool _topBarVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    FocusManager.instance.addEarlyKeyEventHandler(_handleGlobalKeyEvent);
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
      setState(() => _autoScroll = atBottom);
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

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
    final s = ref.watch(settingsProvider);
    final scaffoldBg = const Color(0xFF0D0D0D).withValues(alpha: s.bgOpacity);
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

  Widget _chatList() {
    final l = AppLocalizations.of(context)!;
    final chat = ref.watch(chatProvider);
    final settings = ref.watch(settingsProvider);
    final obsState =
        ref.watch(obsStateProvider).valueOrNull ?? const ObsState();
    final showObsCard = settings.obsEnabled;
    final obsBottomSpacing =
        settings.messageGap < 6 ? 6.0 : settings.messageGap;
    final obsReservedSpace = 56.0 + obsBottomSpacing;

    Widget buildPane(Widget child) {
      if (!showObsCard) return child;
      return Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            left: 24,
            right: 24,
            bottom: obsBottomSpacing,
            child: Align(
              alignment: chatHorizontalAlignment(settings.chatTextAlign),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: _ObsStatusCard(
                  state: obsState,
                  compact: true,
                  styleSettings: settings,
                  displaySettings: settings,
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
      data: (messages) {
        if (messages.isEmpty) {
          final sessionPhase = ref.watch(chatSessionPhaseProvider);
          final hasChannels = (settings.youtubeEnabled &&
                  (settings.youtubeDualStreamEnabled
                      ? settings.youtubeHorizontalUrl.trim().isNotEmpty &&
                          settings.youtubeVerticalUrl.trim().isNotEmpty
                      : settings.youtubeHandle.trim().isNotEmpty ||
                          settings.youtubeLiveId.trim().isNotEmpty)) ||
              (settings.twitchEnabled && settings.twitchChannel.isNotEmpty) ||
              (settings.kickEnabled && settings.kickSlug.isNotEmpty);
          final text = hasChannels
              ? switch (sessionPhase) {
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

        return buildPane(
          Stack(
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
                itemBuilder: (_, i) => ChatBubble(
                  key: ValueKey(messages[messages.length - 1 - i].dedupeKey),
                  message: messages[messages.length - 1 - i],
                ),
              ),
              if (!_autoScroll)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: const Color(0xFF53FC18),
                    foregroundColor: Colors.black,
                    onPressed: () {
                      setState(() => _autoScroll = true);
                      _scrollToBottom();
                    },
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

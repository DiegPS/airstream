import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/speech/speech_model_catalog.dart';
import 'package:airstream/services/tts/tts_model_catalog.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/chat_alignment.dart';
import 'package:airstream/ui/widgets/chat_bubble.dart';
import 'package:airstream/ui/widgets/sidebar_tab_bar.dart';
import 'package:airstream/ui/widgets/styled_slider_row.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:airstream/ui/widgets/window_control_bar.dart';
import 'package:airstream/window/window_state.dart';

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

    final isToggleClickThroughShortcut =
        event.logicalKey == LogicalKeyboardKey.keyC &&
            keyboard.isControlPressed &&
            keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (isToggleClickThroughShortcut) {
      unawaited(windowNotifier.toggleClickThrough());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
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

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
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
          final isRunning = ref.watch(chatConnectionProvider);
          final hasChannels = settings.youtubeHandle.isNotEmpty ||
              settings.youtubeLiveId.isNotEmpty ||
              settings.twitchChannel.isNotEmpty ||
              settings.kickSlug.isNotEmpty;
          final text = hasChannels
              ? (isRunning
                  ? l.listeningForMessages
                  : l.channelsSavedStartPrompt)
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

class _DesktopTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DesktopTopBar({
    required this.sidebarVisible,
    required this.onToggleSidebar,
  });

  static const _barHeight = 38.0;
  static const _accent = Color(0xFF53FC18);

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayUrl = ref.watch(overlayUrlProvider);
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final isRunning = ref.watch(chatConnectionProvider);
    final hasChannels = settings.youtubeHandle.isNotEmpty ||
        settings.youtubeLiveId.isNotEmpty ||
        settings.twitchChannel.isNotEmpty ||
        settings.kickSlug.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          border: Border(
            bottom: BorderSide(color: Color(0xFF222222)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: _barHeight,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DragToMoveArea(
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _TitleBarCaption(overlayUrl: overlayUrl),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      _TopBarActionButton(
                        label: isRunning ? l.stop : l.start,
                        icon: isRunning
                            ? Icons.stop_circle_rounded
                            : Icons.play_arrow_rounded,
                        enabled: hasChannels,
                        accentColor:
                            isRunning ? const Color(0xFFFF5252) : _accent,
                        onTap: hasChannels
                            ? () {
                                ref
                                    .read(chatConnectionProvider.notifier)
                                    .state = !isRunning;
                              }
                            : null,
                      ),
                      const SizedBox(width: 6),
                      _TopBarIconButton(
                        tooltip: sidebarVisible
                            ? l.hideSidebarTooltip
                            : l.showSidebarTooltip,
                        icon: sidebarVisible
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        active: sidebarVisible,
                        onTap: onToggleSidebar,
                      ),
                      const SizedBox(width: 6),
                      const WindowControlBar(),
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
}

class _TitleBarCaption extends StatelessWidget {
  const _TitleBarCaption({required this.overlayUrl});

  final String? overlayUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF53FC18).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: const Color(0xFF53FC18).withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.forum_rounded,
              color: Color(0xFF53FC18),
              size: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'AIRSTREAM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(width: 12),
        _TitleBarCenterStatus(overlayUrl: overlayUrl),
      ],
    );
  }
}

class _TitleBarCenterStatus extends ConsumerWidget {
  const _TitleBarCenterStatus({required this.overlayUrl});

  final String? overlayUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConnectionDots(),
          if (overlayUrl != null) ...[
            const SizedBox(width: 8),
            const Text(
              '•',
              style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                overlayUrl!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBarActionButton extends StatelessWidget {
  const _TopBarActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.accentColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        enabled ? accentColor.withValues(alpha: 0.16) : Colors.transparent;
    final foregroundColor = enabled ? accentColor : const Color(0xFF5E5E5E);

    return Tooltip(
      message: label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? accentColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foregroundColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = active
        ? const Color(0xFF53FC18).withValues(alpha: 0.15)
        : Colors.transparent;
    final foregroundColor =
        active ? const Color(0xFF53FC18) : const Color(0xFFAAAAAA);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? const Color(0xFF53FC18).withValues(alpha: 0.3)
                    : const Color(0xFF2E2E2E),
              ),
            ),
            child: Icon(icon, size: 15, color: foregroundColor),
          ),
        ),
      ),
    );
  }
}

class _DesktopResizeFrame extends StatelessWidget {
  const _DesktopResizeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DragToResizeArea(
      resizeEdgeSize: 8,
      resizeEdgeColor: Colors.transparent,
      child: child,
    );
  }
}

class _SettingsSidebar extends ConsumerStatefulWidget {
  const _SettingsSidebar();

  @override
  ConsumerState<_SettingsSidebar> createState() => _SettingsSidebarState();
}

class _SettingsSidebarState extends ConsumerState<_SettingsSidebar> {
  int _selectedTab = 0;

  late TextEditingController _ytHandle;
  late TextEditingController _twitch;
  late TextEditingController _kick;
  late TextEditingController _port;
  late TextEditingController _obsHost;
  late TextEditingController _obsPassword;
  late TextEditingController _overlayChromaColorCtrl;
  late TextEditingController _overlayTextStrokeColorCtrl;
  late TextEditingController _overlaySuperChatBarColorCtrl;
  late TextEditingController _ttsTestCtrl;
  late TextEditingController _ttsPrefixCtrl;
  late TextEditingController _ttsSeparatorCtrl;
  late TextEditingController _ttsReferenceTextCtrl;
  late TextEditingController _voiceWakeWordCtrl;
  late TextEditingController _blockedUsersCtrl;
  late TextEditingController _blockedWordsCtrl;

  late FocusNode _ytFocus;
  late FocusNode _twitchFocus;
  late FocusNode _kickFocus;
  late FocusNode _portFocus;
  late FocusNode _obsHostFocus;
  late FocusNode _obsPasswordFocus;
  late FocusNode _overlayChromaColorFocus;
  late FocusNode _overlayTextStrokeColorFocus;
  late FocusNode _overlaySuperChatBarColorFocus;
  late FocusNode _ttsPrefixFocus;
  late FocusNode _ttsSeparatorFocus;
  late FocusNode _ttsReferenceTextFocus;
  late FocusNode _voiceWakeWordFocus;
  late FocusNode _blockedUsersFocus;
  late FocusNode _blockedWordsFocus;
  Timer? _textSettingsDebounce;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ytHandle = TextEditingController(text: _youtubeInputValue(s));
    _twitch = TextEditingController(text: s.twitchChannel);
    _kick = TextEditingController(text: s.kickSlug);
    _port = TextEditingController(text: s.overlayPort.toString());
    _obsHost = TextEditingController(text: s.obsHost);
    _obsPassword = TextEditingController(text: s.obsPassword);
    _overlayChromaColorCtrl = TextEditingController(text: s.overlayChromaColor);
    _overlayTextStrokeColorCtrl =
        TextEditingController(text: s.overlayTextStrokeColor);
    _overlaySuperChatBarColorCtrl =
        TextEditingController(text: s.overlaySuperChatBarColor);
    _ttsTestCtrl = TextEditingController();
    _ttsPrefixCtrl = TextEditingController(text: s.ttsCommandPrefix);
    _ttsSeparatorCtrl = TextEditingController(text: s.ttsSeparatorText);
    _ttsReferenceTextCtrl = TextEditingController(text: s.ttsReferenceText);
    _voiceWakeWordCtrl = TextEditingController(text: s.voiceCommandsWakeWord);
    _blockedUsersCtrl =
        TextEditingController(text: _formatFilterList(s.blockedUsers));
    _blockedWordsCtrl =
        TextEditingController(text: _formatFilterList(s.blockedWords));

    _ytFocus = FocusNode();
    _twitchFocus = FocusNode();
    _kickFocus = FocusNode();
    _portFocus = FocusNode();
    _obsHostFocus = FocusNode();
    _obsPasswordFocus = FocusNode();
    _overlayChromaColorFocus = FocusNode();
    _overlayTextStrokeColorFocus = FocusNode();
    _overlaySuperChatBarColorFocus = FocusNode();
    _ttsPrefixFocus = FocusNode();
    _ttsSeparatorFocus = FocusNode();
    _ttsReferenceTextFocus = FocusNode();
    _voiceWakeWordFocus = FocusNode();
    _blockedUsersFocus = FocusNode();
    _blockedWordsFocus = FocusNode();

    for (final node in [
      _ytFocus,
      _twitchFocus,
      _kickFocus,
      _portFocus,
      _obsHostFocus,
      _obsPasswordFocus,
      _overlayChromaColorFocus,
      _overlayTextStrokeColorFocus,
      _overlaySuperChatBarColorFocus,
      _ttsPrefixFocus,
      _ttsSeparatorFocus,
      _ttsReferenceTextFocus,
      _voiceWakeWordFocus,
      _blockedUsersFocus,
      _blockedWordsFocus,
    ]) {
      node.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _textSettingsDebounce?.cancel();

    for (final node in [
      _ytFocus,
      _twitchFocus,
      _kickFocus,
      _portFocus,
      _obsHostFocus,
      _obsPasswordFocus,
      _overlayChromaColorFocus,
      _overlayTextStrokeColorFocus,
      _overlaySuperChatBarColorFocus,
      _ttsPrefixFocus,
      _ttsSeparatorFocus,
      _ttsReferenceTextFocus,
      _voiceWakeWordFocus,
      _blockedUsersFocus,
      _blockedWordsFocus,
    ]) {
      node.removeListener(_handleFocusChange);
      node.dispose();
    }

    _ytHandle.dispose();
    _twitch.dispose();
    _kick.dispose();
    _port.dispose();
    _obsHost.dispose();
    _obsPassword.dispose();
    _overlayChromaColorCtrl.dispose();
    _overlayTextStrokeColorCtrl.dispose();
    _overlaySuperChatBarColorCtrl.dispose();
    _ttsTestCtrl.dispose();
    _ttsPrefixCtrl.dispose();
    _ttsSeparatorCtrl.dispose();
    _ttsReferenceTextCtrl.dispose();
    _voiceWakeWordCtrl.dispose();
    _blockedUsersCtrl.dispose();
    _blockedWordsCtrl.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final anyHasFocus = [
      _ytFocus,
      _twitchFocus,
      _kickFocus,
      _portFocus,
      _obsHostFocus,
      _obsPasswordFocus,
      _overlayChromaColorFocus,
      _overlayTextStrokeColorFocus,
      _overlaySuperChatBarColorFocus,
      _ttsPrefixFocus,
      _ttsSeparatorFocus,
      _ttsReferenceTextFocus,
      _voiceWakeWordFocus,
      _blockedUsersFocus,
      _blockedWordsFocus,
    ].any((n) => n.hasFocus);

    if (!anyHasFocus) {
      _saveTextSettings();
    }
  }

  void _queueTextSettingsSave() {
    _textSettingsDebounce?.cancel();
    _textSettingsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _saveTextSettings();
      }
    });
  }

  Future<void> _saveTextSettings() async {
    _textSettingsDebounce?.cancel();
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    final normalizedTwitch = _normalizePlatformChannel(_twitch.text);
    final normalizedKick = _normalizePlatformChannel(_kick.text);
    final blockedUsers = _parseFilterList(_blockedUsersCtrl.text);
    final blockedWords = _parseFilterList(_blockedWordsCtrl.text);
    final next = current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: '',
      twitchChannel: normalizedTwitch,
      kickSlug: normalizedKick,
      blockedUsers: blockedUsers,
      blockedWords: blockedWords,
      overlayPort: int.tryParse(_port.text.trim()) ?? current.overlayPort,
      overlayChromaColor: _normalizeHexColor(
        _overlayChromaColorCtrl.text,
        fallback: current.overlayChromaColor,
      ),
      overlayTextStrokeColor: _normalizeHexColor(
        _overlayTextStrokeColorCtrl.text,
        fallback: current.overlayTextStrokeColor,
      ),
      overlaySuperChatBarColor: _normalizeHexColor(
        _overlaySuperChatBarColorCtrl.text,
        fallback: current.overlaySuperChatBarColor,
      ),
      obsHost: _obsHost.text.trim(),
      obsPassword: _obsPassword.text,
      ttsCommandPrefix: _ttsPrefixCtrl.text,
      ttsSeparatorText: _ttsSeparatorCtrl.text,
      ttsReferenceText: _ttsReferenceTextCtrl.text,
      voiceCommandsWakeWord: _voiceWakeWordCtrl.text.trim(),
    );

    if (current.youtubeHandle == next.youtubeHandle &&
        current.twitchChannel == next.twitchChannel &&
        current.kickSlug == next.kickSlug &&
        _listEquals(current.blockedUsers, next.blockedUsers) &&
        _listEquals(current.blockedWords, next.blockedWords) &&
        current.overlayPort == next.overlayPort &&
        current.overlayChromaColor == next.overlayChromaColor &&
        current.overlayTextStrokeColor == next.overlayTextStrokeColor &&
        current.overlaySuperChatBarColor == next.overlaySuperChatBarColor &&
        current.obsHost == next.obsHost &&
        current.obsPassword == next.obsPassword &&
        current.ttsCommandPrefix == next.ttsCommandPrefix &&
        current.ttsSeparatorText == next.ttsSeparatorText &&
        current.ttsReferenceText == next.ttsReferenceText &&
        current.voiceCommandsWakeWord == next.voiceCommandsWakeWord) {
      return;
    }

    await notifier.update(next);
  }

  Future<void> _startChat() async {
    await _saveTextSettings();
    ref.read(chatConnectionProvider.notifier).state = true;
  }

  Future<void> _stopChat() async {
    ref.read(chatConnectionProvider.notifier).state = false;
  }

  static void _syncController(
    TextEditingController controller,
    FocusNode focusNode,
    String value,
  ) {
    if (focusNode.hasFocus || controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  static String _youtubeInputValue(SettingsModel s) {
    final liveId = s.youtubeLiveId.trim();
    if (liveId.isNotEmpty) return liveId;
    return s.youtubeHandle;
  }

  static String _normalizePlatformChannel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    try {
      final uri = Uri.parse(trimmed);
      if (uri.hasScheme && uri.host.isNotEmpty) {
        final parts =
            uri.pathSegments.where((part) => part.isNotEmpty).toList();
        final lastPath = parts.isNotEmpty ? parts.last : '';
        return lastPath.replaceFirst(RegExp(r'^@'), '').trim();
      }
    } catch (_) {}

    return trimmed.replaceFirst(RegExp(r'^@'), '').trim();
  }

  static String _normalizeHexColor(
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim().toUpperCase();
    final normalized = trimmed.startsWith('#') ? trimmed : '#$trimmed';
    final isValid = RegExp(r'^#[0-9A-F]{6}$').hasMatch(normalized);
    return isValid ? normalized : fallback.toUpperCase();
  }

  static List<String> _parseFilterList(String raw) {
    final seen = <String>{};
    final values = <String>[];

    for (final part in raw.split(RegExp(r'[\r\n,;]+'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      values.add(trimmed);
    }

    return values;
  }

  static String _formatFilterList(List<String> values) => values.join('\n');

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(settingsProvider.notifier);
    final isRunning = ref.watch(chatConnectionProvider);
    final connectionStatus =
        ref.watch(connectionStatusProvider).valueOrNull ?? {};
    final youtubeBadgeValue = ref.watch(youtubeBadgeValueProvider).valueOrNull;
    final appController = ref.read(appControllerProvider);
    final ttsLoadState = ref.watch(ttsLoadStateProvider).valueOrNull;
    final ttsBusy = ref.watch(ttsBusyProvider).valueOrNull ?? false;
    final captionsState = ref.watch(liveCaptionsStateProvider).valueOrNull ??
        const LiveCaptionsState();
    final obsState =
        ref.watch(obsStateProvider).valueOrNull ?? const ObsState();
    final overlayUrl = ref.watch(overlayUrlProvider);
    final overlayClientCount =
        ref.watch(overlayClientCountProvider).valueOrNull ?? 0;
    final overlayCopyUrl = overlayUrl ?? 'http://localhost:${s.overlayPort}';
    final alertsCopyUrl = '$overlayCopyUrl/alerts';
    final captionsCopyUrl = '$overlayCopyUrl/captions';

    _syncController(_ytHandle, _ytFocus, _youtubeInputValue(s));
    _syncController(_twitch, _twitchFocus, s.twitchChannel);
    _syncController(_kick, _kickFocus, s.kickSlug);
    _syncController(_port, _portFocus, s.overlayPort.toString());
    _syncController(_obsHost, _obsHostFocus, s.obsHost);
    _syncController(_obsPassword, _obsPasswordFocus, s.obsPassword);
    _syncController(
      _overlayChromaColorCtrl,
      _overlayChromaColorFocus,
      s.overlayChromaColor,
    );
    _syncController(
      _overlayTextStrokeColorCtrl,
      _overlayTextStrokeColorFocus,
      s.overlayTextStrokeColor,
    );
    _syncController(
      _overlaySuperChatBarColorCtrl,
      _overlaySuperChatBarColorFocus,
      s.overlaySuperChatBarColor,
    );
    _syncController(_ttsPrefixCtrl, _ttsPrefixFocus, s.ttsCommandPrefix);
    _syncController(
      _ttsSeparatorCtrl,
      _ttsSeparatorFocus,
      s.ttsSeparatorText,
    );
    _syncController(
      _ttsReferenceTextCtrl,
      _ttsReferenceTextFocus,
      s.ttsReferenceText,
    );
    _syncController(
      _voiceWakeWordCtrl,
      _voiceWakeWordFocus,
      s.voiceCommandsWakeWord,
    );
    _syncController(
      _blockedUsersCtrl,
      _blockedUsersFocus,
      _formatFilterList(s.blockedUsers),
    );
    _syncController(
      _blockedWordsCtrl,
      _blockedWordsFocus,
      _formatFilterList(s.blockedWords),
    );

    final hasChannels = _ytHandle.text.trim().isNotEmpty ||
        _twitch.text.trim().isNotEmpty ||
        _kick.text.trim().isNotEmpty;
    final youtubeState = connectionStatus['youtube'];
    final twitchState = connectionStatus['twitch'];
    final kickState = connectionStatus['kick'];
    final youtubeError =
        youtubeState?.$1 == ServiceStatus.error ? youtubeState?.$2 : null;
    final twitchError =
        twitchState?.$1 == ServiceStatus.error ? twitchState?.$2 : null;
    final kickError =
        kickState?.$1 == ServiceStatus.error ? kickState?.$2 : null;

    final tabs = [
      SidebarTabItem(
        icon: Icons.sensors_rounded,
        label: l.connections,
        badgeColor: isRunning ? const Color(0xFF53FC18) : null,
      ),
      SidebarTabItem(
        icon: Icons.record_voice_over_rounded,
        label: l.ttsAndVoice,
        badgeColor: (s.ttsEnabled || s.liveCaptionsEnabled)
            ? const Color(0xFF53FC18)
            : null,
      ),
      SidebarTabItem(
        icon: Icons.palette_outlined,
        label: l.appearance,
      ),
      SidebarTabItem(
        icon: Icons.videocam_outlined,
        label: l.obsAndOverlay,
        badgeColor: obsState.connected ? const Color(0xFF5B9CFF) : null,
      ),
      SidebarTabItem(
        icon: Icons.tune_rounded,
        label: l.systemTab,
      ),
    ];

    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF141414),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sidebarHeader(
                    l: l,
                    youtubeValue: isRunning ? youtubeBadgeValue : null,
                    twitchValue: isRunning ? s.twitchChannel : '',
                    kickValue: isRunning ? s.kickSlug : '',
                    statusMap: connectionStatus,
                  ),
                  const SizedBox(height: 12),
                  SidebarTabBar(
                    selectedIndex: _selectedTab,
                    onTabSelected: (index) =>
                        setState(() => _selectedTab = index),
                    tabs: tabs,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF242424)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                child: switch (_selectedTab) {
                  0 => _buildChannelsTab(
                      context,
                      l,
                      s,
                      notifier,
                      isRunning,
                      hasChannels,
                      youtubeError,
                      twitchError,
                      kickError,
                    ),
                  1 => _buildAudioTab(
                      context,
                      l,
                      s,
                      notifier,
                      appController,
                      ttsLoadState,
                      ttsBusy,
                      captionsState,
                      captionsCopyUrl,
                    ),
                  2 => _buildStyleTab(
                      context,
                      l,
                      s,
                      notifier,
                    ),
                  3 => _buildObsTab(
                      context,
                      l,
                      s,
                      notifier,
                      appController,
                      obsState,
                      overlayClientCount,
                      overlayCopyUrl,
                      alertsCopyUrl,
                    ),
                  _ => _buildSystemTab(
                      context,
                      l,
                      s,
                      notifier,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    bool isRunning,
    bool hasChannels,
    String? youtubeError,
    String? twitchError,
    String? kickError,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.connections,
          icon: Icons.sensors_rounded,
          children: [
            _label(l.youtubeInputLabel),
            _field(
              _ytHandle,
              l.youtubeInputHint,
              focusNode: _ytFocus,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _ytHandle.clear();
                setState(() {});
                _saveTextSettings();
              },
            ),
            if (youtubeError != null && youtubeError.isNotEmpty) ...[
              const SizedBox(height: 8),
              _inlineErrorMessage(l, 'YouTube'),
            ],
            const SizedBox(height: 12),
            _label(l.twitchChannel),
            _field(
              _twitch,
              l.channelNameHint,
              focusNode: _twitchFocus,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _twitch.clear();
                setState(() {});
                _saveTextSettings();
              },
            ),
            if (twitchError != null && twitchError.isNotEmpty) ...[
              const SizedBox(height: 8),
              _inlineErrorMessage(l, 'Twitch'),
            ],
            const SizedBox(height: 12),
            _label(l.kickSlug),
            _field(
              _kick,
              l.channelIdentifierHint,
              focusNode: _kickFocus,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _kick.clear();
                setState(() {});
                _saveTextSettings();
              },
            ),
            if (kickError != null && kickError.isNotEmpty) ...[
              const SizedBox(height: 8),
              _inlineErrorMessage(l, 'Kick'),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed:
                    isRunning ? _stopChat : (hasChannels ? _startChat : null),
                icon: Icon(
                  isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 20,
                ),
                label: Text(
                  isRunning ? l.stopChat : l.startChat,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning
                      ? const Color(0xFFFF5252)
                      : const Color(0xFF53FC18),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: const Color(0xFF262626),
                  disabledForegroundColor: Colors.white38,
                ),
              ),
            ),
          ],
        ),
        UiCard(
          title: l.filters,
          icon: Icons.filter_alt_outlined,
          description: l.filtersDescription,
          isCollapsible: true,
          initiallyExpanded:
              s.blockedUsers.isNotEmpty || s.blockedWords.isNotEmpty,
          children: [
            _label(l.blockedUsers),
            _field(
              _blockedUsersCtrl,
              l.blockedUsersHint,
              focusNode: _blockedUsersFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _blockedUsersCtrl.clear();
                setState(() {});
                _queueTextSettingsSave();
              },
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 4),
            Text(
              l.blockedUsersHelp,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),
            _label(l.blockedWordsOrPhrases),
            _field(
              _blockedWordsCtrl,
              l.blockedWordsHint,
              focusNode: _blockedWordsFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _blockedWordsCtrl.clear();
                setState(() {});
                _queueTextSettingsSave();
              },
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 4),
            Text(
              l.blockedWordsHelp,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    AppController appController,
    TtsLoadState? ttsLoadState,
    bool ttsBusy,
    LiveCaptionsState captionsState,
    String captionsCopyUrl,
  ) {
    Future<void> removeSelectedTtsModel() async {
      final model = TtsModelCatalog.byId(s.ttsModelId);
      final remove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.removeTtsModelTitle(model.name)),
          content: Text(l.removeTtsModelConfirmationNamed(model.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.remove),
            ),
          ],
        ),
      );
      if (remove != true || !context.mounted) return;
      try {
        await notifier.update(s.copyWith(ttsEnabled: false));
        await appController.removeTtsModel(s.ttsModelId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.ttsModelRemoved)),
          );
        }
      } catch (error) {
        debugPrint('Could not remove TTS model: $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.ttsModelRemovalFailed)),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.ttsCardTitle,
          icon: Icons.record_voice_over_rounded,
          description: l.ttsDescription,
          trailing: Switch(
            value: s.ttsEnabled,
            onChanged: (v) => notifier.update(s.copyWith(ttsEnabled: v)),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.ttsEnabled) ...[
              if (ttsLoadState != null) ...[
                _ttsStatusCard(
                  l,
                  ttsLoadState,
                  onDownload: () async {
                    try {
                      await appController.downloadTtsModel();
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 8),
              ],
              Builder(builder: (context) {
                final model = TtsModelCatalog.byId(s.ttsModelId);
                final engineId =
                    model.family == TtsModelFamily.vits ? 'piper' : model.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dropdownRow(
                      l.ttsSelectedModel,
                      engineId,
                      const [
                        'supertonic-3-hybrid',
                        'piper',
                        'kitten-nano-en-v0-8-int8',
                        'kokoro-en-v0-19-int8',
                        'matcha-ljspeech-en',
                        'pocket-tts-int8',
                        'zipvoice-distill-int8-zh-en',
                      ],
                      (id) {
                        final next = id == 'piper'
                            ? (s.ttsLanguage == 'es-ES'
                                ? TtsModelCatalog.piperSpain
                                : TtsModelCatalog.piperMexico)
                            : TtsModelCatalog.byId(id);
                        notifier.update(s.copyWith(
                          ttsModelId: next.id,
                          ttsVoice: next.voices.first.id,
                          ttsLanguage: next.languages.first.code,
                          ttsSteps: next.defaultSteps,
                        ));
                      },
                      optionLabel: _ttsEngineName,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(
                        _ttsModelDescription(l, model.id),
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        l.ttsModelStorageDetails(
                          _formatByteSize(model.downloadBytes),
                          _formatByteSize(model.installedBytes),
                        ),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (model.licenseNotice != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          model.licenseNotice!,
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                );
              }),
              if (ttsLoadState?.isReady ?? false) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: removeSelectedTtsModel,
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: Text(l.removeTtsModel),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white38,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Builder(builder: (context) {
                final model = TtsModelCatalog.byId(s.ttsModelId);
                final voice = model.voice(s.ttsVoice).id;
                final languageOptions = model.family == TtsModelFamily.vits
                    ? const ['es-MX', 'es-ES']
                    : model.languages.map((item) => item.code).toList();
                final language = model.family == TtsModelFamily.vits
                    ? (model.id == TtsModelCatalog.piperSpain.id
                        ? 'es-ES'
                        : 'es-MX')
                    : (model.supportsLanguage(s.ttsLanguage)
                        ? s.ttsLanguage
                        : model.languages.first.code);

                return Column(
                  children: [
                    _dropdownRow(
                      l.voice,
                      voice,
                      model.voices.map((v) => v.id).toList(),
                      (v) => notifier.update(s.copyWith(ttsVoice: v)),
                      optionLabel: (id) => _ttsVoiceLabel(l, model, id),
                    ),
                    _dropdownRow(
                      l.language,
                      language,
                      languageOptions,
                      (value) {
                        if (model.family != TtsModelFamily.vits) {
                          notifier.update(s.copyWith(ttsLanguage: value));
                          return;
                        }
                        final next = value == 'es-ES'
                            ? TtsModelCatalog.piperSpain
                            : TtsModelCatalog.piperMexico;
                        notifier.update(s.copyWith(
                          ttsModelId: next.id,
                          ttsVoice: next.voices.first.id,
                          ttsLanguage: value,
                          ttsSteps: next.defaultSteps,
                        ));
                      },
                      optionLabel: (id) => _ttsLanguageLabel(l, id),
                    ),
                    if (model.referenceMode != TtsReferenceMode.none) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.ttsReferenceAudioPath.isEmpty
                                  ? l.usingBundledVoice(
                                      _ttsVoiceLabel(l, model, voice))
                                  : p.basename(s.ttsReferenceAudioPath),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final selected = await openFile(
                                acceptedTypeGroups: const [
                                  XTypeGroup(
                                    label: 'WAV',
                                    extensions: ['wav'],
                                  ),
                                ],
                              );
                              if (selected == null || !context.mounted) return;
                              await notifier.update(s.copyWith(
                                ttsReferenceAudioPath: selected.path,
                              ));
                            },
                            icon:
                                const Icon(Icons.audio_file_rounded, size: 15),
                            label: Text(l.chooseWav),
                          ),
                          if (s.ttsReferenceAudioPath.isNotEmpty)
                            IconButton(
                              tooltip: l.useBundledSample,
                              onPressed: () => notifier.update(s.copyWith(
                                ttsReferenceAudioPath: '',
                                ttsReferenceText: '',
                              )),
                              icon: const Icon(Icons.close_rounded, size: 16),
                            ),
                        ],
                      ),
                      if (model.needsReferenceText &&
                          s.ttsReferenceAudioPath.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _label(l.referenceTranscript),
                        _field(
                          _ttsReferenceTextCtrl,
                          l.referenceTranscriptHint,
                          focusNode: _ttsReferenceTextFocus,
                          onChanged: (_) => _queueTextSettingsSave(),
                          onSubmitted: (_) => _saveTextSettings(),
                        ),
                      ],
                    ],
                    if (model.family == TtsModelFamily.supertonic ||
                        model.family == TtsModelFamily.zipvoice ||
                        model.family == TtsModelFamily.pocket)
                      _dropdownRow(
                        l.quality,
                        const [3, 4, 5, 6, 8, 12].contains(s.ttsSteps)
                            ? s.ttsSteps.toString()
                            : model.defaultSteps.toString(),
                        const ['3', '4', '5', '6', '8', '12'],
                        (v) =>
                            notifier.update(s.copyWith(ttsSteps: int.parse(v))),
                        optionLabel: (v) => l.ttsInferenceSteps(int.parse(v)),
                      ),
                    StyledSliderRow(
                      label: l.speed,
                      value: s.ttsSpeed,
                      min: 0.6,
                      max: 1.6,
                      divisions: 20,
                      unit: 'x',
                      onChanged: (v) =>
                          notifier.update(s.copyWith(ttsSpeed: v)),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              _label(l.testText),
              _field(_ttsTestCtrl, l.ttsTestTextHint),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (ttsBusy || (ttsLoadState?.isLoading ?? false))
                      ? null
                      : () => appController.testTts(
                            _ttsTestCtrl.text.trim().isEmpty
                                ? l.ttsDefaultTestText
                                : _ttsTestCtrl.text,
                          ),
                  icon: const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(
                    ttsBusy
                        ? l.playingTts
                        : (ttsLoadState?.isLoading ?? false)
                            ? l.loadingTts
                            : l.testTts,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF53FC18),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _switchRow(
                l.membersOnly,
                s.ttsMembersOnly,
                (v) => notifier.update(s.copyWith(ttsMembersOnly: v)),
              ),
              _switchRow(
                l.commandMode,
                s.ttsCommandMode,
                (v) => notifier.update(s.copyWith(ttsCommandMode: v)),
              ),
              if (s.ttsCommandMode) ...[
                const SizedBox(height: 8),
                _label(l.commandPrefix),
                _field(
                  _ttsPrefixCtrl,
                  l.commandPrefixHint,
                  focusNode: _ttsPrefixFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                _switchRow(
                  l.ignoreCommandCase,
                  s.ttsCommandIgnoreCase,
                  (v) => notifier.update(s.copyWith(ttsCommandIgnoreCase: v)),
                ),
              ],
              const SizedBox(height: 8),
              _label(l.separatorText),
              _field(
                _ttsSeparatorCtrl,
                l.separatorTextHint,
                focusNode: _ttsSeparatorFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
            ] else ...[
              Text(
                l.ttsDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        UiCard(
          title: l.localCaptions,
          icon: Icons.subtitles_rounded,
          description: l.captionsDescription,
          trailing: Switch(
            value: s.liveCaptionsEnabled,
            onChanged: (v) => unawaited(notifier.update(
              s.copyWith(liveCaptionsEnabled: v),
            )),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.liveCaptionsEnabled) ...[
              Builder(builder: (context) {
                final model = SpeechModelCatalog.byId(s.liveCaptionsModelId);
                final source =
                    model.supportsLanguage(s.liveCaptionsSourceLanguage)
                        ? s.liveCaptionsSourceLanguage
                        : 'es';
                final targets = model.targetsFor(source);

                return Column(
                  children: [
                    _dropdownRow(
                      l.spokenLanguage,
                      source,
                      model.languages.map((item) => item.code).toList(),
                      (value) => notifier.update(s.copyWith(
                        liveCaptionsSourceLanguage: value,
                        liveCaptionsTargetLanguage: value,
                      )),
                      optionLabel: (value) => _languageLabel(l, value),
                    ),
                    _dropdownRow(
                      l.captionOutput,
                      model.supportsDirection(
                              source, s.liveCaptionsTargetLanguage)
                          ? s.liveCaptionsTargetLanguage
                          : source,
                      targets.map((item) => item.code).toList(),
                      (value) => notifier.update(s.copyWith(
                        liveCaptionsTargetLanguage: value,
                      )),
                      optionLabel: (value) => _languageLabel(l, value),
                    ),
                  ],
                );
              }),
              _switchRow(
                l.sendCaptionsToObs,
                s.liveCaptionsOverlayEnabled,
                (value) => notifier.update(
                  s.copyWith(liveCaptionsOverlayEnabled: value),
                ),
              ),
              _switchRow(
                l.noiseReduction,
                s.liveCaptionsDenoiseEnabled,
                (value) => notifier.update(
                  s.copyWith(liveCaptionsDenoiseEnabled: value),
                ),
              ),
              _switchRow(
                l.voiceCommandsObs,
                s.voiceCommandsEnabled,
                (value) => notifier.update(
                  s.copyWith(voiceCommandsEnabled: value),
                ),
              ),
              if (s.voiceCommandsEnabled) ...[
                const SizedBox(height: 6),
                _label(l.wakeWord),
                _field(
                  _voiceWakeWordCtrl,
                  'airstream',
                  focusNode: _voiceWakeWordFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                const SizedBox(height: 4),
                Text(
                  l.voiceCommandsExamples,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _captionStatusDescription(l, captionsState.phase),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    if (captionsState.caption.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        captionsState.caption,
                        style: const TextStyle(
                          color: Color(0xFF53FC18),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (captionsState.progress case final progress?) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFF333333),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF53FC18),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (captionsState.phase == LiveCaptionsPhase.missingModel ||
                  captionsState.phase == LiveCaptionsPhase.error) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        captionsState.phase == LiveCaptionsPhase.downloading
                            ? null
                            : appController.downloadLiveCaptionsModel,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      '${l.downloadCaptionModel} (${_formatByteSize(SpeechModelCatalog.canary.package.downloadBytes)})',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF53FC18),
                      side: const BorderSide(color: Color(0xFF53FC18)),
                    ),
                  ),
                ),
              ],
              if (s.liveCaptionsOverlayEnabled) ...[
                const SizedBox(height: 8),
                _overlayUrlCard(
                  l: l,
                  title: l.obsCaptions,
                  overlayUrl: captionsCopyUrl,
                  description: l.obsCaptionsDescription,
                  onCopy: () => Clipboard.setData(
                    ClipboardData(text: captionsCopyUrl),
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStyleTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.appearance,
          icon: Icons.format_size_rounded,
          children: [
            StyledSliderRow(
              label: l.fontSize,
              value: s.fontSize,
              min: 10,
              max: 28,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(fontSize: v)),
            ),
            StyledSliderRow(
              label: l.lineHeight,
              value: s.chatLineHeight,
              min: 1,
              max: 2,
              onChanged: (v) => notifier.update(s.copyWith(chatLineHeight: v)),
            ),
            StyledSliderRow(
              label: l.fontWeight,
              value: s.chatFontWeight,
              min: 100,
              max: 900,
              divisions: 8,
              onChanged: (v) => notifier.update(s.copyWith(chatFontWeight: v)),
            ),
            _dropdownRow(
              l.textAlignment,
              s.chatTextAlign,
              const ['left', 'center', 'right'],
              (v) => notifier.update(s.copyWith(chatTextAlign: v)),
              optionLabel: (v) => _alignmentLabel(l, v),
            ),
            StyledSliderRow(
              label: l.maxMessageWidth,
              value: s.chatMaxMessageWidth,
              min: 0.4,
              max: 1.0,
              unit: '%',
              onChanged: (v) =>
                  notifier.update(s.copyWith(chatMaxMessageWidth: v)),
            ),
            StyledSliderRow(
              label: l.horizontalPadding,
              value: s.chatHorizontalPadding,
              min: 0,
              max: 64,
              unit: 'px',
              onChanged: (v) =>
                  notifier.update(s.copyWith(chatHorizontalPadding: v)),
            ),
          ],
        ),
        UiCard(
          title: l.messageDesign,
          icon: Icons.layers_outlined,
          children: [
            StyledSliderRow(
              label: l.backgroundOpacity,
              value: s.bgOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(bgOpacity: v)),
            ),
            StyledSliderRow(
              label: l.bubbleOpacity,
              value: s.messageOpacity,
              min: 0,
              max: 1,
              unit: '%',
              onChanged: (v) => notifier.update(s.copyWith(messageOpacity: v)),
            ),
            StyledSliderRow(
              label: l.borderRadius,
              value: s.borderRadius,
              min: 0,
              max: 24,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(borderRadius: v)),
            ),
            StyledSliderRow(
              label: l.messageGap,
              value: s.messageGap,
              min: 0,
              max: 16,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(messageGap: v)),
            ),
            _switchRow(
              l.bubble,
              s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v)),
            ),
            _switchRow(
              l.bubbleShadow,
              s.showBubbleShadow,
              (v) => notifier.update(s.copyWith(showBubbleShadow: v)),
            ),
            _switchRow(
              l.textShadow,
              s.chatTextShadow,
              (v) => notifier.update(s.copyWith(chatTextShadow: v)),
            ),
            StyledSliderRow(
              label: l.textOutline,
              value: s.chatTextStroke,
              min: 0,
              max: 4,
              unit: 'px',
              onChanged: (v) => notifier.update(s.copyWith(chatTextStroke: v)),
            ),
          ],
        ),
        UiCard(
          title: l.platformDisplay,
          icon: Icons.account_circle_outlined,
          children: [
            _switchRow(
              l.avatars,
              s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v)),
            ),
            _switchRow(
              l.platformIcon,
              s.showPlatformIcons,
              (v) => notifier.update(s.copyWith(showPlatformIcons: v)),
            ),
            _switchRow(
              l.badges,
              s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v)),
            ),
            _switchRow(
              l.timestamp,
              s.showTimestamp,
              (v) => notifier.update(s.copyWith(showTimestamp: v)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildObsTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    AppController appController,
    ObsState obsState,
    int overlayClientCount,
    String overlayCopyUrl,
    String alertsCopyUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.obsIntegration,
          icon: Icons.camera_indoor_rounded,
          description: l.obsDescription,
          trailing: Switch(
            value: s.obsEnabled,
            onChanged: (v) =>
                unawaited(notifier.update(s.copyWith(obsEnabled: v))),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.obsEnabled) ...[
              _label(l.webSocketHost),
              _field(
                _obsHost,
                'localhost:4455',
                focusNode: _obsHostFocus,
                onChanged: (_) {
                  setState(() {});
                  _queueTextSettingsSave();
                },
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 8),
              _label(l.password),
              _field(
                _obsPassword,
                l.optionalPassword,
                focusNode: _obsPasswordFocus,
                obscureText: true,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: obsState.connecting
                      ? null
                      : () async {
                          if (obsState.connected) {
                            await appController.disconnectObs();
                            return;
                          }
                          await _saveTextSettings();
                          await appController.connectObs();
                        },
                  icon: Icon(
                    obsState.connected
                        ? Icons.link_off_rounded
                        : Icons.link_rounded,
                    size: 18,
                  ),
                  label: Text(
                    obsState.connecting
                        ? l.connectingToObs
                        : obsState.connected
                            ? l.disconnectObs
                            : (obsState.error != null &&
                                    obsState.error!.isNotEmpty)
                                ? l.reconnectObs
                                : l.connectObs,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: obsState.connected
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF5B9CFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ObsStatusCard(
                state: obsState,
                showHost: true,
                displaySettings: s,
              ),
              const SizedBox(height: 12),
              Text(
                l.hudElements,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.globalHud),
              _switchRow(
                l.currentScene,
                s.obsShowCurrentScene,
                (v) => notifier.update(s.copyWith(obsShowCurrentScene: v)),
              ),
              _switchRow(
                l.fps,
                s.obsShowFps,
                (v) => notifier.update(s.copyWith(obsShowFps: v)),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.streamHud),
              _switchRow(
                l.streamState,
                s.obsShowStreamState,
                (v) => notifier.update(s.copyWith(obsShowStreamState: v)),
              ),
              _switchRow(
                l.bitrate,
                s.obsShowBitrate,
                (v) => notifier.update(s.copyWith(obsShowBitrate: v)),
              ),
              _switchRow(
                l.droppedFrames,
                s.obsShowDroppedFrames,
                (v) => notifier.update(s.copyWith(obsShowDroppedFrames: v)),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.recordingHud),
              _switchRow(
                l.recordingState,
                s.obsShowRecordingState,
                (v) => notifier.update(s.copyWith(obsShowRecordingState: v)),
              ),
              _switchRow(
                l.recordingDuration,
                s.obsShowRecordingDuration,
                (v) => notifier.update(s.copyWith(obsShowRecordingDuration: v)),
              ),
              _switchRow(
                l.recordingSize,
                s.obsShowRecordingSize,
                (v) => notifier.update(s.copyWith(obsShowRecordingSize: v)),
              ),
            ] else ...[
              Text(
                l.obsDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        UiCard(
          title: l.overlayServer,
          icon: Icons.desktop_windows_rounded,
          description: l.overlayServerDescription,
          trailing: Switch(
            value: s.overlayEnabled,
            onChanged: (v) => notifier.update(s.copyWith(overlayEnabled: v)),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.overlayEnabled) ...[
              _label(l.port),
              _field(
                _port,
                '8080',
                focusNode: _portFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 10),
              _overlayUrlCard(
                l: l,
                title: l.chatObsUrl,
                overlayUrl: overlayCopyUrl,
                description: l.chatObsUrlDescription,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: overlayCopyUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.chatOverlayUrlCopied),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _overlayUrlCard(
                l: l,
                title: l.alertsObsUrl,
                overlayUrl: alertsCopyUrl,
                description: l.alertsObsUrlDescription,
                onCopy: () async {
                  await Clipboard.setData(ClipboardData(text: alertsCopyUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l.alertsOverlayUrlCopied),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                overlayClientCount == 1
                    ? l.oneOverlayClientConnected
                    : l.overlayClientsConnected(overlayClientCount),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final reloaded = appController.reloadOverlay();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          reloaded
                              ? l.overlayReloadSent
                              : l.noOverlayClientConnected,
                        ),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC877),
                    side: const BorderSide(color: Color(0xFF6A4C1D)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l.reloadOverlay),
                ),
              ),
              const SizedBox(height: 12),
              _section(l.alerts),
              Text(
                l.alertsDescription,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              StyledSliderRow(
                label: l.alertFontSize,
                value: s.alertFontSize,
                min: 18,
                max: 56,
                unit: 'px',
                onChanged: (v) => notifier.update(s.copyWith(alertFontSize: v)),
              ),
              StyledSliderRow(
                label: l.alertDuration,
                value: s.alertDisplaySeconds.toDouble(),
                min: 3,
                max: 20,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(alertDisplaySeconds: v.round()),
                ),
              ),
              _switchRow(
                l.alertAvatars,
                s.alertShowAvatars,
                (v) => notifier.update(s.copyWith(alertShowAvatars: v)),
              ),
              const SizedBox(height: 8),
              _alertTestButtons(
                l: l,
                onTest: (kind) {
                  final sent = appController.testOverlayAlert(kind);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent ? l.testAlertSent : l.openAlertsOverlayFirst,
                      ),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _section(l.overlayMode),
              _switchRow(
                l.chromaKey,
                s.overlayChromaMode,
                (v) => notifier.update(s.copyWith(overlayChromaMode: v)),
              ),
              _switchRow(
                l.showGrid,
                s.overlayShowGrid,
                (v) => notifier.update(s.copyWith(overlayShowGrid: v)),
              ),
              _switchRow(
                l.hideScrollbar,
                s.overlayHideScrollbar,
                (v) => notifier.update(s.copyWith(overlayHideScrollbar: v)),
              ),
              if (s.overlayChromaMode) ...[
                const SizedBox(height: 6),
                _label(l.chromaColor),
                _field(
                  _overlayChromaColorCtrl,
                  '#00FF00',
                  focusNode: _overlayChromaColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.platformDisplay),
              _switchRow(
                l.platformIcon,
                s.overlayShowPlatformIcons,
                (v) => notifier.update(
                  s.copyWith(overlayShowPlatformIcons: v),
                ),
              ),
              _switchRow(
                l.twitchAccent,
                s.overlayTwitchBubbleAccent,
                (v) => notifier.update(
                  s.copyWith(overlayTwitchBubbleAccent: v),
                ),
              ),
              _switchRow(
                l.kickAccent,
                s.overlayKickBubbleAccent,
                (v) => notifier.update(
                  s.copyWith(overlayKickBubbleAccent: v),
                ),
              ),
              const SizedBox(height: 12),
              _section(l.styleSettings),
              StyledSliderRow(
                label: l.fontSize,
                value: s.overlayFontSize,
                min: 12,
                max: 32,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontSize: v)),
              ),
              StyledSliderRow(
                label: l.lineHeight,
                value: s.overlayLineHeight,
                min: 1,
                max: 2,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayLineHeight: v)),
              ),
              StyledSliderRow(
                label: l.fontWeight,
                value: s.overlayFontWeight,
                min: 100,
                max: 900,
                divisions: 8,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontWeight: v)),
              ),
              StyledSliderRow(
                label: l.overlayBg,
                value: s.overlayBgOpacity,
                min: 0,
                max: 1,
                unit: '%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayBgOpacity: v)),
              ),
              _switchRow(
                l.avatars,
                s.overlayShowAvatars,
                (v) => notifier.update(s.copyWith(overlayShowAvatars: v)),
              ),
              _switchRow(
                l.badges,
                s.overlayShowBadges,
                (v) => notifier.update(s.copyWith(overlayShowBadges: v)),
              ),
              _switchRow(
                l.timestamp,
                s.overlayShowTimestamp,
                (v) => notifier.update(s.copyWith(overlayShowTimestamp: v)),
              ),
              _switchRow(
                l.textShadow,
                s.overlayTextShadow,
                (v) => notifier.update(s.copyWith(overlayTextShadow: v)),
              ),
              StyledSliderRow(
                label: l.textOutline,
                value: s.overlayTextStroke,
                min: 0,
                max: 4,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayTextStroke: v)),
              ),
              if (s.overlayTextStroke > 0) ...[
                const SizedBox(height: 6),
                _label(l.outlineColor),
                _field(
                  _overlayTextStrokeColorCtrl,
                  '#000000',
                  focusNode: _overlayTextStrokeColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.messageDesign),
              _switchRow(
                l.bubbleBackground,
                s.overlayShowBubble,
                (v) => notifier.update(s.copyWith(overlayShowBubble: v)),
              ),
              _dropdownRow(
                l.textAlignment,
                s.overlayTextAlign,
                const ['left', 'center', 'right'],
                (v) => notifier.update(s.copyWith(overlayTextAlign: v)),
                optionLabel: (v) => _alignmentLabel(l, v),
              ),
              StyledSliderRow(
                label: l.bubbleOpacity,
                value: s.overlayMessageOpacity,
                min: 0,
                max: 1,
                unit: '%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageOpacity: v)),
              ),
              StyledSliderRow(
                label: l.cornerRadius,
                value: s.overlayBorderRadius,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayBorderRadius: v)),
              ),
              StyledSliderRow(
                label: l.verticalGap,
                value: s.overlayMessageGap,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageGap: v)),
              ),
              StyledSliderRow(
                label: l.maxMessages,
                value: s.overlayMaxMessages.toDouble(),
                min: 10,
                max: 500,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMaxMessages: v.round())),
              ),
              StyledSliderRow(
                label: l.messageLifetime,
                value: s.overlayMessageTtlSeconds.toDouble(),
                min: 5,
                max: 120,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(overlayMessageTtlSeconds: v.round()),
                ),
              ),
              _switchRow(
                l.superChatColorBar,
                s.overlaySuperChatBarEnabled,
                (v) => notifier.update(
                  s.copyWith(overlaySuperChatBarEnabled: v),
                ),
              ),
              if (s.overlaySuperChatBarEnabled) ...[
                const SizedBox(height: 6),
                _label(l.superChatBarColor),
                _field(
                  _overlaySuperChatBarColorCtrl,
                  '#1DE9B6',
                  focusNode: _overlaySuperChatBarColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                StyledSliderRow(
                  label: l.superChatWidth,
                  value: s.overlaySuperChatBarWidth,
                  min: 1,
                  max: 8,
                  unit: 'px',
                  onChanged: (v) => notifier.update(
                    s.copyWith(overlaySuperChatBarWidth: v),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.animation),
              _dropdownRow(
                l.entrance,
                s.overlayAnimation,
                const ['slide-up', 'slide-left', 'fade-in', 'zoom-in'],
                (v) => notifier.update(s.copyWith(overlayAnimation: v)),
                optionLabel: (v) => _animationLabel(l, v),
              ),
              StyledSliderRow(
                label: l.duration,
                value: s.overlayAnimationDuration,
                min: 0.1,
                max: 2,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(overlayAnimationDuration: v),
                ),
              ),
              const SizedBox(height: 12),
              _section(l.transform3d),
              _switchRow(
                l.enable3dEffect,
                s.overlayThreeDEnabled,
                (v) => notifier.update(s.copyWith(overlayThreeDEnabled: v)),
              ),
              if (s.overlayThreeDEnabled) ...[
                StyledSliderRow(
                  label: l.perspective,
                  value: s.overlayPerspective,
                  min: 500,
                  max: 2500,
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayPerspective: v)),
                ),
                StyledSliderRow(
                  label: l.rotateX,
                  value: s.overlayRotateX,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateX: v)),
                ),
                StyledSliderRow(
                  label: l.rotateY,
                  value: s.overlayRotateY,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateY: v)),
                ),
                StyledSliderRow(
                  label: l.rotateZ,
                  value: s.overlayRotateZ,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateZ: v)),
                ),
                StyledSliderRow(
                  label: l.skewX,
                  value: s.overlaySkewX,
                  min: -45,
                  max: 45,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlaySkewX: v)),
                ),
                StyledSliderRow(
                  label: l.scale,
                  value: s.overlayScale,
                  min: 0.5,
                  max: 2,
                  unit: 'x',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayScale: v)),
                ),
              ],
            ] else ...[
              Text(
                l.overlayDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSystemTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    final win = ref.watch(windowStateProvider);
    final winNotifier = ref.read(windowStateProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.desktopWindow,
          icon: Icons.window_rounded,
          children: [
            _switchTileWithSubtitle(
              l.clickThrough,
              l.clickThroughDescription,
              win.clickThrough,
              (v) => winNotifier.setClickThrough(v),
              activeThumbColor: const Color(0xFFFFB15C),
            ),
            _switchTileWithSubtitle(
              l.alwaysOnTop,
              l.alwaysOnTopDescription,
              win.alwaysOnTop,
              (v) => winNotifier.setAlwaysOnTop(v),
            ),
            _switchTileWithSubtitle(
              l.antiCapture,
              l.antiCaptureDescription,
              win.excludeFromCapture,
              (v) => winNotifier.setExcludeFromCapture(v),
              activeThumbColor: const Color(0xFFBB86FC),
            ),
          ],
        ),
        UiCard(
          title: l.language,
          icon: Icons.language_rounded,
          children: [
            _dropdownRow(
              l.language,
              s.appLanguageCode,
              const ['en', 'es'],
              (v) => notifier.update(s.copyWith(appLanguageCode: v)),
              optionLabel: (v) => v == 'es' ? l.spanish : l.english,
            ),
          ],
        ),
        UiCard(
          title: l.keyboardShortcuts,
          icon: Icons.keyboard_rounded,
          children: [
            _shortcutRow('Ctrl + B', l.hideSidebarTooltip),
            _shortcutRow('Ctrl + Shift + T', l.toggleTopBarShortcut),
            _shortcutRow('Ctrl + Shift + P', l.toggleAlwaysOnTopShortcut),
            _shortcutRow('Ctrl + Shift + C', l.toggleClickThroughShortcut),
          ],
        ),
      ],
    );
  }

  static Widget _shortcutRow(String keys, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                color: Color(0xFF53FC18),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _switchTileWithSubtitle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Color? activeThumbColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeThumbColor ?? const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  static String _ttsEngineName(String engineId) => switch (engineId) {
        'supertonic-3-hybrid' => 'Supertonic',
        'piper' => 'Piper',
        'kitten-nano-en-v0-8-int8' => 'KittenTTS',
        'kokoro-en-v0-19-int8' => 'Kokoro',
        'matcha-ljspeech-en' => 'Matcha-TTS',
        'pocket-tts-int8' => 'Pocket TTS',
        'zipvoice-distill-int8-zh-en' => 'ZipVoice',
        _ => TtsModelCatalog.byId(engineId).name,
      };

  static String _ttsLanguageLabel(
    AppLocalizations l,
    String languageCode,
  ) {
    if (languageCode == 'es-MX') return l.spanishMexico;
    if (languageCode == 'es-ES') return l.spanishSpain;
    return _languageLabel(l, languageCode);
  }

  static String _languageLabel(AppLocalizations l, String languageCode) =>
      switch (languageCode) {
        'ar' => l.languageArabic,
        'bg' => l.languageBulgarian,
        'zh' => l.languageChinese,
        'hr' => l.languageCroatian,
        'cs' => l.languageCzech,
        'da' => l.languageDanish,
        'nl' => l.languageDutch,
        'en' => l.english,
        'et' => l.languageEstonian,
        'fi' => l.languageFinnish,
        'fr' => l.languageFrench,
        'de' => l.languageGerman,
        'el' => l.languageGreek,
        'hi' => l.languageHindi,
        'hu' => l.languageHungarian,
        'id' => l.languageIndonesian,
        'it' => l.languageItalian,
        'ja' => l.languageJapanese,
        'ko' => l.languageKorean,
        'lv' => l.languageLatvian,
        'lt' => l.languageLithuanian,
        'pl' => l.languagePolish,
        'pt' => l.languagePortuguese,
        'ro' => l.languageRomanian,
        'ru' => l.languageRussian,
        'sk' => l.languageSlovak,
        'sl' => l.languageSlovenian,
        'es' => l.spanish,
        'sv' => l.languageSwedish,
        'tr' => l.languageTurkish,
        'uk' => l.languageUkrainian,
        'vi' => l.languageVietnamese,
        _ => languageCode.toUpperCase(),
      };

  static String _alignmentLabel(AppLocalizations l, String value) =>
      switch (value) {
        'center' => l.alignmentCenter,
        'right' => l.alignmentRight,
        _ => l.alignmentLeft,
      };

  static String _animationLabel(AppLocalizations l, String value) =>
      switch (value) {
        'slide-left' => l.animationSlideLeft,
        'fade-in' => l.animationFadeIn,
        'zoom-in' => l.animationZoomIn,
        _ => l.animationSlideUp,
      };

  static String _ttsModelDescription(AppLocalizations l, String modelId) =>
      switch (modelId) {
        'supertonic-3-hybrid' => l.ttsModelSupertonicDescription,
        'piper-es-mx-claude-high-int8' => l.ttsModelPiperMexicoDescription,
        'piper-es-es-davefx-medium-int8' => l.ttsModelPiperSpainDescription,
        'kitten-nano-en-v0-8-int8' => l.ttsModelKittenDescription,
        'kokoro-en-v0-19-int8' => l.ttsModelKokoroDescription,
        'matcha-ljspeech-en' => l.ttsModelMatchaDescription,
        'pocket-tts-int8' => l.ttsModelPocketDescription,
        'zipvoice-distill-int8-zh-en' => l.ttsModelZipVoiceDescription,
        _ => TtsModelCatalog.byId(modelId).name,
      };

  static String _ttsVoiceLabel(
    AppLocalizations l,
    TtsModelDefinition model,
    String voiceId,
  ) {
    final compactVoice = RegExp(r'^([FM])(\d)$').firstMatch(voiceId);
    if (compactVoice != null) {
      final number = compactVoice.group(2)!;
      final description = compactVoice.group(1) == 'F'
          ? l.femaleVoice(number)
          : l.maleVoice(number);
      return '$voiceId · $description';
    }
    final kittenVoice = RegExp(r'^(female|male)-(\d)$').firstMatch(voiceId);
    if (kittenVoice != null) {
      final number = kittenVoice.group(2)!;
      return kittenVoice.group(1) == 'female'
          ? l.femaleVoice(number)
          : l.maleVoice(number);
    }
    return switch (voiceId) {
      'claude' => 'Claude · ${l.male}',
      'davefx' => 'DaveFX · ${l.male}',
      'af' => '${l.defaultVoice} US · ${l.female}',
      'ljspeech' => 'LJSpeech · ${l.female}',
      'bria' => 'Bria · ${l.includedSample}',
      'news-female' => '${l.newsVoice} · ${l.includedSample}',
      'news-female-2' => '${l.newsVoiceNumber(2)} · ${l.includedSample}',
      'leijun' => 'Lei Jun · ${l.includedSample}',
      _ => model.voice(voiceId).label,
    };
  }

  static String _ttsStatusDescription(
    AppLocalizations l,
    TtsLoadPhase phase,
  ) =>
      switch (phase) {
        TtsLoadPhase.ready => l.ttsStatusReadyDescription,
        TtsLoadPhase.checking => l.ttsStatusCheckingDescription,
        TtsLoadPhase.downloading => l.ttsStatusDownloadingDescription,
        TtsLoadPhase.loading => l.ttsStatusLoadingDescription,
        TtsLoadPhase.error => l.ttsStatusErrorDescription,
        TtsLoadPhase.idle => l.ttsStatusIdleDescription,
      };

  static String _captionStatusDescription(
    AppLocalizations l,
    LiveCaptionsPhase phase,
  ) =>
      switch (phase) {
        LiveCaptionsPhase.idle => l.captionStatusIdle,
        LiveCaptionsPhase.missingModel => l.captionStatusMissingModel,
        LiveCaptionsPhase.downloading => l.captionStatusDownloading,
        LiveCaptionsPhase.loading => l.captionStatusLoading,
        LiveCaptionsPhase.listening => l.captionStatusListening,
        LiveCaptionsPhase.transcribing => l.captionStatusTranscribing,
        LiveCaptionsPhase.error => l.captionStatusError,
      };

  static Widget _ttsStatusCard(
    AppLocalizations l,
    TtsLoadState state, {
    VoidCallback? onDownload,
  }) {
    final model = TtsModelCatalog.byId(state.modelId);
    final (label, color) = switch (state.phase) {
      TtsLoadPhase.ready => (l.ready, const Color(0xFF53FC18)),
      TtsLoadPhase.checking => (l.checking, Colors.lightBlueAccent),
      TtsLoadPhase.downloading => (l.downloading, Colors.orangeAccent),
      TtsLoadPhase.loading => (l.loading, Colors.amber),
      TtsLoadPhase.error => (l.error, Colors.redAccent),
      TtsLoadPhase.idle => (l.voiceStatusNotDownloaded, Colors.white38),
    };

    final isDownloading = state.phase == TtsLoadPhase.downloading;
    final isLoading = state.phase == TtsLoadPhase.loading ||
        state.phase == TtsLoadPhase.checking;
    final isBusy = isDownloading || isLoading;

    final bytesText = state.totalBytes > 0
        ? '${_formatByteSize(state.loadedBytes)} / ${_formatByteSize(state.totalBytes)}'
        : null;
    final percentageText = state.progress != null
        ? '${((state.progress ?? 0) * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.ttsModelStatusBadge(model.name, label),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (percentageText != null && isDownloading)
                Text(
                  percentageText,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _ttsStatusDescription(l, state.phase),
            maxLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          if (isBusy) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: state.progress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (bytesText != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  bytesText,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ],
          ],
          if (onDownload != null &&
              (state.phase == TtsLoadPhase.idle ||
                  state.phase == TtsLoadPhase.error)) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onDownload,
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text(l.downloadTtsModel),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF53FC18),
                side: const BorderSide(color: Color(0xFF3B6B2B)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF53FC18),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      );

  static Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          t,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    FocusNode? focusNode,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onClear,
    int minLines = 1,
    int maxLines = 1,
  }) =>
      TextField(
        controller: ctrl,
        focusNode: focusNode,
        obscureText: obscureText,
        enableSuggestions: !obscureText,
        autocorrect: !obscureText,
        minLines: minLines,
        maxLines: maxLines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF222222),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: onClear != null && ctrl.text.isNotEmpty
              ? IconButton(
                  tooltip: AppLocalizations.of(context)!.clear,
                  onPressed: onClear,
                  splashRadius: 16,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white54,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF53FC18)),
          ),
        ),
      );

  static Widget _sidebarHeader({
    required AppLocalizations l,
    required String? youtubeValue,
    required String twitchValue,
    required String kickValue,
    required Map<String, (ServiceStatus, String?)> statusMap,
  }) {
    final badges = <Widget>[
      if (youtubeValue != null && youtubeValue.trim().isNotEmpty)
        _platformStatusBadge(
          'YouTube',
          youtubeValue.trim(),
          statusMap['youtube']?.$1 ?? ServiceStatus.idle,
        ),
      if (twitchValue.trim().isNotEmpty)
        _platformStatusBadge(
          'Twitch',
          twitchValue.trim(),
          statusMap['twitch']?.$1 ?? ServiceStatus.idle,
        ),
      if (kickValue.trim().isNotEmpty)
        _platformStatusBadge(
          'Kick',
          kickValue.trim(),
          statusMap['kick']?.$1 ?? ServiceStatus.idle,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l.dashboard,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF303030)),
              ),
              child: const Text(
                'Ctrl+B',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges,
          ),
        ],
      ],
    );
  }

  static Widget _platformStatusBadge(
    String platform,
    String value,
    ServiceStatus status,
  ) {
    final color = switch (status) {
      ServiceStatus.connected => const Color(0xFF53FC18),
      ServiceStatus.connecting => Colors.amber,
      ServiceStatus.error => const Color(0xFFFF6B6B),
      ServiceStatus.idle => Colors.white38,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$platform: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _switchRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF53FC18),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      );

  static Widget _dropdownRow(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged, {
    String Function(String value)? optionLabel,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: options
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(optionLabel?.call(e) ?? e),
                            ))
                        .toList(),
                    selectedItemBuilder: (context) => options
                        .map((e) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                optionLabel?.call(e) ?? e,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  static Widget _inlineErrorMessage(
    AppLocalizations l,
    String platform,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 15,
              color: Color(0xFFFF8A80),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l.platformConnectionFailed(platform),
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _overlayUrlCard({
    required AppLocalizations l,
    required String title,
    required String overlayUrl,
    required String description,
    required VoidCallback onCopy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 26,
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFACCBFF),
                    side: const BorderSide(color: Color(0xFF35527A)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 12),
                  label: Text(
                    l.copy,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            overlayUrl,
            style: const TextStyle(
              color: Color(0xFFACCBFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _alertTestButtons({
    required AppLocalizations l,
    required void Function(String kind) onTest,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.testAlerts,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _alertTestButton(
                l.superChat,
                () => onTest('superchat'),
              ),
              _alertTestButton(
                l.noMessage,
                () => onTest('superchat-empty'),
              ),
              _alertTestButton(
                l.member,
                () => onTest('membership'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _alertTestButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFACCBFF),
        side: const BorderSide(color: Color(0xFF35527A)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Widget _obsHudGroupLabel(String label) {
  return Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    ),
  );
}

class _ObsStatusCard extends StatelessWidget {
  const _ObsStatusCard({
    required this.state,
    this.compact = false,
    this.showHost = false,
    this.styleSettings,
    this.displaySettings,
  });

  final ObsState state;
  final bool compact;
  final bool showHost;
  final SettingsModel? styleSettings;
  final SettingsModel? displaySettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (title, color) = _obsStatusVisuals(state, l);

    if (compact) {
      return _ObsCompactPill(
        state: state,
        title: title,
        color: color,
        styleSettings: styleSettings ?? const SettingsModel(),
        displaySettings: displaySettings ?? const SettingsModel(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (showHost && state.host.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.host,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (_showObsScene(displaySettings, state)) ...[
            const SizedBox(height: 6),
            Text(
              l.obsScenePrefix(state.currentScene),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_showObsStreamState(displaySettings)) ...[
            const SizedBox(height: 6),
            Text(
              state.outputActive ? l.obsOutputLive : l.obsOutputOffline,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          if (_showObsRecordingState(displaySettings) &&
              state.recordingActive) ...[
            const SizedBox(height: 6),
            Text(
              state.recordingPaused
                  ? l.obsRecordingPaused
                  : l.obsRecordingActive,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (state.connected) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_showObsBitrate(displaySettings))
                  _ObsPillBadge(
                    label: '${state.bitrateKbps.toStringAsFixed(0)} kbps',
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
                if (_showObsFps(displaySettings))
                  _ObsPillBadge(
                    label: '${state.fps.toStringAsFixed(0)} FPS',
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
                if (_showObsDroppedFrames(displaySettings))
                  _ObsPillBadge(
                    label: l.droppedFramesBadge(
                      state.dropPercentage.toStringAsFixed(1),
                      state.droppedFrames,
                    ),
                    foreground: _obsDropBadgeForeground(state.dropTrend),
                    background: _obsDropBadgeBackground(state.dropTrend),
                    fontSize: 10,
                  ),
                if (_showObsRecordingDuration(displaySettings) &&
                    state.recordingActive)
                  _ObsPillBadge(
                    label: _formatObsDuration(state.recordingDurationMs),
                    foreground: const Color(0xFFFFB4AB),
                    background: const Color(0x33FF6B6B),
                    fontSize: 10,
                  ),
                if (_showObsRecordingSize(displaySettings) &&
                    state.recordingActive)
                  _ObsPillBadge(
                    label: _formatObsBytes(state.recordingBytes),
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
              ],
            ),
          ],
          if (state.error != null && state.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.obsConnectionProblem,
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObsCompactPill extends StatelessWidget {
  const _ObsCompactPill({
    required this.state,
    required this.title,
    required this.color,
    required this.styleSettings,
    required this.displaySettings,
  });

  final ObsState state;
  final String title;
  final Color color;
  final SettingsModel styleSettings;
  final SettingsModel displaySettings;

  @override
  Widget build(BuildContext context) {
    final showBubble = styleSettings.showBubble;
    final bubbleOpacity = styleSettings.messageOpacity.clamp(0.0, 1.0);
    final backgroundColor = _obsCompactBackground(
      showBubble: showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final border = _obsCompactBorder(
      showBubble: showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final radius = BorderRadius.circular(styleSettings.borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  state.connected && _showObsScene(displaySettings, state)
                      ? state.currentScene
                      : title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.connected && _showObsFps(displaySettings)) ...[
                const SizedBox(width: 6),
                _ObsPillBadge(
                  label: '${state.fps.toStringAsFixed(0)} FPS',
                  foreground: const Color(0xFFE7E7E7),
                  background: const Color(0xFF242424),
                  fontSize: 10,
                ),
              ],
              if (state.connected && _showObsBitrate(displaySettings)) ...[
                const SizedBox(width: 4),
                _ObsPillBadge(
                  label: '${state.bitrateKbps.toStringAsFixed(0)}k',
                  foreground: const Color(0xFFE7E7E7),
                  background: const Color(0xFF242424),
                  fontSize: 10,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ObsPillBadge extends StatelessWidget {
  const _ObsPillBadge({
    required this.label,
    required this.foreground,
    required this.background,
    required this.fontSize,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

(String, Color) _obsStatusVisuals(ObsState state, AppLocalizations l) {
  if (state.connecting) {
    return (l.obsStatusConnecting, Colors.amber);
  }
  if (!state.connected) {
    return (l.obsStatusDisconnected, Colors.white38);
  }
  if (state.outputActive && state.recordingActive) {
    return (l.obsStatusLiveAndRec, const Color(0xFF53FC18));
  }
  if (state.outputActive) {
    return (l.obsStatusLive, const Color(0xFF53FC18));
  }
  if (state.recordingActive) {
    return (l.obsStatusRecording, const Color(0xFFFF8A80));
  }
  return (l.obsStatusConnected, const Color(0xFF5B9CFF));
}

bool _showObsScene(SettingsModel? settings, ObsState state) {
  if (settings == null) return state.currentScene.isNotEmpty;
  return settings.obsShowCurrentScene && state.currentScene.isNotEmpty;
}

bool _showObsStreamState(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowStreamState;
}

bool _showObsFps(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowFps;
}

bool _showObsBitrate(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowBitrate;
}

bool _showObsDroppedFrames(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowDroppedFrames;
}

bool _showObsRecordingState(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingState;
}

bool _showObsRecordingDuration(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingDuration;
}

bool _showObsRecordingSize(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingSize;
}

Color _obsDropBadgeForeground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0xFFFFB4AB),
    ObsDropTrend.steady => Colors.amber,
    ObsDropTrend.normal => Colors.white70,
  };
}

Color _obsDropBadgeBackground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0x44FF5252),
    ObsDropTrend.steady => const Color(0x33FFC107),
    ObsDropTrend.normal => const Color(0xFF2A2A2A),
  };
}

String _formatObsDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatObsBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) {
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
  return '${mb.toStringAsFixed(1)} MB';
}

Color _obsCompactBackground({
  required bool showBubble,
  required double bubbleOpacity,
}) {
  if (!showBubble || bubbleOpacity <= 0) return Colors.transparent;

  const baseColor = Color(0xFF111111);

  return baseColor.withAlpha((255 * bubbleOpacity).round().clamp(0, 255));
}

Border? _obsCompactBorder({
  required bool showBubble,
  required double bubbleOpacity,
}) {
  if (!showBubble) return null;

  final side = BorderSide(
    color: Colors.white.withValues(alpha: 0.1 * bubbleOpacity),
  );

  return Border.fromBorderSide(side);
}

class _ConnectionDots extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);

    final platforms = <(String, bool, String)>[
      (
        'YT',
        settings.youtubeHandle.isNotEmpty || settings.youtubeLiveId.isNotEmpty,
        'youtube'
      ),
      ('TW', settings.twitchChannel.isNotEmpty, 'twitch'),
      ('KK', settings.kickSlug.isNotEmpty, 'kick'),
    ];

    final statusMap = status.valueOrNull ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: platforms.where((p) => p.$2).map((p) {
          final s = statusMap[p.$3];
          final serviceStatus = s?.$1 ?? ServiceStatus.idle;
          final error = s?.$2;
          final color = switch (serviceStatus) {
            ServiceStatus.connected => const Color(0xFF53FC18),
            ServiceStatus.connecting => Colors.amber,
            ServiceStatus.error => Colors.red,
            ServiceStatus.idle => Colors.white24,
          };
          return Tooltip(
            message: error ?? serviceStatus.name,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    p.$1,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

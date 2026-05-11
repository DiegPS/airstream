import 'dart:io';
import 'dart:async';

import 'package:airchat_flutter/services/supertonic_helper.dart'
    show availableLangs, formatByteSize;
import 'package:airchat_flutter/services/obs_service.dart';
import 'package:airchat_flutter/settings/settings_model.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/ui/widgets/chat_bubble.dart';
import 'package:airchat_flutter/ui/widgets/window_control_bar.dart';
import 'package:airchat_flutter/window/window_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  void _toggleTopBarVisibility() {
    setState(() => _topBarVisible = !_topBarVisible);
  }

  KeyEventResult _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final keyboard = HardwareKeyboard.instance;
    final isToggleClickThroughShortcut =
        event.logicalKey == LogicalKeyboardKey.keyB &&
            keyboard.isControlPressed &&
            keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (isToggleClickThroughShortcut) {
      final windowNotifier = ref.read(windowStateProvider.notifier);
      _toggleSidebarVisibility();
      _toggleTopBarVisibility();
      unawaited(windowNotifier.toggleAlwaysOnTop());
      unawaited(windowNotifier.toggleClickThrough());
      return KeyEventResult.handled;
    }

    final isToggleSidebarShortcut =
        event.logicalKey == LogicalKeyboardKey.keyB &&
            keyboard.isControlPressed &&
            !keyboard.isShiftPressed &&
            !keyboard.isAltPressed &&
            !keyboard.isMetaPressed;

    if (!isToggleSidebarShortcut) {
      return KeyEventResult.ignored;
    }

    _toggleSidebarVisibility();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final scaffoldBg = const Color(0xFF0D0D0D).withValues(alpha: s.bgOpacity);
    final scaffold = Focus(
      autofocus: true,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: _topBarVisible
            ? _DesktopTopBar(
                sidebarVisible: _sidebarVisible,
                onToggleSidebar: _toggleSidebarVisibility,
              )
            : null,
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: _sidebarVisible ? 360 : 0,
              child: _sidebarVisible
                  ? const _SettingsSidebar()
                  : const SizedBox.shrink(),
            ),
            if (_sidebarVisible)
              const VerticalDivider(width: 1, color: Color(0xFF2A2A2A)),
            Expanded(
              child: _chatList(),
            ),
          ],
        ),
      ),
    );

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return _DesktopResizeFrame(child: scaffold);
    }

    return scaffold;
  }

  Widget _chatList() {
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
            bottom: obsBottomSpacing,
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
        ],
      );
    }

    return chat.when(
      loading: () => buildPane(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF53FC18)),
        ),
      ),
      error: (e, _) => buildPane(
        Center(
          child: Text(
            'Error: $e',
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
                  ? 'Listening for messages...'
                  : 'Channels saved.\nPress Start when you want to listen.')
              : 'No channels configured.\nConfigure channels in the sidebar.';
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
                  24,
                  24,
                  24,
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

  static const _barHeight = 36.0;
  static const _accent = Color(0xFF5B9CFF);

  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;

  @override
  Size get preferredSize => const Size.fromHeight(_barHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayUrl = ref.watch(overlayUrlProvider);
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
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xCC6A0F0F),
              Color(0x66101010),
              Color(0xCC8A1414),
            ],
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
                const Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: _TitleBarCaption(),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: IgnorePointer(
                      child: _TitleBarCenterStatus(overlayUrl: overlayUrl),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      _TopBarActionButton(
                        label: isRunning ? 'Stop' : 'Start',
                        icon: isRunning
                            ? Icons.stop_circle_outlined
                            : Icons.play_arrow_rounded,
                        enabled: hasChannels,
                        accentColor:
                            isRunning ? const Color(0xFFE37D76) : _accent,
                        onTap: hasChannels
                            ? () {
                                ref
                                    .read(chatConnectionProvider.notifier)
                                    .state = !isRunning;
                              }
                            : null,
                      ),
                      const SizedBox(width: 8),
                      _TopBarIconButton(
                        tooltip: sidebarVisible
                            ? 'Hide sidebar (Ctrl+B)'
                            : 'Show sidebar (Ctrl+B)',
                        icon: sidebarVisible
                            ? Icons.menu_open_rounded
                            : Icons.menu_rounded,
                        active: sidebarVisible,
                        onTap: onToggleSidebar,
                      ),
                      const SizedBox(width: 8),
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
  const _TitleBarCaption();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.forum_outlined,
          color: Color(0xFFD7D7D7),
          size: 14,
        ),
        SizedBox(width: 8),
        Text(
          'AIRCHAT',
          style: TextStyle(
            color: Color(0xFFA8A8A8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
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
            const SizedBox(width: 10),
            const Text(
              '•',
              style: TextStyle(
                color: Color(0xFF7A7A7A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                overlayUrl!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFACCBFF),
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
        enabled ? accentColor.withValues(alpha: 0.14) : Colors.transparent;
    final foregroundColor = enabled ? accentColor : const Color(0xFF6E6E6E);

    return Tooltip(
      message: label,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: foregroundColor),
                const SizedBox(width: 6),
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
        ? const Color(0xFF5B9CFF).withValues(alpha: 0.14)
        : Colors.transparent;
    final foregroundColor =
        active ? const Color(0xFF86B8FF) : const Color(0xFFB8B8B8);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: foregroundColor),
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
    _ttsTestCtrl =
        TextEditingController(text: 'Hola, probando sistema Text to Speech.');
    _ttsPrefixCtrl = TextEditingController(text: s.ttsCommandPrefix);
    _ttsSeparatorCtrl = TextEditingController(text: s.ttsSeparatorText);
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
      _blockedUsersFocus,
      _blockedWordsFocus,
    ]) {
      node.addListener(() {
        if (!node.hasFocus) {
          unawaited(_saveTextSettings());
        }
      });
    }
  }

  @override
  void dispose() {
    _textSettingsDebounce?.cancel();
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
    _blockedUsersCtrl.dispose();
    _blockedWordsCtrl.dispose();

    _ytFocus.dispose();
    _twitchFocus.dispose();
    _kickFocus.dispose();
    _portFocus.dispose();
    _obsHostFocus.dispose();
    _obsPasswordFocus.dispose();
    _overlayChromaColorFocus.dispose();
    _overlayTextStrokeColorFocus.dispose();
    _overlaySuperChatBarColorFocus.dispose();
    _ttsPrefixFocus.dispose();
    _ttsSeparatorFocus.dispose();
    _blockedUsersFocus.dispose();
    _blockedWordsFocus.dispose();
    super.dispose();
  }

  void _queueTextSettingsSave() {
    _textSettingsDebounce?.cancel();
    _textSettingsDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_saveTextSettings()),
    );
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
        current.ttsSeparatorText == next.ttsSeparatorText) {
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
    final notifier = ref.read(settingsProvider.notifier);
    final isRunning = ref.watch(chatConnectionProvider);
    final connectionStatus =
        ref.watch(connectionStatusProvider).valueOrNull ?? {};
    final youtubeBadgeValue = ref.watch(youtubeBadgeValueProvider).valueOrNull;
    final appController = ref.read(appControllerProvider);
    final ttsLoadState = ref.watch(ttsLoadStateProvider).valueOrNull;
    final ttsBusy = ref.watch(ttsBusyProvider).valueOrNull ?? false;
    final obsState =
        ref.watch(obsStateProvider).valueOrNull ?? const ObsState();
    final overlayUrl = ref.watch(overlayUrlProvider);
    final overlayClientCount =
        ref.watch(overlayClientCountProvider).valueOrNull ?? 0;
    final overlayCopyUrl = overlayUrl ?? 'http://localhost:${s.overlayPort}';

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

    return Container(
      color: const Color(0xFF141414),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sidebarHeader(
            youtubeValue: youtubeBadgeValue ?? _youtubeInputValue(s),
            twitchValue: s.twitchChannel,
            kickValue: s.kickSlug,
            statusMap: connectionStatus,
          ),
          const SizedBox(height: 16),
          _section('Connections'),
          _label('YouTube handle, channel ID, video ID, or URL'),
          _field(
            _ytHandle,
            '@xqc · UC... · youtube.com/watch?v=...',
            focusNode: _ytFocus,
            onChanged: (_) {
              setState(() {});
              _queueTextSettingsSave();
            },
            onSubmitted: (_) => _saveTextSettings(),
            onClear: () {
              _ytHandle.clear();
              setState(() {});
              _queueTextSettingsSave();
            },
          ),
          if (youtubeError != null && youtubeError.isNotEmpty) ...[
            const SizedBox(height: 8),
            _inlineErrorMessage('YouTube', youtubeError),
          ],
          const SizedBox(height: 12),
          _label('Twitch channel'),
          _field(
            _twitch,
            'xqc',
            focusNode: _twitchFocus,
            onChanged: (_) {
              setState(() {});
              _queueTextSettingsSave();
            },
            onSubmitted: (_) => _saveTextSettings(),
            onClear: () {
              _twitch.clear();
              setState(() {});
              _queueTextSettingsSave();
            },
          ),
          if (twitchError != null && twitchError.isNotEmpty) ...[
            const SizedBox(height: 8),
            _inlineErrorMessage('Twitch', twitchError),
          ],
          const SizedBox(height: 12),
          _label('Kick slug'),
          _field(
            _kick,
            'xqc',
            focusNode: _kickFocus,
            onChanged: (_) {
              setState(() {});
              _queueTextSettingsSave();
            },
            onSubmitted: (_) => _saveTextSettings(),
            onClear: () {
              _kick.clear();
              setState(() {});
              _queueTextSettingsSave();
            },
          ),
          if (kickError != null && kickError.isNotEmpty) ...[
            const SizedBox(height: 8),
            _inlineErrorMessage('Kick', kickError),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  isRunning ? _stopChat : (hasChannels ? _startChat : null),
              icon: Icon(isRunning ? Icons.stop : Icons.play_arrow, size: 18),
              label: Text(isRunning ? 'Stop chat' : 'Start chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isRunning ? Colors.redAccent : const Color(0xFF53FC18),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF2A2A2A),
                disabledForegroundColor: Colors.white38,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('Appearance'),
          _sliderRow('Font size', s.fontSize, 10, 28,
              (v) => notifier.update(s.copyWith(fontSize: v))),
          _sliderRow('Background opacity', s.bgOpacity, 0, 1,
              (v) => notifier.update(s.copyWith(bgOpacity: v))),
          _sliderRow('Bubble opacity', s.messageOpacity, 0, 1,
              (v) => notifier.update(s.copyWith(messageOpacity: v))),
          _sliderRow('Border radius', s.borderRadius, 0, 24,
              (v) => notifier.update(s.copyWith(borderRadius: v))),
          _sliderRow('Message gap', s.messageGap, 0, 16,
              (v) => notifier.update(s.copyWith(messageGap: v))),
          _switchRow('Avatars', s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v))),
          _switchRow('Platform icon', s.showPlatformIcons,
              (v) => notifier.update(s.copyWith(showPlatformIcons: v))),
          _switchRow('Badges', s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v))),
          _switchRow('Timestamp', s.showTimestamp,
              (v) => notifier.update(s.copyWith(showTimestamp: v))),
          _switchRow('Bubble', s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v))),
          _switchRow('Bubble shadow', s.showBubbleShadow,
              (v) => notifier.update(s.copyWith(showBubbleShadow: v))),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('Filters'),
          const Text(
            'Blocked users and words are filtered in the message pipeline, so they are removed for your local chat view, TTS and the Shelf overlay.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _label('Blocked users'),
          _field(
            _blockedUsersCtrl,
            '@nightbot\notrobot',
            focusNode: _blockedUsersFocus,
            onChanged: (_) => _queueTextSettingsSave(),
            onSubmitted: (_) => _saveTextSettings(),
            onClear: () {
              _blockedUsersCtrl.clear();
              setState(() {});
              _queueTextSettingsSave();
            },
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 6),
          const Text(
            'One per line. Prefixing with @ is optional.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _label('Blocked words or phrases'),
          _field(
            _blockedWordsCtrl,
            'palabra1\nfrase completa',
            focusNode: _blockedWordsFocus,
            onChanged: (_) => _queueTextSettingsSave(),
            onSubmitted: (_) => _saveTextSettings(),
            onClear: () {
              _blockedWordsCtrl.clear();
              setState(() {});
              _queueTextSettingsSave();
            },
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 6),
          const Text(
            'Single words respect token boundaries. Phrases are matched after normalization.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('TTS'),
          const Text(
            'Read chat messages aloud with configurable voice, language and command behavior.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _switchRow('Enabled', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
          if (s.ttsEnabled) ...[
            const SizedBox(height: 12),
            if (ttsLoadState != null) ...[
              _ttsStatusCard(ttsLoadState),
              const SizedBox(height: 12),
            ],
            _switchRow('Members only', s.ttsMembersOnly,
                (v) => notifier.update(s.copyWith(ttsMembersOnly: v))),
            _switchRow('Command mode (custom prefix)', s.ttsCommandMode,
                (v) => notifier.update(s.copyWith(ttsCommandMode: v))),
            if (s.ttsCommandMode) ...[
              const SizedBox(height: 8),
              _label('Command prefix'),
              _field(
                _ttsPrefixCtrl,
                '!voz, !v, !say...',
                focusNode: _ttsPrefixFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
            ],
            const SizedBox(height: 8),
            _label('Separator text'),
            _field(
              _ttsSeparatorCtrl,
              'dice',
              focusNode: _ttsSeparatorFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
            ),
            const SizedBox(height: 12),
            _dropdownRow(
              'Voice',
              s.ttsVoice,
              ['M1', 'M2', 'M3', 'M4', 'M5', 'F1', 'F2', 'F3', 'F4', 'F5'],
              (v) => notifier.update(s.copyWith(ttsVoice: v)),
            ),
            _dropdownRow(
              'Language',
              s.ttsLanguage,
              availableLangs,
              (v) => notifier.update(s.copyWith(ttsLanguage: v)),
            ),
            const SizedBox(height: 12),
            _label('Test text'),
            _field(_ttsTestCtrl, 'Hola, probando sistema Text to Speech.'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (ttsBusy || (ttsLoadState?.isLoading ?? false))
                    ? null
                    : () => appController.testTts(_ttsTestCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF53FC18),
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  ttsBusy
                      ? 'Reproduciendo TTS...'
                      : (ttsLoadState?.isLoading ?? false)
                          ? 'Cargando TTS...'
                          : 'Probar TTS',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Turn it on to configure voice, language and test playback.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('OBS Integration'),
          const Text(
            'Connect to OBS over WebSocket to show live status and the current program scene inside AirChat.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _switchRow('Enabled', s.obsEnabled, (v) {
            final next = s.copyWith(obsEnabled: v);
            if (!v) {
              unawaited(appController.disconnectObs());
            }
            unawaited(notifier.update(next));
          }),
          if (s.obsEnabled) ...[
            const SizedBox(height: 12),
            _label('WebSocket host'),
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
            _label('Password'),
            _field(
              _obsPassword,
              'Optional password',
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
                      ? 'Connecting to OBS...'
                      : obsState.connected
                          ? 'Disconnect OBS'
                          : (obsState.error != null &&
                                  obsState.error!.isNotEmpty)
                              ? 'Reconnect OBS'
                              : 'Connect OBS',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: obsState.connected
                      ? const Color(0xFFB54040)
                      : const Color(0xFF5B9CFF),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF2A2A2A),
                  disabledForegroundColor: Colors.white38,
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
            const Text(
              'HUD Elements',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _switchRow('Stream state', s.obsShowStreamState,
                (v) => notifier.update(s.copyWith(obsShowStreamState: v))),
            _switchRow('Current scene', s.obsShowCurrentScene,
                (v) => notifier.update(s.copyWith(obsShowCurrentScene: v))),
            _switchRow('Bitrate', s.obsShowBitrate,
                (v) => notifier.update(s.copyWith(obsShowBitrate: v))),
            _switchRow('FPS', s.obsShowFps,
                (v) => notifier.update(s.copyWith(obsShowFps: v))),
            _switchRow('Dropped frames', s.obsShowDroppedFrames,
                (v) => notifier.update(s.copyWith(obsShowDroppedFrames: v))),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Turn it on to enter the OBS host, password and connect on demand.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('Overlay Server'),
          const Text(
            'Enable a local browser source for OBS. When active, AirChat serves an overlay URL that you can paste into OBS.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _switchRow('Enabled', s.overlayEnabled,
              (v) => notifier.update(s.copyWith(overlayEnabled: v))),
          if (s.overlayEnabled) ...[
            const SizedBox(height: 12),
            _label('Port'),
            _field(
              _port,
              '8080',
              focusNode: _portFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
            ),
            const SizedBox(height: 10),
            _overlayUrlCard(
              overlayUrl: overlayCopyUrl,
              onCopy: () async {
                await Clipboard.setData(ClipboardData(text: overlayCopyUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Overlay URL copied'),
                    duration: Duration(milliseconds: 1400),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              overlayClientCount == 1
                  ? '1 overlay client connected'
                  : '$overlayClientCount overlay clients connected',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
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
                            ? 'Overlay reload sent'
                            : 'No overlay client connected',
                      ),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC877),
                  side: const BorderSide(color: Color(0xFF6A4C1D)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Reload Overlay',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _section('Overlay Mode'),
            _switchRow('Chroma key', s.overlayChromaMode,
                (v) => notifier.update(s.copyWith(overlayChromaMode: v))),
            _switchRow('Show grid', s.overlayShowGrid,
                (v) => notifier.update(s.copyWith(overlayShowGrid: v))),
            _switchRow('Hide scrollbar', s.overlayHideScrollbar,
                (v) => notifier.update(s.copyWith(overlayHideScrollbar: v))),
            if (s.overlayChromaMode) ...[
              const SizedBox(height: 6),
              _label('Chroma color'),
              _field(
                _overlayChromaColorCtrl,
                '#00FF00',
                focusNode: _overlayChromaColorFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
            ],
            const SizedBox(height: 12),
            _section('Platform Display'),
            _switchRow(
                'Platform icon',
                s.overlayShowPlatformIcons,
                (v) =>
                    notifier.update(s.copyWith(overlayShowPlatformIcons: v))),
            _switchRow(
                'Twitch accent',
                s.overlayTwitchBubbleAccent,
                (v) =>
                    notifier.update(s.copyWith(overlayTwitchBubbleAccent: v))),
            _switchRow('Kick accent', s.overlayKickBubbleAccent,
                (v) => notifier.update(s.copyWith(overlayKickBubbleAccent: v))),
            const SizedBox(height: 12),
            _section('Style Settings'),
            _sliderRow('Font size', s.overlayFontSize, 12, 32,
                (v) => notifier.update(s.copyWith(overlayFontSize: v))),
            _sliderRow('Line height', s.overlayLineHeight, 1, 2,
                (v) => notifier.update(s.copyWith(overlayLineHeight: v))),
            _sliderRow('Font weight', s.overlayFontWeight, 100, 900,
                (v) => notifier.update(s.copyWith(overlayFontWeight: v))),
            _sliderRow('Overlay bg', s.overlayBgOpacity, 0, 1,
                (v) => notifier.update(s.copyWith(overlayBgOpacity: v))),
            _switchRow('Avatars', s.overlayShowAvatars,
                (v) => notifier.update(s.copyWith(overlayShowAvatars: v))),
            _switchRow('Badges', s.overlayShowBadges,
                (v) => notifier.update(s.copyWith(overlayShowBadges: v))),
            _switchRow('Timestamp', s.overlayShowTimestamp,
                (v) => notifier.update(s.copyWith(overlayShowTimestamp: v))),
            _switchRow('Text shadow', s.overlayTextShadow,
                (v) => notifier.update(s.copyWith(overlayTextShadow: v))),
            _sliderRow('Text outline', s.overlayTextStroke, 0, 4,
                (v) => notifier.update(s.copyWith(overlayTextStroke: v))),
            if (s.overlayTextStroke > 0) ...[
              const SizedBox(height: 6),
              _label('Outline color'),
              _field(
                _overlayTextStrokeColorCtrl,
                '#000000',
                focusNode: _overlayTextStrokeColorFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
            ],
            const SizedBox(height: 12),
            _section('Message Design'),
            _switchRow('Bubble background', s.overlayShowBubble,
                (v) => notifier.update(s.copyWith(overlayShowBubble: v))),
            _dropdownRow(
              'Text alignment',
              s.overlayTextAlign,
              const ['left', 'center', 'right'],
              (v) => notifier.update(s.copyWith(overlayTextAlign: v)),
            ),
            _sliderRow('Bubble opacity', s.overlayMessageOpacity, 0, 1,
                (v) => notifier.update(s.copyWith(overlayMessageOpacity: v))),
            _sliderRow('Corner radius', s.overlayBorderRadius, 0, 30,
                (v) => notifier.update(s.copyWith(overlayBorderRadius: v))),
            _sliderRow('Vertical gap', s.overlayMessageGap, 0, 30,
                (v) => notifier.update(s.copyWith(overlayMessageGap: v))),
            _sliderRow(
                'Max messages',
                s.overlayMaxMessages.toDouble(),
                10,
                500,
                (v) =>
                    notifier.update(s.copyWith(overlayMaxMessages: v.round()))),
            _switchRow(
                'SuperChat color bar',
                s.overlaySuperChatBarEnabled,
                (v) =>
                    notifier.update(s.copyWith(overlaySuperChatBarEnabled: v))),
            if (s.overlaySuperChatBarEnabled) ...[
              const SizedBox(height: 6),
              _label('SuperChat bar color'),
              _field(
                _overlaySuperChatBarColorCtrl,
                '#1DE9B6',
                focusNode: _overlaySuperChatBarColorFocus,
                onChanged: (_) => _queueTextSettingsSave(),
                onSubmitted: (_) => _saveTextSettings(),
              ),
              _sliderRow(
                'SuperChat width',
                s.overlaySuperChatBarWidth,
                1,
                8,
                (v) => notifier.update(s.copyWith(overlaySuperChatBarWidth: v)),
              ),
            ],
            const SizedBox(height: 12),
            _section('Animation'),
            _dropdownRow(
              'Entrance',
              s.overlayAnimation,
              const ['slide-up', 'slide-left', 'fade-in', 'zoom-in'],
              (v) => notifier.update(s.copyWith(overlayAnimation: v)),
            ),
            _sliderRow(
                'Duration',
                s.overlayAnimationDuration,
                0.1,
                2,
                (v) =>
                    notifier.update(s.copyWith(overlayAnimationDuration: v))),
            const SizedBox(height: 12),
            _section('3D Transform'),
            _switchRow('Enable 3D effect', s.overlayThreeDEnabled,
                (v) => notifier.update(s.copyWith(overlayThreeDEnabled: v))),
            if (s.overlayThreeDEnabled) ...[
              _sliderRow('Perspective', s.overlayPerspective, 500, 2500,
                  (v) => notifier.update(s.copyWith(overlayPerspective: v))),
              _sliderRow('Rotate X', s.overlayRotateX, -180, 180,
                  (v) => notifier.update(s.copyWith(overlayRotateX: v))),
              _sliderRow('Rotate Y', s.overlayRotateY, -180, 180,
                  (v) => notifier.update(s.copyWith(overlayRotateY: v))),
              _sliderRow('Rotate Z', s.overlayRotateZ, -180, 180,
                  (v) => notifier.update(s.copyWith(overlayRotateZ: v))),
              _sliderRow('Skew X', s.overlaySkewX, -45, 45,
                  (v) => notifier.update(s.copyWith(overlaySkewX: v))),
              _sliderRow('Scale', s.overlayScale, 0.5, 2,
                  (v) => notifier.update(s.copyWith(overlayScale: v))),
            ],
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Turn it on to choose a port and reveal the OBS URL.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Widget _ttsStatusCard(TtsLoadState state) {
    final (label, color) = switch (state.phase) {
      TtsLoadPhase.ready => ('Ready', const Color(0xFF53FC18)),
      TtsLoadPhase.checking => ('Checking', Colors.lightBlueAccent),
      TtsLoadPhase.downloading => ('Downloading', Colors.orangeAccent),
      TtsLoadPhase.loading => ('Loading', Colors.amber),
      TtsLoadPhase.error => ('Error', Colors.redAccent),
      TtsLoadPhase.idle => ('Idle', Colors.white38),
    };
    final progressText = state.totalAssets > 0
        ? '${state.loadedAssets}/${state.totalAssets} assets'
        : null;
    final bytesText = state.totalBytes > 0
        ? '${formatByteSize(state.loadedBytes)} / ${formatByteSize(state.totalBytes)}'
        : null;
    final assetText = state.currentFile
        ?.split(RegExp(r'[\\/]'))
        .where((segment) => segment.isNotEmpty)
        .toList();
    final currentFileLabel = assetText == null || assetText.isEmpty
        ? null
        : assetText.length >= 2
            ? '${assetText[assetText.length - 2]}/${assetText.last}'
            : assetText.last;

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
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Supertonic: $label',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (state.progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: state.progress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          if (currentFileLabel != null && currentFileLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Current: $currentFileLabel',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (progressText != null || bytesText != null) ...[
            const SizedBox(height: 6),
            Text(
              [progressText, bytesText]
                  .whereType<String>()
                  .where((v) => v.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          if (state.voiceStyle != null) ...[
            const SizedBox(height: 6),
            Text(
              'Voice: ${_voiceLabel(state.voiceStyle!)}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (state.fromCache && state.cacheDirectory != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cache: ${state.cacheDirectory}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          if (state.error != null && state.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            color: Color(0xFF53FC18),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  static Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          t,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );

  static Widget _field(
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
          hintStyle: const TextStyle(color: Colors.white24),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIcon: onClear != null && ctrl.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  splashRadius: 14,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white38,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
        ),
      );

  static Widget _sidebarHeader({
    required String youtubeValue,
    required String twitchValue,
    required String kickValue,
    required Map<String, (ServiceStatus, String?)> statusMap,
  }) {
    final badges = <Widget>[
      if (youtubeValue.trim().isNotEmpty)
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
            const Text(
              'Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF2F2F2F)),
              ),
              child: const Text(
                'Ctrl+B',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2C2C2C)),
      ),
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
          const SizedBox(width: 8),
          Text(
            '$platform · $value',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );

  static Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                activeColor: const Color(0xFF53FC18),
                inactiveColor: const Color(0xFF2A2A2A),
                onChanged: onChanged,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                value.toStringAsFixed(value < 2 ? 2 : 0),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );

  static Widget _dropdownRow(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              items: options
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(_ttsOptionLabel(label, e)),
                      ))
                  .toList(),
              selectedItemBuilder: (context) => options
                  .map((e) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _ttsOptionLabel(label, e),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      );

  static String _ttsOptionLabel(String field, String value) {
    return switch (field) {
      'Voice' => _voiceLabel(value),
      'Language' => _languageLabel(value),
      _ => value,
    };
  }

  static String _voiceLabel(String value) {
    final match = RegExp(r'^([MF])(\d+)$').firstMatch(value.trim());
    if (match == null) return value;
    final prefix = match.group(1) == 'F' ? 'Female' : 'Male';
    return '$prefix ${match.group(2)}';
  }

  static String _languageLabel(String value) {
    const labels = {
      'en': 'English',
      'ko': 'Korean',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'bg': 'Bulgarian',
      'cs': 'Czech',
      'da': 'Danish',
      'de': 'German',
      'el': 'Greek',
      'es': 'Spanish',
      'et': 'Estonian',
      'fi': 'Finnish',
      'fr': 'French',
      'hi': 'Hindi',
      'hr': 'Croatian',
      'hu': 'Hungarian',
      'id': 'Indonesian',
      'it': 'Italian',
      'lt': 'Lithuanian',
      'lv': 'Latvian',
      'nl': 'Dutch',
      'pl': 'Polish',
      'pt': 'Portuguese',
      'ro': 'Romanian',
      'ru': 'Russian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'sv': 'Swedish',
      'tr': 'Turkish',
      'uk': 'Ukrainian',
      'vi': 'Vietnamese',
    };
    return labels[value] ?? value.toUpperCase();
  }

  static Widget _inlineErrorMessage(String platform, String error) {
    final normalized = error.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: Color(0xFFFF8A80),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$platform error: $normalized',
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _overlayUrlCard({
    required String overlayUrl,
    required VoidCallback onCopy,
  }) {
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
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'OBS URL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFACCBFF),
                    side: const BorderSide(color: Color(0xFF35527A)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            overlayUrl,
            style: const TextStyle(
              color: Color(0xFFACCBFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use this link as a Browser Source in OBS.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
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
    final (title, color) = _obsStatusVisuals(state);
    final showSecondaryStatus =
        !_obsStatusMessageDuplicatesTitle(title, state.statusMessage);

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
          if (showSecondaryStatus) ...[
            const SizedBox(height: 8),
            Text(
              state.statusMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
              'Scene: ${state.currentScene}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_showObsStreamState(displaySettings)) ...[
            const SizedBox(height: 6),
            Text(
              state.outputActive ? 'Output: Live' : 'Output: Offline',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
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
                    label:
                        'DROP ${state.dropPercentage.toStringAsFixed(1)}% (${state.droppedFrames})',
                    foreground: _obsDropBadgeForeground(state.dropTrend),
                    background: _obsDropBadgeBackground(state.dropTrend),
                    fontSize: 10,
                  ),
              ],
            ),
          ],
          if (state.error != null && state.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.error!,
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

(String, Color) _obsStatusVisuals(ObsState state) {
  return switch ((
    state.error,
    state.connecting,
    state.outputActive,
    state.connected,
  )) {
    (final String? error, _, _, _) when error != null && error.isNotEmpty => (
        'OBS Error',
        const Color(0xFFFF8A80)
      ),
    (_, true, _, _) => ('OBS Connecting', Colors.amberAccent),
    (_, _, true, _) => ('OBS Live', const Color(0xFF53FC18)),
    (_, _, _, true) => ('OBS Connected', const Color(0xFF86B8FF)),
    _ => ('OBS Ready', Colors.white54),
  };
}

bool _obsStatusMessageDuplicatesTitle(String title, String statusMessage) {
  final normalizedTitle = title.toLowerCase().replaceFirst('obs ', '').trim();
  final normalizedStatus = statusMessage.toLowerCase().trim();
  return normalizedTitle == normalizedStatus;
}

bool _showObsStreamState(SettingsModel? settings) =>
    settings?.obsShowStreamState ?? true;

bool _showObsScene(SettingsModel? settings, ObsState state) =>
    (settings?.obsShowCurrentScene ?? true) && state.currentScene.isNotEmpty;

bool _showObsBitrate(SettingsModel? settings) =>
    settings?.obsShowBitrate ?? true;

bool _showObsFps(SettingsModel? settings) => settings?.obsShowFps ?? true;

bool _showObsDroppedFrames(SettingsModel? settings) =>
    settings?.obsShowDroppedFrames ?? true;

Color _obsDropBadgeForeground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0xFFFF6B6B),
    ObsDropTrend.steady => const Color(0xFFFFD166),
    ObsDropTrend.normal => const Color(0xFFE7E7E7),
  };
}

Color _obsDropBadgeBackground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0x33FF6B6B),
    ObsDropTrend.steady => const Color(0x33FFD166),
    ObsDropTrend.normal => const Color(0xFF2A2A2A),
  };
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
    final outputLabel = state.outputActive ? 'LIVE' : 'OFF';
    final sceneLabel =
        state.currentScene.trim().isEmpty ? null : state.currentScene.trim();
    final bubbleOpacity = styleSettings.messageOpacity.clamp(0.0, 1.0);
    const neutralForeground = Color(0xFFE7E7E7);
    final backgroundColor = _obsCompactBackground(
      showBubble: styleSettings.showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final shadow = styleSettings.showBubble && styleSettings.showBubbleShadow
        ? const [
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ]
        : const <BoxShadow>[];
    final border = _obsCompactBorder(
      showBubble: styleSettings.showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final fontSize = styleSettings.fontSize;
    final badgeFontSize = (fontSize * 0.68).clamp(9.0, 12.0);
    final pillRadius = (styleSettings.borderRadius + 18).clamp(18.0, 30.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(pillRadius),
        border: border,
        boxShadow: shadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            if (_showObsStreamState(displaySettings)) ...[
              const SizedBox(width: 8),
              _ObsPillBadge(
                label: outputLabel,
                foreground: neutralForeground,
                background: Colors.transparent,
                fontSize: badgeFontSize,
              ),
            ],
            if (state.connected) ...[
              if (_showObsBitrate(displaySettings)) ...[
                const SizedBox(width: 6),
                _ObsPillBadge(
                  label: '${state.bitrateKbps.toStringAsFixed(0)}k',
                  foreground: neutralForeground,
                  background: Colors.transparent,
                  fontSize: badgeFontSize,
                ),
              ],
              if (_showObsFps(displaySettings)) ...[
                const SizedBox(width: 6),
                _ObsPillBadge(
                  label: '${state.fps.toStringAsFixed(0)}fps',
                  foreground: neutralForeground,
                  background: Colors.transparent,
                  fontSize: badgeFontSize,
                ),
              ],
              if (_showObsDroppedFrames(displaySettings)) ...[
                const SizedBox(width: 6),
                _ObsPillBadge(
                  label: state.dropPercentage > 0
                      ? 'drop ${state.dropPercentage.toStringAsFixed(1)}%'
                      : 'drop 0',
                  foreground: _obsDropBadgeForeground(state.dropTrend),
                  background: Colors.transparent,
                  fontSize: badgeFontSize,
                ),
              ],
            ],
            if (_showObsScene(displaySettings, state) &&
                sceneLabel != null) ...[
              const SizedBox(width: 6),
              _ObsPillBadge(
                label: sceneLabel,
                foreground: neutralForeground,
                background: Colors.transparent,
                maxWidth: 150,
                fontSize: badgeFontSize,
              ),
            ],
            if (state.error != null && state.error!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: state.error!,
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: Color(0xFFFF8A80),
                ),
              ),
            ],
          ],
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
    this.maxWidth,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double fontSize;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (maxWidth == null) return badge;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: badge,
    );
  }
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

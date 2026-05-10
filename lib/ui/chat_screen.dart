import 'dart:io';
import 'dart:async';

import 'package:airchat_flutter/services/supertonic_helper.dart'
    show availableLangs, formatByteSize;
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final scaffoldBg = const Color(0xFF0D0D0D).withValues(alpha: s.bgOpacity);
    final scaffold = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleSidebarVisibility,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: scaffoldBg,
          appBar: const _DesktopTopBar(),
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
      ),
    );

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return _DesktopResizeFrame(child: scaffold);
    }

    return scaffold;
  }

  Widget _chatList() {
    final chat = ref.watch(chatProvider);
    return chat.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF53FC18))),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.redAccent))),
      data: (messages) {
        if (messages.isEmpty) {
          final settings = ref.watch(settingsProvider);
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
          return Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (_, i) =>
                  ChatBubble(message: messages[messages.length - 1 - i]),
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
        );
      },
    );
  }
}

class _DesktopTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DesktopTopBar();

  static const _barHeight = 42.0;
  static const _accent = Color(0xFF5B9CFF);

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
          border: Border(
            bottom: BorderSide(color: Color(0xFF262626)),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCC151515),
              Color(0x66111111),
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
    final isRunning = ref.watch(chatConnectionProvider);
    final color = isRunning ? const Color(0xFF76E39F) : const Color(0xFF8A8A8A);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
  late TextEditingController _ytLiveId;
  late TextEditingController _twitch;
  late TextEditingController _kick;
  late TextEditingController _port;
  late TextEditingController _ttsTestCtrl;
  late TextEditingController _ttsPrefixCtrl;
  late TextEditingController _ttsSeparatorCtrl;

  late FocusNode _ytFocus;
  late FocusNode _ytLiveIdFocus;
  late FocusNode _twitchFocus;
  late FocusNode _kickFocus;
  late FocusNode _portFocus;
  late FocusNode _ttsPrefixFocus;
  late FocusNode _ttsSeparatorFocus;
  Timer? _textSettingsDebounce;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ytHandle = TextEditingController(text: s.youtubeHandle);
    _ytLiveId = TextEditingController(text: s.youtubeLiveId);
    _twitch = TextEditingController(text: s.twitchChannel);
    _kick = TextEditingController(text: s.kickSlug);
    _port = TextEditingController(text: s.overlayPort.toString());
    _ttsTestCtrl =
        TextEditingController(text: 'Hola, probando sistema Text to Speech.');
    _ttsPrefixCtrl = TextEditingController(text: s.ttsCommandPrefix);
    _ttsSeparatorCtrl = TextEditingController(text: s.ttsSeparatorText);

    _ytFocus = FocusNode();
    _ytLiveIdFocus = FocusNode();
    _twitchFocus = FocusNode();
    _kickFocus = FocusNode();
    _portFocus = FocusNode();
    _ttsPrefixFocus = FocusNode();
    _ttsSeparatorFocus = FocusNode();

    for (final node in [
      _ytFocus,
      _ytLiveIdFocus,
      _twitchFocus,
      _kickFocus,
      _portFocus,
      _ttsPrefixFocus,
      _ttsSeparatorFocus,
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
    _ytLiveId.dispose();
    _twitch.dispose();
    _kick.dispose();
    _port.dispose();
    _ttsTestCtrl.dispose();
    _ttsPrefixCtrl.dispose();
    _ttsSeparatorCtrl.dispose();

    _ytFocus.dispose();
    _ytLiveIdFocus.dispose();
    _twitchFocus.dispose();
    _kickFocus.dispose();
    _portFocus.dispose();
    _ttsPrefixFocus.dispose();
    _ttsSeparatorFocus.dispose();
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
    final next = current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: _ytLiveId.text.trim(),
      twitchChannel: _twitch.text.trim(),
      kickSlug: _kick.text.trim(),
      overlayPort: int.tryParse(_port.text.trim()) ?? current.overlayPort,
      ttsCommandPrefix: _ttsPrefixCtrl.text,
      ttsSeparatorText: _ttsSeparatorCtrl.text,
    );

    if (current.youtubeHandle == next.youtubeHandle &&
        current.youtubeLiveId == next.youtubeLiveId &&
        current.twitchChannel == next.twitchChannel &&
        current.kickSlug == next.kickSlug &&
        current.overlayPort == next.overlayPort &&
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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final win = ref.watch(windowStateProvider);
    final winNotifier = ref.read(windowStateProvider.notifier);
    final isRunning = ref.watch(chatConnectionProvider);
    final appController = ref.read(appControllerProvider);
    final ttsLoadState = ref.watch(ttsLoadStateProvider).valueOrNull;
    final ttsBusy = ref.watch(ttsBusyProvider).valueOrNull ?? false;

    _syncController(_ytHandle, _ytFocus, s.youtubeHandle);
    _syncController(_ytLiveId, _ytLiveIdFocus, s.youtubeLiveId);
    _syncController(_twitch, _twitchFocus, s.twitchChannel);
    _syncController(_kick, _kickFocus, s.kickSlug);
    _syncController(_port, _portFocus, s.overlayPort.toString());
    _syncController(_ttsPrefixCtrl, _ttsPrefixFocus, s.ttsCommandPrefix);
    _syncController(
      _ttsSeparatorCtrl,
      _ttsSeparatorFocus,
      s.ttsSeparatorText,
    );

    final hasChannels = _ytHandle.text.trim().isNotEmpty ||
        _ytLiveId.text.trim().isNotEmpty ||
        _twitch.text.trim().isNotEmpty ||
        _kick.text.trim().isNotEmpty;

    return Container(
      color: const Color(0xFF141414),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Connections'),
          _label('YouTube handle, channel ID, or video URL'),
          _field(
            _ytHandle,
            '@xqc · UC... · youtube.com/watch?v=...',
            focusNode: _ytFocus,
            onChanged: (_) {
              setState(() {});
              _queueTextSettingsSave();
            },
            onSubmitted: (_) => _saveTextSettings(),
          ),
          const SizedBox(height: 12),
          _label('YouTube live video ID (optional)'),
          _field(
            _ytLiveId,
            'live video ID',
            focusNode: _ytLiveIdFocus,
            onChanged: (_) {
              setState(() {});
              _queueTextSettingsSave();
            },
            onSubmitted: (_) => _saveTextSettings(),
          ),
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
          ),
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
          ),
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
          _section('Overlay Server'),
          _label('Port'),
          _field(
            _port,
            '8080',
            focusNode: _portFocus,
            onChanged: (_) => _queueTextSettingsSave(),
            onSubmitted: (_) => _saveTextSettings(),
          ),
          const SizedBox(height: 8),
          _switchRow('Enabled', s.overlayEnabled,
              (v) => notifier.update(s.copyWith(overlayEnabled: v))),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('Window'),
          _switchTileWithSubtitle(
            'Frameless',
            'Sin barra de titulo, sin bordes, sin sombra DWM.',
            win.frameless,
            (v) => winNotifier.setFrameless(v),
          ),
          _switchTileWithSubtitle(
            'Click-Through',
            'Los clics pasan a traves de la ventana.',
            win.clickThrough,
            (v) => winNotifier.setClickThrough(v),
            activeColor: const Color(0xFFFF6B35),
          ),
          _switchTileWithSubtitle(
            'Always on Top',
            'La ventana se mantiene sobre las demas.',
            win.alwaysOnTop,
            (v) => winNotifier.setAlwaysOnTop(v),
          ),
          if (win.clickThrough)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFFF6B35)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Click-through activo. Desactivalo desde la barra superior para volver a interactuar.',
                      style: TextStyle(color: Color(0xFFFF6B35), fontSize: 11),
                    ),
                  ),
                ],
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
          _sliderRow('Message opacity', s.messageOpacity, 0, 1,
              (v) => notifier.update(s.copyWith(messageOpacity: v))),
          _sliderRow('Border radius', s.borderRadius, 0, 24,
              (v) => notifier.update(s.copyWith(borderRadius: v))),
          _sliderRow('Message gap', s.messageGap, 0, 16,
              (v) => notifier.update(s.copyWith(messageGap: v))),
          _switchRow('Avatars', s.showAvatars,
              (v) => notifier.update(s.copyWith(showAvatars: v))),
          _switchRow('Badges', s.showBadges,
              (v) => notifier.update(s.copyWith(showBadges: v))),
          _switchRow('Timestamp', s.showTimestamp,
              (v) => notifier.update(s.copyWith(showTimestamp: v))),
          _switchRow('Bubble', s.showBubble,
              (v) => notifier.update(s.copyWith(showBubble: v))),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _section('TTS'),
          if (ttsLoadState != null) ...[
            _ttsStatusCard(ttsLoadState),
            const SizedBox(height: 12),
          ],
          _switchRow('TTS', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
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
              'Voice: ${state.voiceStyle}',
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
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) =>
      TextField(
        controller: ctrl,
        focusNode: focusNode,
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
          ),
        ),
      );

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
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ],
        ),
      );

  static Widget _switchTileWithSubtitle(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Color activeColor = const Color(0xFF53FC18),
  }) =>
      SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeColor,
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
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

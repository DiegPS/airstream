import 'dart:io';

import 'package:airchat_flutter/services/supertonic_helper.dart'
    show availableLangs;
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/ui/widgets/chat_bubble.dart';
import 'package:airchat_flutter/ui/widgets/window_control_bar.dart';
import 'package:airchat_flutter/window/acrylic_state.dart';
import 'package:airchat_flutter/window/window_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

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

  @override
  Widget build(BuildContext context) {
    final acrylicEffect = ref.watch(acrylicProvider).effect;
    final scaffoldBg = acrylicEffect == AcrylicEffectOption.disabled
        ? const Color(0xFF0D0D0D)
        : Colors.transparent;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Row(
        children: [
          const SizedBox(
            width: 360,
            child: _SettingsSidebar(),
          ),
          const VerticalDivider(width: 1, color: Color(0xFF2A2A2A)),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _chatList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final overlayUrl = ref.watch(overlayUrlProvider);
    final settings = ref.watch(settingsProvider);
    final isRunning = ref.watch(chatConnectionProvider);
    final hasChannels = settings.youtubeHandle.isNotEmpty ||
        settings.youtubeLiveId.isNotEmpty ||
        settings.twitchChannel.isNotEmpty ||
        settings.kickSlug.isNotEmpty;

    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      elevation: 0,
      title: const Text(
        'AirChat',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      actions: [
        _ConnectionDots(),
        if (overlayUrl != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                overlayUrl,
                style: const TextStyle(
                  color: Color(0xFF53FC18),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        const WindowControlBar(),
        IconButton(
          tooltip: isRunning ? 'Stop chat' : 'Start chat',
          icon: Icon(
            isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outline,
            color: hasChannels ? const Color(0xFF53FC18) : Colors.white24,
          ),
          onPressed: hasChannels
              ? () {
                  ref.read(chatConnectionProvider.notifier).state = !isRunning;
                }
              : null,
        ),
      ],
    );
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
  }

  @override
  void dispose() {
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

  Future<void> _saveTextSettings() async {
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);
    await notifier.update(current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: _ytLiveId.text.trim(),
      twitchChannel: _twitch.text.trim(),
      kickSlug: _kick.text.trim(),
      overlayPort: int.tryParse(_port.text.trim()) ?? current.overlayPort,
      ttsCommandPrefix: _ttsPrefixCtrl.text,
      ttsSeparatorText: _ttsSeparatorCtrl.text,
    ));
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
    controller.text = value;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final win = ref.watch(windowStateProvider);
    final winNotifier = ref.read(windowStateProvider.notifier);
    final isRunning = ref.watch(chatConnectionProvider);
    final appController = ref.read(appControllerProvider);

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
          const Text(
            'AirChat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _section('Connections'),
          _label('YouTube handle, channel ID, or video URL'),
          _field(
            _ytHandle,
            '@xqc · UC... · youtube.com/watch?v=...',
            focusNode: _ytFocus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              notifier.update(s.copyWith(youtubeHandle: v.trim()));
            },
          ),
          const SizedBox(height: 12),
          _label('YouTube live video ID (optional)'),
          _field(
            _ytLiveId,
            'live video ID',
            focusNode: _ytLiveIdFocus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              notifier.update(s.copyWith(youtubeLiveId: v.trim()));
            },
          ),
          const SizedBox(height: 12),
          _label('Twitch channel'),
          _field(
            _twitch,
            'xqc',
            focusNode: _twitchFocus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              notifier.update(s.copyWith(twitchChannel: v.trim()));
            },
          ),
          const SizedBox(height: 12),
          _label('Kick slug'),
          _field(
            _kick,
            'xqc',
            focusNode: _kickFocus,
            onChanged: (_) => setState(() {}),
            onSubmitted: (v) {
              notifier.update(s.copyWith(kickSlug: v.trim()));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _saveTextSettings,
              child: const Text('Save fields'),
            ),
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
            onSubmitted: (v) {
              final port = int.tryParse(v.trim());
              if (port != null) {
                notifier.update(s.copyWith(overlayPort: port));
              }
            },
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
                border:
                    Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.5)),
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
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) ...[
            const SizedBox(height: 8),
            ..._buildAcrylicSection(),
          ],
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
          _switchRow('TTS', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
          _switchRow('Members only', s.ttsMembersOnly,
              (v) => notifier.update(s.copyWith(ttsMembersOnly: v))),
          _switchRow('Command mode (!voz)', s.ttsCommandMode,
              (v) => notifier.update(s.copyWith(ttsCommandMode: v))),
          if (s.ttsCommandMode) ...[
            const SizedBox(height: 8),
            _label('Command prefix'),
            _field(
              _ttsPrefixCtrl,
              '!voz',
              focusNode: _ttsPrefixFocus,
              onChanged: (v) =>
                  notifier.update(s.copyWith(ttsCommandPrefix: v)),
            ),
          ],
          const SizedBox(height: 8),
          _label('Separator text'),
          _field(
            _ttsSeparatorCtrl,
            'dice',
            focusNode: _ttsSeparatorFocus,
            onChanged: (v) =>
                notifier.update(s.copyWith(ttsSeparatorText: v)),
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
              onPressed: () => appController.testTts(_ttsTestCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF53FC18),
                foregroundColor: Colors.black,
              ),
              child: const Text('Probar TTS'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Widget> _buildAcrylicSection() {
    final acrylic = ref.watch(acrylicProvider);
    final acrylicN = ref.read(acrylicProvider.notifier);

    return [
      _section('Visual Effects'),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: AcrylicEffectOption.values.map((opt) {
            final selected = acrylic.effect == opt;
            return ChoiceChip(
              avatar: Icon(opt.icon,
                  size: 14, color: selected ? Colors.black : Colors.white54),
              label: Text(opt.label,
                  style: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.black : Colors.white70)),
              selected: selected,
              selectedColor: const Color(0xFF53FC18),
              backgroundColor: const Color(0xFF1E1E1E),
              onSelected: (_) => acrylicN.setEffect(opt),
            );
          }).toList(),
        ),
      ),
      if (acrylic.effect == AcrylicEffectOption.acrylic ||
          acrylic.effect == AcrylicEffectOption.aero)
        _sliderRow(
          'Tint opacity',
          acrylic.tintColor.a,
          0,
          1,
          (v) =>
              acrylicN.setTintColor(Color.fromARGB((v * 255).round(), 0, 0, 0)),
        ),
    ];
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
        children: platforms
            .where((p) => p.$2)
            .map((p) {
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

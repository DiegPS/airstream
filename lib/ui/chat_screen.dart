import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airchat_flutter/settings/settings_notifier.dart';
import 'package:airchat_flutter/ui/settings/settings_screen.dart';
import 'package:airchat_flutter/ui/widgets/chat_bubble.dart';

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
    // With reverse:true, pixels==0 means we're at the newest messages.
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
    final isWide = MediaQuery.of(context).size.width >= 700;

    if (isWide) {
      return _tabletLayout();
    }
    return _phoneLayout();
  }

  // ── Phone layout ─────────────────────────────────────────────────────────────

  Widget _phoneLayout() => Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: _buildAppBar(),
        body: _chatList(),
      );

  // ── Tablet layout ─────────────────────────────────────────────────────────────

  Widget _tabletLayout() => Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Row(
          children: [
            SizedBox(
              width: 300,
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

  AppBar _buildAppBar() {
    final overlayUrl = ref.watch(overlayUrlProvider);
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
        // ── Botones de acceso rápido para overlay mode ────────────────────
        // Always-on-top toggle
        Consumer(builder: (ctx, r, _) {
          final s = r.watch(settingsProvider);
          final notifier = r.read(settingsProvider.notifier);
          return Tooltip(
            message: s.alwaysOnTop ? 'Desactivar Always on Top' : 'Always on Top',
            child: IconButton(
              icon: Icon(
                Icons.push_pin,
                color: s.alwaysOnTop
                    ? const Color(0xFF53FC18)
                    : Colors.white38,
                size: 20,
              ),
              onPressed: () =>
                  notifier.update(s.copyWith(alwaysOnTop: !s.alwaysOnTop)),
            ),
          );
        }),
        // Click-through toggle — naranja para que sea visible cuando está activo
        Consumer(builder: (ctx, r, _) {
          final s = r.watch(settingsProvider);
          final notifier = r.read(settingsProvider.notifier);
          return Tooltip(
            message: s.clickThrough
                ? '⚠ Click-Through ACTIVO — toca para desactivar'
                : 'Activar Click-Through',
            child: IconButton(
              icon: Icon(
                s.clickThrough
                    ? Icons.mouse_outlined
                    : Icons.mouse,
                color: s.clickThrough
                    ? const Color(0xFFFF6B35)
                    : Colors.white38,
                size: 20,
              ),
              onPressed: () =>
                  notifier.update(s.copyWith(clickThrough: !s.clickThrough)),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white70),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
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
          return const Center(
            child: Text(
              'No messages yet.\nConfigure channels in Settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              // reverse: true anchors to the bottom automatically.
              // New messages appear at the bottom without any programmatic scroll.
              reverse: true,
              padding: const EdgeInsets.all(8),
              itemCount: messages.length,
              // Newest message is at index 0 in the reversed view.
              itemBuilder: (_, i) => ChatBubble(message: messages[messages.length - 1 - i]),
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

// ── Tablet sidebar ────────────────────────────────────────────────────────────

class _SettingsSidebar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsSidebar> createState() => _SettingsSidebarState();
}

class _SettingsSidebarState extends ConsumerState<_SettingsSidebar> {
  late TextEditingController _ytHandle;
  late TextEditingController _twitch;
  late TextEditingController _kick;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _ytHandle = TextEditingController(text: s.youtubeHandle);
    _twitch = TextEditingController(text: s.twitchChannel);
    _kick = TextEditingController(text: s.kickSlug);
  }

  @override
  void dispose() {
    _ytHandle.dispose();
    _twitch.dispose();
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      color: const Color(0xFF141414),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('AirChat',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _label('YouTube handle'),
          _field(_ytHandle, '@MrBeast', onSubmitted: (v) {
            notifier.update(s.copyWith(youtubeHandle: v.trim()));
          }),
          const SizedBox(height: 12),
          _label('Twitch channel'),
          _field(_twitch, 'xqc', onSubmitted: (v) {
            notifier.update(s.copyWith(twitchChannel: v.trim()));
          }),
          const SizedBox(height: 12),
          _label('Kick slug'),
          _field(_kick, 'xqc', onSubmitted: (v) {
            notifier.update(s.copyWith(kickSlug: v.trim()));
          }),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 12),
          _label('Font size'),
          Slider(
            value: s.fontSize.clamp(10.0, 28.0),
            min: 10,
            max: 28,
            // ignore: deprecated_member_use
            activeColor: const Color(0xFF53FC18),
            inactiveColor: const Color(0xFF2A2A2A),
            onChanged: (v) => notifier.update(s.copyWith(fontSize: v)),
          ),
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
          _switchRow('TTS', s.ttsEnabled,
              (v) => notifier.update(s.copyWith(ttsEnabled: v))),
        ],
      ),
    );
  }

  static Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child:
            Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      );

  static Widget _field(
    TextEditingController ctrl,
    String hint, {
    ValueChanged<String>? onSubmitted,
  }) =>
      TextField(
        controller: ctrl,
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            // ignore: deprecated_member_use
            activeColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );
}

// ── Connection status dots ─────────────────────────────────────────────────────

class _ConnectionDots extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);

    final platforms = <(String, bool, String)>[
      // (label, isConfigured, key)
      ('YT', settings.youtubeHandle.isNotEmpty || settings.youtubeLiveId.isNotEmpty, 'youtube'),
      ('TW', settings.twitchChannel.isNotEmpty, 'twitch'),
      ('KK', settings.kickSlug.isNotEmpty, 'kick'),
    ];

    final statusMap = status.valueOrNull ?? {};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: platforms
            .where((p) => p.$2) // only show configured ones
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

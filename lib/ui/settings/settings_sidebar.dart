part of 'package:airstream/ui/chat_screen.dart';

class _SettingsSidebar extends ConsumerStatefulWidget {
  const _SettingsSidebar();

  @override
  ConsumerState<_SettingsSidebar> createState() => _SettingsSidebarState();
}

class _SettingsSidebarState extends ConsumerState<_SettingsSidebar> {
  void _mutate(VoidCallback mutation) => setState(mutation);

  int _selectedTab = 0;

  late TextEditingController _ytHandle;
  late TextEditingController _ytHorizontalUrl;
  late TextEditingController _ytVerticalUrl;
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
  late FocusNode _ytHorizontalFocus;
  late FocusNode _ytVerticalFocus;
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
    _ytHorizontalUrl = TextEditingController(text: s.youtubeHorizontalUrl);
    _ytVerticalUrl = TextEditingController(text: s.youtubeVerticalUrl);
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
    _ytHorizontalFocus = FocusNode();
    _ytVerticalFocus = FocusNode();
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
      _ytHorizontalFocus,
      _ytVerticalFocus,
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
      _ytHorizontalFocus,
      _ytVerticalFocus,
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
    _ytHorizontalUrl.dispose();
    _ytVerticalUrl.dispose();
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
      _ytHorizontalFocus,
      _ytVerticalFocus,
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
    final parsedOverlayPort = int.tryParse(_port.text.trim());
    final validOverlayPort = parsedOverlayPort != null &&
        parsedOverlayPort >= 1 &&
        parsedOverlayPort <= 65535;
    final next = current.copyWith(
      youtubeHandle: _ytHandle.text.trim(),
      youtubeLiveId: '',
      youtubeHorizontalUrl: _ytHorizontalUrl.text.trim(),
      youtubeVerticalUrl: _ytVerticalUrl.text.trim(),
      twitchChannel: normalizedTwitch,
      kickSlug: normalizedKick,
      blockedUsers: blockedUsers,
      blockedWords: blockedWords,
      overlayPort: validOverlayPort ? parsedOverlayPort : current.overlayPort,
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
        current.youtubeHorizontalUrl == next.youtubeHorizontalUrl &&
        current.youtubeVerticalUrl == next.youtubeVerticalUrl &&
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
    if (ref.read(chatConnectionProvider)) {
      ref.read(appControllerProvider).retryChatConnections();
    } else {
      ref.read(chatConnectionProvider.notifier).state = true;
    }
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
    } catch (_) {
      // Non-URL channel values are valid and are normalized below.
    }

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

  bool get _dualYoutubeUrlsAreValid {
    final horizontal = YouTubeService.videoIdFromUrl(_ytHorizontalUrl.text);
    final vertical = YouTubeService.videoIdFromUrl(_ytVerticalUrl.text);
    return horizontal != null && vertical != null && horizontal != vertical;
  }

  static (ServiceStatus, String?) _combinedYoutubeStatus(
    (ServiceStatus, String?)? horizontal,
    (ServiceStatus, String?)? vertical,
  ) {
    final statuses = [
      horizontal?.$1 ?? ServiceStatus.connecting,
      vertical?.$1 ?? ServiceStatus.connecting,
    ];
    if (statuses.every((status) => status == ServiceStatus.connected)) {
      return (ServiceStatus.connected, null);
    }
    if (statuses.every((status) => status == ServiceStatus.error)) {
      return (
        ServiceStatus.error,
        horizontal?.$2 ?? vertical?.$2,
      );
    }
    return (ServiceStatus.connecting, null);
  }

  String? _youtubeStreamUrlError(
    AppLocalizations l,
    String value, {
    String? otherUrl,
  }) {
    if (value.trim().isEmpty) return null;
    final videoId = YouTubeService.videoIdFromUrl(value);
    if (videoId == null) return l.youtubeInvalidStreamUrl;
    final otherId = YouTubeService.videoIdFromUrl(otherUrl ?? '');
    if (otherId != null && otherId == videoId) {
      return l.youtubeDuplicateStreamUrl;
    }
    return null;
  }

  Widget _youtubeDualModeRow({
    required AppLocalizations l,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF303030)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 1,
                  child: _streamOrientationShape(
                    YoutubeStreamOrientation.horizontal,
                    active: enabled,
                  ),
                ),
                Positioned(
                  right: 2,
                  child: _streamOrientationShape(
                    YoutubeStreamOrientation.vertical,
                    active: enabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.youtubeDualMode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.youtubeDualModeDescription,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _youtubeStreamField({
    required String label,
    required YoutubeStreamOrientation orientation,
    required TextEditingController controller,
    required FocusNode focusNode,
    String? errorText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF303030)),
          ),
          child: _streamOrientationShape(orientation, active: true),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(label),
              _field(
                controller,
                AppLocalizations.of(context)!.youtubeStreamUrlHint,
                focusNode: focusNode,
                errorText: errorText,
                onChanged: (_) {
                  setState(() {});
                },
                onSubmitted: (_) => _saveTextSettings(),
                onClear: () {
                  controller.clear();
                  setState(() {});
                  _saveTextSettings();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _streamOrientationShape(
    YoutubeStreamOrientation orientation, {
    required bool active,
  }) {
    final vertical = orientation == YoutubeStreamOrientation.vertical;
    return Container(
      width: vertical ? 11 : 23,
      height: vertical ? 21 : 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2.5),
        border: Border.all(
          color: active ? const Color(0xFFFF5A52) : Colors.white30,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final l = AppLocalizations.of(context)!;
    final notifier = ref.read(settingsProvider.notifier);
    final chatRequested = ref.watch(chatConnectionProvider);
    final sessionPhase = ref.watch(chatSessionPhaseProvider);
    final isRunning = sessionPhase == ChatSessionPhase.connecting ||
        sessionPhase == ChatSessionPhase.connected ||
        sessionPhase == ChatSessionPhase.partiallyConnected;
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
    final overlayState = ref.watch(overlayServerStateProvider).valueOrNull ??
        const OverlayServerState();
    final overlayClientCount =
        ref.watch(overlayClientCountProvider).valueOrNull ?? 0;
    final overlayCopyUrl = overlayUrl ?? 'http://localhost:${s.overlayPort}';
    final alertsCopyUrl = '$overlayCopyUrl/alerts';
    final captionsCopyUrl = '$overlayCopyUrl/captions';

    _syncController(_ytHandle, _ytFocus, _youtubeInputValue(s));
    _syncController(
      _ytHorizontalUrl,
      _ytHorizontalFocus,
      s.youtubeHorizontalUrl,
    );
    _syncController(
      _ytVerticalUrl,
      _ytVerticalFocus,
      s.youtubeVerticalUrl,
    );
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

    final dualYoutubeValid = _dualYoutubeUrlsAreValid;
    final hasChannels = (s.youtubeEnabled &&
            (s.youtubeDualStreamEnabled
                ? dualYoutubeValid
                : _ytHandle.text.trim().isNotEmpty)) ||
        (s.twitchEnabled && _twitch.text.trim().isNotEmpty) ||
        (s.kickEnabled && _kick.text.trim().isNotEmpty);
    final youtubeState = connectionStatus['youtube'];
    final twitchState = connectionStatus['twitch'];
    final kickState = connectionStatus['kick'];
    final youtubeError = s.youtubeEnabled &&
            !s.youtubeDualStreamEnabled &&
            youtubeState?.$1 == ServiceStatus.error
        ? youtubeState?.$2
        : null;
    final youtubeHorizontalError = s.youtubeEnabled &&
            s.youtubeDualStreamEnabled &&
            connectionStatus['youtubeHorizontal']?.$1 == ServiceStatus.error
        ? connectionStatus['youtubeHorizontal']?.$2
        : null;
    final youtubeVerticalError = s.youtubeEnabled &&
            s.youtubeDualStreamEnabled &&
            connectionStatus['youtubeVertical']?.$1 == ServiceStatus.error
        ? connectionStatus['youtubeVertical']?.$2
        : null;
    final displayConnectionStatus = Map<String, (ServiceStatus, String?)>.from(
      connectionStatus,
    );
    if (s.youtubeDualStreamEnabled) {
      displayConnectionStatus['youtube'] = _combinedYoutubeStatus(
        connectionStatus['youtubeHorizontal'],
        connectionStatus['youtubeVertical'],
      );
    }
    final twitchError =
        s.twitchEnabled && twitchState?.$1 == ServiceStatus.error
            ? twitchState?.$2
            : null;
    final kickError = s.kickEnabled && kickState?.$1 == ServiceStatus.error
        ? kickState?.$2
        : null;

    final tabs = [
      SidebarTabItem(
        icon: Icons.sensors_rounded,
        label: l.connections,
        badgeColor: switch (sessionPhase) {
          ChatSessionPhase.connected => const Color(0xFF53FC18),
          ChatSessionPhase.partiallyConnected => Colors.amber,
          ChatSessionPhase.connecting => Colors.amber,
          ChatSessionPhase.failed => const Color(0xFFFF6B6B),
          ChatSessionPhase.idle => null,
        },
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
                    youtubeValue: chatRequested && s.youtubeEnabled
                        ? (s.youtubeDualStreamEnabled
                            ? l.youtubeDualMode
                            : (youtubeBadgeValue ?? _youtubeInputValue(s)))
                        : null,
                    twitchValue:
                        chatRequested && s.twitchEnabled ? s.twitchChannel : '',
                    kickValue: chatRequested && s.kickEnabled ? s.kickSlug : '',
                    statusMap: displayConnectionStatus,
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
                      sessionPhase,
                      hasChannels,
                      youtubeError,
                      youtubeHorizontalError,
                      youtubeVerticalError,
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
                      overlayState.phase == OverlayServerPhase.ready,
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
                      overlayState,
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
    ValueChanged<bool>? onChanged, {
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
    String? errorText,
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
          errorText: errorText,
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

  String? _overlayPortError(AppLocalizations l) {
    final value = int.tryParse(_port.text.trim());
    if (value != null && value >= 1 && value <= 65535) return null;
    return l.invalidOverlayPort;
  }

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
    String platform, {
    required VoidCallback onRetry,
  }) {
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
          const SizedBox(width: 6),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFB4AB),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 28),
            ),
            child: Text(
              l.retryPlatform(platform),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statusMessage(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 11, height: 1.3),
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

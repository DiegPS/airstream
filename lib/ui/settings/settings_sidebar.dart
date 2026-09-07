part of 'package:airstream/ui/chat_screen.dart';

class _SettingsSidebar extends ConsumerStatefulWidget {
  const _SettingsSidebar();

  @override
  ConsumerState<_SettingsSidebar> createState() => _SettingsSidebarState();
}

class _SettingsSidebarState extends ConsumerState<_SettingsSidebar> {
  void _mutate(VoidCallback mutation) => setState(mutation);

  int _selectedTab = 0;

  late final _SettingsFormControllers _form;
  Timer? _textSettingsDebounce;

  @override
  void initState() {
    super.initState();
    _form = _SettingsFormControllers(ref.read(settingsProvider));

    for (final node in _form.focusNodes) {
      node.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _textSettingsDebounce?.cancel();

    for (final node in _form.focusNodes) {
      node.removeListener(_handleFocusChange);
    }

    _form.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final anyHasFocus = [
      _form.ytFocus,
      _form.ytHorizontalFocus,
      _form.ytVerticalFocus,
      _form.twitchFocus,
      _form.kickFocus,
      _form.portFocus,
      _form.obsHostFocus,
      _form.obsPasswordFocus,
      _form.overlayChromaColorFocus,
      _form.overlayTextStrokeColorFocus,
      _form.overlaySuperChatBarColorFocus,
      _form.ttsPrefixFocus,
      _form.ttsSeparatorFocus,
      _form.ttsReferenceTextFocus,
      _form.voiceWakeWordFocus,
      _form.blockedUsersFocus,
      _form.blockedWordsFocus,
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
    final normalizedTwitch =
        SettingsInputNormalizer.platformChannel(_form.twitch.text);
    final normalizedKick =
        SettingsInputNormalizer.platformChannel(_form.kick.text);
    final blockedUsers = SettingsInputNormalizer.filterList(
      _form.blockedUsers.text,
    );
    final blockedWords = SettingsInputNormalizer.filterList(
      _form.blockedWords.text,
    );
    final next = current.copyWith(
      youtubeHandle: _form.ytHandle.text.trim(),
      youtubeLiveId: '',
      youtubeHorizontalUrl: _form.ytHorizontalUrl.text.trim(),
      youtubeVerticalUrl: _form.ytVerticalUrl.text.trim(),
      twitchChannel: normalizedTwitch,
      kickSlug: normalizedKick,
      blockedUsers: blockedUsers,
      blockedWords: blockedWords,
      overlayPort: SettingsInputNormalizer.overlayPort(
        _form.port.text,
        fallback: current.overlayPort,
      ),
      overlayChromaColor: SettingsInputNormalizer.hexColor(
        _form.overlayChromaColor.text,
        fallback: current.overlayChromaColor,
      ),
      overlayTextStrokeColor: SettingsInputNormalizer.hexColor(
        _form.overlayTextStrokeColor.text,
        fallback: current.overlayTextStrokeColor,
      ),
      overlaySuperChatBarColor: SettingsInputNormalizer.hexColor(
        _form.overlaySuperChatBarColor.text,
        fallback: current.overlaySuperChatBarColor,
      ),
      obsHost: _form.obsHost.text.trim(),
      obsPassword: _form.obsPassword.text,
      ttsCommandPrefix: _form.ttsPrefix.text,
      ttsSeparatorText: _form.ttsSeparator.text,
      ttsReferenceText: _form.ttsReferenceText.text,
      voiceCommandsWakeWord: _form.voiceWakeWord.text.trim(),
    );

    if (current.youtubeHandle == next.youtubeHandle &&
        current.youtubeHorizontalUrl == next.youtubeHorizontalUrl &&
        current.youtubeVerticalUrl == next.youtubeVerticalUrl &&
        current.twitchChannel == next.twitchChannel &&
        current.kickSlug == next.kickSlug &&
        SettingsInputNormalizer.listsEqual(
          current.blockedUsers,
          next.blockedUsers,
        ) &&
        SettingsInputNormalizer.listsEqual(
          current.blockedWords,
          next.blockedWords,
        ) &&
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

  bool get _dualYoutubeUrlsAreValid {
    return SettingsInputNormalizer.distinctYoutubeVideoUrls(
      _form.ytHorizontalUrl.text,
      _form.ytVerticalUrl.text,
    );
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
    final videoId = SettingsInputNormalizer.youtubeVideoId(value);
    if (videoId == null) return l.youtubeInvalidStreamUrl;
    final otherId = SettingsInputNormalizer.youtubeVideoId(otherUrl ?? '');
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
    final youtubeMetadata = ref.watch(youtubeMetadataProvider).valueOrNull ??
        const YoutubeLiveMetadataSummary();
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

    _syncController(_form.ytHandle, _form.ytFocus, _youtubeInputValue(s));
    _syncController(
      _form.ytHorizontalUrl,
      _form.ytHorizontalFocus,
      s.youtubeHorizontalUrl,
    );
    _syncController(
      _form.ytVerticalUrl,
      _form.ytVerticalFocus,
      s.youtubeVerticalUrl,
    );
    _syncController(_form.twitch, _form.twitchFocus, s.twitchChannel);
    _syncController(_form.kick, _form.kickFocus, s.kickSlug);
    _syncController(_form.port, _form.portFocus, s.overlayPort.toString());
    _syncController(_form.obsHost, _form.obsHostFocus, s.obsHost);
    _syncController(_form.obsPassword, _form.obsPasswordFocus, s.obsPassword);
    _syncController(
      _form.overlayChromaColor,
      _form.overlayChromaColorFocus,
      s.overlayChromaColor,
    );
    _syncController(
      _form.overlayTextStrokeColor,
      _form.overlayTextStrokeColorFocus,
      s.overlayTextStrokeColor,
    );
    _syncController(
      _form.overlaySuperChatBarColor,
      _form.overlaySuperChatBarColorFocus,
      s.overlaySuperChatBarColor,
    );
    _syncController(_form.ttsPrefix, _form.ttsPrefixFocus, s.ttsCommandPrefix);
    _syncController(
      _form.ttsSeparator,
      _form.ttsSeparatorFocus,
      s.ttsSeparatorText,
    );
    _syncController(
      _form.ttsReferenceText,
      _form.ttsReferenceTextFocus,
      s.ttsReferenceText,
    );
    _syncController(
      _form.voiceWakeWord,
      _form.voiceWakeWordFocus,
      s.voiceCommandsWakeWord,
    );
    _syncController(
      _form.blockedUsers,
      _form.blockedUsersFocus,
      SettingsInputNormalizer.formatFilterList(s.blockedUsers),
    );
    _syncController(
      _form.blockedWords,
      _form.blockedWordsFocus,
      SettingsInputNormalizer.formatFilterList(s.blockedWords),
    );

    final dualYoutubeValid = _dualYoutubeUrlsAreValid;
    final hasChannels = (s.youtubeEnabled &&
            (s.youtubeDualStreamEnabled
                ? dualYoutubeValid
                : _form.ytHandle.text.trim().isNotEmpty)) ||
        (s.twitchEnabled && _form.twitch.text.trim().isNotEmpty) ||
        (s.kickEnabled && _form.kick.text.trim().isNotEmpty);
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
                      youtubeMetadata,
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
    return SettingsInputNormalizer.isValidOverlayPort(_form.port.text)
        ? null
        : l.invalidOverlayPort;
  }
}

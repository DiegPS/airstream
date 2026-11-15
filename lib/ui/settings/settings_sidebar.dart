part of 'package:airstream/ui/chat_screen.dart';

class _SettingsSidebar extends ConsumerStatefulWidget {
  const _SettingsSidebar();

  @override
  ConsumerState<_SettingsSidebar> createState() => _SettingsSidebarState();
}

class _SettingsSidebarState extends ConsumerState<_SettingsSidebar> {
  /// Re-renders the visible tab after a local form change (typing in a
  /// field) without rebuilding the whole sidebar.
  void _mutate(VoidCallback mutation) {
    mutation();
    _tabRevisions[_selectedTab].value++;
  }

  int _selectedTab = 0;
  final _visitedTabs = <int>{0};
  final _tabPages = <int, Widget>{};
  final _tabContents = <int, Widget>{};

  /// Bumped to rebuild one tab's content.
  final _tabRevisions = List.generate(_tabCount, (_) => ValueNotifier<int>(0));

  /// Hidden tabs whose data changed since they were last shown.
  final _staleTabs = <int>{};

  late final _SettingsFormControllers _form;
  Timer? _textSettingsDebounce;

  @override
  void initState() {
    super.initState();
    _form = _SettingsFormControllers(ref.read(settingsProvider));

    for (final node in _form.focusNodes) {
      node.addListener(_handleFocusChange);
    }
    ref.listenManual<SettingsModel>(
      settingsProvider,
      (_, next) => _syncControllers(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _textSettingsDebounce?.cancel();

    for (final node in _form.focusNodes) {
      node.removeListener(_handleFocusChange);
    }

    _form.dispose();
    for (final revision in _tabRevisions) {
      revision.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    final anyHasFocus = _form.focusNodes.any((n) => n.hasFocus);

    if (!anyHasFocus) {
      _saveTextSettings();
      // Show the saved (normalized) values once editing ends.
      _syncControllers(ref.read(settingsProvider));
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

  void _channelEdited() {
    _mutate(() {});
    // A running chat reconnects on every saved change, so it only picks up
    // the channel on Enter or when the field loses focus.
    if (!ref.read(chatConnectionProvider)) _queueTextSettingsSave();
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
    final highlightWords =
        SettingsInputNormalizer.filterList(_form.highlightWords.text);
    final ttsIgnoredUsers =
        SettingsInputNormalizer.filterList(_form.ttsIgnoredUsers.text);
    final next = current.copyWith(
      youtubeHandle: _form.ytHandle.text.trim(),
      youtubeLiveId: '',
      youtubeHorizontalUrl: _form.ytHorizontalUrl.text.trim(),
      youtubeVerticalUrl: _form.ytVerticalUrl.text.trim(),
      twitchChannel: normalizedTwitch,
      kickSlug: normalizedKick,
      blockedUsers: blockedUsers,
      blockedWords: blockedWords,
      highlightWords: highlightWords,
      ttsIgnoredUsers: ttsIgnoredUsers,
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
        SettingsInputNormalizer.listsEqual(
            current.highlightWords, next.highlightWords) &&
        SettingsInputNormalizer.listsEqual(
            current.ttsIgnoredUsers, next.ttsIgnoredUsers) &&
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
                onChanged: (_) => _mutate(() {}),
                onSubmitted: (_) => _saveTextSettings(),
                onClear: () {
                  controller.clear();
                  _mutate(() {});
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

  /// Keeps the text fields in step with settings changed elsewhere (for
  /// example the language or a value restored after loading). Fields being
  /// edited keep what the user is typing.
  void _syncControllers(SettingsModel s) {
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
    _syncController(
      _form.highlightWords,
      _form.highlightWordsFocus,
      SettingsInputNormalizer.formatFilterList(s.highlightWords),
    );
    _syncController(
      _form.ttsIgnoredUsers,
      _form.ttsIgnoredUsersFocus,
      SettingsInputNormalizer.formatFilterList(s.ttsIgnoredUsers),
    );
  }

  static const _tabCount = 5;

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _selectedTab = index;
      _visitedTabs.add(index);
    });
    // A tab whose data did not change shows its kept build as is.
    if (_staleTabs.remove(index)) _tabRevisions[index].value++;
  }

  /// A tab page built once and kept: its scroll position, expanded cards and
  /// fields survive tab switches. Only the selected tab rebuilds when the
  /// data it shows changes.
  Widget _tabPage(int index) => _tabPages[index] ??= SingleChildScrollView(
        key: PageStorageKey<String>('sidebar-tab-$index'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: ValueListenableBuilder<int>(
          valueListenable: _tabRevisions[index],
          builder: (context, _, __) => Consumer(
            builder: (context, ref, _) {
              final cached = _tabContents[index];
              if (index != _selectedTab && cached != null) {
                // Something it shows changed while hidden: keep the old build
                // (and stop watching) until the tab is opened again.
                _staleTabs.add(index);
                return cached;
              }
              return _tabContents[index] = _tabContent(context, ref, index);
            },
          ),
        ),
      );

  Widget _tabContent(BuildContext context, WidgetRef ref, int index) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    switch (index) {
      case 0:
        final sessionPhase = ref.watch(chatSessionPhaseProvider);
        final isRunning = sessionPhase == ChatSessionPhase.connecting ||
            sessionPhase == ChatSessionPhase.connected ||
            sessionPhase == ChatSessionPhase.partiallyConnected;
        final connectionStatus =
            ref.watch(connectionStatusProvider).valueOrNull ?? {};
        final youtubeMetadata =
            ref.watch(youtubeMetadataProvider).valueOrNull ??
                const YoutubeLiveMetadataSummary();
        final hasChannels = (s.youtubeEnabled &&
                (s.youtubeDualStreamEnabled
                    ? _dualYoutubeUrlsAreValid
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
        final twitchError =
            s.twitchEnabled && twitchState?.$1 == ServiceStatus.error
                ? twitchState?.$2
                : null;
        final kickError = s.kickEnabled && kickState?.$1 == ServiceStatus.error
            ? kickState?.$2
            : null;
        return _buildChannelsTab(
          ref,
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
        );
      case 1:
        final overlayUrl = ref.watch(overlayUrlProvider);
        final overlayState =
            ref.watch(overlayServerStateProvider).valueOrNull ??
                const OverlayServerState();
        final overlayCopyUrl =
            overlayUrl ?? 'http://localhost:${s.overlayPort}';
        return _buildAudioTab(
          ref,
          context,
          l,
          s,
          notifier,
          ref.read(appControllerProvider),
          ref.watch(ttsLoadStateProvider).valueOrNull,
          ref.watch(ttsBusyProvider).valueOrNull ?? false,
          ref.watch(liveCaptionsStateProvider).valueOrNull ??
              const LiveCaptionsState(),
          '$overlayCopyUrl/captions',
          overlayState.phase == OverlayServerPhase.ready,
        );
      case 2:
        return _buildStyleTab(ref, context, l, s, notifier);
      case 3:
        final overlayUrl = ref.watch(overlayUrlProvider);
        final overlayCopyUrl =
            overlayUrl ?? 'http://localhost:${s.overlayPort}';
        return _buildObsTab(
          ref,
          context,
          l,
          s,
          notifier,
          ref.read(appControllerProvider),
          ref.watch(obsStateProvider).valueOrNull ?? const ObsState(),
          ref.watch(overlayServerStateProvider).valueOrNull ??
              const OverlayServerState(),
          ref.watch(overlayClientCountProvider).valueOrNull ?? 0,
          overlayCopyUrl,
          '$overlayCopyUrl/alerts',
        );
      default:
        return _buildSystemTab(ref, context, l, s, notifier);
    }
  }

  Widget _header(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final s = ref.watch(settingsProvider);
    final chatRequested = ref.watch(chatConnectionProvider);
    final connectionStatus =
        ref.watch(connectionStatusProvider).valueOrNull ?? {};
    final youtubeBadgeValue = ref.watch(youtubeBadgeValueProvider).valueOrNull;
    final displayConnectionStatus = Map<String, (ServiceStatus, String?)>.from(
      connectionStatus,
    );
    if (s.youtubeDualStreamEnabled) {
      displayConnectionStatus['youtube'] = _combinedYoutubeStatus(
        connectionStatus['youtubeHorizontal'],
        connectionStatus['youtubeVertical'],
      );
    }
    return _sidebarHeader(
      youtubeValue: chatRequested && s.youtubeEnabled
          ? (s.youtubeDualStreamEnabled
              ? l.youtubeDualMode
              : (youtubeBadgeValue ?? _youtubeInputValue(s)))
          : null,
      twitchValue: chatRequested && s.twitchEnabled ? s.twitchChannel : '',
      kickValue: chatRequested && s.kickEnabled ? s.kickSlug : '',
      statusMap: displayConnectionStatus,
    );
  }

  Widget _tabBar(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final sessionPhase = ref.watch(chatSessionPhaseProvider);
    final voiceActive = ref.watch(
      settingsProvider.select((s) => s.ttsEnabled || s.liveCaptionsEnabled),
    );
    final obsConnected = ref.watch(
      obsStateProvider.select((state) => state.valueOrNull?.connected == true),
    );
    return SidebarTabBar(
      selectedIndex: _selectedTab,
      onTabSelected: _selectTab,
      tabs: [
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
          badgeColor: voiceActive ? const Color(0xFF53FC18) : null,
        ),
        SidebarTabItem(
          icon: Icons.palette_outlined,
          label: l.appearance,
        ),
        SidebarTabItem(
          icon: Icons.videocam_outlined,
          label: l.obsAndOverlay,
          badgeColor: obsConnected ? const Color(0xFF5B9CFF) : null,
        ),
        SidebarTabItem(
          icon: Icons.tune_rounded,
          label: l.systemTab,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF141414),
        child: Column(
          children: [
            // Same space above and below, with or without the connection
            // badges, so the block sits centered under the title bar.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Consumer(
                    builder: (context, ref, _) => _header(context, ref),
                  ),
                  Consumer(
                    builder: (context, ref, _) => _tabBar(context, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF242424)),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                sizing: StackFit.expand,
                children: [
                  for (var index = 0; index < _tabCount; index++)
                    // Tabs are built the first time they are opened.
                    // IndexedStack keeps hidden tabs out of focus traversal.
                    _visitedTabs.contains(index)
                        ? _tabPage(index)
                        : const SizedBox.shrink(),
                ],
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
          constraints: minLines == 1 && maxLines == 1 && errorText == null
              ? const BoxConstraints.tightFor(height: 36)
              : null,
          hintText: hint,
          errorText: errorText,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF222222),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 36,
            height: 36,
          ),
          suffixIcon: onClear != null && ctrl.text.isNotEmpty
              ? IconButton(
                  tooltip: AppLocalizations.of(context)!.clear,
                  onPressed: onClear,
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Colors.white54,
                  ),
                )
              : onClear != null
                  ? const SizedBox(width: 36, height: 36)
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

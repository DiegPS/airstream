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
  final _search = TextEditingController();
  final _sectionKeys = <String, GlobalKey>{};
  final _highlightedSection = ValueNotifier<String?>(null);
  Timer? _highlightTimer;

  /// Bumped to rebuild one tab's content.
  final _tabRevisions = List.generate(_tabCount, (_) => ValueNotifier<int>(0));

  /// One storage per tab for what is inside it. Without it every unkeyed
  /// expanding card (a bool) and text field (a scroll offset) inside a tab
  /// shared the tab's own `sidebar-tab-N` entry: opening "List settings"
  /// broke the join-command field, and hiding/showing the sidebar after
  /// expanding a card made the tab restore a bool as its scroll offset.
  final _tabStorage = List.generate(_tabCount, (_) => PageStorageBucket());

  /// Hidden tabs whose data changed since they were last shown.
  final _staleTabs = <int>{};

  late final _SettingsFormControllers _form;
  final _lastSyncedText = <TextEditingController, String>{};
  final _focusListeners = <FocusNode, VoidCallback>{};
  Timer? _textSettingsDebounce;

  @override
  void initState() {
    super.initState();
    _form = _SettingsFormControllers(ref.read(settingsProvider));

    for (final controller in _form.textControllers) {
      _lastSyncedText[controller] = controller.text;
    }
    for (final node in _form.focusNodes) {
      void listener() => _handleFocusChange(node);
      _focusListeners[node] = listener;
      node.addListener(listener);
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
    _highlightTimer?.cancel();
    _highlightedSection.dispose();
    _search.dispose();

    for (final entry in _focusListeners.entries) {
      entry.key.removeListener(entry.value);
    }

    _form.dispose();
    for (final revision in _tabRevisions) {
      revision.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange(FocusNode node) {
    if (node.hasFocus) return;
    if (!_form.focusNodes.any((other) => other.hasFocus)) {
      unawaited(_saveTextSettings());
      return;
    }
    final channel = _form.channelFields[node];
    if (channel != null) unawaited(_saveTextSettings(onlyChannel: channel));
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

  Future<void> _saveTextSettings({TextEditingController? onlyChannel}) async {
    if (onlyChannel == null) _textSettingsDebounce?.cancel();
    final notifier = ref.read(settingsProvider.notifier);
    final current = ref.read(settingsProvider);

    String? takeEdit(TextEditingController controller) {
      if (onlyChannel != null && controller != onlyChannel) return null;
      final value = controller.text;
      if (value == _lastSyncedText[controller]) return null;
      _lastSyncedText[controller] = value;
      return value;
    }

    String? platformChannel(TextEditingController controller) {
      final value = takeEdit(controller);
      return value == null
          ? null
          : SettingsInputNormalizer.platformChannel(value);
    }

    List<String>? filterList(TextEditingController controller) {
      final value = takeEdit(controller);
      return value == null ? null : SettingsInputNormalizer.filterList(value);
    }

    String? hexColor(TextEditingController controller, String fallback) {
      final value = takeEdit(controller);
      return value == null
          ? null
          : SettingsInputNormalizer.hexColor(value, fallback: fallback);
    }

    final youtube = takeEdit(_form.ytHandle);
    final port = takeEdit(_form.port);
    final next = current.copyWith(
      youtubeHandle: youtube?.trim(),
      youtubeLiveId: youtube == null ? null : '',
      youtubeHorizontalUrl: takeEdit(_form.ytHorizontalUrl)?.trim(),
      youtubeVerticalUrl: takeEdit(_form.ytVerticalUrl)?.trim(),
      twitchChannel: platformChannel(_form.twitch),
      kickSlug: platformChannel(_form.kick),
      blockedUsers: filterList(_form.blockedUsers),
      blockedWords: filterList(_form.blockedWords),
      highlightWords: filterList(_form.highlightWords),
      ttsIgnoredUsers: filterList(_form.ttsIgnoredUsers),
      overlayPort: port == null
          ? null
          : SettingsInputNormalizer.overlayPort(port,
              fallback: current.overlayPort),
      overlayChromaColor:
          hexColor(_form.overlayChromaColor, current.overlayChromaColor),
      overlayTextStrokeColor: hexColor(
          _form.overlayTextStrokeColor, current.overlayTextStrokeColor),
      overlaySuperChatBarColor: hexColor(
          _form.overlaySuperChatBarColor, current.overlaySuperChatBarColor),
      obsHost: takeEdit(_form.obsHost)?.trim(),
      obsPassword: takeEdit(_form.obsPassword),
      ttsCommandPrefix: takeEdit(_form.ttsPrefix),
      ttsSeparatorText: takeEdit(_form.ttsSeparator),
      ttsReferenceText: takeEdit(_form.ttsReferenceText),
      voiceCommandsWakeWord: takeEdit(_form.voiceWakeWord)?.trim(),
    );

    if (current.youtubeHandle == next.youtubeHandle &&
        current.youtubeLiveId == next.youtubeLiveId &&
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
      _syncControllers(current);
      return;
    }

    final persisted = notifier.update(next);
    _syncControllers(ref.read(settingsProvider));
    await persisted;
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

  void _syncController(
    TextEditingController controller,
    FocusNode focusNode,
    String value,
  ) {
    if (focusNode.hasFocus || controller.text != _lastSyncedText[controller]) {
      return;
    }
    _lastSyncedText[controller] = value;
    if (controller.text == value) return;
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
                onSubmitted: (_) => _saveTextSettings(onlyChannel: controller),
                onClear: () {
                  controller.clear();
                  _mutate(() {});
                  _saveTextSettings(onlyChannel: controller);
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

  static const _tabCount = 8;

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _selectedTab = index;
      _visitedTabs.add(index);
    });
    // A tab whose data did not change shows its kept build as is.
    if (_staleTabs.remove(index)) _tabRevisions[index].value++;
  }

  Widget Function(Widget) _searchHeader(String id) =>
      (header) => _searchSection(id, header);

  Widget _searchSection(String id, Widget child) => ValueListenableBuilder(
        key: _sectionKeys.putIfAbsent(id, GlobalKey.new),
        valueListenable: _highlightedSection,
        child: child,
        builder: (_, highlighted, child) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: highlighted == id
                  ? const Color(0xFF53FC18)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),
      );

  void _openSearchResult(SettingsSearchEntry entry) {
    FocusScope.of(context).unfocus();
    setState(_search.clear);
    _selectTab(entry.tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedTab != entry.tab) return;
      final id = _sectionKeys[entry.id]?.currentContext != null
          ? entry.id
          : entry.fallback;
      final anchor = _sectionKeys[id]?.currentContext;
      if (anchor == null) return;
      _highlightedSection.value = id;
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        _highlightedSection.value = null;
      });
      unawaited(Scrollable.ensureVisible(anchor,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic));
    });
  }

  Widget _searchResults(AppLocalizations l) {
    final results = searchSettings(l, _search.text);
    final tabs = settingsTabLabels(l);
    return Material(
      type: MaterialType.transparency,
      // Same 14 px gutter as the tabs; each result is a card-coloured row.
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (results.isEmpty) Text(l.settingsSearchEmpty),
          for (final entry in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                key: Key('settings-search-result-${entry.id}'),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: const Color(0xFF191919),
                hoverColor: const Color(0xFF222222),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF282828)),
                ),
                title: Text(entry.title),
                subtitle: Text(tabs[entry.tab]),
                trailing: const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Colors.white38),
                onTap: () => _openSearchResult(entry),
              ),
            ),
        ],
      ),
    );
  }

  /// A tab page built once and kept: its scroll position, expanded cards and
  /// fields survive tab switches. Only the selected tab rebuilds when the
  /// data it shows changes.
  Widget _tabPage(int index) => _tabPages[index] ??= SingleChildScrollView(
        key: PageStorageKey<String>('sidebar-tab-$index'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        child: PageStorage(
          bucket: _tabStorage[index],
          child: ValueListenableBuilder<int>(
            valueListenable: _tabRevisions[index],
            builder: (context, _, __) => Consumer(
              builder: (context, ref, _) {
                final cached = _tabContents[index];
                if (index != _selectedTab && cached != null) {
                  // Something it shows changed while hidden: keep the old
                  // build (and stop watching) until the tab is opened again.
                  _staleTabs.add(index);
                  return cached;
                }
                return _tabContents[index] = _tabContent(context, ref, index);
              },
            ),
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
      case 4:
        final ready = s.overlayEnabled &&
            ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
                OverlayServerPhase.ready;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ready)
                UiCard(
                    key: const Key('live-server-notice'),
                    title: l.liveServerOff,
                    description: l.liveServerNotice,
                    icon: Icons.info_outline_rounded,
                    children: [
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                              key: const Key('live-open-obs'),
                              style: secondarySettingsStyle(),
                              onPressed: () => _selectTab(3),
                              child: Text(l.liveOpenObs))),
                    ]),
              _searchSection('ruleButtons', const RuleButtonsCard()),
              _searchSection('poll', const PollCard()),
              _searchSection('giveaway', const GiveawayCard()),
              _searchSection('queue', const QueueCard()),
              _searchSection('goals', const GoalsCard()),
              _searchSection('subathon', const SubathonCard()),
              _searchSection('clock', const ClockCard()),
              _searchSection('recentAlerts', const RecentAlertsCard()),
            ]);
      case 5:
        return _searchSection('rules', const RulesCard());
      case 6:
        return _searchSection('templates', const TemplatesCard());
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
      displayConnectionStatus['youtube'] = combineYoutubeChatStatuses(
        connectionStatus['youtubeHorizontal'],
        connectionStatus['youtubeVertical'],
      );
    }
    return _sidebarHeader(
      youtubeValue: chatRequested &&
              s.youtubeEnabled &&
              (!s.youtubeDualStreamEnabled ||
                  configuredDualYoutubeVideoIds(s) != null)
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
            ChatSessionPhase.idle || ChatSessionPhase.ended => null,
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
        SidebarTabItem(icon: Icons.bolt_rounded, label: l.liveTab),
        SidebarTabItem(icon: Icons.rule_rounded, label: l.ruleLabel('krules')),
        SidebarTabItem(
            icon: Icons.dashboard_customize_outlined, label: l.templatesTitle),
        SidebarTabItem(
          icon: Icons.tune_rounded,
          label: l.systemTab,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final searching = _search.text.trim().isNotEmpty;
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
                  KeyedSubtree(
                    key: const Key('settings-search'),
                    child: _field(_search, l.settingsSearchHint,
                        onChanged: (_) => setState(() {}),
                        onClear: () => setState(_search.clear)),
                  ),
                  if (!searching) ...[
                    const SizedBox(height: 10),
                    Consumer(
                      builder: (context, ref, _) => _header(context, ref),
                    ),
                    Consumer(
                      builder: (context, ref, _) => _tabBar(context, ref),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF242424)),
            Expanded(
              child: SettingsPanelTheme(
                  child: Stack(
                fit: StackFit.expand,
                children: [
                  Offstage(
                    offstage: searching,
                    child: ExcludeFocus(
                      excluding: searching,
                      child: IndexedStack(
                        index: _selectedTab,
                        sizing: StackFit.expand,
                        children: [
                          for (var index = 0; index < _tabCount; index++)
                            _visitedTabs.contains(index)
                                ? TickerMode(
                                    enabled:
                                        !searching && index == _selectedTab,
                                    child: _tabPage(index),
                                  )
                                : const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                  if (searching) _searchResults(l),
                ],
              )),
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
        // Same fill, border, hint and 40 px height as settingsInput, used by
        // the live tools and dialogs.
        decoration: InputDecoration(
          constraints: minLines == 1 && maxLines == 1 && errorText == null
              ? const BoxConstraints.tightFor(height: 40)
              : null,
          hintText: hint,
          errorText: errorText,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
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

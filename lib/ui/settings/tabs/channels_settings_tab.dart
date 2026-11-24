part of 'package:airstream/ui/chat_screen.dart';

extension _ChannelsSettingsTabBuilder on _SettingsSidebarState {
  Future<void> _clearChannel(
    TextEditingController controller,
    String label,
  ) async {
    final l = AppLocalizations.of(context)!;
    final original = controller.text;
    final confirmed = await confirmLiveAction(
      context,
      title: l.settingsRemoveChannel(label),
      action: l.remove,
    );
    if (!mounted || !confirmed || controller.text != original) return;
    _mutate(controller.clear);
    await _saveTextSettings(onlyChannel: controller);
  }

  Widget _buildHighlightSounds(
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
  ) {
    final library = MediaLibraryEntries.sanitize(s.mediaLibrary)
      ..removeWhere((_, item) => item['kind'] != 'audio');
    final labels = {
      HighlightSounds.none: l.alertSoundNone,
      'chime': l.alertSoundChime,
      'coin': l.alertSoundCoin,
      'fanfare': l.alertSoundFanfare,
      for (final item in library.entries)
        item.key: l.mediaLibraryName(item.value['name'] as String),
    };
    final kinds = {
      HighlightKind.mention: l.highlightSoundMention,
      HighlightKind.word: l.highlightSoundWord,
      HighlightKind.firstMessage: l.highlightSoundFirstMessage,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.highlightSound),
        Text(l.highlightSoundDescription,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
        for (final entry in kinds.entries)
          KeyedSubtree(
            key: Key('highlight-sound-${entry.key.name}'),
            child: _dropdownRow(
              entry.value,
              labels.containsKey(s.highlightSounds[entry.key])
                  ? s.highlightSounds[entry.key]!
                  : HighlightSounds.none,
              labels.keys.toList(),
              (v) => notifier.update(s.copyWith(
                highlightSounds: {...s.highlightSounds, entry.key: v},
              )),
              optionLabel: (v) => labels[v]!,
            ),
          ),
        Text(l.highlightSoundPriority,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildChannelsTab(
    WidgetRef ref,
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    bool isRunning,
    ChatSessionPhase sessionPhase,
    bool hasChannels,
    Map<String, (ServiceStatus, String?)> statuses,
    YoutubeLiveMetadataSummary youtubeMetadata,
  ) {
    final dualYoutube = s.youtubeDualStreamEnabled;
    final chatRequested = sessionPhase != ChatSessionPhase.idle;

    Widget status(String id, String label, bool configured) {
      if (!configured) return const SizedBox.shrink();
      if (!chatRequested) {
        return settingsStatus(l.platformStatusIdle(label), Colors.white54);
      }
      final (phase, detail) = statuses[id] ?? (ServiceStatus.connecting, null);
      return switch (phase) {
        ServiceStatus.error => _inlineErrorMessage(
            l,
            label,
            onRetry: () =>
                ref.read(appControllerProvider).retryChatPlatform(id),
          ),
        ServiceStatus.connected => settingsStatus(
            l.platformStatusConnected(label), const Color(0xFF53FC18)),
        ServiceStatus.ended =>
          settingsStatus(l.youtubeBroadcastEnded, Colors.white54),
        ServiceStatus.connecting || ServiceStatus.idle => settingsStatus(
            detail == youtubeWaitingForLiveStatus
                ? l.youtubeWaitingForLiveDetail
                : l.platformStatusConnecting(label),
            const Color(0xFFFFB15C),
          ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          wrapHeader: _searchHeader('connections'),
          title: l.connections,
          icon: Icons.sensors_rounded,
          children: [
            if (!dualYoutube) ...[
              _label(l.youtubeInputLabel),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _form.ytHandle,
                      l.youtubeInputHint,
                      focusNode: _form.ytFocus,
                      onChanged: (_) => _channelEdited(),
                      onSubmitted: (_) =>
                          _saveTextSettings(onlyChannel: _form.ytHandle),
                      onClear: () => _clearChannel(_form.ytHandle, 'YouTube'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _form.ytHandle.text.trim().isNotEmpty &&
                        s.youtubeEnabled,
                    onChanged: _form.ytHandle.text.trim().isEmpty
                        ? null
                        : (value) =>
                            notifier.update(s.copyWith(youtubeEnabled: value)),
                    activeThumbColor: const Color(0xFF53FC18),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              status('youtube', 'YouTube', hasSingleYoutubeChat(s)),
              const SizedBox(height: 12),
            ],
            _label(l.twitchChannel),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _form.twitch,
                    l.channelNameHint,
                    focusNode: _form.twitchFocus,
                    onChanged: (_) => _channelEdited(),
                    onSubmitted: (_) =>
                        _saveTextSettings(onlyChannel: _form.twitch),
                    onClear: () => _clearChannel(_form.twitch, 'Twitch'),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _form.twitch.text.trim().isNotEmpty && s.twitchEnabled,
                  onChanged: _form.twitch.text.trim().isEmpty
                      ? null
                      : (value) =>
                          notifier.update(s.copyWith(twitchEnabled: value)),
                  activeThumbColor: const Color(0xFF53FC18),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            status('twitch', 'Twitch',
                s.twitchEnabled && s.twitchChannel.trim().isNotEmpty),
            const SizedBox(height: 12),
            _label(l.kickSlug),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _form.kick,
                    l.channelIdentifierHint,
                    focusNode: _form.kickFocus,
                    onChanged: (_) => _channelEdited(),
                    onSubmitted: (_) =>
                        _saveTextSettings(onlyChannel: _form.kick),
                    onClear: () => _clearChannel(_form.kick, 'Kick'),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _form.kick.text.trim().isNotEmpty && s.kickEnabled,
                  onChanged: _form.kick.text.trim().isEmpty
                      ? null
                      : (value) =>
                          notifier.update(s.copyWith(kickEnabled: value)),
                  activeThumbColor: const Color(0xFF53FC18),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            status(
                'kick', 'Kick', s.kickEnabled && s.kickSlug.trim().isNotEmpty),
            const SizedBox(height: 14),
            if (sessionPhase == ChatSessionPhase.failed)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: hasChannels ? _startChat : null,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text(l.retry),
                        style: primarySettingsStyle(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _stopChat,
                        icon: const Icon(Icons.stop_rounded, size: 20),
                        label: Text(l.stop),
                        style: secondarySettingsStyle(destructive: true),
                      ),
                    ),
                  ),
                ],
              )
            else
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
                    isRunning
                        ? l.stop
                        : sessionPhase == ChatSessionPhase.failed
                            ? l.retry
                            : l.startChat,
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
            if (!hasChannels && !isRunning)
              Text(l.settingsStartChatHelp, style: settingsHintStyle),
            _switchRow(
              l.connectChatOnLaunch,
              s.connectChatOnLaunch,
              (v) => notifier.update(s.copyWith(connectChatOnLaunch: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('session-summary-button'),
                onPressed: () => showSessionSummaryDialog(context, ref),
                icon: const Icon(Icons.insights_rounded, size: 16),
                label: Text(l.sessionSummary),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 14),
            _youtubeDualModeRow(
              l: l,
              enabled: dualYoutube,
              onChanged: (enabled) => notifier.update(
                s.copyWith(youtubeDualStreamEnabled: enabled),
              ),
            ),
            if (dualYoutube) ...[
              const SizedBox(height: 12),
              _youtubeStreamField(
                label: l.youtubeHorizontalUrl,
                orientation: YoutubeStreamOrientation.horizontal,
                controller: _form.ytHorizontalUrl,
                focusNode: _form.ytHorizontalFocus,
                errorText: _youtubeStreamUrlError(
                  l,
                  _form.ytHorizontalUrl.text,
                ),
              ),
              status(
                'youtubeHorizontal',
                l.youtubeHorizontalUrl,
                s.youtubeEnabled && configuredDualYoutubeVideoIds(s) != null,
              ),
              const SizedBox(height: 10),
              _youtubeStreamField(
                label: l.youtubeVerticalUrl,
                orientation: YoutubeStreamOrientation.vertical,
                controller: _form.ytVerticalUrl,
                focusNode: _form.ytVerticalFocus,
                errorText: _youtubeStreamUrlError(
                  l,
                  _form.ytVerticalUrl.text,
                  otherUrl: _form.ytHorizontalUrl.text,
                ),
              ),
              status(
                'youtubeVertical',
                l.youtubeVerticalUrl,
                s.youtubeEnabled && configuredDualYoutubeVideoIds(s) != null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'YouTube',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Switch(
                    value: s.youtubeEnabled,
                    onChanged: s.youtubeEnabled || _dualYoutubeUrlsAreValid
                        ? (value) => notifier.update(
                              s.copyWith(youtubeEnabled: value),
                            )
                        : null,
                    activeThumbColor: const Color(0xFF53FC18),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              if (!s.youtubeEnabled && !_dualYoutubeUrlsAreValid)
                Text(l.settingsDualYoutubeHelp, style: settingsHintStyle),
            ],
            if (youtubeMetadata.totalViewerCount != null) ...[
              const SizedBox(height: 12),
              YoutubeLiveStats(summary: youtubeMetadata),
            ],
          ],
        ),
        UiCard(
          wrapHeader: _searchHeader('filters'),
          title: l.filters,
          icon: Icons.filter_alt_outlined,
          description: l.filtersDescription,
          isCollapsible: true,
          initiallyExpanded:
              s.blockedUsers.isNotEmpty || s.blockedWords.isNotEmpty,
          children: [
            _label(l.blockedUsers),
            _field(
              _form.blockedUsers,
              l.blockedUsersHint,
              focusNode: _form.blockedUsersFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _form.blockedUsers.clear();
                _mutate(() {});
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
              _form.blockedWords,
              l.blockedWordsHint,
              focusNode: _form.blockedWordsFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _form.blockedWords.clear();
                _mutate(() {});
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
        UiCard(
          key: const Key('highlights-card'),
          wrapHeader: _searchHeader('highlights'),
          title: l.highlights,
          icon: Icons.auto_awesome_outlined,
          description: l.highlightsDescription,
          isCollapsible: true,
          initiallyExpanded: false,
          children: [
            _switchTileWithSubtitle(
              l.highlightMentions,
              l.highlightMentionsDescription,
              s.highlightMentions,
              (v) => notifier.update(s.copyWith(highlightMentions: v)),
            ),
            const SizedBox(height: 8),
            _label(l.highlightWords),
            _field(
              _form.highlightWords,
              l.highlightWordsHint,
              focusNode: _form.highlightWordsFocus,
              onChanged: (_) => _queueTextSettingsSave(),
              onSubmitted: (_) => _saveTextSettings(),
              onClear: () {
                _form.highlightWords.clear();
                _mutate(() {});
                _queueTextSettingsSave();
              },
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 4),
            Text(
              l.highlightWordsHelp,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 8),
            _switchTileWithSubtitle(
              l.highlightFirstMessages,
              l.highlightFirstMessagesDescription,
              s.highlightFirstMessages,
              (v) => notifier.update(s.copyWith(highlightFirstMessages: v)),
            ),
            const SizedBox(height: 8),
            _buildHighlightSounds(l, s, notifier),
          ],
        ),
        UiCard(
          wrapHeader: _searchHeader('eventBanners'),
          title: l.eventBanners,
          icon: Icons.campaign_outlined,
          description: l.eventBannersDescription,
          isCollapsible: true,
          initiallyExpanded: false,
          children: [
            StyledSliderRow(
              label: l.eventBannerDuration,
              value: s.providerEventBannerSeconds.toDouble(),
              min: 1,
              max: 20,
              divisions: 19,
              unit: 's',
              onChanged: (value) => notifier.update(
                s.copyWith(providerEventBannerSeconds: value.round()),
              ),
            ),
            const SizedBox(height: 6),
            for (final kind in ChatProviderEventKind.values)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                title: Text(
                  _providerEventLabel(l, kind),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                value: s.providerEventBannerKinds.contains(kind.name),
                onChanged: (enabled) {
                  final kinds = [...s.providerEventBannerKinds];
                  if (enabled) {
                    if (!kinds.contains(kind.name)) kinds.add(kind.name);
                  } else {
                    kinds.remove(kind.name);
                  }
                  notifier.update(s.copyWith(providerEventBannerKinds: kinds));
                },
                activeThumbColor: const Color(0xFF53FC18),
              ),
          ],
        ),
      ],
    );
  }

  String _providerEventLabel(
    AppLocalizations l,
    ChatProviderEventKind kind,
  ) =>
      switch (kind) {
        ChatProviderEventKind.raid => l.chatEventRaid,
        ChatProviderEventKind.unraid => l.chatEventUnraid,
        ChatProviderEventKind.pinnedMessage => l.chatEventPinnedMessage,
        ChatProviderEventKind.unpinnedMessage => l.chatEventUnpinnedMessage,
        ChatProviderEventKind.poll => l.chatEventPoll,
        ChatProviderEventKind.reward => l.chatEventReward,
        ChatProviderEventKind.support => l.chatEventSupport,
        ChatProviderEventKind.host => l.chatEventHost,
        ChatProviderEventKind.goal => l.chatEventGoal,
        ChatProviderEventKind.notice => l.chatEventNotice,
        ChatProviderEventKind.modiversary => l.chatEventModiversary,
        ChatProviderEventKind.viewerMilestone => l.chatEventViewerMilestone,
        ChatProviderEventKind.watchStreak => l.chatEventWatchStreak,
        ChatProviderEventKind.sharedChat => l.chatEventSharedChat,
        ChatProviderEventKind.roomState => l.chatEventRoomState,
        ChatProviderEventKind.streamOnline => l.chatEventStreamOnline,
        ChatProviderEventKind.streamOffline => l.chatEventStreamOffline,
        ChatProviderEventKind.unknown => l.chatEventUnknown,
      };
}

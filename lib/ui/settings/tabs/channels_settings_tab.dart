part of 'package:airstream/ui/chat_screen.dart';

extension _ChannelsSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildChannelsTab(
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    bool isRunning,
    ChatSessionPhase sessionPhase,
    bool hasChannels,
    String? youtubeError,
    String? youtubeHorizontalError,
    String? youtubeVerticalError,
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
            if (!s.youtubeDualStreamEnabled) ...[
              _label(l.youtubeInputLabel),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _form.ytHandle,
                      l.youtubeInputHint,
                      focusNode: _form.ytFocus,
                      onChanged: (_) => _mutate(() {}),
                      onSubmitted: (_) => _saveTextSettings(),
                      onClear: () {
                        _form.ytHandle.clear();
                        _mutate(() {});
                        _saveTextSettings();
                      },
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
              if (youtubeError != null && youtubeError.isNotEmpty) ...[
                const SizedBox(height: 8),
                _inlineErrorMessage(
                  l,
                  'YouTube',
                  onRetry: () => ref
                      .read(appControllerProvider)
                      .retryChatPlatform('youtube'),
                ),
              ],
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
                    onChanged: (_) => _mutate(() {}),
                    onSubmitted: (_) => _saveTextSettings(),
                    onClear: () {
                      _form.twitch.clear();
                      _mutate(() {});
                      _saveTextSettings();
                    },
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
            if (twitchError != null && twitchError.isNotEmpty) ...[
              const SizedBox(height: 8),
              _inlineErrorMessage(
                l,
                'Twitch',
                onRetry: () =>
                    ref.read(appControllerProvider).retryChatPlatform('twitch'),
              ),
            ],
            const SizedBox(height: 12),
            _label(l.kickSlug),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _form.kick,
                    l.channelIdentifierHint,
                    focusNode: _form.kickFocus,
                    onChanged: (_) => _mutate(() {}),
                    onSubmitted: (_) => _saveTextSettings(),
                    onClear: () {
                      _form.kick.clear();
                      _mutate(() {});
                      _saveTextSettings();
                    },
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
            if (kickError != null && kickError.isNotEmpty) ...[
              const SizedBox(height: 8),
              _inlineErrorMessage(
                l,
                'Kick',
                onRetry: () =>
                    ref.read(appControllerProvider).retryChatPlatform('kick'),
              ),
            ],
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF53FC18),
                          foregroundColor: Colors.black,
                        ),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF8A80),
                          side: const BorderSide(color: Color(0xFF7A3636)),
                        ),
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
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFF2A2A2A)),
            const SizedBox(height: 14),
            _youtubeDualModeRow(
              l: l,
              enabled: s.youtubeDualStreamEnabled,
              onChanged: (enabled) => notifier.update(
                s.copyWith(youtubeDualStreamEnabled: enabled),
              ),
            ),
            if (s.youtubeDualStreamEnabled) ...[
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
              if (youtubeHorizontalError != null &&
                  youtubeHorizontalError.isNotEmpty) ...[
                const SizedBox(height: 8),
                _inlineErrorMessage(
                  l,
                  l.youtubeHorizontalUrl,
                  onRetry: () => ref
                      .read(appControllerProvider)
                      .retryChatPlatform('youtubeHorizontal'),
                ),
              ],
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
              if (youtubeVerticalError != null &&
                  youtubeVerticalError.isNotEmpty) ...[
                const SizedBox(height: 8),
                _inlineErrorMessage(
                  l,
                  l.youtubeVerticalUrl,
                  onRetry: () => ref
                      .read(appControllerProvider)
                      .retryChatPlatform('youtubeVertical'),
                ),
              ],
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
                    value: _dualYoutubeUrlsAreValid && s.youtubeEnabled,
                    onChanged: _dualYoutubeUrlsAreValid
                        ? (value) => notifier.update(
                              s.copyWith(youtubeEnabled: value),
                            )
                        : null,
                    activeThumbColor: const Color(0xFF53FC18),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
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
      ],
    );
  }
}

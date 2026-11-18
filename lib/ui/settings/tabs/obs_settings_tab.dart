part of 'package:airstream/ui/chat_screen.dart';

extension _ObsSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildObsTab(
    WidgetRef ref,
    BuildContext context,
    AppLocalizations l,
    SettingsModel s,
    SettingsNotifier notifier,
    AppController appController,
    ObsState obsState,
    OverlayServerState overlayState,
    int overlayClientCount,
    String overlayCopyUrl,
    String alertsCopyUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          title: l.obsIntegration,
          icon: Icons.camera_indoor_rounded,
          description: l.obsDescription,
          trailing: Switch(
            value: s.obsEnabled,
            onChanged: (v) =>
                unawaited(notifier.update(s.copyWith(obsEnabled: v))),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.obsEnabled) ...[
              _label(l.webSocketHost),
              _field(
                _form.obsHost,
                'localhost:4455',
                focusNode: _form.obsHostFocus,
                onChanged: (_) {
                  _mutate(() {});
                  _queueTextSettingsSave();
                },
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 8),
              _label(l.password),
              _field(
                _form.obsPassword,
                l.optionalPassword,
                focusNode: _form.obsPasswordFocus,
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
                        ? l.connectingToObs
                        : obsState.connected
                            ? l.disconnectObs
                            : (obsState.error != null &&
                                    obsState.error!.isNotEmpty)
                                ? l.reconnectObs
                                : l.connectObs,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: obsState.connected
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF5B9CFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              _switchRow(
                l.obsConnectOnLaunch,
                s.obsConnectOnLaunch,
                (v) => notifier.update(s.copyWith(obsConnectOnLaunch: v)),
              ),
              const SizedBox(height: 10),
              _ObsStatusCard(
                state: obsState,
                showHost: true,
                displaySettings: s,
              ),
              const SizedBox(height: 12),
              Text(
                l.hudElements,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.globalHud),
              _switchRow(
                l.currentScene,
                s.obsShowCurrentScene,
                (v) => notifier.update(s.copyWith(obsShowCurrentScene: v)),
              ),
              _switchRow(
                l.fps,
                s.obsShowFps,
                (v) => notifier.update(s.copyWith(obsShowFps: v)),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.streamHud),
              _switchRow(
                l.streamState,
                s.obsShowStreamState,
                (v) => notifier.update(s.copyWith(obsShowStreamState: v)),
              ),
              _switchRow(
                l.bitrate,
                s.obsShowBitrate,
                (v) => notifier.update(s.copyWith(obsShowBitrate: v)),
              ),
              _switchRow(
                l.droppedFrames,
                s.obsShowDroppedFrames,
                (v) => notifier.update(s.copyWith(obsShowDroppedFrames: v)),
              ),
              const SizedBox(height: 6),
              _obsHudGroupLabel(l.recordingHud),
              _switchRow(
                l.recordingState,
                s.obsShowRecordingState,
                (v) => notifier.update(s.copyWith(obsShowRecordingState: v)),
              ),
              _switchRow(
                l.recordingDuration,
                s.obsShowRecordingDuration,
                (v) => notifier.update(s.copyWith(obsShowRecordingDuration: v)),
              ),
              _switchRow(
                l.recordingSize,
                s.obsShowRecordingSize,
                (v) => notifier.update(s.copyWith(obsShowRecordingSize: v)),
              ),
            ] else ...[
              Text(
                l.obsDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        UiCard(
          title: l.overlayServer,
          icon: Icons.desktop_windows_rounded,
          description: l.overlayServerDescription,
          trailing: Switch(
            value: s.overlayEnabled,
            onChanged: (v) => notifier.update(s.copyWith(overlayEnabled: v)),
            activeThumbColor: const Color(0xFF53FC18),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          children: [
            if (s.overlayEnabled) ...[
              _label(l.port),
              _field(
                _form.port,
                '8080',
                focusNode: _form.portFocus,
                errorText: _overlayPortError(l),
                // Each saved port restarts the server, so partial numbers
                // typed on the way are not applied.
                onChanged: (_) => _mutate(() {}),
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 10),
              _previewSwitch(ref, l),
              if (overlayState.phase == OverlayServerPhase.starting)
                _statusMessage(
                  l.overlayStarting,
                  color: Colors.amber,
                  icon: Icons.hourglass_top_rounded,
                ),
              if (overlayState.phase == OverlayServerPhase.error)
                _statusMessage(
                  l.overlayStartFailed(
                    overlayState.port ?? s.overlayPort,
                  ),
                  color: const Color(0xFFFF6B6B),
                  icon: Icons.error_outline_rounded,
                ),
              if (overlayState.phase == OverlayServerPhase.ready &&
                  overlayState.requestedPort != null) ...[
                _statusMessage(
                  l.overlayPortFallback(
                    overlayState.requestedPort!,
                    overlayState.port ?? s.overlayPort,
                  ),
                  color: Colors.amber,
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 8),
              ],
              if (overlayState.phase == OverlayServerPhase.ready) ...[
                _overlayUrlCard(
                  l: l,
                  title: l.chatObsUrl,
                  overlayUrl: overlayCopyUrl,
                  description: l.chatObsUrlDescription,
                  onCopy: () async {
                    await Clipboard.setData(
                        ClipboardData(text: overlayCopyUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.chatOverlayUrlCopied),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _overlayUrlCard(
                  l: l,
                  title: l.alertsObsUrl,
                  overlayUrl: alertsCopyUrl,
                  description: l.alertsObsUrlDescription,
                  onCopy: () async {
                    await Clipboard.setData(ClipboardData(text: alertsCopyUrl));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.alertsOverlayUrlCopied),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _overlayUrlCard(
                  l: l,
                  title: l.featuredTitle,
                  overlayUrl: '$overlayCopyUrl/featured',
                  description: l.featuredDescription,
                  onCopy: () async {
                    await Clipboard.setData(
                        ClipboardData(text: '$overlayCopyUrl/featured'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.featuredUrlCopied)));
                  },
                ),
                _overlayUrlCard(
                  l: l,
                  title: l.giveawayTitle,
                  overlayUrl: '$overlayCopyUrl/giveaway',
                  description: l.giveawayDescription,
                  onCopy: () async {
                    await Clipboard.setData(
                        ClipboardData(text: '$overlayCopyUrl/giveaway'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.giveawayUrlCopied)));
                  },
                ),
                _overlayUrlCard(
                  l: l,
                  title: l.goalsTitle,
                  overlayUrl: '$overlayCopyUrl/goals',
                  description: l.goalsDescription,
                  onCopy: () async {
                    await Clipboard.setData(
                        ClipboardData(text: '$overlayCopyUrl/goals'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.goalsUrlCopied)));
                  },
                ),
                _overlayUrlCard(
                  l: l,
                  title: l.subathonTitle,
                  overlayUrl: '$overlayCopyUrl/timer',
                  description: l.subathonDescription,
                  onCopy: () async {
                    await Clipboard.setData(
                        ClipboardData(text: '$overlayCopyUrl/timer'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.subathonUrlCopied)));
                  },
                ),
                _overlayUrlCard(
                  l: l,
                  title: l.clockTitle,
                  overlayUrl: '$overlayCopyUrl/clock',
                  description: l.clockDescription,
                  onCopy: () => Clipboard.setData(
                      ClipboardData(text: '$overlayCopyUrl/clock')),
                ),
                const SizedBox(height: 6),
                Text(
                  overlayClientCount == 1
                      ? l.oneOverlayClientConnected
                      : l.overlayClientsConnected(overlayClientCount),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
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
                              ? l.overlayReloadSent
                              : l.noOverlayClientConnected,
                        ),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFC877),
                    side: const BorderSide(color: Color(0xFF6A4C1D)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l.reloadOverlay),
                ),
              ),
              const SizedBox(height: 12),
              _section(l.alerts),
              Text(
                l.alertsDescription,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.alertFontSize,
                value: s.alertFontSize,
                min: 18,
                max: 56,
                unit: 'px',
                onChanged: (v) => notifier.update(s.copyWith(alertFontSize: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.alertDuration,
                value: s.alertDisplaySeconds.toDouble(),
                min: 3,
                max: 20,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(alertDisplaySeconds: v.round()),
                ),
              ),
              _switchRow(
                l.alertAvatars,
                s.alertShowAvatars,
                (v) => notifier.update(s.copyWith(alertShowAvatars: v)),
              ),
              _dropdownRow(
                  l.alertPosition,
                  s.alertPosition,
                  const ['top', 'center', 'bottom'],
                  (v) => notifier.update(s.copyWith(alertPosition: v)),
                  optionLabel: (v) => {
                        'top': l.alertPositionTop,
                        'center': l.alertPositionCenter,
                        'bottom': l.alertPositionBottom
                      }[v]!),
              _dropdownRow(
                  l.alertLayout,
                  s.alertLayout,
                  const ['row', 'stacked'],
                  (v) => notifier.update(s.copyWith(alertLayout: v)),
                  optionLabel: (v) =>
                      v == 'stacked' ? l.alertLayoutStacked : l.alertLayoutRow),
              _dropdownRow(
                  l.alertEntrance,
                  s.alertAnimation,
                  const ['pop', 'slide-up', 'slide-down', 'fade', 'zoom'],
                  (v) => notifier.update(s.copyWith(alertAnimation: v)),
                  optionLabel: (v) => {
                        'pop': l.alertAnimationPop,
                        'slide-up': l.alertAnimationSlideUp,
                        'slide-down': l.alertAnimationSlideDown,
                        'fade': l.alertAnimationFade,
                        'zoom': l.alertAnimationZoom
                      }[v]!),
              StyledSliderRow(
                wrapLabel: true,
                key: const Key('alert-sound-volume'),
                label: l.alertSoundVolume,
                value: s.alertSoundVolume.toDouble(),
                min: 0,
                max: 100,
                unit: '%',
                formatValue: (v) => '${v.round()}%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(alertSoundVolume: v.round())),
              ),
              Text(l.alertSoundObsHint,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 8),
              _section(l.alertPlatformFilter),
              Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    for (final (id, label) in const [
                      ('youtube', 'YouTube'),
                      ('twitch', 'Twitch'),
                      ('kick', 'Kick'),
                    ])
                      CheckboxListTile(
                        key: Key('alert-platform-$id'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(label),
                        value: s.alertPlatforms.contains(id),
                        onChanged: (enabled) => notifier.update(s.copyWith(
                          alertPlatforms: {
                            ...s.alertPlatforms
                                .where((platform) => platform != id),
                            if (enabled == true) id,
                          },
                        )),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _section(l.alertTypes),
              for (final (id, label) in [
                ('superchat', l.alertTypeSuperChat),
                ('membership', l.alertTypeMembership),
                ('bits', l.alertTypeBits),
                ('subscription', l.alertTypeSubscription),
                ('gift', l.alertTypeGift),
                ('raid', l.alertTypeRaid),
                ('kicks', l.alertTypeKicks),
              ])
                _AlertTypeRow(
                  key: ValueKey(id),
                  id: id,
                  label: label,
                  settings: s,
                  onChanged: (next) => notifier.update(next),
                  onTest: () {
                    final sent = appController.testOverlayAlert(id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          sent ? l.testAlertSent : l.openAlertsOverlayFirst),
                      duration: const Duration(milliseconds: 1400),
                    ));
                  },
                ),
              const SizedBox(height: 8),
              _alertTestButtons(
                l: l,
                onTest: (kind) {
                  final sent = appController.testOverlayAlert(kind);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        sent ? l.testAlertSent : l.openAlertsOverlayFirst,
                      ),
                      duration: const Duration(milliseconds: 1400),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _section(l.featuredTitle),
              _dropdownRow(
                l.alertPosition,
                s.featuredPosition,
                const ['top', 'center', 'bottom'],
                (v) => notifier.update(s.copyWith(featuredPosition: v)),
                optionLabel: (v) => {
                  'top': l.alertPositionTop,
                  'center': l.alertPositionCenter,
                  'bottom': l.alertPositionBottom,
                }[v]!,
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.featuredFontScale,
                value: s.featuredFontScale.toDouble(),
                min: 80,
                max: 200,
                unit: '%',
                formatValue: (v) => '${v.round()}%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(featuredFontScale: v.round())),
              ),
              _switchRow(
                  l.featuredKeepVisible,
                  s.featuredSeconds == 0,
                  (v) => notifier.update(s.copyWith(
                        featuredSeconds:
                            v ? 0 : s.alertDisplaySeconds.clamp(5, 120),
                      ))),
              if (s.featuredSeconds != 0)
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.alertDuration,
                  value: s.featuredSeconds.toDouble(),
                  min: 5,
                  max: 120,
                  unit: 's',
                  divisions: 115,
                  onChanged: (v) =>
                      notifier.update(s.copyWith(featuredSeconds: v.round())),
                ),
              const SizedBox(height: 12),
              const MediaLibraryCard(),
              _section(l.overlayMode),
              _switchRow(
                l.chromaKey,
                s.overlayChromaMode,
                (v) => notifier.update(s.copyWith(overlayChromaMode: v)),
              ),
              _switchRow(
                l.showGrid,
                s.overlayShowGrid,
                (v) => notifier.update(s.copyWith(overlayShowGrid: v)),
              ),
              _switchRow(
                l.hideScrollbar,
                s.overlayHideScrollbar,
                (v) => notifier.update(s.copyWith(overlayHideScrollbar: v)),
              ),
              if (s.overlayChromaMode) ...[
                const SizedBox(height: 6),
                _label(l.chromaColor),
                _field(
                  _form.overlayChromaColor,
                  '#00FF00',
                  focusNode: _form.overlayChromaColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.platformDisplay),
              _switchRow(
                l.platformIcon,
                s.overlayShowPlatformIcons,
                (v) => notifier.update(
                  s.copyWith(overlayShowPlatformIcons: v),
                ),
              ),
              _switchRow(
                l.twitchAccent,
                s.overlayTwitchBubbleAccent,
                (v) => notifier.update(
                  s.copyWith(overlayTwitchBubbleAccent: v),
                ),
              ),
              _switchRow(
                l.kickAccent,
                s.overlayKickBubbleAccent,
                (v) => notifier.update(
                  s.copyWith(overlayKickBubbleAccent: v),
                ),
              ),
              const SizedBox(height: 12),
              const OverlayStylePresetsCard(),
              const SizedBox(height: 12),
              _section(l.styleSettings),
              StyledSliderRow(
                wrapLabel: true,
                label: l.fontSize,
                value: s.overlayFontSize,
                min: 12,
                max: 32,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontSize: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.lineHeight,
                value: s.overlayLineHeight,
                min: 1,
                max: 2,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayLineHeight: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.fontWeight,
                value: s.overlayFontWeight,
                min: 100,
                max: 900,
                divisions: 8,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontWeight: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.overlayBg,
                value: s.overlayBgOpacity,
                min: 0,
                max: 1,
                unit: '%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayBgOpacity: v)),
              ),
              _switchRow(
                l.avatars,
                s.overlayShowAvatars,
                (v) => notifier.update(s.copyWith(overlayShowAvatars: v)),
              ),
              _switchRow(
                l.badges,
                s.overlayShowBadges,
                (v) => notifier.update(s.copyWith(overlayShowBadges: v)),
              ),
              if (s.youtubeDualStreamEnabled)
                _switchRow(
                  l.youtubeStreamBadges,
                  s.overlayShowYoutubeStreamBadges,
                  (v) => notifier.update(
                    s.copyWith(overlayShowYoutubeStreamBadges: v),
                  ),
                ),
              _switchRow(
                l.timestamp,
                s.overlayShowTimestamp,
                (v) => notifier.update(s.copyWith(overlayShowTimestamp: v)),
              ),
              _switchRow(
                l.textShadow,
                s.overlayTextShadow,
                (v) => notifier.update(s.copyWith(overlayTextShadow: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.textOutline,
                value: s.overlayTextStroke,
                min: 0,
                max: 4,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayTextStroke: v)),
              ),
              if (s.overlayTextStroke > 0) ...[
                const SizedBox(height: 6),
                _label(l.outlineColor),
                _field(
                  _form.overlayTextStrokeColor,
                  '#000000',
                  focusNode: _form.overlayTextStrokeColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.messageDesign),
              _switchRow(
                l.bubbleBackground,
                s.overlayShowBubble,
                (v) => notifier.update(s.copyWith(overlayShowBubble: v)),
              ),
              _dropdownRow(
                l.textAlignment,
                s.overlayTextAlign,
                const ['left', 'center', 'right'],
                (v) => notifier.update(s.copyWith(overlayTextAlign: v)),
                optionLabel: (v) => _alignmentLabel(l, v),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.bubbleOpacity,
                value: s.overlayMessageOpacity,
                min: 0,
                max: 1,
                unit: '%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageOpacity: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.cornerRadius,
                value: s.overlayBorderRadius,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayBorderRadius: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.verticalGap,
                value: s.overlayMessageGap,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageGap: v)),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.maxMessages,
                value: s.overlayMaxMessages.toDouble(),
                min: 10,
                max: 500,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMaxMessages: v.round())),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.messageLifetime,
                value: s.overlayMessageTtlSeconds.toDouble(),
                min: 5,
                max: 120,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(overlayMessageTtlSeconds: v.round()),
                ),
              ),
              _switchRow(
                l.superChatColorBar,
                s.overlaySuperChatBarEnabled,
                (v) => notifier.update(
                  s.copyWith(overlaySuperChatBarEnabled: v),
                ),
              ),
              if (s.overlaySuperChatBarEnabled) ...[
                const SizedBox(height: 6),
                _label(l.superChatBarColor),
                _field(
                  _form.overlaySuperChatBarColor,
                  '#1DE9B6',
                  focusNode: _form.overlaySuperChatBarColorFocus,
                  onChanged: (_) => _queueTextSettingsSave(),
                  onSubmitted: (_) => _saveTextSettings(),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.superChatWidth,
                  value: s.overlaySuperChatBarWidth,
                  min: 1,
                  max: 8,
                  unit: 'px',
                  onChanged: (v) => notifier.update(
                    s.copyWith(overlaySuperChatBarWidth: v),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _section(l.animation),
              _dropdownRow(
                l.entrance,
                s.overlayAnimation,
                const ['slide-up', 'slide-left', 'fade-in', 'zoom-in'],
                (v) => notifier.update(s.copyWith(overlayAnimation: v)),
                optionLabel: (v) => _animationLabel(l, v),
              ),
              StyledSliderRow(
                wrapLabel: true,
                label: l.duration,
                value: s.overlayAnimationDuration,
                min: 0.1,
                max: 2,
                unit: 's',
                onChanged: (v) => notifier.update(
                  s.copyWith(overlayAnimationDuration: v),
                ),
              ),
              const SizedBox(height: 12),
              _section(l.transform3d),
              _switchRow(
                l.enable3dEffect,
                s.overlayThreeDEnabled,
                (v) => notifier.update(s.copyWith(overlayThreeDEnabled: v)),
              ),
              if (s.overlayThreeDEnabled) ...[
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.perspective,
                  value: s.overlayPerspective,
                  min: 500,
                  max: 2500,
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayPerspective: v)),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.rotateX,
                  value: s.overlayRotateX,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateX: v)),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.rotateY,
                  value: s.overlayRotateY,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateY: v)),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.rotateZ,
                  value: s.overlayRotateZ,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateZ: v)),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.skewX,
                  value: s.overlaySkewX,
                  min: -45,
                  max: 45,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlaySkewX: v)),
                ),
                StyledSliderRow(
                  wrapLabel: true,
                  label: l.scale,
                  value: s.overlayScale,
                  min: 0.5,
                  max: 2,
                  unit: 'x',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayScale: v)),
                ),
              ],
            ] else ...[
              Text(
                l.overlayDisabledHelp,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _AlertTypeRow extends StatefulWidget {
  const _AlertTypeRow(
      {super.key,
      required this.id,
      required this.label,
      required this.settings,
      required this.onChanged,
      required this.onTest});
  final String id;
  final String label;
  final SettingsModel settings;
  final ValueChanged<SettingsModel> onChanged;
  final VoidCallback onTest;

  @override
  State<_AlertTypeRow> createState() => _AlertTypeRowState();
}

class _AlertTypeRowState extends State<_AlertTypeRow> {
  bool _expanded = false;
  bool _invalidSound = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = widget.settings;
    final id = widget.id;
    final option = AlertTypeOptions.of(s, id);
    final library = MediaLibraryEntries.sanitize(s.mediaLibrary);
    final visuals = library.entries.where((e) => e.value['kind'] != 'audio');
    final audio = library.entries.where((e) => e.value['kind'] == 'audio');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: KeyedSubtree(
          key: Key('alert-type-$id'),
          child: _switchRow(
              widget.label,
              !s.alertDisabledTypes.contains(id),
              (enabled) => widget.onChanged(s.copyWith(
                      alertDisabledTypes: {
                    ...s.alertDisabledTypes.where((type) => type != id),
                    if (!enabled) id,
                  }.toList()))),
        )),
        if (option.seconds != 0 ||
            option.animation.isNotEmpty ||
            option.sound.isNotEmpty ||
            option.media.isNotEmpty ||
            AlertTypeOptions.tiers(
              AlertTypeOptions.sanitize(s.alertTypeOptions)[id],
            ).isNotEmpty)
          Tooltip(
              message: l.alertTypeCustomized,
              child: const Icon(Icons.circle, size: 6, color: Colors.white70)),
        IconButton(
            key: Key('alert-type-options-$id'),
            tooltip: l.alertTypeOptions,
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _expanded = !_expanded)),
      ]),
      if (_expanded) ...[
        KeyedSubtree(
            key: Key('alert-type-duration-switch-$id'),
            child: _switchRow(
                l.alertTypeOwnDuration,
                option.seconds != 0,
                (enabled) => widget.onChanged(AlertTypeOptions.withOption(s, id,
                    seconds:
                        enabled ? s.alertDisplaySeconds.clamp(3, 20) : 0)))),
        if (option.seconds != 0)
          StyledSliderRow(
              wrapLabel: true,
              key: Key('alert-type-duration-$id'),
              label: l.alertDuration,
              value: option.seconds.toDouble(),
              min: 3,
              max: 20,
              divisions: 17,
              unit: 's',
              onChanged: (v) => widget.onChanged(
                  AlertTypeOptions.withOption(s, id, seconds: v.round()))),
        KeyedSubtree(
            key: Key('alert-type-animation-$id'),
            child: _dropdownRow(
                l.alertEntrance,
                option.animation,
                const ['', 'pop', 'slide-up', 'slide-down', 'fade', 'zoom'],
                (v) => widget.onChanged(
                    AlertTypeOptions.withOption(s, id, animation: v)),
                optionLabel: (v) => {
                      '': l.alertTypeUseGeneral,
                      'pop': l.alertAnimationPop,
                      'slide-up': l.alertAnimationSlideUp,
                      'slide-down': l.alertAnimationSlideDown,
                      'fade': l.alertAnimationFade,
                      'zoom': l.alertAnimationZoom
                    }[v]!)),
        KeyedSubtree(
            key: Key('alert-type-media-$id'),
            child: _dropdownRow(
                l.alertMedia,
                option.media,
                ['', ...visuals.map((e) => e.key)],
                (v) => widget.onChanged(AlertTypeOptions.withOption(s, id,
                    media: v, mediaAudio: false)),
                optionLabel: (v) =>
                    v.isEmpty ? l.mediaNone : library[v]!['name'] as String)),
        if (library[option.media]?['kind'] == 'video')
          KeyedSubtree(
              key: Key('alert-type-media-audio-$id'),
              child: _switchRow(
                  l.alertMediaAudio,
                  option.mediaAudio,
                  (v) => widget.onChanged(
                      AlertTypeOptions.withOption(s, id, mediaAudio: v)))),
        KeyedSubtree(
          key: Key('alert-type-sound-$id'),
          child: _dropdownRow(
            l.alertSound,
            option.sound == 'library' ? option.soundMediaId : option.sound,
            [
              '',
              'chime',
              'coin',
              'fanfare',
              'custom',
              ...audio.map((e) => e.key)
            ],
            (v) {
              setState(() => _invalidSound = false);
              widget.onChanged(AlertTypeOptions.withOption(s, id,
                  sound: library[v]?['kind'] == 'audio' ? 'library' : v,
                  soundMediaId: library[v]?['kind'] == 'audio' ? v : ''));
            },
            optionLabel: (v) => library.containsKey(v)
                ? l.mediaLibraryName(library[v]!['name'] as String)
                : {
                    '': l.alertSoundNone,
                    'chime': l.alertSoundChime,
                    'coin': l.alertSoundCoin,
                    'fanfare': l.alertSoundFanfare,
                    'custom': l.alertSoundCustom,
                  }[v]!,
          ),
        ),
        if (option.sound == 'custom') ...[
          Row(children: [
            Expanded(
                child: Text(
                    option.soundPath.isEmpty
                        ? l.alertSoundNoFile
                        : p.basename(option.soundPath),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11))),
            TextButton(
              key: Key('alert-type-sound-file-$id'),
              onPressed: () async {
                final picked = await openFile(acceptedTypeGroups: [
                  const XTypeGroup(
                      label: 'Audio', extensions: ['wav', 'mp3', 'ogg']),
                ]);
                if (!mounted || picked == null) return;
                final valid = picked.path.length <= 1024 &&
                    AlertSounds.customFile(picked.path) != null;
                setState(() => _invalidSound = !valid);
                if (valid) {
                  widget.onChanged(AlertTypeOptions.withOption(
                      widget.settings, id,
                      soundPath: picked.path));
                }
              },
              child: Text(l.alertSoundChoose),
            ),
          ]),
          if (_invalidSound)
            Text(l.alertSoundInvalid,
                style: const TextStyle(color: Color(0xFFFFB15C), fontSize: 11)),
        ],
        if (amountAlertTypeIds.contains(id))
          _AlertTierSettings(
              type: id, settings: s, onChanged: widget.onChanged),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: Key('alert-type-test-$id'),
              onPressed: widget.onTest,
              child: Text(l.alertTypeTest),
            )),
      ],
    ]);
  }
}

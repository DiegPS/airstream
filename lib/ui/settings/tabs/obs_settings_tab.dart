part of 'package:airstream/ui/chat_screen.dart';

extension _ObsSettingsTabBuilder on _SettingsSidebarState {
  Widget _buildObsTab(
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
                onChanged: (_) {
                  _mutate(() {});
                  _queueTextSettingsSave();
                },
                onSubmitted: (_) => _saveTextSettings(),
              ),
              const SizedBox(height: 10),
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
                label: l.alertFontSize,
                value: s.alertFontSize,
                min: 18,
                max: 56,
                unit: 'px',
                onChanged: (v) => notifier.update(s.copyWith(alertFontSize: v)),
              ),
              StyledSliderRow(
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
              _section(l.styleSettings),
              StyledSliderRow(
                label: l.fontSize,
                value: s.overlayFontSize,
                min: 12,
                max: 32,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontSize: v)),
              ),
              StyledSliderRow(
                label: l.lineHeight,
                value: s.overlayLineHeight,
                min: 1,
                max: 2,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayLineHeight: v)),
              ),
              StyledSliderRow(
                label: l.fontWeight,
                value: s.overlayFontWeight,
                min: 100,
                max: 900,
                divisions: 8,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayFontWeight: v)),
              ),
              StyledSliderRow(
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
                label: l.bubbleOpacity,
                value: s.overlayMessageOpacity,
                min: 0,
                max: 1,
                unit: '%',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageOpacity: v)),
              ),
              StyledSliderRow(
                label: l.cornerRadius,
                value: s.overlayBorderRadius,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayBorderRadius: v)),
              ),
              StyledSliderRow(
                label: l.verticalGap,
                value: s.overlayMessageGap,
                min: 0,
                max: 30,
                unit: 'px',
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMessageGap: v)),
              ),
              StyledSliderRow(
                label: l.maxMessages,
                value: s.overlayMaxMessages.toDouble(),
                min: 10,
                max: 500,
                onChanged: (v) =>
                    notifier.update(s.copyWith(overlayMaxMessages: v.round())),
              ),
              StyledSliderRow(
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
                  label: l.perspective,
                  value: s.overlayPerspective,
                  min: 500,
                  max: 2500,
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayPerspective: v)),
                ),
                StyledSliderRow(
                  label: l.rotateX,
                  value: s.overlayRotateX,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateX: v)),
                ),
                StyledSliderRow(
                  label: l.rotateY,
                  value: s.overlayRotateY,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateY: v)),
                ),
                StyledSliderRow(
                  label: l.rotateZ,
                  value: s.overlayRotateZ,
                  min: -180,
                  max: 180,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlayRotateZ: v)),
                ),
                StyledSliderRow(
                  label: l.skewX,
                  value: s.overlaySkewX,
                  min: -45,
                  max: 45,
                  unit: '°',
                  onChanged: (v) =>
                      notifier.update(s.copyWith(overlaySkewX: v)),
                ),
                StyledSliderRow(
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

part of 'package:airstream/ui/chat_screen.dart';

class _ObsStatusCard extends StatelessWidget {
  const _ObsStatusCard({
    required this.state,
    this.compact = false,
    this.showHost = false,
    this.styleSettings,
    this.displaySettings,
  });

  final ObsState state;
  final bool compact;
  final bool showHost;
  final SettingsModel? styleSettings;
  final SettingsModel? displaySettings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (title, color) = _obsStatusVisuals(state, l);

    if (compact) {
      return _ObsCompactPill(
        state: state,
        title: title,
        color: color,
        styleSettings: styleSettings ?? const SettingsModel(),
        displaySettings: displaySettings ?? const SettingsModel(),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (showHost && state.host.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.host,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (_showObsScene(displaySettings, state)) ...[
            const SizedBox(height: 6),
            Text(
              l.obsScenePrefix(state.currentScene),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_showObsStreamState(displaySettings)) ...[
            const SizedBox(height: 6),
            Text(
              state.outputActive ? l.obsOutputLive : l.obsOutputOffline,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          if (_showObsRecordingState(displaySettings) &&
              state.recordingActive) ...[
            const SizedBox(height: 6),
            Text(
              state.recordingPaused
                  ? l.obsRecordingPaused
                  : l.obsRecordingActive,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          if (state.connected) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_showObsBitrate(displaySettings))
                  _ObsPillBadge(
                    label: '${state.bitrateKbps.toStringAsFixed(0)} kbps',
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
                if (_showObsFps(displaySettings))
                  _ObsPillBadge(
                    label: '${state.fps.toStringAsFixed(0)} FPS',
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
                if (_showObsDroppedFrames(displaySettings))
                  _ObsPillBadge(
                    label: l.droppedFramesBadge(
                      state.dropPercentage.toStringAsFixed(1),
                      state.droppedFrames,
                    ),
                    foreground: _obsDropBadgeForeground(state.dropTrend),
                    background: _obsDropBadgeBackground(state.dropTrend),
                    fontSize: 10,
                  ),
                if (_showObsRecordingDuration(displaySettings) &&
                    state.recordingActive)
                  _ObsPillBadge(
                    label: _formatObsDuration(state.recordingDurationMs),
                    foreground: const Color(0xFFFFB4AB),
                    background: const Color(0x33FF6B6B),
                    fontSize: 10,
                  ),
                if (_showObsRecordingSize(displaySettings) &&
                    state.recordingActive)
                  _ObsPillBadge(
                    label: _formatObsBytes(state.recordingBytes),
                    foreground: const Color(0xFFE7E7E7),
                    background: const Color(0xFF2A2A2A),
                    fontSize: 10,
                  ),
              ],
            ),
          ],
          if (state.error != null && state.error!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.obsConnectionProblem,
              style: const TextStyle(
                color: Color(0xFFFFB4AB),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObsCompactPill extends StatelessWidget {
  const _ObsCompactPill({
    required this.state,
    required this.title,
    required this.color,
    required this.styleSettings,
    required this.displaySettings,
  });

  final ObsState state;
  final String title;
  final Color color;
  final SettingsModel styleSettings;
  final SettingsModel displaySettings;

  @override
  Widget build(BuildContext context) {
    final showBubble = styleSettings.showBubble;
    final bubbleOpacity = styleSettings.messageOpacity.clamp(0.0, 1.0);
    final backgroundColor = _obsCompactBackground(
      showBubble: showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final border = _obsCompactBorder(
      showBubble: showBubble,
      bubbleOpacity: bubbleOpacity,
    );
    final radius = BorderRadius.circular(styleSettings.borderRadius);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  state.connected && _showObsScene(displaySettings, state)
                      ? state.currentScene
                      : title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (state.connected && _showObsFps(displaySettings)) ...[
                const SizedBox(width: 6),
                _ObsPillBadge(
                  label: '${state.fps.toStringAsFixed(0)} FPS',
                  foreground: const Color(0xFFE7E7E7),
                  background: const Color(0xFF242424),
                  fontSize: 10,
                ),
              ],
              if (state.connected && _showObsBitrate(displaySettings)) ...[
                const SizedBox(width: 4),
                _ObsPillBadge(
                  label: '${state.bitrateKbps.toStringAsFixed(0)}k',
                  foreground: const Color(0xFFE7E7E7),
                  background: const Color(0xFF242424),
                  fontSize: 10,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ObsPillBadge extends StatelessWidget {
  const _ObsPillBadge({
    required this.label,
    required this.foreground,
    required this.background,
    required this.fontSize,
  });

  final String label;
  final Color foreground;
  final Color background;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

(String, Color) _obsStatusVisuals(ObsState state, AppLocalizations l) {
  if (state.connecting) {
    return (l.obsStatusConnecting, Colors.amber);
  }
  if (!state.connected) {
    return (l.obsStatusDisconnected, Colors.white38);
  }
  if (state.outputActive && state.recordingActive) {
    return (l.obsStatusLiveAndRec, const Color(0xFF53FC18));
  }
  if (state.outputActive) {
    return (l.obsStatusLive, const Color(0xFF53FC18));
  }
  if (state.recordingActive) {
    return (l.obsStatusRecording, const Color(0xFFFF8A80));
  }
  return (l.obsStatusConnected, const Color(0xFF5B9CFF));
}

bool _showObsScene(SettingsModel? settings, ObsState state) {
  if (settings == null) return state.currentScene.isNotEmpty;
  return settings.obsShowCurrentScene && state.currentScene.isNotEmpty;
}

bool _showObsStreamState(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowStreamState;
}

bool _showObsFps(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowFps;
}

bool _showObsBitrate(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowBitrate;
}

bool _showObsDroppedFrames(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowDroppedFrames;
}

bool _showObsRecordingState(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingState;
}

bool _showObsRecordingDuration(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingDuration;
}

bool _showObsRecordingSize(SettingsModel? settings) {
  if (settings == null) return true;
  return settings.obsShowRecordingSize;
}

Color _obsDropBadgeForeground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0xFFFFB4AB),
    ObsDropTrend.steady => Colors.amber,
    ObsDropTrend.normal => Colors.white70,
  };
}

Color _obsDropBadgeBackground(ObsDropTrend trend) {
  return switch (trend) {
    ObsDropTrend.rising => const Color(0x44FF5252),
    ObsDropTrend.steady => const Color(0x33FFC107),
    ObsDropTrend.normal => const Color(0xFF2A2A2A),
  };
}

String _formatObsDuration(int ms) {
  final totalSeconds = (ms / 1000).floor();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatObsBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  final mb = bytes / (1024 * 1024);
  if (mb >= 1024) {
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
  return '${mb.toStringAsFixed(1)} MB';
}

Color _obsCompactBackground({
  required bool showBubble,
  required double bubbleOpacity,
}) {
  if (!showBubble || bubbleOpacity <= 0) return Colors.transparent;

  const baseColor = Color(0xFF111111);

  return baseColor.withAlpha((255 * bubbleOpacity).round().clamp(0, 255));
}

Border? _obsCompactBorder({
  required bool showBubble,
  required double bubbleOpacity,
}) {
  if (!showBubble) return null;

  final side = BorderSide(
    color: Colors.white.withValues(alpha: 0.1 * bubbleOpacity),
  );

  return Border.fromBorderSide(side);
}

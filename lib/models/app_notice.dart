enum AppNoticeSeverity { info, warning, error }

enum AppNoticeCode {
  ttsPlaybackFailed,
  voiceCommandFailed,
}

class AppNotice {
  const AppNotice({
    required this.code,
    required this.severity,
    required this.id,
  });

  final AppNoticeCode code;
  final AppNoticeSeverity severity;
  final int id;
}

enum OverlayServerPhase { disabled, starting, ready, error }

class OverlayServerState {
  const OverlayServerState({
    this.phase = OverlayServerPhase.disabled,
    this.port,
    this.requestedPort,
    this.error,
  });

  final OverlayServerPhase phase;
  final int? port;

  /// The configured port, when it was busy and [port] is the next free one.
  final int? requestedPort;
  final Object? error;
}

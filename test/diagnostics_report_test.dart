import 'package:airstream/application/diagnostics_report.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/models/chat_session_state.dart';
import 'package:airstream/services/kick_service.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/alert_type_options.dart';
import 'package:airstream/window/global_shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settings = SettingsModel(
      youtubeHandle: 'PRIVATE_CHANNEL_Y',
      twitchChannel: 'PRIVATE_CHANNEL_T',
      kickSlug: 'PRIVATE_CHANNEL_K',
      obsEnabled: true,
      overlayEnabled: true,
      ttsEnabled: true,
      liveCaptionsEnabled: true);
  DiagnosticItem item(DiagnosticsSnapshot snapshot, String area) =>
      diagnosticItems(snapshot).singleWhere((i) => i.area == area);
  test('disabled areas are off and shortcuts are healthy', () {
    final items = diagnosticItems(const DiagnosticsSnapshot(
        settings: SettingsModel(
            youtubeEnabled: false, twitchEnabled: false, kickEnabled: false)));
    expect(
        items.take(7).every((i) => i.status == DiagnosticStatus.off), isTrue);
    expect(diagnosticAttentionCount(items), 0);
  });
  for (final platform in ['youtube', 'twitch', 'kick']) {
    for (final state in ServiceStatus.values) {
      test('$platform maps $state like connection badges', () {
        final row = item(
            DiagnosticsSnapshot(
                settings: settings,
                connections: {platform: (state, 'Connection refused')}),
            platform);
        expect(
            row.status,
            switch (state) {
              ServiceStatus.idle || ServiceStatus.ended => DiagnosticStatus.off,
              ServiceStatus.connecting => DiagnosticStatus.warning,
              ServiceStatus.connected => DiagnosticStatus.ok,
              ServiceStatus.error => DiagnosticStatus.error
            });
        expect(
            row.summary,
            contains(switch (state) {
              ServiceStatus.idle => 'Not connected',
              ServiceStatus.ended => 'Broadcast ended',
              ServiceStatus.connecting => 'Connecting',
              ServiceStatus.connected => 'Connected',
              ServiceStatus.error => 'Connection refused'
            }));
      });
    }
  }
  test('YouTube dual streams aggregate and waiting for live is a warning', () {
    expect(
        item(
                const DiagnosticsSnapshot(settings: settings, connections: {
                  'youtube': (
                    ServiceStatus.connecting,
                    youtubeWaitingForLiveStatus
                  )
                }),
                'youtube')
            .summary,
        contains('Waiting for live'));
    for (final state in [
      ServiceStatus.connected,
      ServiceStatus.error,
      ServiceStatus.connecting
    ]) {
      expect(
          item(
                  DiagnosticsSnapshot(
                      settings: settings.copyWith(
                          youtubeDualStreamEnabled: true,
                          youtubeHorizontalUrl: 'https://youtu.be/dQw4w9WgXcQ',
                          youtubeVerticalUrl: 'https://youtu.be/aqz-KE-bpKQ'),
                      connections: {
                        'youtubeHorizontal': (state, null),
                        'youtubeVertical': (state, null)
                      }),
                  'youtube')
              .status,
          switch (state) {
            ServiceStatus.connected => DiagnosticStatus.ok,
            ServiceStatus.error => DiagnosticStatus.error,
            _ => DiagnosticStatus.warning
          });
    }
  });
  test('OBS connection, failure, streaming metrics and drop threshold', () {
    final cases = <ObsState, DiagnosticStatus>{
      const ObsState(): DiagnosticStatus.off,
      const ObsState(connecting: true): DiagnosticStatus.warning,
      const ObsState(reconnecting: true): DiagnosticStatus.warning,
      const ObsState(error: 'bad', statusMessage: 'Connection refused'):
          DiagnosticStatus.error,
      const ObsState(connected: true, dropPercentage: 1): DiagnosticStatus.ok,
      const ObsState(connected: true, dropPercentage: 1.01):
          DiagnosticStatus.warning
    };
    for (final entry in cases.entries) {
      expect(
          item(DiagnosticsSnapshot(settings: settings, obs: entry.key), 'obs')
              .status,
          entry.value);
    }
    final row = item(
        const DiagnosticsSnapshot(
            settings: settings,
            obs: ObsState(
                connected: true,
                outputActive: true,
                bitrateKbps: 6000,
                dropPercentage: 2.5)),
        'obs');
    expect(row.summary, contains('6000 kbps'));
    expect(row.summary, contains('2.50%'));
  });
  for (final phase in OverlayServerPhase.values) {
    test('server $phase and enabled alerts without pages', () {
      final snapshot = DiagnosticsSnapshot(
          settings: settings,
          server: OverlayServerState(
              phase: phase, port: 8123, error: 'port is taken'),
          pages: const {
            'alerts': 1,
            'chat': 2,
            'poll': 3,
            'captions': 4,
            'custom': 5
          });
      final row = item(snapshot, 'overlay');
      expect(
          row.status,
          phase == OverlayServerPhase.error
              ? DiagnosticStatus.error
              : phase == OverlayServerPhase.ready
                  ? DiagnosticStatus.ok
                  : DiagnosticStatus.warning);
      if (phase == OverlayServerPhase.ready) {
        expect(row.summary, contains('Listening on port 8123'));
        expect(row.summary, contains('2 / 1 / 3 / 4 / 0 / 0 / 0 / 5'));
        expect(row.summary, contains('goals / timer / custom'));
      }
    });
  }
  test('missing alerts warns only when alert types enabled', () {
    expect(
        item(
                const DiagnosticsSnapshot(
                    settings: settings,
                    server:
                        OverlayServerState(phase: OverlayServerPhase.ready)),
                'overlay')
            .summary,
        contains('No alerts page connected in OBS'));
    expect(
        item(
                DiagnosticsSnapshot(
                    settings:
                        settings.copyWith(alertDisabledTypes: alertTypeIds),
                    server: const OverlayServerState(
                        phase: OverlayServerPhase.ready)),
                'overlay')
            .status,
        DiagnosticStatus.ok);
  });
  for (final phase in TtsLoadPhase.values) {
    test('TTS $phase', () {
      final row = item(
          DiagnosticsSnapshot(
              settings: settings,
              tts:
                  TtsLoadState(phase: phase, loadedBytes: 50, totalBytes: 100)),
          'tts');
      expect(
          row.status,
          phase == TtsLoadPhase.error
              ? DiagnosticStatus.error
              : phase == TtsLoadPhase.ready
                  ? DiagnosticStatus.ok
                  : DiagnosticStatus.warning);
      expect(
          row.summary,
          contains(phase == TtsLoadPhase.error
              ? 'Failed'
              : phase == TtsLoadPhase.ready
                  ? 'Supertonic'
                  : '50%'));
    });
  }
  for (final phase in LiveCaptionsPhase.values) {
    test('captions $phase and commands', () {
      final row = item(
          DiagnosticsSnapshot(
              settings: settings.copyWith(voiceCommandsEnabled: true),
              captions: LiveCaptionsState(phase: phase)),
          'captions');
      expect(
          row.status,
          phase == LiveCaptionsPhase.error
              ? DiagnosticStatus.error
              : [LiveCaptionsPhase.listening, LiveCaptionsPhase.transcribing]
                      .contains(phase)
                  ? DiagnosticStatus.ok
                  : DiagnosticStatus.warning);
      expect(row.summary, contains('Voice commands on'));
    });
  }
  test('shortcut conflict lists action and counts attention', () {
    final rows = diagnosticItems(const DiagnosticsSnapshot(
        settings: SettingsModel(),
        shortcutFailures: {
          GlobalShortcutAction.silenceTts,
          GlobalShortcutAction.toggleTts
        }));
    expect(rows.last.summary,
        contains('Silence voice reader, Toggle voice reader'));
    expect(rows.last.status, DiagnosticStatus.warning);
    expect(diagnosticAttentionCount(rows), 1);
  });
  test(
      'support report never exposes private payloads; '
      'screen hides the OBS password', () {
    const secrets = [
      'PRIVATE_PASSWORD',
      'PRIVATE_HOST',
      'PRIVATE_CHANNEL_Y',
      'PRIVATE_CHANNEL_T',
      'PRIVATE_CHANNEL_K',
      'PRIVATE_CHAT',
      'PRIVATE_VIEWER',
      r'C:\private\audio.wav',
      'PRIVATE_TOKEN'
    ];
    final payload = secrets.join(' ');
    final snapshot = DiagnosticsSnapshot(
        settings: settings.copyWith(
            obsPassword: secrets[0],
            obsHost: secrets[1],
            ttsReferenceAudioPath: secrets[7],
            alertTypeOptions: {
              'gift': {'sound': 'custom', 'soundPath': secrets[7]}
            }),
        connections: {'youtube': (ServiceStatus.error, payload)},
        obs: ObsState(
            error: payload, statusMessage: payload, currentScene: payload),
        server:
            OverlayServerState(phase: OverlayServerPhase.error, error: payload),
        tts: TtsLoadState(phase: TtsLoadPhase.error, error: payload),
        captions: LiveCaptionsState(
            phase: LiveCaptionsPhase.error, error: payload, caption: payload));
    final report = diagnosticsReport(snapshot,
        dateTime: DateTime.utc(2026, 11, 16, 12),
        operatingSystemVersion: 'Windows test');
    for (final secret in secrets) {
      expect(report, isNot(contains(secret)));
    }
    // The streamer's own screen shows the real error so they can act on it,
    // but never the OBS password, even when the error text contains it.
    final screen = diagnosticItems(snapshot).map((i) => i.summary).join('\n');
    expect(screen, isNot(contains('PRIVATE_PASSWORD')));
    expect(screen, contains('PRIVATE_HOST'));
    expect(screen, contains('•••'));
    for (final row in diagnosticItems(snapshot)) {
      expect(
          report.split('\n').where((line) => line.startsWith('${row.area}:')),
          hasLength(1));
    }
    expect(report, contains('Channel set'));
    // ignore: avoid_print
    print(report);
  });
}

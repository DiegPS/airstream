import 'dart:io' as io;

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/diagnostics_report.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:airstream/services/obs_service.dart';
import 'package:airstream/services/speech/live_captions_service.dart';
import 'package:airstream/services/tts_service.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class DiagnosticsCard extends ConsumerWidget {
  const DiagnosticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final snapshot = DiagnosticsSnapshot(
      settings: ref.watch(settingsProvider),
      connections: ref.watch(connectionStatusProvider).valueOrNull ?? const {},
      chatPhase: ref.watch(chatSessionPhaseProvider),
      obs: ref.watch(obsStateProvider).valueOrNull ?? const ObsState(),
      server: ref.watch(overlayServerStateProvider).valueOrNull ??
          const OverlayServerState(),
      pages: ref.watch(overlayViewCountsProvider).valueOrNull ?? const {},
      tts: ref.watch(ttsLoadStateProvider).valueOrNull ?? const TtsLoadState(),
      captions: ref.watch(liveCaptionsStateProvider).valueOrNull ??
          const LiveCaptionsState(),
      shortcutFailures: ref.watch(globalShortcutsProvider),
    );
    // Keep the existing total-client subscription consistent with other cards.
    ref.watch(overlayClientCountProvider);
    final items = diagnosticItems(snapshot, text: l.diagnosticsMessage);
    return UiCard(
      key: const Key('diagnostics-card'),
      title: l.diagnosticsTitle,
      icon: Icons.monitor_heart_outlined,
      description: l.diagnosticsHeader(diagnosticAttentionCount(items)),
      children: [
        for (final item in items)
          Padding(
            key: Key('diagnostics-${item.area}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: switch (item.status) {
                            DiagnosticStatus.ok => const Color(0xFF53FC18),
                            DiagnosticStatus.warning => const Color(0xFFFFB15C),
                            DiagnosticStatus.error => const Color(0xFFFF4E45),
                            DiagnosticStatus.off => Colors.white24,
                          }))),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        l.diagnosticsArea(
                            item.area == 'overlay' ? 'server' : item.area),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12)),
                    Text(item.summary,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ])),
            ]),
          ),
        Wrap(spacing: 8, children: [
          TextButton.icon(
            key: const Key('diagnostics-copy'),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l.diagnosticsCopy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: diagnosticsReport(snapshot,
                      dateTime: DateTime.now(),
                      operatingSystemVersion:
                          io.Platform.operatingSystemVersion)));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.diagnosticsCopied)));
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.folder_open_rounded, size: 16),
            label: Text(l.diagnosticsLogs),
            onPressed: () async {
              try {
                final directory = await AppLogger.directory;
                await directory.create(recursive: true);
                await io.Process.start('explorer', [directory.path]);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.diagnosticsLogsFailed)));
                }
              }
            },
          ),
        ]),
      ],
    );
  }
}

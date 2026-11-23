import 'package:airstream/ui/widgets/settings_controls.dart';
import 'dart:io' show File;

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/session_csv.dart';
import 'package:airstream/services/windows_list_separator.dart';
import 'package:file_selector/file_selector.dart';
import 'package:airstream/application/session_summary.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

String _platformName(Platform platform) => platform.displayName;

String sessionDurationText(AppLocalizations l, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return l.sessionDurationHours(hours, minutes);
  return l.sessionDurationMinutes(minutes);
}

String sessionSupporterText(AppLocalizations l, SessionSupporter supporter) {
  final name = supporter.name;
  return switch (supporter.kind) {
    // Twitch Bits share the paid-message kind with Super Chats.
    SupportKind.superChat when supporter.type == 'bits' =>
      l.sessionSupportBits(name, supporter.amount ?? ''),
    SupportKind.superChat =>
      l.sessionSupportSuperChat(name, supporter.amount ?? ''),
    SupportKind.membership => supporter.platform == Platform.youtube
        ? l.sessionSupportMember(name, supporter.months ?? 1)
        : l.sessionSupportSubscription(name, supporter.months ?? 1),
    // YouTube gifts memberships; Twitch and Kick gift subscriptions.
    SupportKind.gift when supporter.platform == Platform.youtube =>
      l.sessionSupportGiftMembership(name, supporter.count ?? 1),
    SupportKind.gift => l.sessionSupportGift(name, supporter.count ?? 1),
    SupportKind.raid => l.sessionSupportRaid(name, supporter.count ?? 0),
    // Kick's Kicks keep their count instead of reading as a generic gift.
    SupportKind.support
        when supporter.type == 'kicks' && supporter.count != null =>
      l.sessionSupportKicks(name, supporter.count!.toInt()),
    SupportKind.support => l.sessionSupportOther(name),
  };
}

/// The summary as plain text, to paste in Discord or social networks.
String sessionSummaryText(
  AppLocalizations l,
  SessionSummary summary,
  DateTime now,
) {
  final lines = <String>[
    l.sessionSummary,
    l.sessionSummaryLine(
      sessionDurationText(l, summary.duration(now)),
      summary.messages,
      summary.chatters,
    ),
    for (final entry in summary.messagesByPlatform.entries)
      '· ${_platformName(entry.key)}: ${l.sessionMessages(entry.value)}',
    if (summary.topChatters.isNotEmpty) ...[
      '',
      l.sessionTopChatters,
      for (final (index, chatter) in summary.topChatters.indexed)
        '${index + 1}. ${chatter.name} (${_platformName(chatter.platform)}) — '
            '${l.sessionMessages(chatter.messages)}',
    ],
    if (summary.supporters.isNotEmpty) ...[
      '',
      l.sessionSupporters,
      for (final supporter in summary.supporters)
        '· ${sessionSupporterText(l, supporter)} '
            '(${_platformName(supporter.platform)})',
    ],
  ];
  return lines.join('\n');
}

Future<void> showSessionSummaryDialog(BuildContext context, WidgetRef ref) {
  final controller = ref.read(appControllerProvider);
  final summary = controller.sessionSummary;
  final chat = controller.sessionChat;
  final truncated = controller.sessionChatTruncated;
  return showDialog<void>(
    context: context,
    builder: (context) => SessionSummaryDialog(
        summary: summary, chat: chat, chatTruncated: truncated),
  );
}

typedef SaveSessionCsv = Future<void> Function(String name, Uint8List bytes);

Future<void> _saveSessionCsv(String name, Uint8List bytes) async {
  final location = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'CSV', extensions: ['csv'])
    ],
  );
  if (location != null) await File(location.path).writeAsBytes(bytes);
}

class SessionSummaryDialog extends StatefulWidget {
  const SessionSummaryDialog({
    super.key,
    required this.summary,
    required this.chat,
    this.chatTruncated = false,
    this.saveCsv = _saveSessionCsv,
    this.listSeparator = windowsListSeparator,
  });

  final SessionSummary summary;
  final List<ChatMessage> chat;
  final bool chatTruncated;
  final SaveSessionCsv saveCsv;

  /// The column separator Excel expects on this computer.
  final Future<String> Function() listSeparator;

  @override
  State<SessionSummaryDialog> createState() => _SessionSummaryDialogState();
}

class _SessionSummaryDialogState extends State<SessionSummaryDialog> {
  bool _saving = false;

  // The counts are a snapshot taken when the dialog opened; the duration is
  // measured at the same moment so the numbers always belong together.
  final DateTime _openedAt = DateTime.now();

  Future<void> _export(
      String name, Uint8List Function(String separator) buildCsv) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.saveCsv(name, buildCsv(await widget.listSeparator()));
    } catch (_) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l.sessionExportFailed,
                  style:
                      const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final l = AppLocalizations.of(context)!;
    final now = _openedAt;
    const muted = TextStyle(color: Colors.white54, fontSize: 12);
    const heading = TextStyle(
      color: Color(0xFF53FC18),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    return AlertDialog(
      title: Text(l.sessionSummary),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.startedAt != null) ...[
                if (widget.chatTruncated)
                  Text(l.sessionExportChatScope(widget.chat.length),
                      style: muted),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      style: dialogSecondaryStyle(),
                      key: const Key('session-export-chat'),
                      onPressed: _saving || widget.chat.isEmpty
                          ? null
                          : () => _export(
                              'airstream-chat.csv',
                              (separator) => SessionCsv.chat(widget.chat,
                                  separator: separator)),
                      child: Text(l.sessionExportChat),
                    ),
                    OutlinedButton(
                      style: dialogSecondaryStyle(),
                      key: const Key('session-export-participants'),
                      onPressed: _saving || summary.participants.isEmpty
                          ? null
                          : () => _export(
                              'airstream-participants.csv',
                              (separator) => SessionCsv.participants(
                                  summary.participants,
                                  separator: separator)),
                      child: Text(l.sessionExportParticipants),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (summary.startedAt == null || summary.isEmpty)
                Text(l.sessionSummaryEmpty, style: muted)
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Stat(
                      l.sessionDuration,
                      sessionDurationText(l, summary.duration(now)),
                    ),
                    _Stat(l.sessionMessagesLabel, '${summary.messages}'),
                    _Stat(l.sessionChatters, '${summary.chatters}'),
                    for (final entry in summary.messagesByPlatform.entries)
                      _Stat(_platformName(entry.key), '${entry.value}'),
                  ],
                ),
                if (summary.topChatters.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(l.sessionTopChatters, style: heading),
                  const SizedBox(height: 6),
                  for (final (index, chatter) in summary.topChatters.indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${index + 1}. ${chatter.name} · '
                        '${_platformName(chatter.platform)} · '
                        '${l.sessionMessages(chatter.messages)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(l.sessionSupporters, style: heading),
                const SizedBox(height: 6),
                if (summary.supporters.isEmpty)
                  Text(l.sessionNoSupporters, style: muted)
                else
                  for (final supporter in summary.supporters)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${sessionSupporterText(l, supporter)} · '
                        '${_platformName(supporter.platform)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (summary.startedAt != null && !summary.isEmpty)
          OutlinedButton.icon(
            style: dialogSecondaryStyle(),
            key: const Key('session-summary-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                text: sessionSummaryText(l, summary, now),
              ));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.sessionSummaryCopied),
                  duration: const Duration(milliseconds: 1400),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(l.sessionSummaryCopy),
          ),
        ElevatedButton(
          style: dialogPrimaryStyle(),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
}

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/session_summary.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

String _platformName(Platform platform) => switch (platform) {
      Platform.youtube => 'YouTube',
      Platform.twitch => 'Twitch',
      Platform.kick => 'Kick',
    };

String sessionDurationText(AppLocalizations l, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return l.sessionDurationHours(hours, minutes);
  return l.sessionDurationMinutes(minutes);
}

String sessionSupporterText(AppLocalizations l, SessionSupporter supporter) {
  final name = supporter.name;
  return switch (supporter.kind) {
    SupportKind.superChat =>
      l.sessionSupportSuperChat(name, supporter.amount ?? ''),
    SupportKind.membership => supporter.platform == Platform.youtube
        ? l.sessionSupportMember(name, supporter.months ?? 1)
        : l.sessionSupportSubscription(name, supporter.months ?? 1),
    SupportKind.gift => l.sessionSupportGift(name, supporter.count ?? 1),
    SupportKind.raid => l.sessionSupportRaid(name, supporter.count ?? 0),
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
  final summary = ref.read(appControllerProvider).sessionSummary;
  return showDialog<void>(
    context: context,
    builder: (context) => _SessionSummaryDialog(summary: summary),
  );
}

class _SessionSummaryDialog extends StatelessWidget {
  const _SessionSummaryDialog({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    const muted = TextStyle(color: Colors.white54, fontSize: 12);
    const heading = TextStyle(
      color: Color(0xFF53FC18),
      fontSize: 12,
      fontWeight: FontWeight.w800,
    );

    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      title: Text(l.sessionSummary),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: summary.startedAt == null || summary.isEmpty
            ? Text(l.sessionSummaryEmpty, style: muted)
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      for (final (index, chatter)
                          in summary.topChatters.indexed)
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
                ),
              ),
      ),
      actions: [
        if (summary.startedAt != null && !summary.isEmpty)
          TextButton.icon(
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
        TextButton(
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

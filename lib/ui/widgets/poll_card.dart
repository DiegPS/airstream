import 'settings_controls.dart';
import 'dart:async';

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/app_notice.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const _accent = Color(0xFF53FC18);

/// Creates a poll viewers answer from every chat, and shows its results.
class PollCard extends ConsumerStatefulWidget {
  const PollCard({super.key});

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  final _question = TextEditingController();
  final _options = [TextEditingController(), TextEditingController()];
  int? _minutes;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _question.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  bool get _canStart =>
      _question.text.trim().isNotEmpty &&
      _options.where((o) => o.text.trim().isNotEmpty).length >=
          ChatPoll.minOptions;

  void _start() {
    ref.read(appControllerProvider).startPoll(
          question: _question.text,
          options: [for (final option in _options) option.text],
          duration: _minutes == null ? null : Duration(minutes: _minutes!),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final poll = ref.watch(chatPollProvider).valueOrNull;
    final running = poll != null && !poll.closed && poll.endsAt != null;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => mounted ? setState(() {}) : null,
      );
    } else if (!running) {
      _ticker?.cancel();
      _ticker = null;
    }

    return UiCard(
      key: const Key('poll-card'),
      title: l.pollTitle,
      icon: Icons.poll_outlined,
      description: l.pollDescription,
      children: [
        if (poll == null) ..._editor(l) else ..._results(l, poll),
        const SizedBox(height: 10),
        _overlayHint(l),
      ],
    );
  }

  List<Widget> _editor(AppLocalizations l) => [
        _input(_question, l.pollQuestionHint, key: const Key('poll-question')),
        const SizedBox(height: 8),
        for (var i = 0; i < _options.length; i++) ...[
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '!${i + 1}',
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: _input(
                  _options[i],
                  l.pollOptionHint(i + 1),
                  key: Key('poll-option-$i'),
                ),
              ),
              if (_options.length > ChatPoll.minOptions)
                IconButton(
                  tooltip: l.pollRemoveOption,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: Colors.white38,
                  onPressed: () => setState(() {
                    _options.removeAt(i).dispose();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            if (_options.length < ChatPoll.maxOptions)
              TextButton.icon(
                key: const Key('poll-add-option'),
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.pollAddOption),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l.pollDuration,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            DropdownButton<int?>(
              value: _minutes,
              isDense: true,
              underline: const SizedBox.shrink(),
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                DropdownMenuItem(value: null, child: Text(l.pollNoTimeLimit)),
                for (final minutes in const [1, 2, 5])
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(l.pollMinutes(minutes)),
                  ),
              ],
              onChanged: (value) => setState(() => _minutes = value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('poll-start'),
            onPressed: _canStart ? _start : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(l.pollStart),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF262626),
            ),
          ),
        ),
      ];

  List<Widget> _results(AppLocalizations l, ChatPoll poll) {
    final counts = poll.counts;
    final total = poll.total;
    final leader = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final endsAt = poll.endsAt;
    final status = poll.closed
        ? l.pollClosed
        : endsAt == null
            ? l.pollOpen
            : l.pollSecondsLeft(
                endsAt.difference(DateTime.now()).inSeconds.clamp(0, 9999),
              );
    return [
      Text(
        poll.question,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < poll.options.length; i++) ...[
        Row(
          children: [
            Text(
              '!${i + 1} ',
              style:
                  const TextStyle(color: _accent, fontWeight: FontWeight.w800),
            ),
            Expanded(
              child: Text(
                poll.options[i],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            Text(
              '${total == 0 ? 0 : (counts[i] * 100 / total).round()}% · '
              '${counts[i]}',
              key: Key('poll-count-$i'),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : counts[i] / total,
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: counts[i] > 0 && counts[i] == leader
                ? const Color(0xFFFFC83D)
                : _accent,
          ),
        ),
        const SizedBox(height: 8),
      ],
      Text(
        '${l.pollVotes(total)} · $status',
        key: const Key('poll-status'),
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          if (!poll.closed)
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('poll-end'),
                onPressed: () => ref.read(appControllerProvider).endPoll(),
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: Text(l.pollEnd),
              ),
            ),
          if (poll.closed)
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('poll-new'),
                onPressed: () => ref.read(appControllerProvider).clearPoll(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.pollNew),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _overlayHint(AppLocalizations l) {
    final ready = ref.watch(overlayServerStateProvider).valueOrNull?.phase ==
        OverlayServerPhase.ready;
    final url = ref.watch(overlayUrlProvider);
    if (!ready || url == null) {
      return const SizedBox.shrink();
    }
    final pollUrl = '$url/poll';
    return PageUrlRow(
        url: pollUrl,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: pollUrl));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.pollOverlayUrlCopied),
              duration: const Duration(milliseconds: 1400),
            ),
          );
        });
  }

  Widget _input(TextEditingController controller, String hint, {Key? key}) =>
      TextField(
        key: key,
        controller: controller,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
          ),
        ),
      );
}

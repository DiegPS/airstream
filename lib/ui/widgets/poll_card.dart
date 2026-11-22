import 'settings_controls.dart';
import 'dart:async';

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_poll.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/application/saved_poll.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:intl/intl.dart';
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
  final _command = TextEditingController(text: ChatPoll.defaultCommand);
  PollMode _mode = PollMode.numbered;
  QueueRole _allowed = QueueRole.everyone;
  bool _hideResults = false;
  bool _allowChange = true;
  bool _showOptions = false;
  PollInputError? _error;
  int? _minutes;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _question.dispose();
    _command.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  bool get _usesOptions => _mode == PollMode.numbered || _mode == PollMode.word;

  bool get _canStart =>
      _question.text.trim().isNotEmpty &&
      (!_usesOptions ||
          _options.where((o) => o.text.trim().isNotEmpty).length >=
              ChatPoll.minOptions);

  void _start(AppLocalizations l) {
    try {
      ref.read(appControllerProvider).startPoll(
            question: _question.text,
            options: [for (final option in _options) option.text],
            duration: _minutes == null ? null : Duration(minutes: _minutes!),
            mode: _mode,
            allowed: _allowed,
            hideResults: _hideResults,
            allowChange: _allowChange,
            command: _command.text,
            language: l.localeName,
          );
    } on ArgumentError catch (error) {
      final code = error.invalidValue;
      setState(() =>
          _error = code is PollInputError ? code : PollInputError.invalid);
    }
  }

  Future<void> _saveSetup(AppLocalizations l, [SavedPoll? existing]) async {
    final draft = existing?.toJson() ??
        {
          'question': _question.text,
          'options': [for (final option in _options) option.text],
          'mode': _mode.name,
          'minutes': _minutes,
          'allowed': _allowed.name,
          'hideResults': _hideResults,
          'allowChange': _allowChange,
          'command': _command.text,
        };
    if (existing == null) {
      try {
        ChatPollController.validateSetup(_question.text,
            [for (final option in _options) option.text], _mode, _command.text);
      } on ArgumentError catch (error) {
        setState(() => _error = error.invalidValue as PollInputError);
        return;
      }
    }
    final saved = ref.read(settingsProvider).savedPolls;
    bool taken(List<SavedPoll> polls, String name) => polls.any((poll) =>
        !identical(poll, existing) &&
        poll.name.toLowerCase() == name.toLowerCase());
    var input = existing?.name ?? '';
    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final clean = SavedPoll.cleanName(input);
          final duplicate = taken(saved, clean);
          return AlertDialog(
            title: Text(existing == null ? l.pollSaveSetup : l.pollRenameSetup),
            content: TextFormField(
              key: const Key('poll-setup-name'),
              initialValue: input,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
              decoration: settingsInput(
                hint: l.pollSetupName,
                error: duplicate ? l.pollSetupDuplicate : null,
              ),
              onChanged: (value) => setDialogState(() => input = value),
            ),
            actions: [
              OutlinedButton(
                  style: dialogSecondaryStyle(),
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel)),
              ElevatedButton(
                style: dialogPrimaryStyle(),
                onPressed: duplicate || clean.isEmpty
                    ? null
                    : () => Navigator.pop(context, clean),
                child: Text(l.ruleLabel('ksave')),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || name == null) return;
    final updated = SavedPoll.fromJson({...draft, 'name': name});
    if (updated == null) {
      setState(() => _error = PollInputError.invalid);
      return;
    }
    final latest = ref.read(settingsProvider).savedPolls;
    if (taken(latest, name) ||
        (existing == null && latest.length >= SavedPoll.limit)) {
      return;
    }
    await _writeSaved([
      for (final poll in latest) identical(poll, existing) ? updated : poll,
      if (existing == null) updated,
    ]);
  }

  Future<void> _writeSaved(List<SavedPoll> polls) {
    final settings = ref.read(settingsProvider);
    return ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(savedPolls: List.unmodifiable(polls)));
  }

  void _launch(SavedPoll setup, AppLocalizations l) {
    setState(() {
      _question.text = setup.question;
      _command.text = setup.command;
      for (final option in _options) {
        option.dispose();
      }
      _options
        ..clear()
        ..addAll(
            setup.options.map((option) => TextEditingController(text: option)));
      while (_options.length < ChatPoll.minOptions) {
        _options.add(TextEditingController());
      }
      _mode = setup.mode;
      _minutes = setup.minutes;
      _allowed = setup.allowed;
      _hideResults = setup.hideResults;
      _allowChange = setup.allowChange;
      _error = null;
    });
    ref
        .read(appControllerProvider)
        .launchSavedPoll(setup, language: l.localeName);
  }

  Widget _savedPolls(AppLocalizations l, List<SavedPoll> saved,
          {required bool pollOpen}) =>
      Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          key: const Key('saved-polls'),
          tilePadding: EdgeInsets.zero,
          title: Text(l.pollSavedSetups),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _canStart && saved.length < SavedPoll.limit
                  ? () => _saveSetup(l)
                  : null,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l.pollSaveSetup),
            ),
            if (saved.length >= SavedPoll.limit) Text(l.pollSetupLimit),
            for (final poll in saved)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(poll.question,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          key: ValueKey(poll),
                          onPressed: pollOpen ? null : () => _launch(poll, l),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(l.pollStart),
                        ),
                        IconButton(
                          tooltip: l.pollRenameSetup,
                          onPressed: () => _saveSetup(l, poll),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: l.pollDeleteSetup,
                          onPressed: () => _writeSaved([
                            for (final current
                                in ref.read(settingsProvider).savedPolls)
                              if (!identical(current, poll)) current,
                          ]),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  String _modeLabel(AppLocalizations l, PollMode mode) => switch (mode) {
        PollMode.numbered => l.pollModeNumbered,
        PollMode.word => l.pollModeWord,
        PollMode.yesNo => l.pollModeYesNo,
        PollMode.rating => l.pollModeRating,
        PollMode.freeAnswer => l.pollModeFreeAnswer,
      };

  String _roleLabel(AppLocalizations l, QueueRole role) => switch (role) {
        QueueRole.everyone => l.queueEveryone,
        QueueRole.member => l.queueMembers,
        QueueRole.vip => l.queueVip,
        QueueRole.moderator => l.queueModerators,
      };

  String _errorLabel(AppLocalizations l, PollInputError error) =>
      switch (error) {
        PollInputError.ambiguousOptions => l.pollAmbiguousOptions,
        PollInputError.optionTooLong => l.pollOptionTooLong,
        PollInputError.invalidCommand => l.pollInvalidCommand,
        PollInputError.invalid => l.pollInvalidInput,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final poll = ref.watch(chatPollProvider).valueOrNull;
    final saved = ref.watch(settingsProvider.select((s) => s.savedPolls));
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
        // Launching a saved poll would silently replace an open one and its
        // votes; end the current poll first.
        _savedPolls(l, saved, pollOpen: poll != null && !poll.closed),
        const SizedBox(height: 10),
        _overlayHint(l),
      ],
    );
  }

  List<Widget> _editor(AppLocalizations l) => [
        _selection(
          l.pollMode,
          _mode,
          PollMode.values,
          (mode) => _modeLabel(l, mode),
          (mode) => setState(() {
            _mode = mode;
            _error = null;
          }),
          key: const Key('poll-mode'),
        ),
        const SizedBox(height: 8),
        // Labels above the field, like Voting mode and Duration.
        settingsLabel(l.pollQuestionHint),
        _input(_question, '', key: const Key('poll-question')),
        const SizedBox(height: 8),
        if (_mode == PollMode.freeAnswer) ...[
          settingsLabel(l.pollCommand),
          _input(_command, '', key: const Key('poll-command')),
          const SizedBox(height: 8),
        ],
        if (_usesOptions) ...[
          for (var i = 0; i < _options.length; i++) ...[
            Row(
              children: [
                if (_mode == PollMode.numbered)
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
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (_options.length < ChatPoll.maxOptions)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('poll-add-option'),
                onPressed: () =>
                    setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.pollAddOption),
              ),
            ),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            settingsLabel(l.pollDuration),
            settingsDropdown<int?>(
              value: _minutes,
              items: [
                DropdownMenuItem(value: null, child: Text(l.pollNoTimeLimit)),
                for (final minutes in SavedPoll.durations)
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(l.pollMinutes(minutes)),
                  ),
              ],
              onChanged: (value) => setState(() => _minutes = value),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            expanded: _showOptions,
            child: TextButton.icon(
              key: const Key('poll-settings'),
              onPressed: () => setState(() => _showOptions = !_showOptions),
              icon: Icon(_showOptions ? Icons.expand_less : Icons.expand_more),
              label: Text(l.pollOptions),
            ),
          ),
        ),
        if (_showOptions)
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                _selection(
                    l.pollAllowed,
                    _allowed,
                    QueueRole.values,
                    (role) => _roleLabel(l, role),
                    (role) => setState(() => _allowed = role)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.pollHideResults, style: settingsBodyStyle),
                  value: _hideResults,
                  onChanged: (hidden) => setState(() => _hideResults = hidden),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.pollAllowChange, style: settingsBodyStyle),
                  value: _allowChange,
                  onChanged: (allow) => setState(() => _allowChange = allow),
                ),
              ],
            ),
          ),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_errorLabel(l, error),
                key: const Key('poll-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: const Key('poll-start'),
            onPressed: _canStart ? () => _start(l) : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(l.pollStart),
            style: primarySettingsStyle(),
          ),
        ),
      ];

  Widget _selection<T>(
    String label,
    T value,
    List<T> values,
    String Function(T) name,
    ValueChanged<T> update, {
    Key? key,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingsLabel(label),
          settingsDropdown<T>(
            key: key,
            value: value,
            items: [
              for (final item in values)
                DropdownMenuItem(
                    value: item,
                    child: Text(name(item), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) {
              if (value != null) update(value);
            },
          ),
        ],
      );

  List<Widget> _results(AppLocalizations l, ChatPoll poll) {
    final total = poll.total;
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
      ..._tally(l, poll),
      if (!poll.closed && poll.hideResults)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(l.pollResultsHiddenOnPages,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
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
                style: secondarySettingsStyle(),
              ),
            ),
          if (poll.closed)
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('poll-new'),
                onPressed: () => ref.read(appControllerProvider).clearPoll(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.pollNew),
                style: primarySettingsStyle(),
              ),
            ),
        ],
      ),
    ];
  }

  List<Widget> _tally(AppLocalizations l, ChatPoll poll) {
    if (poll.mode == PollMode.freeAnswer) {
      final answers = poll.answers;
      return [
        if (answers.top.isEmpty) Text(l.pollNoAnswers),
        for (final (index, answer) in answers.top.indexed)
          _resultRow('${index + 1}.', answer.text, '${answer.votes}'),
        if (answers.distinct > 0)
          Text('${l.pollDistinctAnswers}: ${answers.distinct}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
      ];
    }
    final counts = poll.counts;
    if (poll.mode == PollMode.rating) {
      final average = poll.average;
      final formatted = average == null
          ? '—'
          : NumberFormat('0.0', l.localeName).format(average);
      final peak = counts.fold<int>(1, (a, b) => a > b ? a : b);
      return [
        Text('${l.pollAverage}: $formatted', key: const Key('poll-average')),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (index, count) in counts.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text('$count',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10)),
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: ColoredBox(
                          color: Colors.white12,
                          child: FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: count / peak,
                            child: const ColoredBox(color: _accent),
                          ),
                        ),
                      ),
                      Text('${index + 1}',
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ];
    }
    final leader = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final total = poll.total;
    return [
      for (final (index, count) in counts.indexed) ...[
        _resultRow(
            poll.mode == PollMode.word ? '' : '!${index + 1}',
            poll.options[index],
            '${total == 0 ? 0 : (count * 100 / total).round()}% · $count',
            key: Key('poll-count-$index')),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: count > 0 && count == leader
                ? const Color(0xFFFFC83D)
                : _accent,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _resultRow(String prefix, String label, String count, {Key? key}) =>
      Row(
        children: [
          if (prefix.isNotEmpty)
            Text('$prefix ',
                style: const TextStyle(
                    color: _accent, fontWeight: FontWeight.w800)),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Text(count,
              key: key,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );

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
        onChanged: (_) => setState(() => _error = null),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint.isEmpty ? null : hint,
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

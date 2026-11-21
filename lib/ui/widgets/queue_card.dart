import 'dart:async';

import 'package:airstream/application/app_providers.dart';
import 'package:airstream/application/chat_queue.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/models/chat_message.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'settings_controls.dart';
import 'ui_card.dart';

class QueueCard extends ConsumerWidget {
  const QueueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final (options, language) = ref.watch(
      settingsProvider.select((s) => (s.queueOptions, s.appLanguageCode)),
    );
    final queue = ref.watch(chatQueueProvider);
    final command = options.commandFor(language);
    void save(QueueOptions Function(QueueOptions) change) {
      final settings = ref.read(settingsProvider);
      unawaited(ref.read(settingsProvider.notifier).update(
            settings.copyWith(queueOptions: change(settings.queueOptions)),
          ));
    }

    return StreamBuilder<QueueState>(
      stream: queue.states,
      initialData: queue.current,
      builder: (context, snapshot) {
        final state = snapshot.requireData;
        Widget button(String id, String label, VoidCallback? onPressed,
                {bool destructive = false}) =>
            OutlinedButton(
              key: Key('queue-$id'),
              style: secondarySettingsStyle(destructive: destructive),
              onPressed: onPressed,
              child: Text(label),
            );

        final statusText = switch (state.status) {
          QueueStatus.closed => l.queueClosed,
          QueueStatus.open => l.queueOpenStatus,
          QueueStatus.paused => l.queuePaused,
        };
        final statusColor = switch (state.status) {
          QueueStatus.closed => Colors.white70,
          QueueStatus.open => const Color(0xFF53FC18),
          QueueStatus.paused => const Color(0xFFFFB15C),
        };
        final hint = state.status == QueueStatus.open
            ? l.queueJoinHint(command)
            : l.queueJoinWhenOpen(command);
        final playingFull =
            state.playing.length >= ChatQueueController.maxPlaying;
        return UiCard(
          key: const Key('queue-card'),
          title: l.queueTitle,
          icon: Icons.groups_outlined,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                    label:
                        Text(statusText, style: TextStyle(color: statusColor))),
                Text('${state.entries.length} / ${options.max}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                button(
                    'open',
                    l.queueOpen,
                    state.status == QueueStatus.open
                        ? null
                        : () => queue.setStatus(QueueStatus.open)),
                button(
                    'pause',
                    l.queuePause,
                    state.status == QueueStatus.paused
                        ? null
                        : () => queue.setStatus(QueueStatus.paused)),
                button(
                    'close',
                    l.queueClose,
                    state.status == QueueStatus.closed
                        ? null
                        : () => queue.setStatus(QueueStatus.closed)),
              ],
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: hint,
              child: Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            if (state.entries.isEmpty)
              settingsLabel(l.queueEmpty)
            else
              _QueueRows(
                entries: state.entries,
                action: queue.remove,
                actionLabel: l.queueRemove,
                actionId: 'remove',
              ),
            const SizedBox(height: 8),
            if (playingFull && state.entries.isNotEmpty) ...[
              Text(l.queuePlayingFull,
                  key: const Key('queue-playing-full'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ElevatedButton(
                    key: const Key('queue-next'),
                    style: primarySettingsStyle(),
                    onPressed: state.entries.isEmpty || playingFull
                        ? null
                        : () => queue.next(options.nextCount),
                    child: Text(l.queueNext),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: _QueueSelect<int>(
                    label: l.queueNextCount,
                    value: options.nextCount,
                    choices: {for (var n = 1; n <= 10; n++) n: '$n'},
                    onChanged: (value) =>
                        save((s) => s.copyWith(nextCount: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                button(
                    'random',
                    l.queueRandom,
                    state.entries.isEmpty || playingFull
                        ? null
                        : () => queue.next(options.nextCount, random: true)),
                button(
                    'clear',
                    l.queueClear,
                    state.entries.isEmpty &&
                            state.playing.isEmpty &&
                            state.played.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: Text(l.queueClearConfirm),
                                actions: [
                                  OutlinedButton(
                                    style: secondarySettingsStyle(),
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: Text(l.cancel),
                                  ),
                                  OutlinedButton(
                                    key: const Key('queue-clear-confirm'),
                                    style: secondarySettingsStyle(
                                        destructive: true),
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: Text(l.queueClear),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              queue.clear();
                            }
                          },
                    destructive: true),
              ],
            ),
            const SizedBox(height: 12),
            settingsLabel(l.queuePlaying),
            if (state.playing.isEmpty)
              settingsLabel(l.queueNobodyPlaying)
            else
              _QueueRows(
                entries: state.playing,
                action: queue.done,
                actionLabel: l.queueDone,
                actionId: 'done',
                playing: true,
              ),
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.queueSettings),
                children: [
                  _QueueCommandField(
                    key: ValueKey(command),
                    command: command,
                    onSave: (value) => save((s) => s.copyWith(command: value)),
                  ),
                  const SizedBox(height: 8),
                  _QueueSelect<int>(
                    label: l.queueMax,
                    value: options.max,
                    choices: {for (var n = 5; n <= 100; n++) n: '$n'},
                    onChanged: (value) => save((s) => s.copyWith(max: value)),
                  ),
                  const SizedBox(height: 8),
                  _QueueSelect<QueueRole>(
                    label: l.queueRoles,
                    value: options.role,
                    choices: {
                      QueueRole.everyone: l.queueEveryone,
                      QueueRole.member: l.queueMembers,
                      QueueRole.vip: l.queueVip,
                      QueueRole.moderator: l.queueModerators,
                    },
                    onChanged: (value) => save((s) => s.copyWith(role: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.queuePriority),
                    value: options.priority,
                    onChanged: (value) =>
                        save((s) => s.copyWith(priority: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.queueRejoin),
                    value: options.rejoin,
                    onChanged: (value) =>
                        save((s) => s.copyWith(rejoin: value)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.queueChatMods),
                    subtitle: Text(l.queueChatModsHint,
                        style: const TextStyle(color: Color(0xFFFFB15C))),
                    value: options.moderatorCommands,
                    onChanged: (value) =>
                        save((s) => s.copyWith(moderatorCommands: value)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueSelect<T> extends StatelessWidget {
  const _QueueSelect({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> choices;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          settingsLabel(label),
          settingsDropdown<T>(
            menuMaxHeight: 280,
            value: value,
            items: [
              for (final choice in choices.entries)
                DropdownMenuItem(
                  value: choice.key,
                  child: Text(choice.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ],
      );
}

class _QueueCommandField extends StatefulWidget {
  const _QueueCommandField(
      {super.key, required this.command, required this.onSave});

  final String command;
  final ValueChanged<String> onSave;

  @override
  State<_QueueCommandField> createState() => _QueueCommandFieldState();
}

class _QueueCommandFieldState extends State<_QueueCommandField> {
  final _form = GlobalKey<FormState>();
  late String _draft = widget.command;

  void _save() {
    if (_form.currentState!.validate()) {
      widget.onSave(_draft.trim().toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Form(
      key: _form,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              initialValue: widget.command,
              decoration: settingsInput().copyWith(
                labelText: l.queueCommand,
                errorMaxLines: 3,
              ),
              validator: (value) {
                final command = value?.trim() ?? '';
                if (!QueueOptions.validCommand(command)) {
                  return l.queueInvalidCommand;
                }
                if (QueueOptions.reservedCommand(command)) {
                  return l.queueReservedCommand;
                }
                return null;
              },
              onChanged: (value) => _draft = value,
              onFieldSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: secondarySettingsStyle(),
            onPressed: _save,
            child: Text(l.queueSave),
          ),
        ],
      ),
    );
  }
}

class _QueueRows extends StatelessWidget {
  const _QueueRows({
    required this.entries,
    required this.action,
    required this.actionLabel,
    required this.actionId,
    this.playing = false,
  });

  final List<QueueEntry> entries;
  final ValueChanged<String> action;
  final String actionLabel, actionId;
  final bool playing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: playing ? 144 : 240),
        child: ListView.builder(
          shrinkWrap: true,
          primary: false,
          itemExtent: 48,
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return Row(
              key: ValueKey(entry.id),
              children: [
                if (!playing)
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}.',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: switch (entry.platform) {
                      Platform.youtube => const Color(0xFFFF4444),
                      Platform.twitch => const Color(0xFFAD70FF),
                      Platform.kick => const Color(0xFF53FC18),
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (entry.note.isNotEmpty)
                        Text(entry.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                if (playing)
                  OutlinedButton(
                    key: Key('queue-$actionId-${entry.id}'),
                    style: secondarySettingsStyle(),
                    onPressed: () => action(entry.id),
                    child: Text(actionLabel),
                  )
                else
                  IconButton(
                    key: Key('queue-$actionId-${entry.id}'),
                    tooltip: actionLabel,
                    color: const Color(0xFFFF6B6B),
                    onPressed: () => action(entry.id),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            );
          },
        ),
      );
}

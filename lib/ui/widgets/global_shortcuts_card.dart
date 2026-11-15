import 'package:airstream/application/app_providers.dart';
import 'package:airstream/l10n/generated/app_localizations.dart';
import 'package:airstream/settings/settings_model.dart';
import 'package:airstream/settings/settings_notifier.dart';
import 'package:airstream/ui/widgets/ui_card.dart';
import 'package:airstream/window/global_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Assigns system-wide shortcuts, off until the user records one.
class GlobalShortcutsCard extends ConsumerWidget {
  const GlobalShortcutsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return UiCard(
      key: const Key('global-shortcuts-card'),
      title: l.globalShortcutsTitle,
      icon: Icons.keyboard_command_key_rounded,
      description: l.globalShortcutsDescription,
      children: [
        for (final action in GlobalShortcutAction.values)
          _ShortcutRow(action: action),
      ],
    );
  }
}

String shortcutSettingOf(SettingsModel settings, GlobalShortcutAction action) =>
    switch (action) {
      GlobalShortcutAction.silenceTts => settings.shortcutSilenceTts,
      GlobalShortcutAction.toggleTts => settings.shortcutToggleTts,
    };

SettingsModel withShortcut(
  SettingsModel settings,
  GlobalShortcutAction action,
  String value,
) =>
    switch (action) {
      GlobalShortcutAction.silenceTts =>
        settings.copyWith(shortcutSilenceTts: value),
      GlobalShortcutAction.toggleTts =>
        settings.copyWith(shortcutToggleTts: value),
    };

class _ShortcutRow extends ConsumerStatefulWidget {
  const _ShortcutRow({required this.action});

  final GlobalShortcutAction action;

  @override
  ConsumerState<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends ConsumerState<_ShortcutRow> {
  final _focus = FocusNode();
  bool _recording = false;
  String? _problem;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _problem = null;
    });
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_recording || event is! KeyDownEvent) return KeyEventResult.ignored;
    final l = AppLocalizations.of(context)!;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _recording = false);
      return KeyEventResult.handled;
    }
    final shortcut = GlobalShortcut.fromKeyEvent(
      event.logicalKey,
      HardwareKeyboard.instance.logicalKeysPressed,
    );
    // Modifier keys alone: keep waiting for the rest of the combination.
    if (shortcut == null) return KeyEventResult.handled;
    final settings = ref.read(settingsProvider);
    final usedByOther = GlobalShortcutAction.values.any((other) =>
        other != widget.action &&
        shortcutSettingOf(settings, other) == shortcut.encode());
    final problem = !shortcut.isAllowed
        ? l.globalShortcutNeedsModifier
        : shortcut == GlobalShortcut.clickThrough
            ? l.globalShortcutReserved
            : usedByOther
                ? l.globalShortcutDuplicate
                : null;
    setState(() {
      _recording = false;
      _problem = problem;
    });
    if (problem == null) {
      ref.read(settingsProvider.notifier).update(
            withShortcut(settings, widget.action, shortcut.encode()),
          );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final value = ref.watch(
      settingsProvider.select((s) => shortcutSettingOf(s, widget.action)),
    );
    final failed = ref.watch(globalShortcutsProvider).contains(widget.action);
    final shortcut = GlobalShortcut.parse(value);
    final label = switch (widget.action) {
      GlobalShortcutAction.silenceTts => l.globalShortcutSilenceTts,
      GlobalShortcutAction.toggleTts => l.globalShortcutToggleTts,
    };
    final message = _problem ?? (failed ? l.globalShortcutInUse : null);

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      onFocusChange: (focused) {
        if (!focused && _recording) setState(() => _recording = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                OutlinedButton(
                  key: Key('shortcut-record-${widget.action.name}'),
                  onPressed: _startRecording,
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _recording ? const Color(0xFF53FC18) : Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    _recording
                        ? l.globalShortcutPress
                        : shortcut?.label ?? l.globalShortcutNone,
                  ),
                ),
                if (shortcut != null)
                  IconButton(
                    key: Key('shortcut-clear-${widget.action.name}'),
                    tooltip: l.globalShortcutClear,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: Colors.white38,
                    onPressed: () {
                      setState(() => _problem = null);
                      ref.read(settingsProvider.notifier).update(withShortcut(
                            ref.read(settingsProvider),
                            widget.action,
                            '',
                          ));
                    },
                  ),
              ],
            ),
            if (message != null)
              Text(
                message,
                style: const TextStyle(color: Color(0xFFFFB15C), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

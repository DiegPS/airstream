import 'dart:async';

import 'package:air_window_control/air_window_control.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a global shortcut does, from any app (for example during a game).
enum GlobalShortcutAction { silenceTts, toggleTts }

/// A system-wide key combination, saved as text such as `control+shift+S`.
class GlobalShortcut {
  const GlobalShortcut(this.modifiers, this.key);

  final Set<AirHotKeyModifier> modifiers;
  final AirHotKey key;

  static const _order = [
    AirHotKeyModifier.control,
    AirHotKeyModifier.alt,
    AirHotKeyModifier.shift,
    AirHotKeyModifier.meta,
  ];

  /// Click-through's own shortcut, reserved while click-through is on.
  static const clickThrough = GlobalShortcut(
    {AirHotKeyModifier.control, AirHotKeyModifier.shift},
    AirHotKey.keyC,
  );

  /// A shortcut must use Ctrl, Alt or Win: Shift alone would take a letter
  /// (or a capital letter) away from typing in every app.
  bool get isAllowed => modifiers.any((m) => m != AirHotKeyModifier.shift);

  String encode() => [
        for (final modifier in _order)
          if (modifiers.contains(modifier)) modifier.platformName,
        key.platformName,
      ].join('+');

  static GlobalShortcut? parse(String value) {
    final parts = value.split('+').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final key =
        AirHotKey.values.where((k) => k.platformName == parts.last).firstOrNull;
    if (key == null) return null;
    final modifiers = <AirHotKeyModifier>{};
    for (final name in parts.take(parts.length - 1)) {
      final modifier =
          AirHotKeyModifier.values.where((m) => m.platformName == name);
      if (modifier.isEmpty) return null;
      modifiers.add(modifier.first);
    }
    return GlobalShortcut(modifiers, key);
  }

  /// `Ctrl + Shift + S`.
  String get label => [
        for (final modifier in _order)
          if (modifiers.contains(modifier))
            switch (modifier) {
              AirHotKeyModifier.control => 'Ctrl',
              AirHotKeyModifier.alt => 'Alt',
              AirHotKeyModifier.shift => 'Shift',
              AirHotKeyModifier.meta => 'Win',
            },
        key.platformName,
      ].join(' + ');

  /// The shortcut a key press makes, or null for keys that cannot be one.
  static GlobalShortcut? fromKeyEvent(
    LogicalKeyboardKey key,
    Set<LogicalKeyboardKey> pressed,
  ) {
    final label = switch (key) {
      LogicalKeyboardKey.space => 'Space',
      _ => key.keyLabel.toUpperCase(),
    };
    final hotKey =
        AirHotKey.values.where((k) => k.platformName == label).firstOrNull;
    if (hotKey == null || hotKey == AirHotKey.escape) return null;
    bool any(Set<LogicalKeyboardKey> keys) => pressed.any(keys.contains);
    return GlobalShortcut({
      if (any({
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
      }))
        AirHotKeyModifier.control,
      if (any({LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight}))
        AirHotKeyModifier.alt,
      if (any({LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight}))
        AirHotKeyModifier.shift,
      if (any({LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight}))
        AirHotKeyModifier.meta,
    }, hotKey);
  }

  @override
  bool operator ==(Object other) =>
      other is GlobalShortcut && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Registers the shortcuts the user assigned and runs their actions. The
/// state is the set of actions whose shortcut another app already owns.
class GlobalShortcutsNotifier extends StateNotifier<Set<GlobalShortcutAction>>
    with AirWindowListener {
  GlobalShortcutsNotifier({required this.onPressed}) : super(const {}) {
    airWindow.addListener(this);
  }

  final void Function(GlobalShortcutAction action) onPressed;
  final _registered = <GlobalShortcutAction, String>{};
  Future<void> _queue = Future.value();

  static String _id(GlobalShortcutAction action) => 'shortcut-${action.name}';

  /// Registers [shortcuts] (encoded; empty means none), replacing the
  /// previous ones.
  Future<void> apply(Map<GlobalShortcutAction, String> shortcuts) =>
      _queue = _queue.then((_) => _apply(shortcuts));

  Future<void> _apply(Map<GlobalShortcutAction, String> shortcuts) async {
    final failed = {...state};
    final changed = {
      for (final action in GlobalShortcutAction.values)
        if (_registered[action] != (shortcuts[action] ?? ''))
          action: shortcuts[action] ?? '',
    };
    // Windows rejects a binding while another action still owns it.
    for (final action in changed.keys) {
      if (_registered.remove(action) != null) {
        try {
          await airWindow.unregisterGlobalHotKey(_id(action));
        } catch (error) {
          AppLogger.warning('Global shortcut release failed', error: error);
        }
      }
    }
    for (final MapEntry(key: action, value: wanted) in changed.entries) {
      failed.remove(action);
      final shortcut = GlobalShortcut.parse(wanted);
      if (shortcut == null) continue;
      try {
        final registered = await airWindow.registerGlobalHotKey(
          AirGlobalHotKey(
            id: _id(action),
            key: shortcut.key,
            modifiers: shortcut.modifiers,
          ),
        );
        if (registered) {
          _registered[action] = wanted;
        } else {
          failed.add(action);
        }
      } catch (error) {
        AppLogger.warning('Global shortcut registration failed', error: error);
        failed.add(action);
      }
    }
    if (mounted) state = failed;
  }

  @override
  void onGlobalHotKeyPressed(String id) {
    for (final action in GlobalShortcutAction.values) {
      if (id == _id(action)) onPressed(action);
    }
  }

  @override
  void dispose() {
    airWindow.removeListener(this);
    for (final action in _registered.keys) {
      unawaited(
          airWindow.unregisterGlobalHotKey(_id(action)).catchError((_) {}));
    }
    super.dispose();
  }
}

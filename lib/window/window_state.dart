import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airchat_flutter/services/window_control_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Immutable snapshot of native-window behaviour flags.
class WindowState {
  final bool frameless;
  final bool clickThrough;
  final bool alwaysOnTop;
  final bool excludeFromCapture;

  const WindowState({
    this.frameless          = false,
    this.clickThrough       = false,
    this.alwaysOnTop        = false,
    this.excludeFromCapture = false,
  });

  WindowState copyWith({
    bool? frameless,
    bool? clickThrough,
    bool? alwaysOnTop,
    bool? excludeFromCapture,
  }) =>
      WindowState(
        frameless:          frameless          ?? this.frameless,
        clickThrough:       clickThrough       ?? this.clickThrough,
        alwaysOnTop:        alwaysOnTop        ?? this.alwaysOnTop,
        excludeFromCapture: excludeFromCapture ?? this.excludeFromCapture,
      );

  Map<String, dynamic> toJson() => {
        'frameless':          frameless,
        'clickThrough':       clickThrough,
        'alwaysOnTop':        alwaysOnTop,
        'excludeFromCapture': excludeFromCapture,
      };

  factory WindowState.fromJson(Map<String, dynamic> j) => WindowState(
        frameless:          j['frameless']          as bool? ?? false,
        clickThrough:       j['clickThrough']       as bool? ?? false,
        alwaysOnTop:        j['alwaysOnTop']        as bool? ?? false,
        excludeFromCapture: j['excludeFromCapture'] as bool? ?? false,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

const _kPrefsKey = 'AIRCHAT_WINDOW_STATE';

/// Owns the native window state. Each setter immediately applies the
/// corresponding Win32 API call via [WindowControlService] and persists.
class WindowStateNotifier extends StateNotifier<WindowState> {
  WindowStateNotifier() : super(const WindowState()) {
    _load();
  }

  // ── Public setters ────────────────────────────────────────────────────────

  Future<void> setFrameless(bool value) async {
    state = state.copyWith(frameless: value);
    await WindowControlService.setFrameless(value);
    await _persist();
  }

  Future<void> setClickThrough(bool value) async {
    state = state.copyWith(clickThrough: value);
    await WindowControlService.setClickThrough(value);
    await _persist();
  }

  Future<void> setAlwaysOnTop(bool value) async {
    state = state.copyWith(alwaysOnTop: value);
    await WindowControlService.setAlwaysOnTop(value);
    await _persist();
  }

  // ── Toggle helpers ────────────────────────────────────────────────────────

  Future<void> toggleFrameless()    => setFrameless(!state.frameless);
  Future<void> toggleClickThrough() => setClickThrough(!state.clickThrough);
  Future<void> toggleAlwaysOnTop()  => setAlwaysOnTop(!state.alwaysOnTop);
  Future<void> toggleExcludeFromCapture() => setExcludeFromCapture(!state.excludeFromCapture);

  /// Electron-style: stores the desired state and calls native.
  /// If the native side reports "not applied yet" (window not visible),
  /// we retry once after a short delay.
  Future<void> setExcludeFromCapture(bool value) async {
    state = state.copyWith(excludeFromCapture: value);
    final applied = await WindowControlService.setExcludeFromCapture(value);
    if (!applied && value) {
      // Deferred apply — window might not be visible yet.
      Future.delayed(const Duration(milliseconds: 300), () {
        WindowControlService.setExcludeFromCapture(value);
      });
    }
    await _persist();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      final loaded = WindowState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      state = loaded;
      _applyAll(loaded);
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
  }

  // Only restores flags that are safe to re-apply at startup.
  // frameless is intentionally skipped — if it was active when the app
  // crashed it could leave the window undecorated on the next launch.
  // clickThrough is also skipped — if it was active when the app closed,
  // re-applying it at launch makes the window invisible/unclickable with
  // no way to recover short of manually editing shared_preferences.json.
  void _applyAll(WindowState s) {
    WindowControlService.setAlwaysOnTop(s.alwaysOnTop);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>(
  (ref) => WindowStateNotifier(),
);

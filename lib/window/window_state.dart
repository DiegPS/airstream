import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airchat_flutter/services/window_control_service.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Immutable snapshot of native-window behaviour flags.
class WindowState {
  final bool clickThrough;
  final bool alwaysOnTop;
  final bool transparent;
  final bool frameless;

  const WindowState({
    this.clickThrough = false,
    this.alwaysOnTop  = false,
    this.transparent  = false,
    this.frameless    = false,
  });

  WindowState copyWith({
    bool? clickThrough,
    bool? alwaysOnTop,
    bool? transparent,
    bool? frameless,
  }) =>
      WindowState(
        clickThrough: clickThrough ?? this.clickThrough,
        alwaysOnTop:  alwaysOnTop  ?? this.alwaysOnTop,
        transparent:  transparent  ?? this.transparent,
        frameless:    frameless    ?? this.frameless,
      );

  Map<String, dynamic> toJson() => {
        'clickThrough': clickThrough,
        'alwaysOnTop':  alwaysOnTop,
        'transparent':  transparent,
        'frameless':    frameless,
      };

  factory WindowState.fromJson(Map<String, dynamic> j) => WindowState(
        clickThrough: j['clickThrough'] as bool? ?? false,
        alwaysOnTop:  j['alwaysOnTop']  as bool? ?? false,
        transparent:  j['transparent']  as bool? ?? false,
        frameless:    j['frameless']    as bool? ?? false,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

const _kPrefsKey = 'AIRCHAT_WINDOW_STATE';

/// Owns the native window state. Each setter immediately applies the
/// corresponding Win32 API call via [WindowControlService] and persists the
/// new state to SharedPreferences.
class WindowStateNotifier extends StateNotifier<WindowState> {
  WindowStateNotifier() : super(const WindowState()) {
    _load();
  }

  // ── Public setters (one per flag for clarity) ─────────────────────────────

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

  Future<void> setTransparent(bool value) async {
    state = state.copyWith(transparent: value);
    await WindowControlService.setTransparent(value);
    await _persist();
  }

  // ── Toggle helpers ────────────────────────────────────────────────────────

  Future<void> toggleFrameless()    => setFrameless(!state.frameless);
  Future<void> toggleClickThrough() => setClickThrough(!state.clickThrough);
  Future<void> toggleAlwaysOnTop()  => setAlwaysOnTop(!state.alwaysOnTop);
  Future<void> toggleTransparent()  => setTransparent(!state.transparent);

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      final loaded = WindowState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      state = loaded;
      _applyAll(loaded);          // re-apply on startup
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(state.toJson()));
  }

  void _applyAll(WindowState s) {
    WindowControlService.setFrameless(s.frameless);
    WindowControlService.setClickThrough(s.clickThrough);
    WindowControlService.setAlwaysOnTop(s.alwaysOnTop);
    WindowControlService.setTransparent(s.transparent);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>(
  (ref) => WindowStateNotifier(),
);

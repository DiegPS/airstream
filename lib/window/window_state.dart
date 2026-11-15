import 'dart:async';

import 'package:air_window_control/air_window_control.dart';
import 'package:airstream/services/app_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class WindowState {
  final bool clickThrough;
  final bool alwaysOnTop;
  final bool excludeFromCapture;
  final bool? globalClickThroughHotKeyRegistered;
  final String? globalClickThroughHotKeyError;

  const WindowState({
    this.clickThrough = false,
    this.alwaysOnTop = false,
    this.excludeFromCapture = false,
    this.globalClickThroughHotKeyRegistered,
    this.globalClickThroughHotKeyError,
  });

  WindowState copyWith({
    bool? clickThrough,
    bool? alwaysOnTop,
    bool? excludeFromCapture,
    bool? globalClickThroughHotKeyRegistered,
    String? globalClickThroughHotKeyError,
  }) =>
      WindowState(
        clickThrough: clickThrough ?? this.clickThrough,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        excludeFromCapture: excludeFromCapture ?? this.excludeFromCapture,
        globalClickThroughHotKeyRegistered:
            globalClickThroughHotKeyRegistered ??
                this.globalClickThroughHotKeyRegistered,
        globalClickThroughHotKeyError:
            globalClickThroughHotKeyError ?? this.globalClickThroughHotKeyError,
      );
}

class WindowStateNotifier extends StateNotifier<WindowState>
    with AirWindowListener {
  static const clickThroughHotKeyId = 'toggle-click-through';

  WindowStateNotifier() : super(const WindowState()) {
    airWindow.addListener(this);
  }

  Future<void> _clickThroughQueue = Future.value();
  bool _hotKeyRegistered = false;

  /// Reserves Ctrl+Shift+C system-wide.
  ///
  /// The shortcut is only reserved while click-through is on, where it is the
  /// only way back to the window. The rest of the time other apps (terminals,
  /// browser developer tools) keep using it.
  Future<bool> _registerGlobalClickThroughHotKey() async {
    if (_hotKeyRegistered) return true;
    try {
      final registered = await airWindow.registerGlobalHotKey(
        const AirGlobalHotKey(
          id: clickThroughHotKeyId,
          key: AirHotKey.keyC,
          modifiers: {
            AirHotKeyModifier.control,
            AirHotKeyModifier.shift,
          },
        ),
      );
      _hotKeyRegistered = registered;
      if (mounted) {
        state = WindowState(
          clickThrough: state.clickThrough,
          alwaysOnTop: state.alwaysOnTop,
          excludeFromCapture: state.excludeFromCapture,
          globalClickThroughHotKeyRegistered: registered,
        );
      }
      return registered;
    } catch (error) {
      AppLogger.warning(
        'Global click-through hotkey registration failed',
        error: error,
      );
      if (mounted) {
        state = state.copyWith(
          globalClickThroughHotKeyRegistered: false,
          globalClickThroughHotKeyError:
              error is PlatformException ? error.code : 'registration_failed',
        );
      }
      return false;
    }
  }

  Future<void> _unregisterGlobalClickThroughHotKey() async {
    if (!_hotKeyRegistered) return;
    _hotKeyRegistered = false;
    try {
      await airWindow.unregisterGlobalHotKey(clickThroughHotKeyId);
    } catch (error) {
      AppLogger.warning(
        'Global click-through hotkey release failed',
        error: error,
      );
    }
  }

  Future<void> setClickThrough(bool value) async {
    return _enqueueClickThrough((_) => value);
  }

  Future<void> _enqueueClickThrough(bool Function(bool current) nextValue) {
    final operation = _clickThroughQueue.then((_) async {
      final value = nextValue(state.clickThrough);
      if (value) {
        // Without the shortcut there would be no way back to the window.
        if (!await _registerGlobalClickThroughHotKey()) return;
        try {
          await airWindow.setClickThrough(true);
        } catch (_) {
          await _unregisterGlobalClickThroughHotKey();
          rethrow;
        }
      } else {
        await airWindow.setClickThrough(false);
        await _unregisterGlobalClickThroughHotKey();
      }
      if (mounted) state = state.copyWith(clickThrough: value);
    });
    _clickThroughQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        AppLogger.warning(
          'Click-through window update failed',
          error: error,
          stackTrace: stack,
        );
      },
    );
    return operation;
  }

  Future<void> setAlwaysOnTop(bool value) async {
    state = state.copyWith(alwaysOnTop: value);
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> toggleClickThrough() =>
      _enqueueClickThrough((current) => !current);

  Future<void> toggleAlwaysOnTop() => setAlwaysOnTop(!state.alwaysOnTop);
  Future<void> toggleExcludeFromCapture() =>
      setExcludeFromCapture(!state.excludeFromCapture);

  Future<void> setExcludeFromCapture(bool value) async {
    state = state.copyWith(excludeFromCapture: value);
    final applied = await airWindow.setExcludeFromCapture(value);
    if (!applied && value) {
      Future.delayed(const Duration(milliseconds: 300), () {
        airWindow.setExcludeFromCapture(value);
      });
    }
  }

  @override
  void onGlobalHotKeyPressed(String id) {
    if (id == clickThroughHotKeyId) {
      unawaited(toggleClickThrough());
    }
  }

  @override
  void dispose() {
    airWindow.removeListener(this);
    unawaited(_unregisterGlobalClickThroughHotKey());
    super.dispose();
  }
}

final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>(
  (ref) => WindowStateNotifier(),
);

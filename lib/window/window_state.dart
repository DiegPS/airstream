import 'dart:async';

import 'package:air_window_control/air_window_control.dart';
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
    _globalHotKeyRegistration = _registerGlobalClickThroughHotKey();
    unawaited(_globalHotKeyRegistration);
  }

  late final Future<void> _globalHotKeyRegistration;
  Future<void> _clickThroughQueue = Future.value();

  Future<void> _registerGlobalClickThroughHotKey() async {
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
      if (mounted) {
        state = state.copyWith(
          globalClickThroughHotKeyRegistered: registered,
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          globalClickThroughHotKeyRegistered: false,
          globalClickThroughHotKeyError:
              error is PlatformException ? error.code : 'registration_failed',
        );
      }
    }
  }

  Future<void> setClickThrough(bool value) async {
    return _enqueueClickThrough((_) => value);
  }

  Future<void> _enqueueClickThrough(bool Function(bool current) nextValue) {
    final operation = _clickThroughQueue.then((_) async {
      final value = nextValue(state.clickThrough);
      if (value) {
        await _globalHotKeyRegistration;
        if (state.globalClickThroughHotKeyRegistered != true) return;
      }
      await airWindow.setClickThrough(value);
      if (mounted) state = state.copyWith(clickThrough: value);
    });
    _clickThroughQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
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
    unawaited(
      _globalHotKeyRegistration.whenComplete(
        () => airWindow.unregisterGlobalHotKey(clickThroughHotKeyId),
      ),
    );
    super.dispose();
  }
}

final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>(
  (ref) => WindowStateNotifier(),
);

import 'package:air_window_control/air_window_control.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

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
}

class WindowStateNotifier extends StateNotifier<WindowState> {
  WindowStateNotifier() : super(const WindowState());

  Future<void> setFrameless(bool value) async {
    state = state.copyWith(frameless: value);
    await airWindow.setFrameless(value);
  }

  Future<void> setClickThrough(bool value) async {
    state = state.copyWith(clickThrough: value);
    await airWindow.setClickThrough(value);
  }

  Future<void> setAlwaysOnTop(bool value) async {
    state = state.copyWith(alwaysOnTop: value);
    await windowManager.setAlwaysOnTop(value);
  }

  Future<void> toggleFrameless()    => setFrameless(!state.frameless);
  Future<void> toggleClickThrough() => setClickThrough(!state.clickThrough);
  Future<void> toggleAlwaysOnTop()  => setAlwaysOnTop(!state.alwaysOnTop);
  Future<void> toggleExcludeFromCapture() => setExcludeFromCapture(!state.excludeFromCapture);

  Future<void> setExcludeFromCapture(bool value) async {
    state = state.copyWith(excludeFromCapture: value);
    final applied = await airWindow.setExcludeFromCapture(value);
    if (!applied && value) {
      Future.delayed(const Duration(milliseconds: 300), () {
        airWindow.setExcludeFromCapture(value);
      });
    }
  }
}

final windowStateProvider =
    StateNotifierProvider<WindowStateNotifier, WindowState>(
  (ref) => WindowStateNotifier(),
);

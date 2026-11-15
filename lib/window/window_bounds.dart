import 'dart:async';
import 'dart:ui';

import 'package:airstream/services/app_logger.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

/// The smallest window in which the top bar and chat still fit.
const minimumWindowSize = Size(360, 240);

const _boundsKey = 'window.bounds';

/// How much of the top edge must stay on a screen for the window to be
/// reachable: enough to grab it and drag it back.
const _reachableWidth = 80.0;
const _reachableHeight = 24.0;

String encodeWindowBounds(Rect bounds) => [
      bounds.left,
      bounds.top,
      bounds.width,
      bounds.height,
    ].map((value) => value.round()).join(',');

Rect? decodeWindowBounds(String? value) {
  final parts = value?.split(',').map(double.tryParse).toList();
  if (parts == null || parts.length != 4 || parts.contains(null)) return null;
  final [left, top, width, height] = parts.cast<double>();
  if (width <= 0 || height <= 0) return null;
  return Rect.fromLTWH(left, top, width, height);
}

/// [saved] adjusted to [minimum], or null when no screen in [screens] shows
/// its top edge anymore (for example after unplugging a monitor).
Rect? restorableWindowBounds(
  Rect saved,
  List<Rect> screens, {
  Size minimum = minimumWindowSize,
}) {
  final bounds = Rect.fromLTWH(
    saved.left,
    saved.top,
    saved.width < minimum.width ? minimum.width : saved.width,
    saved.height < minimum.height ? minimum.height : saved.height,
  );
  final topEdge = Rect.fromLTWH(
    bounds.left,
    bounds.top,
    bounds.width,
    _reachableHeight,
  );
  final reachable = screens.any((screen) {
    final visible = screen.intersect(topEdge);
    return visible.width >= _reachableWidth &&
        visible.height >= _reachableHeight;
  });
  return reachable ? bounds : null;
}

/// Restores the window where the user left it and remembers later moves.
class WindowBoundsKeeper with WindowListener {
  Timer? _saveTimer;

  Future<void> restore() async {
    await windowManager.setMinimumSize(minimumWindowSize);
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = decodeWindowBounds(preferences.getString(_boundsKey));
      if (saved == null) return;
      final displays = await screenRetriever.getAllDisplays();
      final screens = [
        for (final display in displays)
          (display.visiblePosition ?? Offset.zero) &
              (display.visibleSize ?? display.size),
      ];
      final bounds = restorableWindowBounds(saved, screens);
      if (bounds != null) await windowManager.setBounds(bounds);
    } catch (error, stack) {
      AppLogger.warning(
        'Window position could not be restored',
        error: error,
        stackTrace: stack,
      );
    }
  }

  void startTracking() => windowManager.addListener(this);

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  Future<void> _save() async {
    try {
      if (await windowManager.isMaximized() ||
          await windowManager.isMinimized() ||
          await windowManager.isFullScreen()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_boundsKey, encodeWindowBounds(bounds));
    } catch (error, stack) {
      AppLogger.warning(
        'Window position could not be saved',
        error: error,
        stackTrace: stack,
      );
    }
  }
}

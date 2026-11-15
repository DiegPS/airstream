import 'dart:ui';

import 'package:airstream/window/window_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Rect.fromLTWH(0, 0, 1920, 1040);

  test('round-trips saved window bounds', () {
    const bounds = Rect.fromLTWH(1300, 40, 420, 900);
    expect(decodeWindowBounds(encodeWindowBounds(bounds)), bounds);
    expect(decodeWindowBounds(null), isNull);
    expect(decodeWindowBounds('nonsense'), isNull);
    expect(decodeWindowBounds('1,2,0,4'), isNull);
  });

  test('restores a window that is still on a screen', () {
    const saved = Rect.fromLTWH(1300, 40, 420, 900);
    expect(restorableWindowBounds(saved, [screen]), saved);
  });

  test('ignores a window left on a screen that is gone', () {
    const onSecondMonitor = Rect.fromLTWH(2200, 100, 420, 900);
    expect(restorableWindowBounds(onSecondMonitor, [screen]), isNull);
    expect(
      restorableWindowBounds(
        onSecondMonitor,
        [screen, const Rect.fromLTWH(1920, 0, 1920, 1040)],
      ),
      onSecondMonitor,
    );
  });

  test('ignores a window whose title bar is off screen', () {
    const titleAbove = Rect.fromLTWH(100, -200, 420, 900);
    expect(restorableWindowBounds(titleAbove, [screen]), isNull);
  });

  test('grows a saved window that is below the minimum size', () {
    final restored =
        restorableWindowBounds(const Rect.fromLTWH(10, 10, 100, 50), [screen]);
    expect(restored!.size, minimumWindowSize);
  });
}

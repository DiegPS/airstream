import 'dart:io';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Controla propiedades nativas de la ventana en Windows via un MethodChannel
/// que habla con el runner C++ (window_channel.cpp).
class WindowControlService {
  static const _channel = MethodChannel('com.airchat/window_control');

  /// Frameless real: quita WS_OVERLAPPEDWINDOW, deshabilita shadow DWM.
  /// Igual a Wails: Frameless:true + DisableFramelessWindowDecorations:true
  static Future<void> setFrameless(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setFrameless', {'enabled': enabled});
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setFrameless error: ${e.message}');
    }
  }

  /// Click-through: WS_EX_TRANSPARENT | WS_EX_LAYERED (idéntico a la versión Go).
  static Future<void> setClickThrough(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setClickThrough', {'enabled': enabled});
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setClickThrough error: ${e.message}');
    }
  }

  /// Always-on-top: SetWindowPos HWND_TOPMOST / HWND_NOTOPMOST.
  static Future<void> setAlwaysOnTop(bool enabled) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    try {
      await windowManager.setAlwaysOnTop(enabled);
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setAlwaysOnTop error: ${e.message}');
    } catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setAlwaysOnTop error: $e');
    }
  }
}

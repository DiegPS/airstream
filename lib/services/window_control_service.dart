import 'dart:io';
import 'package:flutter/services.dart';

/// Controla propiedades nativas de la ventana en Windows (transparencia, click-through)
/// via un MethodChannel que habla con el runner C++.
class WindowControlService {
  static const _channel = MethodChannel('com.airchat/window_control');

  /// Activa o desactiva la transparencia total de la ventana.
  /// En Windows usa WS_EX_LAYERED + SetLayeredWindowAttributes con alpha=0 en el background.
  static Future<void> setTransparent(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setTransparent', {'enabled': enabled});
    } on PlatformException catch (e) {
      // ignore silently — no queremos crashear si el runner no soporta el canal aún
      // ignore: avoid_print
      print('[WindowControl] setTransparent error: ${e.message}');
    }
  }

  /// Activa o desactiva el modo frameless real.
  /// Quita WS_OVERLAPPEDWINDOW (sin barra de título, sin bordes de resize),
  /// deshabilita el shadow DWM y los bordes de color del Snap de Windows.
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

  /// Activa o desactiva el click-through.
  /// En Windows: WS_EX_TRANSPARENT | WS_EX_LAYERED (idéntico a la versión Go).
  static Future<void> setClickThrough(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setClickThrough', {'enabled': enabled});
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setClickThrough error: ${e.message}');
    }
  }

  /// Activa o desactiva "always on top".
  static Future<void> setAlwaysOnTop(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('setAlwaysOnTop', {'enabled': enabled});
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[WindowControl] setAlwaysOnTop error: ${e.message}');
    }
  }
}

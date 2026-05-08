#pragma once

#include <windows.h>
#include <flutter/binary_messenger.h>

/// Registers the "com.airchat/window_control" MethodChannel.
///
/// Exposes three methods to Dart:
///   setFrameless(bool enabled)     – strips WS_OVERLAPPEDWINDOW + disables DWM shadow
///   setClickThrough(bool enabled)  – WS_EX_LAYERED | WS_EX_TRANSPARENT (mirrors Go impl)
///   setAlwaysOnTop(bool enabled)   – SetWindowPos HWND_TOPMOST / HWND_NOTOPMOST
///
/// Must be called once after the Flutter engine is initialized.
namespace window_channel {
void Register(flutter::BinaryMessenger* messenger, HWND hwnd);
}  // namespace window_channel

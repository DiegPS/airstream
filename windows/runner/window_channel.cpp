#include "window_channel.h"

#include <dwmapi.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

namespace window_channel {

namespace {

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extracts the boolean "enabled" argument from a MethodCall argument map.
bool ExtractEnabled(const flutter::EncodableValue* args) {
  if (!args) return false;
  const auto* map = std::get_if<flutter::EncodableMap>(args);
  if (!map) return false;
  const auto it = map->find(flutter::EncodableValue("enabled"));
  if (it == map->end()) return false;
  const auto* val = std::get_if<bool>(&it->second);
  return val != nullptr && *val;
}

// The channel is held in a file-local unique_ptr so it outlives the call site.
// For a single-window app this is the simplest correct approach.
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

}  // anonymous namespace

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void Register(flutter::BinaryMessenger* messenger, HWND hwnd) {
  g_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger,
          "com.airchat/window_control",
          &flutter::StandardMethodCodec::GetInstance());

  g_channel->SetMethodCallHandler(
      [hwnd](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        const bool enabled = ExtractEnabled(call.arguments());
        const LONG style = GetWindowLong(hwnd, GWL_EXSTYLE);
        const std::string& method = call.method_name();

        // ── setClickThrough ───────────────────────────────────────────────
        // Identical to the Go implementation:
        //   win.SetWindowLong(hwnd, GWL_EXSTYLE,
        //       style | WS_EX_LAYERED | WS_EX_TRANSPARENT)
        if (method == "setClickThrough") {
          SetWindowLong(hwnd, GWL_EXSTYLE,
                        enabled
                            ? (style | WS_EX_LAYERED | WS_EX_TRANSPARENT)
                            : (style & ~(WS_EX_LAYERED | WS_EX_TRANSPARENT)));
          result->Success();

        // ── setTransparent ────────────────────────────────────────────────
        // Extends the DWM glass frame to the full client area.
        // Equivalent to Wails: BackgroundColour{R:0,G:0,B:0,A:0} + Frameless.
        } else if (method == "setTransparent") {
          if (enabled) {
            SetWindowLong(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED);
            MARGINS m = {-1, -1, -1, -1};
            DwmExtendFrameIntoClientArea(hwnd, &m);
          } else {
            SetWindowLong(hwnd, GWL_EXSTYLE, style & ~WS_EX_LAYERED);
            MARGINS m = {0, 0, 0, 0};
            DwmExtendFrameIntoClientArea(hwnd, &m);
          }
          result->Success();

        // ── setAlwaysOnTop ────────────────────────────────────────────────
        } else if (method == "setAlwaysOnTop") {
          SetWindowPos(hwnd,
                       enabled ? HWND_TOPMOST : HWND_NOTOPMOST,
                       0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE);
          result->Success();

        } else {
          result->NotImplemented();
        }
      });
}

}  // namespace window_channel

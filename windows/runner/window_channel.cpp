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
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_channel;

// ---------------------------------------------------------------------------
// setFrameless implementation
// ---------------------------------------------------------------------------
//
// Wails uses Frameless:true + DisableFramelessWindowDecorations:true which:
//   1) Removes WS_OVERLAPPEDWINDOW (title bar, resize borders, system menu)
//   2) Intercepts WM_NCHITTEST returning HTCLIENT for the entire window
//      so Windows never draws Aero borders or colored snap-assist highlights
//   3) Disables DWM non-client rendering to kill the drop shadow
//
// We replicate all three steps here so the result is identical.
//
// Note: this stores the original GWL_STYLE so it can be restored when
// frameless is disabled.
LONG g_saved_style = 0;

void ApplyFrameless(HWND hwnd, bool enabled) {
  if (enabled) {
    // ── Step 1: strip native chrome ──────────────────────────────────────
    // Save the current style so we can restore it later.
    g_saved_style = GetWindowLong(hwnd, GWL_STYLE);

    // WS_POPUP: bare window with no caption, no border, no system menu.
    // Keep WS_VISIBLE so the window stays shown.
    const LONG new_style =
        (g_saved_style & ~(WS_OVERLAPPEDWINDOW)) | WS_POPUP;
    SetWindowLong(hwnd, GWL_STYLE, new_style);

    // ── Step 2: disable DWM shadow / non-client rendering ────────────────
    // DWMNCRP_DISABLED tells DWM to stop drawing the drop-shadow and the
    // colored Snap-Assist border that Wails' plain Frameless:true leaves on.
    DWMNCRENDERINGPOLICY policy = DWMNCRP_DISABLED;
    DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY,
                          &policy, sizeof(policy));

    // ── Step 3: force a frame/size refresh ───────────────────────────────
    // SWP_FRAMECHANGED makes Windows re-evaluate the non-client area.
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);

  } else {
    // Restore original style
    if (g_saved_style != 0) {
      SetWindowLong(hwnd, GWL_STYLE, g_saved_style);
      g_saved_style = 0;
    }

    // Re-enable DWM non-client rendering (restores shadow + borders)
    DWMNCRENDERINGPOLICY policy = DWMNCRP_USEWINDOWSTYLE;
    DwmSetWindowAttribute(hwnd, DWMWA_NCRENDERING_POLICY,
                          &policy, sizeof(policy));

    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  }
}

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
        const LONG exstyle  = GetWindowLong(hwnd, GWL_EXSTYLE);
        const std::string& method = call.method_name();

        // ── setClickThrough ───────────────────────────────────────────────
        // Identical to the Go/Wails implementation:
        //   win.SetWindowLong(hwnd, GWL_EXSTYLE,
        //       style | WS_EX_LAYERED | WS_EX_TRANSPARENT)
        if (method == "setClickThrough") {
          SetWindowLong(hwnd, GWL_EXSTYLE,
                        enabled
                            ? (exstyle | WS_EX_LAYERED | WS_EX_TRANSPARENT)
                            : (exstyle & ~(WS_EX_LAYERED | WS_EX_TRANSPARENT)));
          result->Success();

        // ── setFrameless ──────────────────────────────────────────────────
        // True frameless: no chrome, no DWM shadow, no colored Snap border.
        // Mirrors Wails: Frameless:true + DisableFramelessWindowDecorations:true
        } else if (method == "setFrameless") {
          ApplyFrameless(hwnd, enabled);
          result->Success();

        // ── setTransparent ────────────────────────────────────────────────
        // Extends the DWM glass frame to the full client area.
        // Mirrors Wails: BackgroundColour{A:0} + WindowIsTranslucent:true
        } else if (method == "setTransparent") {
          if (enabled) {
            SetWindowLong(hwnd, GWL_EXSTYLE, exstyle | WS_EX_LAYERED);
            MARGINS m = {-1, -1, -1, -1};
            DwmExtendFrameIntoClientArea(hwnd, &m);
          } else {
            SetWindowLong(hwnd, GWL_EXSTYLE, exstyle & ~WS_EX_LAYERED);
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

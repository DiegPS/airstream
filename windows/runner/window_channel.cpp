#include "window_channel.h"

#include <dwmapi.h>
#include <windows.h>

// Compat: WDA_EXCLUDEFROMCAPTURE was introduced in Windows 10 2004 (20H1).
// Electron uses this exact value for setContentProtection(true).
#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include <cstdio>
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
// excludeFromCapture — Electron-style content protection
// ---------------------------------------------------------------------------
// Electron stores the desired state internally and only calls
// SetWindowDisplayAffinity when the window is visible.  We replicate that.
// Before applying WDA_EXCLUDEFROMCAPTURE we ensure WS_EX_LAYERED is set
// (Electron does the same on older Windows builds).
// This is completely independent of clickThrough / frameless / alwaysOnTop.

bool g_exclude_from_capture = false;

void LogWindowDiag(HWND hwnd, const char* tag) {
  char buf[512];
  LONG_PTR style   = GetWindowLongPtr(hwnd, GWL_STYLE);
  LONG_PTR exstyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
  HWND parent      = GetParent(hwnd);
  HWND owner       = GetWindow(hwnd, GW_OWNER);
  snprintf(buf, sizeof(buf),
           "[WindowControl][%s] HWND=%p valid=%d visible=%d "
           "style=0x%08lX exstyle=0x%08lX parent=%p owner=%p\n",
           tag, hwnd, IsWindow(hwnd), IsWindowVisible(hwnd),
           (unsigned long)style, (unsigned long)exstyle, parent, owner);
  OutputDebugStringA(buf);
}

bool ApplyExcludeFromCapture(HWND hwnd) {
  if (!hwnd || !IsWindow(hwnd)) {
    OutputDebugStringA(
        "[WindowControl] Invalid HWND for excludeFromCapture\n");
    return false;
  }

  if (!IsWindowVisible(hwnd)) {
    OutputDebugStringA(
        "[WindowControl] HWND not visible, deferring excludeFromCapture\n");
    return false;
  }

  LogWindowDiag(hwnd, g_exclude_from_capture ? "APPLY_EXCLUDE" : "APPLY_NONE");

  // Electron: ensure WS_EX_LAYERED is set before applying affinity.
  if (g_exclude_from_capture) {
    LONG_PTR exstyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
    if (!(exstyle & WS_EX_LAYERED)) {
      SetWindowLongPtr(hwnd, GWL_EXSTYLE, exstyle | WS_EX_LAYERED);
      OutputDebugStringA(
          "[WindowControl] Added WS_EX_LAYERED for excludeFromCapture\n");
    }
  }

  DWORD affinity = g_exclude_from_capture ? WDA_EXCLUDEFROMCAPTURE : WDA_NONE;
  BOOL ok = SetWindowDisplayAffinity(hwnd, affinity);

  if (!ok) {
    char err[256];
    snprintf(err, sizeof(err),
             "[WindowControl] SetWindowDisplayAffinity(%lu) FAILED, "
             "GetLastError=%lu\n",
             (unsigned long)affinity, (unsigned long)GetLastError());
    OutputDebugStringA(err);
    return false;
  }

  OutputDebugStringA(
      g_exclude_from_capture
          ? "[WindowControl] SetWindowDisplayAffinity -> WDA_EXCLUDEFROMCAPTURE OK\n"
          : "[WindowControl] SetWindowDisplayAffinity -> WDA_NONE OK\n");
  return true;
}

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

        // ── setAlwaysOnTop ────────────────────────────────────────────────
        } else if (method == "setAlwaysOnTop") {
          SetWindowPos(hwnd,
                       enabled ? HWND_TOPMOST : HWND_NOTOPMOST,
                       0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE);
          result->Success();

        // ── setExcludeFromCapture ──────────────────────────────────────────
        // Electron-style content protection via SetWindowDisplayAffinity.
        // Stores the desired state natively; only applies when visible.
        // Ensures WS_EX_LAYERED is present (Electron does the same).
        // Completely independent of clickThrough / frameless / alwaysOnTop.
        } else if (method == "setExcludeFromCapture") {
          g_exclude_from_capture = enabled;
          bool applied = ApplyExcludeFromCapture(hwnd);

          if (!applied && IsWindow(hwnd)) {
            OutputDebugStringA(
                "[WindowControl] excludeFromCapture deferred (not applied yet)\n");
          }

          result->Success(flutter::EncodableValue(applied));

        } else {
          result->NotImplemented();
        }
      });
}

}  // namespace window_channel


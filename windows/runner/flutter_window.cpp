#include "flutter_window.h"

#include <optional>
#include <dwmapi.h>

#include <flutter/method_channel.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  // Registra el canal nativo para controlar la ventana desde Dart.
  RegisterWindowControlChannel();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// ---------------------------------------------------------------------------
// Window control platform channel
// ---------------------------------------------------------------------------
// Implementación idéntica a la versión Go/Wails:
//   SetClickThrough(true)  → WS_EX_LAYERED | WS_EX_TRANSPARENT
//   SetClickThrough(false) → quita ambos flags
//
// Añadimos además:
//   setTransparent   → DWM extend-frame-to-client-area (bg 100% transparente)
//   setAlwaysOnTop   → SetWindowPos HWND_TOPMOST / HWND_NOTOPMOST
// ---------------------------------------------------------------------------
void FlutterWindow::RegisterWindowControlChannel() {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.airchat/window_control",
          &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = GetHandle();

  channel->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {

        const std::string& method = call.method_name();

        // Extrae el argumento "enabled" del mapa de argumentos.
        bool enabled = false;
        if (const auto* args =
                std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto it = args->find(flutter::EncodableValue("enabled"));
          if (it != args->end()) {
            if (const auto* val = std::get_if<bool>(&it->second)) {
              enabled = *val;
            }
          }
        }

        LONG currStyle = GetWindowLong(hwnd, GWL_EXSTYLE);

        // ── setClickThrough ──────────────────────────────────────────────────
        // Exactamente igual que la versión Go:
        //   win.SetWindowLong(a.hwnd, win.GWL_EXSTYLE,
        //       currStyle | win.WS_EX_LAYERED | win.WS_EX_TRANSPARENT)
        if (method == "setClickThrough") {
          if (enabled) {
            SetWindowLong(hwnd, GWL_EXSTYLE,
                          currStyle | WS_EX_LAYERED | WS_EX_TRANSPARENT);
          } else {
            SetWindowLong(hwnd, GWL_EXSTYLE,
                          currStyle & ~(WS_EX_LAYERED | WS_EX_TRANSPARENT));
          }
          result->Success();

        // ── setTransparent ───────────────────────────────────────────────────
        // Extiende el frame DWM a toda el área cliente (fondo 100% transparente).
        // Igual a cómo Wails lo hace con BackgroundColour RGBA{A:0}.
        } else if (method == "setTransparent") {
          if (enabled) {
            SetWindowLong(hwnd, GWL_EXSTYLE, currStyle | WS_EX_LAYERED);
            MARGINS margins = {-1, -1, -1, -1};
            DwmExtendFrameIntoClientArea(hwnd, &margins);
          } else {
            SetWindowLong(hwnd, GWL_EXSTYLE, currStyle & ~WS_EX_LAYERED);
            MARGINS margins = {0, 0, 0, 0};
            DwmExtendFrameIntoClientArea(hwnd, &margins);
          }
          result->Success();

        // ── setAlwaysOnTop ───────────────────────────────────────────────────
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

  // Mantiene el canal vivo mientras la ventana exista.
  window_control_channel_ = std::move(channel);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

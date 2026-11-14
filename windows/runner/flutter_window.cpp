#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr UINT_PTR kDesktopAttachTimer = 1;

BOOL CALLBACK FindDesktopWorker(HWND top_window, LPARAM result) {
  HWND shell_view = FindWindowExW(top_window, nullptr, L"SHELLDLL_DefView",
                                 nullptr);
  if (shell_view == nullptr) {
    return TRUE;
  }

  *reinterpret_cast<HWND*>(result) =
      FindWindowExW(nullptr, top_window, L"WorkerW", nullptr);
  return FALSE;
}

HWND GetDesktopWorkerW() {
  HWND progman = FindWindowW(L"Progman", nullptr);
  if (progman == nullptr) {
    return nullptr;
  }

  DWORD_PTR result = 0;
  SendMessageTimeoutW(progman, 0x052C, 0xD, 0x1, SMTO_NORMAL, 1000, &result);

  HWND worker = nullptr;
  EnumWindows(FindDesktopWorker, reinterpret_cast<LPARAM>(&worker));
  return worker;
}

}  // namespace

void AttachToDesktop(HWND window) {
  HWND desktop_worker = GetDesktopWorkerW();
  if (desktop_worker == nullptr || window == nullptr ||
      GetParent(window) == desktop_worker) {
    return;
  }

  RECT bounds;
  GetWindowRect(window, &bounds);
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;

  SetParent(window, desktop_worker);

  LONG_PTR style = GetWindowLongPtrW(window, GWL_STYLE);
  style &= ~WS_POPUP;
  style &= ~WS_CAPTION;
  style &= ~WS_THICKFRAME;
  style |= WS_CHILD | WS_VISIBLE;
  SetWindowLongPtrW(window, GWL_STYLE, style);

  SetWindowPos(window, nullptr, 100, 100, width, height,
               SWP_NOZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
}

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
  HWND flutter_view = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(flutter_view);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // The clock is a desktop child window. Keep it visible if Windows or a
  // window manager sends a minimize command; shutdown messages still pass
  // through to the normal window procedure.
  if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_MINIMIZE) {
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    return 0;
  }

  if (message == WM_SIZE && wparam == SIZE_MINIMIZED) {
    ShowWindow(hwnd, SW_SHOWNOACTIVATE);
    return 0;
  }

  if (message == WM_TIMER && wparam == kDesktopAttachTimer) {
    AttachToDesktop(hwnd);
    return 0;
  }

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

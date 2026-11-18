#include <winsock2.h>
#include <ws2tcpip.h>

#include "monitor_bridge.h"

#include <iphlpapi.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <optional>
#include <utility>

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr wchar_t kMeterClass[] = L"RARNetCareMiniMeter";

std::string Utf8(const wchar_t* value) {
  const auto length = static_cast<int>(wcslen(value));
  if (length == 0) return {};
  const int size =
      WideCharToMultiByte(CP_UTF8, 0, value, length, nullptr, 0, nullptr, nullptr);
  if (size == 0) return {};
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, length, result.data(), size, nullptr,
                      nullptr);
  return result;
}

std::wstring Wide(const std::string& value) {
  const auto length = static_cast<int>(value.size());
  if (length == 0) return {};
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, value.data(), length, nullptr, 0);
  if (size == 0) return {};
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), length, result.data(), size);
  return result;
}

std::optional<EncodableList> ReadAdapters() {
  PMIB_IF_TABLE2 table = nullptr;
  if (GetIfTable2(&table) != NO_ERROR || !table) return std::nullopt;
  const std::unique_ptr<MIB_IF_TABLE2, decltype(&FreeMibTable)> storage(
      table, &FreeMibTable);
  EncodableList rows;
  for (ULONG i = 0; i < table->NumEntries; ++i) {
    const auto& row = table->Table[i];
    if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK ||
        row.InterfaceAndOperStatusFlags.FilterInterface) {
      continue;
    }
    wchar_t id[40] = {};
    if (StringFromGUID2(row.InterfaceGuid, id, ARRAYSIZE(id)) == 0) continue;
    rows.emplace_back(EncodableMap{
        {EncodableValue("id"), EncodableValue(Utf8(id))},
        {EncodableValue("name"), EncodableValue(Utf8(row.Alias))},
        {EncodableValue("description"), EncodableValue(Utf8(row.Description))},
        {EncodableValue("type"), EncodableValue(static_cast<int>(row.Type))},
        {EncodableValue("physical"),
         EncodableValue(row.InterfaceAndOperStatusFlags.HardwareInterface != 0)},
        {EncodableValue("up"),
         EncodableValue(row.OperStatus == IfOperStatusUp)},
        {EncodableValue("rx"), EncodableValue(static_cast<int64_t>(row.InOctets))},
        {EncodableValue("tx"), EncodableValue(static_cast<int64_t>(row.OutOctets))},
        {EncodableValue("link"),
         EncodableValue(static_cast<int64_t>(row.ReceiveLinkSpeed))},
    });
  }
  return rows;
}
}  // namespace

MonitorBridge::MonitorBridge(flutter::BinaryMessenger* messenger,
                             HWND main_window)
    : channel_(messenger, "rar_netcare/monitor",
               &flutter::StandardMethodCodec::GetInstance()),
      main_window_(main_window) {
  channel_.SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* arguments = call.arguments();
    if (call.method_name() == "adapters") {
      auto rows = ReadAdapters();
      if (rows) {
        result->Success(EncodableValue(std::move(*rows)));
      } else {
        result->Error("adapter_read_failed", "GetIfTable2 failed");
      }
    } else if (call.method_name() == "overlay") {
      const auto* visible = arguments ? std::get_if<bool>(arguments) : nullptr;
      if (!visible) {
        result->Error("invalid_arguments");
      } else if (*visible && !ShowOverlay()) {
        result->Error("overlay_failed");
      } else {
        if (!*visible && meter_) ShowWindow(meter_, SW_HIDE);
        result->Success();
      }
    } else if (call.method_name() == "style") {
      const auto* fields = arguments ? std::get_if<EncodableList>(arguments) : nullptr;
      if (!fields || fields->size() != 4) { result->Error("invalid_style"); return; }
      size_ = std::clamp(std::get<int32_t>((*fields)[0]), 10, 24);
      font_ = Wide(std::get<std::string>((*fields)[1]));
      bold_ = std::get<bool>((*fields)[2]);
      amber_ = std::get<std::string>((*fields)[3]) == "Amber";
      if (meter_) {
        const int dpi = static_cast<int>(GetDpiForWindow(meter_));
        SetWindowPos(meter_, nullptr, 0, 0, MulDiv(90 + size_ * 6,dpi,96), MulDiv(18 + size_*3,dpi,96),SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
        InvalidateRect(meter_, nullptr, FALSE);
      }
      result->Success();
    } else if (call.method_name() == "display") {
      const auto* values =
          arguments ? std::get_if<EncodableList>(arguments) : nullptr;
      if (!values || values->size() != 2 ||
          !std::holds_alternative<std::string>((*values)[0]) ||
          !std::holds_alternative<std::string>((*values)[1])) {
        result->Error("invalid_arguments");
        return;
      }
      const auto download = Wide(std::get<std::string>((*values)[0]));
      const auto upload = Wide(std::get<std::string>((*values)[1]));
      if (download != download_ || upload != upload_) {
        download_ = download;
        upload_ = upload;
        if (meter_) InvalidateRect(meter_, nullptr, FALSE);
      }
      result->Success();
    } else {
      result->NotImplemented();
    }
  });
}

MonitorBridge::~MonitorBridge() {
  channel_.SetMethodCallHandler(nullptr);
  if (meter_) DestroyWindow(meter_);
}

bool MonitorBridge::ShowOverlay() {
  if (!meter_) {
    const HINSTANCE instance = GetModuleHandle(nullptr);
    WNDCLASS wc{};
    wc.hInstance = instance;
    wc.hCursor = LoadCursor(nullptr, IDC_SIZEALL);
    wc.lpfnWndProc = MeterProc;
    wc.lpszClassName = kMeterClass;
    if (!RegisterClass(&wc) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
      return false;
    }
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (!GetMonitorInfo(MonitorFromWindow(main_window_, MONITOR_DEFAULTTONEAREST),
                        &monitor)) {
      return false;
    }
    const auto dpi = static_cast<int>(GetDpiForWindow(main_window_));
    const int width = MulDiv(164, dpi, 96);
    const int height = MulDiv(56, dpi, 96);
    const int margin = MulDiv(16, dpi, 96);
    POINT position{monitor.rcWork.right - width - margin, monitor.rcWork.bottom - height - margin};
    POINT saved{};
    DWORD count = sizeof(saved);
    if (RegGetValueW(HKEY_CURRENT_USER, L"Software\\RAR NetCare", L"MeterPosition", RRF_RT_REG_BINARY, nullptr, &saved, &count) == ERROR_SUCCESS && count == sizeof(saved) && MonitorFromPoint(saved, MONITOR_DEFAULTTONULL)) position = saved;
    meter_ = CreateWindowEx(WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                            kMeterClass, L"RAR NetCare mini meter", WS_POPUP,
                            position.x, position.y, width,
                            height, nullptr, nullptr, instance, this);
    if (!meter_) return false;
  }
  ShowWindow(meter_, SW_SHOWNOACTIVATE);
  return true;
}

LRESULT CALLBACK MonitorBridge::MeterProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<const CREATESTRUCT*>(lparam);
    SetWindowLongPtr(hwnd, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* self =
      reinterpret_cast<MonitorBridge*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (!self) return DefWindowProc(hwnd, message, wparam, lparam);
  switch (message) {
    case WM_EXITSIZEMOVE: {
      RECT pos{};
      if (GetWindowRect(hwnd, &pos)) {
        POINT point{pos.left, pos.top};
        RegSetKeyValueW(HKEY_CURRENT_USER, L"Software\\RAR NetCare", L"MeterPosition", REG_BINARY, &point, sizeof(point));
      }
      return 0;
    }
    case WM_NCHITTEST:
      return HTCAPTION;
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_NCRBUTTONUP:
      ShowWindow(self->main_window_, SW_RESTORE);
      SetForegroundWindow(self->main_window_);
      return 0;
    case WM_DPICHANGED: {
      const auto* suggested = reinterpret_cast<const RECT*>(lparam);
      SetWindowPos(hwnd, nullptr, suggested->left, suggested->top,
                   suggested->right - suggested->left,
                   suggested->bottom - suggested->top,
                   SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
    case WM_PAINT: {
      PAINTSTRUCT paint{};
      HDC dc = BeginPaint(hwnd, &paint);
      RECT bounds{};
      GetClientRect(hwnd, &bounds);
      HBRUSH background = CreateSolidBrush(RGB(10, 28, 43));
      FillRect(dc, &bounds, background);
      DeleteObject(background);
      const int dpi = static_cast<int>(GetDpiForWindow(hwnd));
      HFONT font = CreateFont(-MulDiv(self->size_, dpi, 96), 0, 0, 0, self->bold_ ? FW_BOLD : FW_NORMAL,
                              FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                              OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                              CLEARTYPE_QUALITY, DEFAULT_PITCH, self->font_.c_str());
      HGDIOBJ previous = font ? SelectObject(dc, font) : nullptr;
      SetBkMode(dc, TRANSPARENT);
      const auto draw = [dc, dpi, &bounds, self](const std::wstring& text, int top,
                                           COLORREF color) {
        RECT line{MulDiv(12, dpi, 96), MulDiv(top, dpi, 96), bounds.right,
                  MulDiv(top + self->size_ + 8, dpi, 96)};
        SetTextColor(dc, color);
        DrawText(dc, text.c_str(), -1, &line, DT_LEFT | DT_SINGLELINE | DT_NOPREFIX);
      };
      draw(L"\u2193   " + self->download_, 6, self->amber_ ? RGB(255, 206, 95) : RGB(109, 193, 255));
      draw(L"\u2191   " + self->upload_, 12 + self->size_, self->amber_ ? RGB(255, 160, 110) : RGB(69, 228, 191));
      if (font) {
        SelectObject(dc, previous);
        DeleteObject(font);
      }
      EndPaint(hwnd, &paint);
      return 0;
    }
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

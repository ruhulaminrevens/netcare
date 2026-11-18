#ifndef RUNNER_MONITOR_BRIDGE_H_
#define RUNNER_MONITOR_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <string>

class MonitorBridge {
 public:
  MonitorBridge(flutter::BinaryMessenger* messenger, HWND main_window);
  ~MonitorBridge();

 private:
  bool ShowOverlay();
  static LRESULT CALLBACK MeterProc(HWND hwnd, UINT message, WPARAM wparam,
                                    LPARAM lparam);

  flutter::MethodChannel<flutter::EncodableValue> channel_;
  int size_ = 15;
  bool bold_ = false;
  bool amber_ = false;
  std::wstring font_ = L"Segoe UI";
  HWND main_window_;
  HWND meter_ = nullptr;
  std::wstring download_ = L"\u2014";
  std::wstring upload_ = L"\u2014";
};

#endif  // RUNNER_MONITOR_BRIDGE_H_

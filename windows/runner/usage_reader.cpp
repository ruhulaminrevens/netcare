// Runs outside the UI thread so slow Windows accounting queries stay cancellable.
#include <winrt/Windows.Data.Json.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Networking.Connectivity.h>
#include <algorithm>
#include <chrono>
#include <iostream>
#include <string>

using namespace winrt;
using namespace Windows::Data::Json;
using namespace Windows::Networking::Connectivity;

static auto instant(long long ms) {
  return clock::from_sys(std::chrono::system_clock::time_point(std::chrono::milliseconds(ms)));
}

static JsonObject counts(hstring const& label, uint64_t rx, uint64_t tx) {
  JsonObject row;
  row.Insert(L"label", JsonValue::CreateStringValue(label));
  row.Insert(L"rx", JsonValue::CreateNumberValue(static_cast<double>(rx)));
  row.Insert(L"tx", JsonValue::CreateNumberValue(static_cast<double>(tx)));
  return row;
}

int wmain(int argc, wchar_t** argv) {
  try {
    init_apartment(apartment_type::multi_threaded);
    JsonArray result;
    auto profiles = NetworkInformation::GetConnectionProfiles();
    for (auto const& profile : profiles) {
      auto adapter = profile.NetworkAdapter();
      if (!adapter) continue;
      auto id = to_hstring(adapter.NetworkAdapterId()) + L"|" + profile.ProfileName();
      if (argc == 1) {
        JsonObject row;
        row.Insert(L"id", JsonValue::CreateStringValue(id));
        row.Insert(L"label", JsonValue::CreateStringValue(profile.ProfileName()));
        result.Append(row);
        continue;
      }
      if (argc < 5 || id != argv[1]) continue;
      NetworkUsageStates states{TriStates::DoNotCare, TriStates::DoNotCare};
      if (std::wstring(argv[2]) == L"apps") {
        auto entries = profile.GetAttributedNetworkUsageAsync(
            instant(std::stoll(argv[3])), instant(std::stoll(argv[argc-1])), states).get();
        for (auto const& app : entries) {
          auto label = app.AttributionName();
          if (label.empty()) label = app.AttributionId();
          result.Append(counts(label, app.BytesReceived(), app.BytesSent()));
        }
      } else {
        for (int i = 3; i + 1 < argc; ++i) {
          auto entries = profile.GetNetworkUsageAsync(instant(std::stoll(argv[i])),
              instant(std::stoll(argv[i+1])), DataUsageGranularity::Total, states).get();
          uint64_t rx = 0, tx = 0;
          for (auto const& entry : entries) { rx += entry.BytesReceived(); tx += entry.BytesSent(); }
          result.Append(counts(argv[i], rx, tx));
        }
      }
      break;
    }
    std::cout << to_string(result.Stringify());
    return 0;
  } catch (hresult_error const& error) {
    std::cerr << to_string(error.message());
    return 1;
  } catch (std::exception const& error) {
    std::cerr << error.what();
    return 2;
  }
}

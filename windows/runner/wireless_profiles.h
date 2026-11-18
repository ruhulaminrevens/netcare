#pragma once
#include <windows.h>
#include <wlanapi.h>
#include <winrt/Windows.Data.Json.h>
#include <memory>
#include <string>

namespace wireless {
struct Client {
  HANDLE handle{};
  Client() {
    DWORD version{};
    winrt::check_win32(WlanOpenHandle(2, nullptr, &version, &handle));
  }
  ~Client() { WlanCloseHandle(handle, nullptr); }
};

inline std::wstring element(std::wstring const& xml, std::wstring const& name) {
  const auto tag = L"<" + name + L">";
  const auto begin = xml.find(tag);
  if (begin == std::wstring::npos) return {};
  const auto start = begin + tag.size();
  const auto end = xml.find(L"</" + name + L">", start);
  return end == std::wstring::npos ? L"" : xml.substr(start, end - start);
}

inline auto list() {
  using namespace winrt::Windows::Data::Json;
  Client client;
  WLAN_INTERFACE_INFO_LIST* interfaces{};
  winrt::check_win32(WlanEnumInterfaces(client.handle, nullptr, &interfaces));
  const std::unique_ptr<WLAN_INTERFACE_INFO_LIST, decltype(&WlanFreeMemory)> owner(interfaces,WlanFreeMemory);
  JsonArray rows;
  for(DWORD i=0;i<interfaces->dwNumberOfItems;i++) {
    const auto& nic=interfaces->InterfaceInfo[i];
    WLAN_PROFILE_INFO_LIST* profiles{};
    winrt::check_win32(WlanGetProfileList(client.handle,&nic.InterfaceGuid,nullptr,&profiles));
    const std::unique_ptr<WLAN_PROFILE_INFO_LIST,decltype(&WlanFreeMemory)> owned(profiles,WlanFreeMemory);
    std::wstring current;
    DWORD bytes{};
    WLAN_CONNECTION_ATTRIBUTES* active{};
    if(WlanQueryInterface(client.handle,&nic.InterfaceGuid,wlan_intf_opcode_current_connection,nullptr,&bytes,reinterpret_cast<void**>(&active),nullptr)==ERROR_SUCCESS){
      current=active->strProfileName;WlanFreeMemory(active);
    }
    for(DWORD j=0;j<profiles->dwNumberOfItems;j++){
      const auto name=profiles->ProfileInfo[j].strProfileName;
      JsonObject row;
      row.Insert(L"Name",JsonValue::CreateStringValue(name));
      row.Insert(L"Interface",JsonValue::CreateStringValue(nic.strInterfaceDescription));
      wchar_t id[40]{};
      if(!StringFromGUID2(nic.InterfaceGuid,id,40))continue;
      row.Insert(L"InterfaceId",JsonValue::CreateStringValue(id));
      row.Insert(L"Status",JsonValue::CreateStringValue(current==name?L"Connected":L"Saved"));
      wchar_t* xml{}; DWORD flags=0,access=0;
      if(WlanGetProfile(client.handle,&nic.InterfaceGuid,name,nullptr,&xml,&flags,&access)==ERROR_SUCCESS){
        const std::unique_ptr<wchar_t,decltype(&WlanFreeMemory)> doc(xml,WlanFreeMemory);
        row.Insert(L"Authentication",JsonValue::CreateStringValue(element(xml,L"authentication")));
        row.Insert(L"Encryption",JsonValue::CreateStringValue(element(xml,L"encryption")));
      }
      rows.Append(row);
    }
  }
  return rows;
}
inline void forget(wchar_t const* id, wchar_t const* name) {
  Client client;
  GUID guid{};
  winrt::check_hresult(CLSIDFromString(id,&guid));
  winrt::check_win32(WlanDeleteProfile(client.handle,&guid,name,nullptr));
}
}

// Copyright 2022. Chema Molins.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include "include/flutter_downloader_fde/flutter_downloader_plugin.h"

#include <windows.h>

#include <VersionHelpers.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <sstream>
#include <codecvt>

namespace {

  using flutter::EncodableMap;
  using flutter::EncodableValue;

  class FlutterDownloaderPlugin : public flutter::Plugin {

  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);

    // Creates a plugin that communicates on the given channel.
    FlutterDownloaderPlugin(
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);


    virtual ~FlutterDownloaderPlugin();

  private:

    // Called when a method is called on plugin channel;
    void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

    // The MethodChannel used for communication with the Flutter engine.
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  };

  // static
  void FlutterDownloaderPlugin::RegisterWithRegistrar(flutter::PluginRegistrar* registrar) {

    auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "vn.hunghd/downloader", &flutter::StandardMethodCodec::GetInstance());

    auto* channel_pointer = channel.get();

    auto plugin = std::make_unique<FlutterDownloaderPlugin>(std::move(channel));

    channel_pointer->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
      plugin_pointer->HandleMethodCall(call, std::move(result));
    });

    registrar->AddPlugin(std::move(plugin));
  }

  FlutterDownloaderPlugin::FlutterDownloaderPlugin(
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : channel_(std::move(channel)) {}

  FlutterDownloaderPlugin::~FlutterDownloaderPlugin() {}

  void FlutterDownloaderPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {

    if (method_call.method_name().compare("initialize") == 0) {
      result->Success();
    }
    else if (method_call.method_name().compare("registerCallback") == 0) {
      result->Success();
    }
    else if (method_call.method_name().compare("enqueue") == 0) {
      result->Success();
    }
    else if (method_call.method_name().compare("remove") == 0) {
      result->Success();
    }
    else if (method_call.method_name().compare("open") == 0) {

      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {

        // The Flutter_Downloader plugin uses "taskId" to find the task and its corresponding file
        // In windows, I have not implemented the task architecture so I will use the "TaskId" coming form the
        // channel as the file path or full filename
        auto path_it = arguments->find(flutter::EncodableValue("task_id"));

        if (path_it != arguments->end()) {
          // path comes as a utf8 string
          std::string u8Path = std::get<std::string>(path_it->second);

          // utf8 to wide
          std::wstring_convert<std::codecvt_utf8<wchar_t>, wchar_t> conv1;
          std::wstring wPath = conv1.from_bytes(u8Path);

          ShellExecute(0, 0, wPath.c_str(), 0, 0, SW_SHOWNORMAL);
        }
      }
      result->Success();
    }
    else {
      result->NotImplemented();
    }
  }

}  // namespace

void FlutterDownloaderPluginRegisterWithRegistrar(
  FlutterDesktopPluginRegistrarRef registrar) {
  // The plugin registrar owns the plugin, registered callbacks, etc., so must
  // remain valid for the life of the application.
  static auto* plugin_registrar = new flutter::PluginRegistrar(registrar);

  FlutterDownloaderPlugin::RegisterWithRegistrar(plugin_registrar);
}

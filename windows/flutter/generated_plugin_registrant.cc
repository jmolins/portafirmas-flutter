//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <digital_certificates/digital_certificates_plugin.h>
#include <flutter_downloader_fde/flutter_downloader_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  DigitalCertificatesPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DigitalCertificatesPlugin"));
  FlutterDownloaderPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterDownloaderPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}

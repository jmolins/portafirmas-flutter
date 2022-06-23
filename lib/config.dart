/*
    Copyright 2022. Chema Molins.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        https://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

Config? config;

class Config {
  static const String certificateSubjectKey = 'certificate_subject_key';
  static const String certificateIssuerKey = 'certificate_issuer_key';
  static const String certificateSerialKey = 'certificate_serial_key';

  static const String serverNameKey = 'server_name_key';
  static const String serverUrlKey = 'server_url_key';

  // Portafirmas PRO
  static const String serverAgeName = 'Portafirmas General AGE';
  static const String serverAgeUrl = 'https://servicios.seap.minhap.es/pfmovil/signfolder';
  static const String serverRedsaraName = 'Portafirmas RedSARA';
  static const String serverRedsaraUrl = 'https://portafirmas.redsara.es/pfmovil/pf';

  // Portafirmas PRE
  static const String serverAgepreName = 'Portafirmas AGE PRE';
  static const String serverAgepreUrl =
      'https://preappjava.seap.minhap.es/afirma-signfolder-proxy/signfolder';
  static const String serveerRedsarapreName = 'Portafirmas RedSARA PRE';
  static const String serverRedsarapreUrl = 'https://pre-portafirmas.redsara.es/pfmovil/pf';

  late SharedPreferences prefs;

  late String serverURL;
  late String serverName;

  bool storagePermissionReady = false;
  String? _applicationPath;
  String? _tempStoragePath;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    serverName = prefs.getString(Config.serverNameKey) ?? Config.serverAgeName;
    serverURL = prefs.getString(Config.serverUrlKey) ?? Config.serverAgeUrl;
    _applicationPath = await applicationPath;
    _tempStoragePath = await tempStoragePath;
  }

  Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  Future<String> get applicationPath async {
    if (_applicationPath != null) return _applicationPath!;

    final directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    String applicationPath = directory!.path;
    return applicationPath;
  }

  Future<String> get tempStoragePath async {
    if (_tempStoragePath != null) return _tempStoragePath!;

    String tempStoragePath = '${await applicationPath}/PortafirmasTemp';

    final dir = Directory(tempStoragePath);
    bool hasExisted = await dir.exists();
    // If it exists, delete its contents
    if (hasExisted) await dir.delete(recursive: true);
    // then create it
    await dir.create();

    return tempStoragePath;
  }
}

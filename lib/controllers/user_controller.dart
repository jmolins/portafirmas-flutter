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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:digital_certificates/digital_certificates.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/api/login_token_response_parser.dart';
import 'package:portafirmas/api/login_validation_response_parser.dart';
import 'package:portafirmas/api/logout_response_parser.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/validation_login_result.dart';

part 'user_controller.g.dart';

enum AuthState { loggedIn, loggedOut, checking, unknown }

class UserController extends _UserController with _$UserController {
  UserController(Api api) : super(api);
}

/// The majority of methods set the user in the controller to be widely available
/// in the application.
/// This class extends ChangeNotifier and notifies listeners when the user changes.
/// Other stores can listen to this class if the want to react to user changes.
abstract class _UserController extends ChangeNotifier with Store {
  final Api api;

  static const MethodChannel methodChannel = MethodChannel('digital_certificates');

  @observable
  ValidationLoginResult? loginResult;

  @observable
  RequestResult? logoutResult;

  @observable
  ObservableList<Map<String, String>>? certificates;

  @observable
  ObservableList<String>? files;

  _UserController(this.api);

  @action
  Future<void> login() async {
    try {
      if (api.certB64 == null || api.dni == null) {
        if (Platform.isAndroid) {
          // Select certificate from system
          api.certB64 = await DigitalCertificates.selectCertificate();
          // We don't care if we are not able to get the subject. Just
          // ignore the exception
          try {
            String? subject = await DigitalCertificates.certificateSubject();
            if (subject != null) {
              await config!.prefs.setString(Config.certificateSubjectKey, subject);
            }
            debugPrint('Subject in Flutter: $subject');
            // ignore: empty_catches
          } on PlatformException {}
        } else if (Platform.isIOS) {
          Map<String, String?> certificate = {};
          certificate['subject'] = config!.prefs.getString(Config.certificateSubjectKey);
          certificate['issuer'] = config!.prefs.getString(Config.certificateIssuerKey);
          certificate['serial'] = config!.prefs.getString(Config.certificateSerialKey);
          if (certificate['subject'] == null || certificate['issuer'] == null) {
            debugPrint('Certificado no seleccionado');
            loginResult =
                ValidationLoginResult(errorMsg: 'Certificado no seleccionado', statusOk: false);
          }
          api.certB64 = await methodChannel.invokeMethod('selectCertificate', certificate);
        } else if (Platform.isWindows) {
          api.certB64 = await DigitalCertificates.selectCertificate();
          try {
            String? subject = await DigitalCertificates.certificateSubject();
            if (subject != null) {
              await config!.prefs.setString(Config.certificateSubjectKey, subject);
            }
            debugPrint('Subject in Flutter: $subject');
            // ignore: empty_catches
          } on PlatformException {}
        }
        assert(api.certB64 != null, 'Certificate is null');
        debugPrint('Certificate loaded');
        debugPrint('${api.certB64}');
      }
      // Signal that the certificate has been loaded
      loginResult = ValidationLoginResult(errorMsg: 'certificate_loaded', statusOk: true);

      // Request challenge token from server
      String document = await api.loginRequest();
      RequestResult result = LoginTokenResponseParser.parse(document);

      // Sign the token and send it to server to request login
      Uint8List? pkcs1;
      if (Platform.isIOS) {
        pkcs1 = await methodChannel.invokeMethod('signData', {'data': base64Decode(result.id!)});
      } else {
        pkcs1 = await DigitalCertificates.signData(base64Decode(result.id!), 'SHA256withRSA');
      }
      debugPrint('Returned: $pkcs1');
      document = await api.login(base64Encode(pkcs1!));
      ValidationLoginResult tempLoginResult = LoginValidationResponseParser.parse(document);
      if (tempLoginResult.statusOk) {
        api.dni = tempLoginResult.dni;
        tempLoginResult.certificateB64 = api.certB64;
        loginResult = tempLoginResult;
      }
      // If the certificate is not registered in the portafirmas, the error
      // "result.data" will contain the following text:
      // "El certificado no es valido"
      else {
        loginResult = ValidationLoginResult(errorMsg: tempLoginResult.errorMsg, statusOk: false);
      }
    } on PlatformException catch (e) {
      var err = 'Error al conectar: ${e.message}';
      debugPrint(err);
      loginResult = ValidationLoginResult(errorMsg: err, statusOk: false);
    } on NetworkException {
      debugPrint('Error de red');
      loginResult = ValidationLoginResult(errorMsg: 'Error de red', statusOk: false);
    }
  }

  @action
  Future<void> logout() async {
    try {
      String document = await api.logout();
      RequestResult result = LogoutResponseParser.parse(document);
      if (result.statusOk) {
        logoutResult = result;
      } else {
        logoutResult = RequestResult(errorMsg: 'Error indefinido', statusOk: false);
      }
    } on NetworkException {
      debugPrint('Error de red');
      logoutResult = RequestResult(errorMsg: 'Error de red', statusOk: false);
    } on UnauthorizedException {
      debugPrint('No autorizado. Logout directo.');
      logoutResult = RequestResult(errorMsg: 'No autorizado', statusOk: true);
    }
    // If you try to logout when you are already logged out, the following
    // error message is received
    //  <err cd="ERR-11">Error en la autenticacion de la peticion</err>
    on ErrorMessageException {
      debugPrint('Mensaje de error. Ya desconectado.');
      logoutResult = RequestResult(errorMsg: 'Ya desconectado', statusOk: true);
    }
  }

  @action
  Future<String?> selectIosCertificate(Map<String, String> certificate) async {
    String? result;
    try {
      result = await methodChannel.invokeMethod('selectCertificate', certificate);
      debugPrint('Result: $result');
    } on PlatformException {
      debugPrint('Error al seleccionar el certificado');
      result = 'Error al seleccionar el certificado';
    }
    return result;
  }

  @action
  Future<void> getCertificateFiles() async {
    try {
      List<String>? certificatefiles = await methodChannel.invokeListMethod('getCertificateFiles');
      debugPrint('Certificate files from iOS system $files');
      files = certificatefiles != null ? [...certificatefiles].asObservable() : null;
    } on PlatformException {
      debugPrint('Error al conectar');
      files = null;
    }
  }

  @action
  Future<void> getAddedIosCertificates() async {
    try {
      List<dynamic>? addedCertificates =
          await methodChannel.invokeMethod('getAddedCertificatesInfo');
      List<Map<String, String>>? typedCertificates = addedCertificates
          ?.cast<Map<dynamic, dynamic>>()
          .map((certificate) => certificate.cast<String, String>())
          .toList();
      certificates = typedCertificates != null ? [...typedCertificates].asObservable() : null;
      debugPrint('Available certificates $typedCertificates');
    } on PlatformException {
      debugPrint('Error al conectar');
      certificates = null;
    }
  }

  /*
  Returns null if successful, the error message otherwise.
   */
  @action
  Future<String?> loadIosCertificate(String filename, String password) async {
    String? result;
    try {
      result = await methodChannel
          .invokeMethod('loadCertificate', {'fileName': filename, 'pass': password});
      debugPrint('Result: $result');
    } on PlatformException {
      debugPrint('Error al registrar el certificado');
      result = 'Error al registrar el certificado';
    }
    return result;
  }

  /*
  Returns null if successful, the error message otherwise.
   */
  @action
  Future<String?> deleteIosCertificate(Map<String, String> certificate) async {
    String? result;
    try {
      result = await methodChannel.invokeMethod('deleteCertificate', certificate);
    } on PlatformException {
      debugPrint('Error al eliminar el certificado');
      result = 'Error al eliminar el certificado';
    }
    return result;
  }
}

/// Prints the Base64 certificate in console
/// Calling print() or debugPrint() doesn't print the whole string
void printCertificate(String certBase64) {
  int len = certBase64.length;
  int startIndex = 0;
  while (startIndex < len) {
    int endIndex = startIndex + 250;
    if (endIndex >= len) endIndex = len - 1;
    debugPrint(certBase64.substring(startIndex, endIndex));
    startIndex += 250;
  }
}

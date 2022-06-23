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

import 'package:portafirmas/user/configuration_role.dart';

/// Resultado final del proceso de login.
class ValidationLoginResult {
  /// Resultado de la operación sobre la petición.
  bool statusOk;

  /// DNI del usuario que accede a la aplicación.
  String? dni;

  /// Alias del certificado seleccionado por el usuario. Solo se usara cuando se utiliza
  /// certificado local.
  String? certAlias;

  /// Certificado local usado para auteticar al usuario.
  String? certificateB64;

  /// Mensaje de error de la operación
  String? errorMsg;

  /// Lista de roles asociados al usuario.
  List<ConfigurationRole>? roles;

  /// Resultado de una petici&oacute;n login.
  /// @param ok Resultado del login.
  ValidationLoginResult({this.statusOk = true, this.errorMsg});
}

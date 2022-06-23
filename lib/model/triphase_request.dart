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

import 'package:portafirmas/model/triphase_sign_request_document.dart';

/// Petición de fase de firma de documentos.
class TriphaseRequest {
  /// Referencia de la petición.
  final String _ref;

  /// Resultado de la petición de la petición.
  bool _statusOk = true;

  /// Listado de documentos de la petición que se desean firmar.
  List<TriphaseSignRequestDocument>? _requestDocuments;

  /// Resultado de la petición de la petición.
  String? _exception;

  /// Construye un objeto de petición de prefirma o postfirma de documentos.
  TriphaseRequest(this._ref, this._requestDocuments);

  /// Construye un objeto de petición de firma de documentos.
  TriphaseRequest.withStatus(this._ref, this._requestDocuments, this._statusOk);

  /// Construye un objeto de petición de firma de documentos.
  TriphaseRequest.withException(this._ref, this._statusOk, this._exception) {
    _requestDocuments = null;
  }

  /// Recupera la referencia de la petición firma de documentos.
  String get ref => _ref;

  /// Indica si el estado de la petición es correcto.
  bool get isStatusOk => _statusOk;

  /// Establece el estado actual de la petición.
  set statusOk(final bool ok) => _statusOk = ok;

  /// Listado de peticiones de documentos para los que se desea la firma en multiples fases.
  List<TriphaseSignRequestDocument>? get requestDocuments => _requestDocuments;

  /// En caso de error, recupera la traza de la excepción que lo provocó
  String? getException() => _exception;
}

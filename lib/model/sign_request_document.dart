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

import 'package:portafirmas/model/request_document.dart';

/// Información de un documento de una solicitud de firma.
class SignRequestDocument extends RequestDocument {
  static const String cryptoOperationSign = 'sign';
  static const String cryptoOperationCosign = 'cosign';
  static const String cryptoOperationCountersign = 'countersign';

  /// Operación que se debe realizar sobre el documento (sign, cosign o countersign).
  final String? _cryptoOperation;

  /// Formato de firma a aplicar
  final String _signFormat;

  /// Formato de firma a aplicar
  final String _messageDigestAlgorithm;

  /// Par&aacute;metros de firma conforme a las especificaciones de los extraParams de @firma.
  final String? _params;

  /// Crea un documento englobado en una petición de firma/multifirma.
  SignRequestDocument(final String id, final String name, final int? size, final String mimeType,
      this._signFormat, this._messageDigestAlgorithm, this._params, this._cryptoOperation)
      : super(id, name, size, mimeType);

  /// Recupera la operación que debe realizarse sobre el documento (firma, cofirma, contrafirma de hojas o contrafirma de arbol).
  String? get cryptoOperation => _cryptoOperation;

  /// Recupera el formato de firma que se le debe aplicar al documento.
  String get signFormat => _signFormat;

  /// Recupera el algoritmo de huella digital asociado al algoritmo de firma que se desea utilizar.
  String get messageDigestAlgorithm => _messageDigestAlgorithm;

  /// Recupera los par&aacute;metros de configuración para la firma
  /// conforme al formato de extraParams de @firma.
  String? get params => _params;

  @override
  String toString() {
    return name;
  }
}

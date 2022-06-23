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

/// Datos temporales de un documento para su firma en tres fases
/// @author Carlos Gamuci Mill&aacute;n
import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';

class TriphaseSignRequestDocument {
  static const String cryptoOperationSign = 'sign';
  static const String cryptoOperationCosign = 'cosign';
  static const String cryptoOperationCounterSign = 'countersign';

  static const String defaultAlgorithm = 'SHA-512';

  static const String defaultCryptoOperation = 'sign';

  /// Identificador del documento.
  String? _id;

  /// Operación que se debe realizar sobre el documento (sign, cosign o countersign).
  String? _cryptoOperation;

  /// Formato de firma electrónica que se desea utilizar.
  String? _signatureFormat;

  /// Propiedades de configuracion de la firma codificadas en Base64.
  String? _params;

  /// Atributos de configuracion trifasica de la firma.
  TriphaseConfigData? partialResult;

  /// Algoritmo de firma.
  String? _algorithm;

  /// Construye un objeto petición de prefirma de un documento.
  TriphaseSignRequestDocument.withDefault(
    String? id,
    String? signatureFormat,
    String? messageDigestAlgorithm,
    String? params,
  ) {
    TriphaseSignRequestDocument(
      id,
      defaultCryptoOperation,
      signatureFormat,
      messageDigestAlgorithm,
      params,
      null,
    );
  }

  /// Construye un objeto petición de postfirma de un documento.
  TriphaseSignRequestDocument(this._id, this._cryptoOperation, this._signatureFormat,
      String? messageDigestAlgorithm, this._params, this.partialResult) {
    _algorithm = messageDigestAlgorithm ?? defaultAlgorithm;
  }

  /// Recupera el identificador del documento.
  String? get id => _id;

  /// Recupera el identificador de la operación a realizar.
  String? get cryptoOperation => _cryptoOperation;

  /// Recupera el formato de firma.
  String? get signatureFormat => _signatureFormat;

  /// Recupera el algoritmo de huella digital de la operación de firma.
  String? get messageDigestAlgorithm => _algorithm;

  /// Recupera las propiedades de configuración para la firma.
  String? get params => _params;
}

/// Clase que almacena los resultados parciales de la firma trifásica.
class TriphaseConfigData extends DelegatingMap<String, String> {
  static const String nodePart1 = "<p n='";
  static const String nodePart2 = "'>";
  static const String nodePart3 = '</p>';

  static const String paramPre = 'PRE';
  static const String paramNeedPre = 'NEED_PRE';
  static const String paramNeedData = 'NEED_DATA';
  static const String paramPkcs1 = 'PK1';

  TriphaseConfigData() : super({});

  /// Obtiene la prefirma del documento.
  Uint8List getPreSign() {
    return base64.decode(this[paramPre]!);
  }

  /// Indica si el proceso necesita la prefirma para realizar la postfirma.
  bool needsPreSign() {
    return containsKey(paramNeedPre) && this[paramNeedPre]!.toLowerCase() == 'true' ? true : false;
  }

  /// Indica si el proceso necesita los datos para realizar la postfirma.
  bool needsData() {
    String? needData = this[paramNeedData];
    needData ??= 'true';
    return needData.toLowerCase() == 'true' ? true : false;
  }

  /// Elimina la prefirma de entre los datos de la operación.
  void removePreSign() {
    remove(paramPre);
  }

  /// Obtiene la firma PKCS#1 de la firma indicada.
  Uint8List getPk1() {
    return base64.decode(this[paramPkcs1]!);
  }

  /// Almacena la firma PKCS#1.
  void setPk1(final Uint8List pkcs1) {
    this[paramPkcs1] = base64.encode(pkcs1);
  }

  /// Devuelve la configuración a modo de listado XML.
  String toXMLParamList() {
    final StringBuffer builder = StringBuffer();
    forEach((key, value) {
      builder
        ..write(nodePart1)
        ..write(key)
        ..write(nodePart2)
        ..write(value)
        ..write(nodePart3);
    });
    return builder.toString();
  }
}

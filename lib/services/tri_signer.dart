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

import 'dart:async';
import 'dart:io' show Platform;

import 'package:digital_certificates/digital_certificates.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/api/postsign_response_parser.dart';
import 'package:portafirmas/api/presign_response_parser.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/triphase_request.dart';
import 'package:portafirmas/model/triphase_sign_request_document.dart';

/// Firmador trifásico.
class TriSigner {
  static const MethodChannel methodChannel = MethodChannel('digital_certificates');

  static Future<RequestResult> sign(final SignRequest request, final Api api) async {
    try {
      return await doSign(request, api);
    }
    // includes ErrorMessageException, NetworkException and UnauthorizedException
    // In this case whatever the exception we just fail on the specific request
    // without providing a general connection or authorization error
    catch (e) {
      debugPrint('TriSigner.sign() Error durante la operacion de firma: ${e.toString()}');
      String error = 'Error de firma';
      if (e is NetworkException) {
        error = 'Error de red';
      }
      return RequestResult(id: request.id, statusOk: false, errorMsg: error);
    }
  }

  /// Firma de forma trifásica una petición de firma.
  static Future<RequestResult> doSign(final SignRequest request, final Api api) async {
    // *****************************************************************************************************
    // **************************** PREFIRMA ***************************************************************
    // *****************************************************************************************************

    debugPrint('TriSigner - sign: == PREFIRMA ==');

    // Mandamos a prefirmar y obtenemos los resultados
    final List<TriphaseRequest> triphaseRequests = await signPhase1(request, api);

    // *****************************************************************************************************
    // ******************************* FIRMA ***************************************************************
    // *****************************************************************************************************

    // Recorremos las peticiones trifásicas (varios documentos de una petición)
    for (int i = 0; i < triphaseRequests.length; i++) {
      // Si falló una sola firma de la petición, esta es errónea al completo
      if (!triphaseRequests[i].isStatusOk) {
        debugPrint('Se encontró prefirma errónea, se aborta el proceso de firma. '
            'La traza de la excepción es: ${triphaseRequests[i].getException()}');
        return RequestResult(id: request.id, statusOk: false, errorMsg: 'Error en la prefirma');
      }

      debugPrint('TriSigner - sign: == FIRMA ==');

      // Recorremos cada uno de los documentos de cada peticion de firma
      for (final TriphaseSignRequestDocument requestDoc in triphaseRequests[i].requestDocuments!) {
        // Firmamos las prefirmas y actualizamos los parciales de cada documento de cada peticion
        try {
          await signPhase2(requestDoc);
        } on Exception catch (e) {
          debugPrint('Error en la fase de FIRMA: ${e.toString()}');
          debugPrint(e.toString());

          // Si un documento falla en firma toda la peticion se da por fallida
          return RequestResult(id: request.id, statusOk: false);
        }
      }
    }

    // *****************************************************************************************************
    // **************************** POSTFIRMA **************************************************************
    //******************************************************************************************************

    debugPrint('TriSigner - sign: == POSTFIRMA ==');

    // Mandamos a postfirmar y recogemos el resultado
    return await signPhase3(triphaseRequests, api);
  }

  /// Obtiene el nombre de un algoritmo de firma que usa un algoritmo de huella específico.
  static String getSignatureAlgorithm(final String mdAlgorithm) {
    return '${mdAlgorithm.replaceAll('-', '')}withRSA';
  }

  /// Genera la prefirma de una petición de firma.
  static Future<List<TriphaseRequest>> signPhase1(final SignRequest request, final Api api) async {
    String document = await api.preSignRequest(request);
    return PresignResponseParser.parse(document);
  }

  /// Genera la firma PKCS#1 (segunda fase del proceso de firma trifásica) y muta el objeto
  /// de petición de firma de un documento para almacenar el mismo el resultado.
  static Future signPhase2(final TriphaseSignRequestDocument requestDoc) async {
    final String algorithm = getSignatureAlgorithm(requestDoc.messageDigestAlgorithm!);

    final TriphaseConfigData config = requestDoc.partialResult!;

    // TODO(jmolins): Es posible que se ejecute mas de una firma como resultado de haber proporcionado varios
    // identificadores de datos o en una operacion de contrafirma.

    Uint8List? preSign;
    try {
      preSign = config.getPreSign();
    } on Exception {
      // Cuando la respuesta no indica el numero de firmas y no se ha devuelto ninguna
      debugPrint('No se ha devuelto ningún resultado de firma');
      preSign = null;
    }

    if (preSign == null) {
      throw Exception('El servidor no ha devuelto la prefirma del documento');
    }

    Uint8List? pkcs1sign;
    if (Platform.isIOS) {
      pkcs1sign = await methodChannel.invokeMethod<Uint8List>(
        'signData',
        {'data': preSign, 'algorithm': algorithm},
      );
    } else {
      pkcs1sign = await DigitalCertificates.signData(preSign, algorithm);
    }

    // Configuramos la petición de postfirma indicando las firmas PKCS#1 generadas
    config.setPk1(pkcs1sign!);

    if (!config.needsPreSign()) {
      config.removePreSign();
    }
  }

  /// Genera la postfirma de un listado de prefirmas.
  static Future<RequestResult> signPhase3(
      final List<TriphaseRequest> requests, final Api api) async {
    return PostsignResponseParser.parse(await api.postSignRequests(requests));
  }
}

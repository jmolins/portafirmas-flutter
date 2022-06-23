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
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/sign_request_document.dart';
import 'package:portafirmas/model/triphase_request.dart';
import 'package:portafirmas/model/triphase_sign_request_document.dart';

/// Factor&ía para la creación de solitidudes XML hacia el servidor de firmas multi-fase.
class XmlRequestFactory {
  static const String xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';

  static const String xmlTrisignOpen = '<rqttri>';
  static const String xmlTrisignClose = '</rqttri>';

  static const String xmlRequestsOpen = '<reqs>';
  static const String xmlRequestsClose = '</reqs>';

  static const String xmlRejectsOpen = '<reqrjcts>';
  static const String xmlRejectsClose = '</reqrjcts>';

  static const String xmlApproveOpen = '<apprv>';
  static const String xmlApproveClose = '</apprv>';

  static const String xmlParamsOpen = '<params>';
  static const String xmlParamsClose = '</params>';

  static const String xmlResultOpen = '<result>';
  static const String xmlResultClose = '</result>';

  static const String xmlRsnOpen = '<rsn>';
  static const String xmlRsnClose = '</rsn>';

  static String createRequestListRequest(
    String state,
    List<String>? filters,
    int numPage,
    int pageSize,
  ) {
    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write('<rqtlst state="$state" pg="$numPage" sz="$pageSize">');
    List<String> signFormats = ['CAdES', 'XAdES', 'PDF'];
    sb.write('<fmts>');
    for (final String signFormat in signFormats) {
      sb.write('<fmt>$signFormat</fmt>');
    }
    sb.write('</fmts>');
    if (filters != null && filters.isNotEmpty) {
      sb.write('<fltrs>');
      for (final String filter in filters) {
        sb.write('<fltr>');
        final int equalPos = filter.contains('=') ? filter.indexOf('=') : filter.length;
        sb.write('<key>');
        if (equalPos > 0) {
          sb.write(filter.substring(0, equalPos));
        }
        sb.write('</key>');
        sb.write('<value>');
        if (equalPos < filter.length - 1) {
          sb.write(filter.substring(equalPos + 1));
        }
        sb.write('</value>');
        sb.write('</fltr>');
      }
      sb.write('</fltrs>');
    }
    sb.write('</rqtlst>');

    // Imprimimos la peticion en el log
    debugPrint('Peticion de la lista de peticiones:');
    printXml(sb.toString());

    return sb.toString();
  }

  /// Crea una solicitud de prefirma a partir de una petición de firma.
  static String createPresignRequest(SignRequest? request) {
    if (request == null) {
      throw Exception('La lista de peticiones no puede ser nula');
    }
    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write(xmlTrisignOpen);

    // Listado de peticiones
    sb.write(xmlRequestsOpen);

    // Peticion
    List<SignRequestDocument>? documents = request.docs;

    sb.write('<req id="${request.id}">');
    if (documents != null) {
      for (final SignRequestDocument document in documents) {
        sb
          ..write('<doc docid="${document.id}" ')
          ..write('cop="${document.cryptoOperation}" ')
          ..write('sigfrmt="${document.signFormat}" ')
          ..write('mdalgo="${document.messageDigestAlgorithm}">')
          ..write(xmlParamsOpen)
          ..write(document.params ?? '')
          ..write(xmlParamsClose)
          ..write('</doc>');
      }
    }
    sb.write('</req>');
    sb.write(xmlRequestsClose); // Cierre del listado de peticiones
    sb.write(xmlTrisignClose); // Cierre del XML

    // Imprimimos la peticion en el log
    debugPrint('Peticion prefirma:');
    printXml(sb.toString());

    return sb.toString();
  }

  /// Crea una solicitud de postfirma a partir de una lista de peticiones de firma.
  static String createPostsignRequest(final List<TriphaseRequest>? requests) {
    if (requests == null) {
      throw Exception('La lista de peticiones no puede ser nula');
    }
    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write(xmlTrisignOpen);

    // Peticiones
    sb.write(xmlRequestsOpen);
    List<TriphaseSignRequestDocument>? documents;
    for (final TriphaseRequest request in requests) {
      sb.write('<req id="${request.ref}" status="');
      sb.write(request.isStatusOk ? 'OK' : 'KO');
      sb.write('">');
      // Solo procesamos los documentos si la peticion es buena
      if (request.isStatusOk) {
        documents = request.requestDocuments;
        if (documents != null) {
          for (final TriphaseSignRequestDocument document in documents) {
            sb
              ..write('<doc docid="${document.id}')
              ..write('" cop="${document.cryptoOperation}')
              ..write('" sigfrmt="${document.signatureFormat}')
              ..write('" mdalgo="${document.messageDigestAlgorithm}')
              ..write('">')
              ..write(xmlParamsOpen)
              ..write(document.params ?? '')
              ..write(xmlParamsClose)
              ..write(xmlResultOpen)
              ..write(document.partialResult!.toXMLParamList())
              ..write(xmlResultClose)
              ..write('</doc>');
          }
        }
      }
      sb.write('</req>');
    }
    sb.write(xmlRequestsClose);
    sb.write(xmlTrisignClose);

    // Imprimimos la peticion en el log
    debugPrint('Peticion postfirma:');
    printXml(sb.toString());

    return sb.toString();
  }

  /// Crea una solicitud de aprobación a partir de una lista de IDs de peticiones.
  static String createApproveRequest(final List<String>? requestIds) {
    if (requestIds == null || requestIds.isEmpty) {
      throw Exception('La lista de peticiones no puede ser nula');
    }

    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write(xmlApproveOpen);
    sb.write('<reqs>');
    // Peticiones que se aprueban
    for (final String requestId in requestIds) {
      sb.write('<r id="');
      sb.write(requestId);
      sb.write('"/>');
    }
    sb.write('</reqs>');
    sb.write(xmlApproveClose);

    return sb.toString();
  }

  /// Crea una solicitud de aprobación a partir de una lista de IDs de peticiones.
  static String createRejectRequest(final List<String>? requestIds, final String? reason) {
    if (requestIds == null || requestIds.isEmpty) {
      throw Exception('La lista de peticiones no puede ser nula');
    }

    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write(xmlRejectsOpen);
    if (reason != null && reason != '') {
      sb.write(xmlRsnOpen);
      sb.write(base64UrlEncode(utf8.encode(reason)));
      sb.write(xmlRsnClose);
    }
    sb.write('<rjcts>');
    // Peticiones que se rechazan
    for (final String requestId in requestIds) {
      sb.write('<rjct id="');
      sb.write(requestId);
      sb.write('"/>');
    }
    sb.write('</rjcts>');
    sb.write(xmlRejectsClose);

    return sb.toString();
  }

  static String createDetailRequest(final String? requestId) {
    if (requestId == null || requestId.trim().isEmpty) {
      throw Exception('El identificador de la solicitud de firma no puede ser nulo');
    }

    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write('<rqtdtl id="');
    sb.write(requestId);
    sb.write('">');
    sb.write('</rqtdtl>');

    return sb.toString();
  }

  static String createPreviewRequest(final String? documentId) {
    if (documentId == null || documentId.trim().isEmpty) {
      throw Exception('El identificador del documento no puede ser nulo');
    }

    final StringBuffer sb = StringBuffer(xmlHeader);
    sb.write('<rqtprw docid="');
    sb.write(documentId);
    sb.write('">');
    sb.write('</rqtprw>');

    return sb.toString();
  }

  static void printXml(final String xml) {
    const int bufferLength = 200;
    for (int i = 0; i < xml.length / bufferLength; i++) {
      debugPrint(xml.substring(i * bufferLength, min((i + 1) * bufferLength, xml.length)));
    }
  }
}

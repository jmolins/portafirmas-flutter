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

import 'package:collection/collection.dart';
import 'package:portafirmas/api/sign_request_document_parser.dart';
import 'package:portafirmas/model/partial_sign_requests_list.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/sign_request_document.dart';
import 'package:xml/xml.dart' as xml;

/// Analizador de XML para la generación de listas de peticiones de firma.
class RequestListResponseParser {
  static const String listNode = 'list';

  static const String errorNode = 'err';

  static const String numRequestsAttribute = 'n';

  static const String errorCodeAttribute = 'cd';

  /// Valor usado por el Portafirmas para indicar que una petición es de firma.
  static const String requestTypeSign = 'FIRMA';

  /// Valor usado por el Portafirmas para indicar que una petición
  /// es de visto bueno.
  static const String requestTypeApprove = 'VISTOBUENO';

  /// Analiza un documento XML y, en caso de tener el formato correcto,
  /// obtiene una lista de peticiones de firma.
  static PartialSignRequestsList parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var firstNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    if (firstNode == null) {
      throw Exception('El nodo no existe');
    }

    String firstNodeName = firstNode.name.toString().toLowerCase();

    List<xml.XmlAttribute> atts = firstNode.attributes;

    if (firstNodeName == errorNode) {
      xml.XmlAttribute? cdAtt =
          atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == errorCodeAttribute);
      if (cdAtt != null) {
        throw Exception('El servicio proxy notificó un error (${cdAtt.name}): ${cdAtt.value}');
      }
    }

    if (firstNodeName != listNode) {
      throw Exception('El elemento raiz del XML debe ser $listNode y aparece: $firstNodeName');
    }

    xml.XmlAttribute? numRequestAttr =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == numRequestsAttribute);
    int numRequests = 0;
    if (numRequestAttr != null) numRequests = int.tryParse(numRequestAttr.value) ?? 0;

    List<SignRequest> listSignRequest = firstNode.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => SignRequestParser.parse(node as xml.XmlElement))
        .toList();

    return PartialSignRequestsList(listSignRequest, numRequests);
  }
}

class SignRequestParser {
  static const String requestNode = 'rqt';
  static const String idAttribute = 'id';
  static const String priorityAttribute = 'priority';
  static const String workflowAttribute = 'workflow';
  static const String forwardAttribute = 'forward';
  static const String typeAttribute = 'type';
  static const String subjectNode = 'subj';
  static const String senderNode = 'snder';
  static const String viewNode = 'view';
  static const String dateNode = 'date';
  static const String expirationDateNode = 'expdate';
  static const String documentsNode = 'docs';
  static const String attachedNode = 'attached';

  static SignRequest parse(final xml.XmlElement signRequestNode) {
    String nodeName = signRequestNode.name.toString().toLowerCase();
    if (nodeName != requestNode) {
      throw Exception("Se ha encontrado el elemento '$nodeName' en el listado de peticiones");
    }

    /*Atributos */
    String ref;
    int? priority = 1; // Valor por defecto
    bool workflow = false; // Valor por defecto
    bool forward = false; // Valor por defecto
    RequestType? type = RequestType.signature; // Valor por defecto

    /* Elementos */
    String subject;
    String sender;
    String view;
    String date;
    String? expirationDate;

    // Cargamos los atributos
    List<xml.XmlAttribute> atts = signRequestNode.attributes;

    xml.XmlAttribute? attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception(
          "No se ha encontrado el atributo obligatorio '$idAttribute' en un peticion de firma");
    }
    ref = attribute.value;

    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == priorityAttribute);
    if (attribute != null) {
      priority = int.tryParse(attribute.value);
      if (priority == null) {
        throw Exception(
            "La prioridad de la peticion con referencia '$ref' no es valida. Debe ser un valor entero");
      }
    }

    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == workflowAttribute);
    if (attribute != null) {
      try {
        workflow = attribute.value.parseBool();
      } catch (e) {
        throw Exception(
            "El valor del atributo '$workflow' de la peticion con referencia '$ref' no es valida. no es valido. Debe ser 'true' o 'false'");
      }
    }

    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == forwardAttribute);
    if (attribute != null) {
      try {
        forward = attribute.value.parseBool();
      } catch (e) {
        throw Exception(
            "El valor del atributo '$forward' de la peticion con referencia '$ref' no es valida. no es valido. Debe ser 'true' o 'false'");
      }
    }

    attribute = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == typeAttribute);
    if (attribute != null) {
      if (attribute.value == RequestListResponseParser.requestTypeSign) {
        type = RequestType.signature;
      } else if (attribute.value == RequestListResponseParser.requestTypeApprove) {
        type = RequestType.approve;
      } else {
        type = null;
      }
    }

    // Cargamos los elementos
    final List<xml.XmlNode> childNodes = signRequestNode.children;
    final List<xml.XmlElement> elementNodes = childNodes
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .toList()
        .cast<xml.XmlElement>();

    // Subject node
    xml.XmlElement? element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == subjectNode);
    if (element == null) {
      throw Exception("La petición con referencia '$ref' no contiene el elemento $subjectNode");
    }
    subject = normalizeValue(element.text);

    // Sender node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == senderNode);
    if (element == null) {
      throw Exception("La petición con referencia '$ref' no contiene el elemento $senderNode");
    }
    sender = normalizeValue(element.text);

    // View node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == viewNode);
    if (element == null) {
      throw Exception("La petición con referencia '$ref' no contiene el elemento $viewNode");
    }
    view = element.text;

    // Date node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == dateNode);
    if (element == null) {
      throw Exception("La petición con referencia '$ref' no contiene el elemento $dateNode");
    }
    date = element.text;

    // Expiration Date node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == expirationDateNode);
    if (element == null) {
      // No hay fecha de caducidad, es opcional
      expirationDate = null;
    } else {
      String expDate = element.text;
      expirationDate = expDate != '' ? expDate : null;
    }

    // Documents node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == documentsNode);
    if (element == null) {
      throw Exception("La petición con referencia '$ref' no contiene el elemento $documentsNode");
    }

    final List<SignRequestDocument> signRequestDocumentsList = element.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => SignRequestDocumentParser.parse(node as xml.XmlElement))
        .toList();

    return SignRequest(ref, subject, sender, view, date, expirationDate, priority, workflow,
        forward, type, signRequestDocumentsList, null);
  }

  /// Deshace los cambios que hizo el proxy para asegurar que el XML estaba bien formado.
  static String normalizeValue(final String value) {
    return value.trim().replaceAll('&_lt;', '<').replaceAll('&_gt;', '>');
  }
}

extension BoolParsing on String {
  bool parseBool() {
    if (toLowerCase() == 'true') {
      return true;
    } else if (toLowerCase() == 'false') {
      return false;
    }

    throw '"$this" can not be parsed to boolean.';
  }
}

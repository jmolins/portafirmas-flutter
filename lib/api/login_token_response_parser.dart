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
import 'package:portafirmas/model/request_result.dart';
import 'package:xml/xml.dart' as xml;

/// XML Analizer for the generation of a login or logout request
class LoginTokenResponseParser {
  static const String loginTokenResponseNode = 'lgnrq';
  static const String idAttribute = 'id';
  static const String errorAttribute = 'err';

  LoginTokenResponseParser() {
    // No instanciable
  }

  /// Analizes an XML document and, if correctly formatted, provides a
  /// [RequestResult]
  static RequestResult parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var loginNode = document.children.firstWhere((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        as xml.XmlElement?;
    //print(document.firstChild);
    String? name = loginNode?.name.toString().toLowerCase();
    if (name != loginTokenResponseNode) {
      throw Exception('El elemento raiz del XML debe ser $loginTokenResponseNode y aparece: $name');
    }

    var childNode = loginNode!.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    final xml.XmlElement requestNode;
    if (childNode == null) {
      requestNode = loginNode;
    } else {
      requestNode = childNode;
    }
    return RequestResultParser.parse(requestNode);
  }
}

class RequestResultParser {
  static const String loginTokenResponseNode = 'lgnrq';
  static const String idAttribute = 'id';
  static const String ssidAttribute = 'ssid';
  static const String errorAttribute = 'err';
  static const String rolesAttribute = 'roles';

  /// Analizes an XML document and, if correctly formatted, provides a
  /// [RequestResult]
  static RequestResult parse(final xml.XmlElement requestNode) {
    String name = requestNode.name.toString().toLowerCase();
    if (name != loginTokenResponseNode) {
      throw Exception('Se encontró un elemento $name en la solicitud de token de inicio de sesión');
    }

    // Datos de la petición
    String? ref = requestNode.text;
    bool statusOk = true;
    String? ssid;

    List<xml.XmlAttribute> atts = requestNode.attributes;

    xml.XmlAttribute? idAtt =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (idAtt == null) {
      throw Exception(
          'No se ha encontrado el atributo obligatorio $idAttribute en un petición de login');
    }

    // If the error attribute exits, an error has occurred
    xml.XmlAttribute? ssidAtt =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == ssidAttribute);
    if (ssidAtt != null) {
      ssid = ssidAtt.value;
    }

    // If the error attribute exits, an error has occurred
    xml.XmlAttribute? errorAtt =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == errorAttribute);
    if (errorAtt != null) {
      statusOk = false;
    }

    return RequestResult(id: ref, statusOk: statusOk, ssid: ssid);
  }
}

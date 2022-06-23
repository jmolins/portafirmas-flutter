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
import 'package:portafirmas/model/validation_login_result.dart';
import 'package:xml/xml.dart' as xml;

/// Analizador de XML para la generación del token firmado para validar la identidad.
class LoginValidationResponseParser {
  static const tokenValidationResponseNode = 'vllgnrq';

  /// Analiza un documento XML y, en caso de tener el formato correcto, obtiene de &eacute;l
  /// un listado de objetos de tipo {@link TriphaseRequest}.
  static ValidationLoginResult parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var loginNode = document.children.firstWhere((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        as xml.XmlElement?;
    String? name = loginNode?.name.toString().toLowerCase();
    if (name != tokenValidationResponseNode) {
      throw Exception(
          'El elemento raiz del XML debe ser $tokenValidationResponseNode y aparece: $name');
    }

    var childNode = loginNode!.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    final xml.XmlElement requestNode;
    if (childNode == null) {
      requestNode = loginNode;
    } else {
      requestNode = childNode;
    }
    return LoginValidationResultParser.parse(requestNode);
  }
}

class LoginValidationResultParser {
  static const requestNodeName = 'vllgnrq';
  static const okAttribute = 'ok';
  static const dniAttribute = 'dni';
  static const errorAttribute = 'er';

  /// Analizes an XML document and, if correctly formatted, provides a
  /// [RequestResult]
  static ValidationLoginResult parse(final xml.XmlElement requestNode) {
    String name = requestNode.name.toString().toLowerCase();
    if (name != requestNodeName) {
      throw Exception('Se encontró un elemento $name en el listado de peticiones');
    }

    // Datos de la peticion
    bool statusOk = true;
    String? dni;
    String? errorMessage = '';

    List<xml.XmlAttribute> atts = requestNode.attributes;

    xml.XmlAttribute? okAtt =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == okAttribute);
    if (okAtt == null) {
      throw Exception(
          'No se ha encontrado el atributo obligatorio $okAttribute en un respuesta de login');
    }

    // statusOk = true, salvo que la propiedad status tenga el valor "false"
    if (okAtt.value.toLowerCase() == 'false') {
      statusOk = false;
    }

    // Cargamos el mensaje de error
    xml.XmlAttribute? errorAtt = atts.firstWhereOrNull((att) {
      return att.name.toString().toLowerCase() == errorAttribute ||
          att.name.toString().toLowerCase() == errorAttribute;
    });
    if (errorAtt != null) {
      errorMessage = errorAtt.value;
    }

    // Cargamos el DNI
    xml.XmlAttribute? dniAtt =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == dniAttribute);
    if (dniAtt != null) {
      dni = dniAtt.value;
    }

    final ValidationLoginResult result = ValidationLoginResult(statusOk: statusOk);

    result.dni = dni;
    result.errorMsg = errorMessage;

    return result;
  }
}

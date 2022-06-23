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

/// Analizador de XML de respuesta de la petición de visto bueno de
/// solicitudes de firma.
class ApproveResponseParser {
  static const String approveResponseNode = 'apprq';

  /// Analiza la respuesta XML de aprobación y devuelve el resultado en
  /// un listado de objetos de tipo [RequestResult].
  static List<RequestResult> parse(final String? doc) {
    /// doc string is of the form:
    ///     <?xml version="1.0" encoding="UTF-8"?><apprq><r id="8jov2Bciys" ok="OK"/>
    ///     <r id="9U0orb8jv9" ok="OK"/></apprq>

    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var approveNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? approveNodeName = approveNode?.name.toString().toLowerCase();
    if (approveNodeName != approveResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$approveResponseNode ' y aparece: $approveNodeName");
    }

    List<RequestResult> approveResults = approveNode!.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => ApproveParser.parse(node as xml.XmlElement))
        .toList();

    return approveResults;
  }
}

class ApproveParser {
  static const String approveNode = 'r';
  static const String idAttribute = 'id';
  static const String okAttribute = 'ok';

  static RequestResult parse(final xml.XmlElement node) {
    String nodeName = node.name.toString().toLowerCase();
    if (nodeName != approveNode) {
      throw Exception("Se ha encontrado el elemento '$nodeName' en la respuesta de aprobación.");
    }

    /*Atributos */
    String ref;
    bool ok = true;

    // Cargamos los atributos
    List<xml.XmlAttribute> atts = node.attributes;

    xml.XmlAttribute? attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception(
          "No se ha encontrado el atributo obligatorio '$idAttribute' en una respuesta de aprobación");
    }
    ref = attribute.value;

    // ok = true, salvo que la propiedad 'ok' tenga el valor "KO"
    attribute = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == okAttribute);
    if (attribute != null) {
      ok = attribute.value.toUpperCase() == 'KO' ? false : true;
    }

    return RequestResult(id: ref, statusOk: ok);
  }
}

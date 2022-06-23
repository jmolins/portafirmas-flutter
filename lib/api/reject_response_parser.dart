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

/// Analizador de XML de respuesta de la petición de rechazo de
/// solicitudes de firma.
class RejectResponseParser {
  static const String rejectResponseNode = 'rjcts';

  /// Analiza la respuesta XML de rechazo y devuelve el resultado en
  /// un listado de objetos de tipo [RequestResult].
  static List<RequestResult> parse(final String? doc) {
    /// doc string is of the form:
    ///     <?xml version="1.0" encoding="UTF-8"?>
    ///     <rjcts>
    ///     <rjct id="mSHSOSjZ0O" status="OK"/>
    ///     <rjct id="DCBurSx9dW" status="OK"/>
    ///     </rjcts>

    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var rejectNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? rejectNodeName = rejectNode?.name.toString().toLowerCase();
    if (rejectNodeName != rejectResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$rejectResponseNode ' y aparece: $rejectNodeName");
    }

    List<RequestResult> rejectResults = rejectNode!.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => RejectParser.parse(node as xml.XmlElement))
        .toList();

    return rejectResults;
  }
}

class RejectParser {
  static const String rejectNode = 'rjct';
  static const String idAttibute = 'id';
  static const String statusAttribute = 'status';

  static RequestResult parse(final xml.XmlElement node) {
    String nodeName = node.name.toString().toLowerCase();
    if (nodeName != rejectNode) {
      throw Exception("Se ha encontrado el elemento '$nodeName' en la respuesta de rechazo.");
    }

    /*Atributos */
    String ref;
    bool status = true;

    // Cargamos los atributos
    List<xml.XmlAttribute> atts = node.attributes;

    var attribute = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttibute);
    if (attribute == null) {
      throw Exception(
          "No se ha encontrado el atributo obligatorio '$idAttibute' en una respuesta de rechazo");
    }
    ref = attribute.value;

    // statusOk = true, salvo que la propiedad status tenga el valor "KO"
    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == statusAttribute);
    if (attribute != null) {
      status = attribute.value.toUpperCase() == 'KO' ? false : true;
    }

    return RequestResult(id: ref, statusOk: status);
  }
}

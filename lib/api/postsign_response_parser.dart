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
import 'package:flutter/material.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:xml/xml.dart' as xml;

/// Analizador de XML para la generación de un listado de objetos
/// de tipo [TriphaseRequest] a partir de un XML de respuesta de postfirma.
class PostsignResponseParser {
  static const String postsignResponseNode = 'posts';
  static const String requestNodeName = 'req';
  static const String idAttribute = 'id';
  static const String statusAttribute = 'status';

  /// Analiza un documento XML y, en caso de tener el formato correcto, obtiene de él
  /// un listado de objetos de tipo [TriphaseRequest].
  static RequestResult parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var postsignNode = document.children
        .firstWhere((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? postsignNodeName = postsignNode?.name.toString().toLowerCase();
    if (postsignNodeName != postsignResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$postsignResponseNode ' y aparece: $postsignNodeName");
    }

    var requestNode = postsignNode?.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? nodeName = requestNode?.name.toString().toLowerCase();
    if (nodeName != requestNodeName) {
      throw Exception("No se encontró el elemento '$requestNodeName' y aparece: $requestNodeName");
    }

    // Datos de la respuesta
    String ref;
    bool statusOk = true;

    // Cargamos los atributos
    List<xml.XmlAttribute> atts = requestNode!.attributes;

    var attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception(
          "No se ha encontrado el atributo '$idAttribute' en una respuesta de postfirma");
    }
    ref = attribute.value;

    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == statusAttribute);
    // statusOk = true, salvo que la propiedad status tenga el valor "KO"
    statusOk = attribute == null || attribute.value != 'KO';

    debugPrint('Ref=$ref; status=$statusOk');

    return RequestResult(id: ref, statusOk: statusOk);
  }
}

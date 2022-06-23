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

/// Analizador de XML de respuesta de la petición de logout
class LogoutResponseParser {
  static const String logoutTokenResponseNode = 'lgorq';
  static const String logoutNode = 'lgorq';

  static RequestResult parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var logoutRootNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? logoutNodeName = logoutRootNode?.name.toString().toLowerCase();
    if (logoutNodeName != logoutTokenResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$logoutTokenResponseNode ' y aparece: $logoutNodeName");
    }

    // According to the android implementation the logout response may be
    // one of the following forms:
    //   <?xml version="1.0" encoding="UTF-8"?><lgorq/>
    //   <?xml version="1.0" encoding="UTF-8"?><lgorq><lgorq/>...</lgorq>
    // If the root <lgorq/> node has children, the first one must also be a
    // <lgorq/> node
    var childLogoutNode = logoutRootNode!.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    final xml.XmlElement requestNode;
    if (childLogoutNode == null) {
      requestNode = logoutRootNode;
    } else {
      requestNode = childLogoutNode;
    }

    return RequestResultParser.parse(requestNode);
  }
}

class RequestResultParser {
  static const String logoutNode = 'lgorq';

  /// Analizes an XML document and, if correctly formatted, provides a
  /// [RequestResult]
  static RequestResult parse(final xml.XmlElement requestNode) {
    String name = requestNode.name.toString().toLowerCase();
    if (name != logoutNode) {
      throw Exception('Se encontró un elemento $name en la respuesta de logout');
    }

    // Datos de la petición
    var textElement = requestNode.children.firstWhereOrNull(
      (node) => node.nodeType == xml.XmlNodeType.TEXT,
    ) as xml.XmlText?;

    String? ref = textElement?.toString();
    bool statusOk = true;

    return RequestResult(id: ref, statusOk: statusOk);
  }
}

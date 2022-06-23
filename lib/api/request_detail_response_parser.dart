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
import 'package:portafirmas/api/request_document_parser.dart';
import 'package:portafirmas/api/sign_request_document_parser.dart';
import 'package:portafirmas/model/request_detail.dart';
import 'package:portafirmas/model/request_document.dart';
import 'package:portafirmas/model/sign_line.dart';
import 'package:portafirmas/model/sign_line_element.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/sign_request_document.dart';

import 'package:xml/xml.dart' as xml;

/// Analizador de XML de respuesta del detalle de una petición de firma.
///
/// Esto es un ejemplo del XML recibido del servidor
///
/// <?xml version="1.0" encoding="UTF-8"?>
///	<dtl id="d80E1lC3vd" priority="1" workflow="false" forward="false" type="FIRMA">
///		<subj>
///			<![CDATA[FIRMe test 13]]>
///		</subj>
///		<msg>
///			<![CDATA[FIRMe test 13]]>
///		</msg>
///		<snders>
///			<snder>
///				<![CDATA[Anf Usuario Activo]]>
///			</snder>
///		</snders>
///		<date>03/12/2019  17:43</date>
///		<expdate/>
///		<app>
///			<![CDATA[PORTAFIRMAS]]>
///		</app>
///		<ref>
///			<![CDATA[FIRMe test 13]]>
///		</ref>
///		<signlinestype>CASCADA</signlinestype>
///		<sgnlines>
///			<sgnline>
///				<rcvr>
///					<![CDATA[Anf Usuario Activo]]>
///				</rcvr>
///			</sgnline>
///		</sgnlines>
///		<docs>
///			<doc docid="6OCVFEs8km">
///				<nm>
///					<![CDATA[PDF-A.pdf]]>
///				</nm>
///				<sz>90928</sz>
///				<mmtp>application/pdf</mmtp>
///				<sigfrmt>PDF</sigfrmt>
///				<mdalgo>SHA1</mdalgo>
///				<params/>
///			</doc>
///		</docs>
///	</dtl>
///
class RequestDetailResponseParser {
  static const String detailResponseNode = 'dtl';
  static const String idAttribute = 'id';
  static const String priorityAttribute = 'priority';
  static const String workflowAttribute = 'workflow';
  static const String forwardAttribute = 'forward';
  static const String typeAttribute = 'type';

  static const String subjectNode = 'subj';
  static const String messageNode = 'msg';
  static const String sendersNode = 'snders';
  static const String senderNode = 'snder';
  static const String dateNode = 'date';
  static const String expirationDateNode = 'expdate';
  static const String applicationNode = 'app';
  static const String rejectTextNode = 'rejt';
  static const String referenceNode = 'ref';
  static const String signLinesNode = 'sgnlines';
  static const String signLineNode = 'sgnline';
  static const String receiverNode = 'rcvr';
  static const String signStateAttribute = 'st';
  static const String documentsNode = 'docs';
  static const String attachedNode = 'attachedlist';
  static const String signlinetypeNode = 'signlinestype';

  static const int defaultRequestPriorityValue = 1;
  static const bool defaultRequestWorkflowValue = false;
  static const bool defaultRequestForwardValue = false;

  /// Valor usado por el Portafirmas para indicar que una petición es de firma.
  static const String requestTypeSign = 'FIRMA';

  /// Valor usado por el Portafirmas para indicar que una petición es de visto bueno.
  static const String requestTypeApprove = 'VISTOBUENO';

  /// Analiza un documento XML y, en caso de tener el formato correcto, obtiene de él
  /// el detalle de una petición de firma.
  static RequestDetail parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var firstNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? firstNodeName = firstNode?.name.toString().toLowerCase();
    if (firstNodeName != detailResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$detailResponseNode ' y aparece: $firstNodeName");
    }

    List<xml.XmlAttribute> atts = firstNode!.attributes;
    var attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception(
          "El detalle de la peticion carece del atributo '$idAttribute' con el identificador de la peticion");
    }

    final RequestDetail reqDetail = RequestDetail(attribute.value);

    // Establecemos los atributos opcionales de la petición
    setOptionalAttributes(atts, reqDetail);

    //return reqDetail;

    // Cargamos los elementos
    final List<xml.XmlNode> childNodes = firstNode.children;
    final List<xml.XmlElement> elementNodes = childNodes
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .toList()
        .cast<xml.XmlElement>();

    // Subject node
    var element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == subjectNode);
    if (element == null) {
      throw Exception("No se encontró el nodo '$subjectNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }

    reqDetail.subject = normalizeValue(element.text);

    // Configuramos el mensaje de la peticion (no obligatorio)
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == messageNode);
    if (element != null) reqDetail.message = normalizeValue(element.text);

    // Configuramos los remitentes
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == sendersNode);
    if (element == null) {
      throw Exception("No se encontró el nodo '$sendersNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.senders = getSenders(element.children);

    // Configuramos la fecha
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == dateNode);
    if (element == null) {
      throw Exception("No se encontró el nodo '$dateNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.date = element.text;

    // Configuramos la fecha de caducidad (no obligatoria)
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == expirationDateNode);
    if (element != null) {
      String expDate = element.text;
      if (expDate != '') reqDetail.expDate = expDate;
    }

    // Configuramos la aplicacion que solicitó la firma
    element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == applicationNode,
    );
    if (element == null) {
      throw Exception("No se encontró el nodo '$applicationNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.app = normalizeValue(element.text);

    // Configuramos el motivo de rechazo (no obligatorio)
    element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == rejectTextNode,
    );
    if (element != null) reqDetail.rejectReason = element.text;

    // Configuramos la referencia de la solicitud
    element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == referenceNode,
    );
    if (element == null) {
      throw Exception("No se encontró el nodo '$referenceNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.ref = normalizeValue(element.text);

    // Configuramos el tipo de línea de firma (paralelo o en cascada).
    // Si no esta definido es en cascada por defecto
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == signlinetypeNode);
    if (element == null) {
      reqDetail.signlinestype = 'cascada';
    } else {
      reqDetail.signlinestype = normalizeValue(element.text);
    }

    // Configuramos las línea de firma de la aplicación
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == signLinesNode);
    if (element == null) {
      throw Exception("No se encontró el nodo '$signLinesNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.signLines = getSignLines(element.children);

    // Configuramos los documentos de la solicitud
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == documentsNode);
    if (element == null) {
      throw Exception("No se encontró el nodo '$documentsNode ' en la peticion con "
          'identificador ${reqDetail.id}');
    }
    reqDetail.docs = getDocuments(element.children);

    // Configuramos los anexos de la solicitud, no es obligatorio que existan
    element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == attachedNode,
    );
    if (element != null) {
      reqDetail.attached = getAttachments(element.children);
    }

    return reqDetail;
  }

  /// Recoge los valores de los atributos opcionales de la solicitud: prioridad, flujo de trabajo y
  /// reenvío.
  static void setOptionalAttributes(
      final List<xml.XmlAttribute> atts, final RequestDetail reqDetail) {
    // Establecemos la prioridad de la petición
    var att =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == priorityAttribute);
    int? priority = defaultRequestPriorityValue;
    if (att != null) {
      priority = int.tryParse(att.value);
      if (priority == null) {
        throw Exception('Se ha establecido un valor no valido en el '
            "atributo '$priorityAttribute ' en el detalle "
            'de la peticion  ${reqDetail.id}');
      }
    }
    reqDetail.priority = priority;

    // Establecemos el valor indicativo de Workflow de la petición
    att = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == workflowAttribute);
    bool workflow = defaultRequestWorkflowValue;
    if (att != null) {
      bool validValue = att.value.toLowerCase() == 'true' || att.value.toLowerCase() == 'false';
      if (!validValue) {
        throw Exception('Se ha establecido un valor no valido en el '
            "atributo '$workflowAttribute ' en el detalle "
            'de la peticion  ${reqDetail.id}');
      }

      workflow = att.value.toLowerCase() == 'true';
    }
    reqDetail.workflow = workflow;

    // Establecemos si la petición fue reenviada por otro usuario
    att = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == forwardAttribute);
    bool forward = defaultRequestForwardValue;
    if (att != null) {
      bool validValue = att.value.toLowerCase() == 'true' || att.value.toLowerCase() == 'false';
      if (!validValue) {
        throw Exception('Se ha establecido un valor no valido en el '
            "atributo '$forwardAttribute ' en el detalle "
            'de la peticion  ${reqDetail.id}');
      }

      forward = att.value.toLowerCase() == 'true';
    }
    reqDetail.forward = forward;

    // Establecemos el tipo de peticion
    att = atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == typeAttribute);
    if (att != null) {
      if (att.value.toUpperCase() == requestTypeSign) {
        reqDetail.type = RequestType.signature;
      } else if (att.value.toUpperCase() == requestTypeApprove) {
        reqDetail.type = RequestType.approve;
      } else {
        reqDetail.type = null;
      }
    }
  }

  /// Obtiene el listado de remitentes de un nodo de remitentes.
  static List<String> getSenders(final List<xml.XmlNode> senderNodes) {
    final List<String> sendersList = <String>[];
    for (xml.XmlNode node in senderNodes) {
      // Nos aseguramos de procesar solo nodos de tipo Element
      if (node.nodeType == xml.XmlNodeType.ELEMENT) {
        var element = node as xml.XmlElement; // Cast it
        String? nodeName = element.name.toString().toLowerCase();
        if (nodeName != senderNode) {
          throw Exception('Se ha encontrado el nodo $nodeName  en el listado de '
              'remitentes de la solicitud de firma');
        }

        sendersList.add(normalizeValue(element.text));
      }
    }
    final List<String> senders = List<String>.from(sendersList);
    return senders;
  }

  /// Obtiene el listado de lineas de firmante. Cada linea de firmante puede poseer un
  /// indeterminado número de firmantes.
  static List<SignLine> getSignLines(final List<xml.XmlNode> signLinesNode) {
    final List<SignLine> signLinesList = [];
    bool done = false;
    String type = requestTypeSign;

    for (xml.XmlNode node in signLinesNode) {
      // Nos aseguramos de procesar solo nodos de tipo Element
      if (node.nodeType == xml.XmlNodeType.ELEMENT) {
        var element = node as xml.XmlElement; // Cast it
        String? nodeName = element.name.toString().toLowerCase();
        if (nodeName != signLineNode) {
          throw Exception('Se ha encontrado el nodo $nodeName en el listado de '
              'líneas de firma');
        }

        final List<xml.XmlAttribute> atts = node.attributes;
        xml.XmlAttribute? att =
            atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == typeAttribute);
        // Comprobamos si se indica el estado de la firma en cuestion
        if (att != null) {
          type = att.value;
        } else {
          type = requestTypeSign;
        }

        final SignLine signLine = SignLine.withType(type);
        final List<xml.XmlNode> recivers = node.children;

        for (xml.XmlNode recNode in recivers) {
          // Nos aseguramos de procesar solo nodos de tipo Element
          if (recNode.nodeType == xml.XmlNodeType.ELEMENT) {
            var recElement = recNode as xml.XmlElement; // Cast it
            String? recNodeName = recElement.name.toString().toLowerCase();
            if (recNodeName != receiverNode) {
              throw Exception('Se ha encontrado el nodo $recNodeName en el listado de '
                  'líneas de receptores');
            }

            // Comprobamos si se indica el nombre del firmante en cuestion, es obligatorio
            final List<xml.XmlAttribute> recAtts = recNode.attributes;
            xml.XmlAttribute? recAtt = recAtts.firstWhereOrNull(
                (recAtt) => recAtt.name.toString().toLowerCase() == signStateAttribute);

            // Comprobamos si se indica el estado de la firma en cuestion
            if (recAtt != null) done = recAtt.value.toLowerCase() == 'true';

            signLine.addElement(SignLineElement(normalizeValue(recElement.text), done));
          }
        }
        signLinesList.add(signLine);
      }
    }
    return signLinesList;
  }

  /// Obtiene el listado con la información necesaria de los documentos a firmar.
  static List<SignRequestDocument> getDocuments(final List<xml.XmlNode> documentNodes) {
    final List<SignRequestDocument> docsList = [];
    for (xml.XmlNode docNode in documentNodes) {
      if (docNode.nodeType == xml.XmlNodeType.ELEMENT) {
        docsList.add(SignRequestDocumentParser.parse(docNode as xml.XmlElement));
      }
    }

    return docsList;
  }

  static List<RequestDocument> getAttachments(final List<xml.XmlNode> documentNodes) {
    final List<RequestDocument> docsList = [];
    for (xml.XmlNode docNode in documentNodes) {
      if (docNode.nodeType == xml.XmlNodeType.ELEMENT) {
        docsList.add(RequestDocumentParser.parse(docNode as xml.XmlElement));
      }
    }

    return docsList;
  }

  /// Deshace los cambios que hizo el proxy para asegurar que el XML estába bien formado.
  static String normalizeValue(final String value) {
    return value.trim().replaceAll('&_lt;', '<').replaceAll('&_gt;', '>');
  }
}

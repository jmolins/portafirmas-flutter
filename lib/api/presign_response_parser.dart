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

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:portafirmas/model/triphase_request.dart';
import 'package:portafirmas/model/triphase_sign_request_document.dart';
import 'package:xml/xml.dart' as xml;

/// Analizador de XML para la generación de un listado de objetos
/// de tipo [TriphaseRequest] a partir de un XML de respuesta de prefirma.
class PresignResponseParser {
  static const String presignResponseNode = 'pres';

  /// Analiza un documento XML y, en caso de tener el formato correcto, obtiene de él
  /// un listado de objetos [TriphaseRequest].
  static List<TriphaseRequest> parse(final String? doc) {
    if (doc == null) {
      throw Exception('El documento proporcionado no puede ser nulo');
    }

    xml.XmlDocument document = xml.XmlDocument.parse(doc);
    var firstNode = document.children
        .firstWhereOrNull((node) => node.nodeType == xml.XmlNodeType.ELEMENT) as xml.XmlElement?;
    String? firstNodeName = firstNode?.name.toString().toLowerCase();
    if (firstNodeName != presignResponseNode) {
      throw Exception(
          "El elemento raiz del XML debe ser '$presignResponseNode ' y aparece: $firstNodeName");
    }

    return parseElement(firstNode);
  }

  /// Analiza un elemento XML y, en caso de tener el formato correcto, obtiene de él
  /// un listado de objetos [TriphaseRequest].
  static List<TriphaseRequest> parseElement(final xml.XmlElement? element) {
    if (element == null) {
      throw Exception('El nodo XML proporcionado no puede ser nulo');
    }

    final List<TriphaseRequest> listPresignRequests = element.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => TriphaseRequestParser.parse(node as xml.XmlElement))
        .toList();

    return listPresignRequests;
  }
}

class TriphaseRequestParser {
  static const String requestNode = 'req';
  static const String idAttribute = 'id';
  static const String statusAttribute = 'status';
  static const String exceptionB64Attribute = 'exceptionb64';

  static TriphaseRequest parse(final xml.XmlElement presignRequestNode) {
    String nodeName = presignRequestNode.name.toString().toLowerCase();
    if (nodeName != requestNode) {
      throw Exception("Se ha encontrado el elemento '$nodeName' en los nodos de prefirma");
    }

    // Datos de la peticion
    String ref;
    bool statusOk;

    // Cargamos los atributos
    // Atributos del nodo
    List<xml.XmlAttribute> atts = presignRequestNode.attributes;

    var attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception("No se ha encontrado el atributo '$idAttribute' en una prefirma");
    }
    ref = attribute.value;

    // statusOk = true, salvo que la propiedad status tenga el valor "KO"
    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == statusAttribute);
    statusOk = attribute == null || attribute.value.toLowerCase() != 'ko';

    attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == exceptionB64Attribute);
    String? exception;
    try {
      exception = attribute == null ? null : utf8.decode(base64.decode(attribute.value));
    } on Exception {
      debugPrint('No se ha podido descodificar el base 64 de la traza de la '
          'excepcion, se usara tal cual');
      exception = attribute?.value;
    }

    // Si la peticion no se ha procesado correctamente se descarta
    if (!statusOk) {
      return TriphaseRequest.withException(ref, false, exception);
    }

    // Cargamos el listado de documentos
    final List<TriphaseSignRequestDocument> requestDocuements = presignRequestNode.children
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .map((node) => PresignRequestDocumentParser.parse(node as xml.XmlElement))
        .toList();

    return TriphaseRequest.withStatus(ref, requestDocuements, statusOk);
  }
}

class PresignRequestDocumentParser {
  static const String documentRequestNode = 'doc';
  static const String idAttribute = 'docid';
  static const String cryptoOperationAttribute = 'cop';
  static const String signatureFormatAttribute = 'sigfrmt';
  static const String messageDigestAlgorithmAttribute = 'mdalgo';
  static const String paramsNode = 'params';
  static const String resultNode = 'result';

  static const String cryptoOperationSign = 'sign';
  static const String cryptoOperationCosign = 'cosign';
  static const String cryptoOperationCountersign = 'countersign';

  static const String defaultCryptoOperation = cryptoOperationSign;

  static TriphaseSignRequestDocument parse(final xml.XmlElement presignRequestDocumentNode) {
    String nodeName = presignRequestDocumentNode.name.toString().toLowerCase();
    if (nodeName != documentRequestNode) {
      throw Exception(
          "Se ha encontrado el elemento '$nodeName' en el listado de documentos de prefirma");
    }

    // Datos de la peticion
    String docId;
    String cryptoOperation;
    String signatureFormat;
    String? messageDigestAlgorithm;
    String? params;

    // Cargamos los atributos
    List<xml.XmlAttribute> atts = presignRequestDocumentNode.attributes;

    var attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception(
          "No se ha encontrado el atributo '$idAttribute' en una petición de prefirma de documento");
    }
    docId = attribute.value;

    attribute = atts
        .firstWhereOrNull((att) => att.name.toString().toLowerCase() == cryptoOperationAttribute);
    cryptoOperation =
        attribute != null ? normalizeCriptoOperationName(attribute.value) : defaultCryptoOperation;

    attribute = atts
        .firstWhereOrNull((att) => att.name.toString().toLowerCase() == signatureFormatAttribute);
    if (attribute == null) {
      throw Exception('No se ha encontrado el atributo obligatorio '
          "'$signatureFormatAttribute' en una peticion de prefirma de documento");
    }
    signatureFormat = attribute.value;

    attribute = atts.firstWhereOrNull(
        (att) => att.name.toString().toLowerCase() == messageDigestAlgorithmAttribute);
    messageDigestAlgorithm = attribute?.value;

    // Cargamos la respuesta de la prefirma
    final List<xml.XmlNode> presignConfigNodes = presignRequestDocumentNode.children;

    final List<xml.XmlElement> elementNodes = presignConfigNodes
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .toList()
        .cast<xml.XmlElement>();

    // Comprobamos el nodo con los parametros
    xml.XmlElement? element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == paramsNode);
    if (element != null) params = element.text;

    // Comprobamos el nodo con el resultado parcial
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == resultNode);
    if (element == null) {
      throw Exception('No se ha encontrado el nodo $resultNode  en la '
          'respuesta de la peticion de prefirma del documento');
    }

    return TriphaseSignRequestDocument(
      docId,
      cryptoOperation,
      signatureFormat,
      messageDigestAlgorithm,
      params,
      TriphaseConfigDataParser.parse(element.children),
    );
  }

  /// Normaliza varios nombres alternativos para las oepraciones criptográficas, dejando uno solo
  /// para cada uno de ellos.
  static String normalizeCriptoOperationName(final String criptoOperation) {
    String normalizedName = criptoOperation;
    if (criptoOperation.toLowerCase() == 'firma') {
      normalizedName = cryptoOperationSign;
    } else if (criptoOperation.toLowerCase() == 'cofirma') {
      normalizedName = cryptoOperationCosign;
    } else if (criptoOperation.toLowerCase() == 'contrafirma') {
      normalizedName = cryptoOperationCountersign;
    }

    return normalizedName;
  }
}

class TriphaseConfigDataParser {
  static const String attributeKey = 'n';

  static TriphaseConfigData parse(final List<xml.XmlNode> params) {
    final TriphaseConfigData config = TriphaseConfigData();

    for (xml.XmlNode param in params) {
      List<xml.XmlAttribute> atts = param.attributes;
      var attribute = atts.firstWhereOrNull(
        (att) => att.name.toString().toLowerCase() == attributeKey,
      );
      final String? key = attribute?.value;
      if (key == null) {
        throw Exception('Se ha indicado un parametro de firma trifasica sin clave');
      }

      debugPrint('Clave: $key Valor: ${param.text}');

      config[key] = param.text.trim();
    }
    return config;
  }
}

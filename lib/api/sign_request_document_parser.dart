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
import 'package:portafirmas/model/sign_request_document.dart';
import 'package:xml/xml.dart' as xml;

/// Analizador de XML con la información requerida para la firma de documentos.
class SignRequestDocumentParser {
  static const String docNode = 'doc';
  static const String idAttribute = 'docid';
  static const String nameNode = 'nm';
  static const String sizeNode = 'sz';
  static const String mimetypeNode = 'mmtp';
  static const String signatureFormatNode = 'sigfrmt';
  static const String messageDigestAlgorithmNode = 'mdalgo';
  static const String paramsNode = 'params';

  static SignRequestDocument parse(final xml.XmlElement signRequestDocumentNode) {
    String nodeName = signRequestDocumentNode.name.toString().toLowerCase();
    if (nodeName != docNode) {
      throw Exception("Se ha encontrado el elemento '$nodeName' en el listado de documentos");
    }

    // Elementos del documento
    String docId;
    String name;
    int? size = -1;
    String mimeType;
    String signatureFormat;
    String messageDigestAlgorithm;
    String? params;

    // Atributos del nodo
    List<xml.XmlAttribute> atts = signRequestDocumentNode.attributes;

    xml.XmlAttribute? attribute =
        atts.firstWhereOrNull((att) => att.name.toString().toLowerCase() == idAttribute);
    if (attribute == null) {
      throw Exception("Existe un documento sin el atributo '$idAttribute'");
    }
    docId = attribute.value;

    // Cargamos los elementos
    final List<xml.XmlNode> childNodes = signRequestDocumentNode.children;
    final List<xml.XmlElement> elementNodes = childNodes
        .where((node) => node.nodeType == xml.XmlNodeType.ELEMENT)
        .toList()
        .cast<xml.XmlElement>();

    // Subject node
    xml.XmlElement? element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == nameNode,
    );
    if (element == null) {
      throw Exception('Existe un documento sin el elemento  $nameNode');
    }
    name = element.text;

    // Size node
    element = elementNodes.firstWhereOrNull(
      (element) => element.name.toString().toLowerCase() == sizeNode,
    );
    if (element != null) {
      size = int.tryParse(element.text);
      if (size == null) {
        debugPrint('No se ha indicado un tamano de documento valido: ${element.text}');
      }
    }

    // Mimetype node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == mimetypeNode);
    if (element == null) {
      throw Exception('Existe un documento sin el elemento $mimetypeNode');
    }
    mimeType = element.text;

    // Signature Format node
    element = elementNodes.firstWhereOrNull(
        (element) => element.name.toString().toLowerCase() == signatureFormatNode);
    if (element == null) {
      throw Exception('Existe un documento sin el elemento $signatureFormatNode');
    }
    signatureFormat = element.text;

    // MessageDigestAlgorithm node
    element = elementNodes.firstWhereOrNull(
        (element) => element.name.toString().toLowerCase() == messageDigestAlgorithmNode);
    if (element == null) {
      throw Exception('Existe un documento sin el elemento $messageDigestAlgorithmNode');
    }
    messageDigestAlgorithm = element.text;

    // Params node
    element = elementNodes
        .firstWhereOrNull((element) => element.name.toString().toLowerCase() == paramsNode);
    if (element != null) {
      params = element.text;
      if ((params.trim().isEmpty || params.trim() == 'null')) {
        params = null;
      }
    }

    return SignRequestDocument(
        docId, name, size, mimeType, signatureFormat, messageDigestAlgorithm, params, null);
  }
}

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

/// Información de un documento de una solicitud de firma.
class RequestDocument {
  /// Identificador del documento
  final String _id;

  /// Nombre del documento
  final String _name;

  /// Tamaño del documento
  final int? _size;

  /// MimeType del documento
  final String _mimeType;

  /// Crea un documento englobado en una petición de firma/multifirma.
  RequestDocument(this._id, this._name, this._size, this._mimeType);

  /// Recupera el identificador del documento.
  String get id => _id;

  /// Recupera el nombre del documento.
  String get name => _name;

  /// Recupera el tamaño del documento.
  int? get size => _size;

  /// Recupera el mimetype del documento.
  String get mimeType => _mimeType;

  @override
  String toString() {
    return name;
  }
}

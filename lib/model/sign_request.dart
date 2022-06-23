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

import 'package:portafirmas/model/request_document.dart';
import 'package:portafirmas/model/sign_request_document.dart';

/// Tipos de petición
enum RequestType {
  /// Firma.
  signature,

  /// Visto bueno.
  approve
}

/// Petición de firma.
class SignRequest {
  /// Estado de solicitud de firma pendiente de firmar.
  static const String stateUnresolved = 'unresolved';

  /// Estado de solicitud de firma ya firmada.
  static const String stateSigned = 'signed';

  /// Estado de solicitud de firma rechazada.
  static const String stateRejected = 'rejected';

  /// Identificador correspondiente a las peticiones aun no vistas.
  static const String viewNew = 'NUEVO';

  /// Identificador correspondiente a las peticiones ya vistas.
  static const String viewRead = 'LEIDO';

  /// Referencia &uacute;nica de la petición.
  final String id;

  /// Asunto de la petición.
  String? subject;

  /// Peticionario de la petición.
  late List<String> senders;

  /// Estado que se debe mostrar de la petici&oacute;n (sin abrir, vista,...).
  String? view;

  /// Para listados que admitan selección, si la petición está seleccionada o no.
  bool selected = false;

  /// Fecha de la petición.
  String? date;

  /// Fecha de la caducidad de la petición.
  String? _expDate;

  /// Prioridad de la petición.
  int priority = 0;

  /// Indica si la petición forma parte de un flujo e trabajo.
  bool workflow = false;

  /// Indica si alguien nos reenvió esta petición.
  bool forward = false;

  /// Tipo de la petición.
  RequestType? type;

  /// Listado de documentos de la petición.
  List<SignRequestDocument>? docs;

  /// Listado de anexos de la petición.
  List<RequestDocument>? _attached;

  /// Construye la petición de firma.
  SignRequest.withId(this.id);

  /// Construye la petición de firma.
  SignRequest(this.id, this.subject, String sender, this.view, this.date, this._expDate,
      this.priority, this.workflow, this.forward, this.type, this.docs, this._attached) {
    senders = [sender];
  }

  /// Recupera el peticionario de la petición.
  String get sender => senders[0];

  /// Recupera la fecha de caducidad de la petición.
  String? get expDate {
    if (_expDate != null && _expDate != 'null') {
      return _expDate;
    }
    return null;
  }

  /// Recupera el listado de anexos de la petición de firma.
  List<RequestDocument>? get attached {
    if (_attached == null) {
      return <RequestDocument>[];
    } else {
      return _attached;
    }
  }

  /// Invierte el estado de selección de la petición.
  void check() {
    selected = !selected;
  }

  /// Establece si la petición ha sido ya vista o no.
  void setView(final bool viewed) {
    view = viewed ? viewRead : viewNew;
  }

  /// Establece la fecha de caducidad.
  /// @param expirationDate Fecha.
  set expDate(String? expDate) => _expDate = expDate;

  /// Establece el listado de anexos.
  /// @param attached Listado de anexos.
  set attached(List<RequestDocument>? attached) => _attached = attached;

  @override
  String toString() {
    return '${subject!} ($id)';
  }
}

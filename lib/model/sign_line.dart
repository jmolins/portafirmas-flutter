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

import 'package:portafirmas/model/sign_line_element.dart';

/// Línea de firma.
class SignLine {
  final String type;
  final List<SignLineElement> signers;

  /// Crea la línea de firma indicando el tipo y los firmantes
  SignLine(this.type, this.signers);

  ///Crea la línea de firma indicando el tipo y sin firmantes.
  SignLine.withType(this.type) : signers = <SignLineElement>[];

  /// Crea la línea de firma indicando los firmantes. Por defecto, se considera que
  /// la operación son de Firma.
  SignLine.withSigners(this.signers) : type = 'FIRMA';

  /// Agrega un nuevo elemento a la línea de firma.
  void addElement(final SignLineElement sle) {
    signers.add(sle);
  }
}

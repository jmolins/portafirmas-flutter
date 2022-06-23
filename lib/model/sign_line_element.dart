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

/// Elemento de la línea de firma.
class SignLineElement {
  final String signer;
  final bool done;

  /// Crea la línea de firma indicando el firmante. Por defecto, se considera que
  /// la operación de firma/visto bueno en cuestión aún no se ha ejecutado.
  SignLineElement.notSigned(this.signer) : done = false;

  /// Crea la línea de firma indicando el firmante y el estado de la firma/visto
  /// bueno en cuestion.
  SignLineElement(this.signer, this.done);

  /// Recupera el firmante de la operación.
  String getSigner() {
    return signer;
  }

  /// Indica si la operación ya se ha realizado.
  bool isDone() {
    return done;
  }
}

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

///
/// Result of a specific operation on a request.
///
class RequestResult {
  /// The request id
  final String? id;

  /// The status of the operation on the request.
  final bool statusOk;

  /// The shared session id
  final String? ssid;

  /// Error associated to the operation
  final String? errorMsg;

  /// Result of an operation.
  RequestResult({this.id, this.statusOk = true, this.ssid, this.errorMsg = ''});
}

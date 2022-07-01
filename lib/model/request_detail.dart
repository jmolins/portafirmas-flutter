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

import 'package:portafirmas/model/sign_line.dart';
import 'package:portafirmas/model/sign_request.dart';

///
/// Datos identificados de una petición para visualizar su detalle.
///
class RequestDetail extends SignRequest {
  String? app;

  String? ref;

  String? message;

  String? signlinestype;

  List<SignLine>? signLines;

  String? rejectReason;

  /// The status of the operation to get the request details.
  /// If false, the error message may be placed in the 'message' field
  bool statusOk = true;

  RequestDetail(String id) : super.withId(id);
}

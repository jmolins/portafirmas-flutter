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

import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/api/approve_response_parser.dart';
import 'package:portafirmas/api/reject_response_parser.dart';
import 'package:portafirmas/api/request_detail_response_parser.dart';
import 'package:portafirmas/api/request_list_response_parser.dart';
import 'package:portafirmas/model/request_detail.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/services/tri_signer.dart';

part 'request_controller.g.dart';

enum ServerRequestState { waiting, quiet }

class RequestController extends _RequestController with _$RequestController {
  RequestController(Api api) : super(api);
}

abstract class _RequestController with Store {
  final Api api;

  @observable
  var unresolvedRequests = ObservableList<SignRequest>();

  // This field will be used for requests in the signed and rejected tab
  // They are treated differently because these tabs are accessed very rarely
  @observable
  var otherRequests = ObservableList<SignRequest>();

  @observable
  RequestDetail? activeRequestDetail;

  /// For operations where a single request is involved
  @observable
  RequestResult requestResult = RequestResult();

  /// For operations where multiple requests are involved
  @observable
  RequestResult requestsResult = RequestResult();

  ServerRequestState eventsState = ServerRequestState.quiet;

  _RequestController(this.api);

  Future<void> getRequests(String requestsState) async {
    // This is to force the widget to show the circular progress indicator
    if (requestsState == SignRequest.stateUnresolved) {
      unresolvedRequests = ObservableList<SignRequest>();
    } else {
      otherRequests = ObservableList<SignRequest>();
    }
    eventsState = ServerRequestState.waiting;
    var response = await api.getSignRequests(requestsState, null, 1, 50);
    var requests =
        RequestListResponseParser.parse(utf8.decode(response.codeUnits)).currentSignRequests;
    eventsState = ServerRequestState.quiet;
    if (requestsState == SignRequest.stateUnresolved) {
      unresolvedRequests = [...requests].asObservable();
    } else {
      otherRequests = [...requests].asObservable();
    }
  }

  Future<void> requestDetail(SignRequest request) {
    return api.getRequestDetail(request.id).then((response) {
      activeRequestDetail = RequestDetailResponseParser.parse(utf8.decode(response.codeUnits));
      // ignore: avoid_types_on_closure_parameters
    }).catchError((Object e) {
      debugPrint('Problema en la respuesta de detalle: ${e.toString()}');
      String error = 'Error en la descarga';
      if (e is NetworkException) {
        error = 'Error de red';
      }
      if (e is ErrorMessageException) {
        error = 'Error al cargar los detalles de la petición';
      }
      // This will make stop waiting for the detail
      activeRequestDetail = null;
      // This will forward the error to display a message
      requestResult = RequestResult(id: request.id, statusOk: false, errorMsg: error);
    });
  }

  // Signs a handful of requests
  Future<void> signRequests(List<SignRequest> requests) async {
    // Create a Stream that will produce a SignRequest every interval of time
    Stream<SignRequest> requestProducer(Duration interval, List<SignRequest> requests) async* {
      for (SignRequest request in requests) {
        yield request;
        await Future<void>.delayed(interval);
      }
    }

    // Emit requests every 200 milliseconds. This has proved to be the correct
    // interval to avoid errors in the server when sending a handful of them.
    requestProducer(const Duration(milliseconds: 200), requests).listen((request) {
      TriSigner.sign(request, api).then((result) {
        requestsResult = result;
      });
    });
  }

  // Signs a single request
  Future<void> signRequest(SignRequest request) {
    return TriSigner.sign(request, api).then((result) {
      requestResult = result;
    });
  }

  // Approve several requests
  Future<void> approveRequests(List<SignRequest>? requests) {
    if (requests != null && requests.isNotEmpty) {
      List<String> requestIds = [];
      for (int i = 0; i < requests.length; i++) {
        requestIds.add(requests[i].id);
      }

      return api.approveRequests(requestIds).then((response) {
        ApproveResponseParser.parse(response).forEach((result) {
          requestsResult = result;
        });
        // ignore: avoid_types_on_closure_parameters
      }).catchError((Object e) {
        debugPrint('Problema en la respuesta aprobación: ${e.toString()}');
        // Format errors are handled individually in the parser
        // Here we consider general errors (network, unanthorized, etc) so
        // we add a false result for all the requests.
        for (SignRequest request in requests) {
          requestsResult = RequestResult(id: request.id, statusOk: false);
        }
      });
    }
    return Future<void>(() {});
  }

  // Approve one request
  Future<void> approveRequest(SignRequest request) {
    // Even for just one request, the api requires a list
    List<String> requestIds = [request.id];

    return api.approveRequests(requestIds).then((response) {
      ApproveResponseParser.parse(response).forEach((result) {
        requestResult = result;
      });
      // ignore: avoid_types_on_closure_parameters
    }).catchError((Object e) {
      debugPrint('Problema en la respuesta aprobación: ${e.toString()}');
      String error = 'Error de firma';
      if (e is NetworkException) {
        error = 'Error de red';
      }
      // Format errors are handled individually in the parser
      // Here we consider general errors (network, unanthorized, etc) so
      // we add a false result for all the requests.
      requestsResult = RequestResult(id: request.id, statusOk: false, errorMsg: error);
    });
  }

  // Reject several requests
  Future<void> rejectRequests(List<SignRequest>? requests, String reason) {
    if (requests != null && requests.isNotEmpty) {
      List<String> requestIds = [];
      for (int i = 0; i < requests.length; i++) {
        requestIds.add(requests[i].id);
      }

      return api.rejectRequests(requestIds, reason).then((response) {
        RejectResponseParser.parse(response).forEach((result) {
          requestsResult = result;
        });
        // ignore: avoid_types_on_closure_parameters
      }).catchError((Object e) {
        debugPrint('Problema en la respuesta de rechazo: ${e.toString()}');
        // Format errors are handled individually in the parser
        // Here we consider general errors (network, unanthorized, etc) so
        // we add a false result for all the requests.
        for (SignRequest request in requests) {
          requestsResult = RequestResult(id: request.id, statusOk: false);
        }
      });
    }
    return Future<void>(() {});
  }

  // Reject one request
  Future<void> rejectRequest(SignRequest request, String reason) {
    // Even for just one request, the api requires a list
    List<String> requestIds = [request.id];

    return api.rejectRequests(requestIds, reason).then((response) {
      RejectResponseParser.parse(response).forEach((result) {
        requestResult = result;
      });
      // ignore: avoid_types_on_closure_parameters
    }).catchError((Object e) {
      debugPrint('Problema en la respuesta rechazo: ${e.toString()}');
      String error = 'Error de firma';
      if (e is NetworkException) {
        error = 'Error de red';
      }
      // Format errors are handled individually in the parser
      // Here we consider general errors (network, unanthorized, etc) so
      // we add a false result for all the requests.
      requestsResult = RequestResult(id: request.id, statusOk: false, errorMsg: error);
    });
  }
}

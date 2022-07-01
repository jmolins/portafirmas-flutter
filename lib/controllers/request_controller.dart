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
import 'package:portafirmas/config.dart';
import 'package:portafirmas/model/request_detail.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/services/tri_signer.dart';
import 'package:synchronized/synchronized.dart';

part 'request_controller.g.dart';

enum PageLoadType { initial, previous, next }

class RequestController extends _RequestController with _$RequestController {
  RequestController(Api api) : super(api);
}

abstract class _RequestController with Store {
  final Api api;

  final _lock = Lock();

  // ----------------- Unresolved requests ------------------------

  @observable
  var unresolvedRequests = ObservableList<SignRequest>();

  @observable
  ObservableFuture? loadUnresolvedRequestsFuture;

  /// The page downloaded from server and loaded into the list
  int unresolvedPresentPage = 1;

  /// Tells if there are more pages in the server beyond the presently loaded one
  bool unresolvedHasMore = false;

  final int _requestPageSize = Config.deafultRequestPageSize;

  /// Result used in operations where a single request is involved.
  @observable
  RequestResult requestResult = RequestResult();

  /// Result used in operations where multiple requests are involved.
  @observable
  RequestResult requestsResult = RequestResult();

  // ----------------- Other requests ---------------------------

  // This field will be used for requests in the signed and rejected tab
  // They are treated differently because these tabs are rarely accessed
  @observable
  var otherRequests = ObservableList<SignRequest>();

  @observable
  ObservableFuture? loadOtherRequestsFuture;

  // ----------------- Active requests -------------------------

  @observable
  RequestDetail? activeRequestDetail;

  _RequestController(this.api);

  @action
  Future<void> loadInitialRequests(String requestsState) {
    if (requestsState == SignRequest.stateUnresolved) {
      return loadUnresolvedRequestsFuture = ObservableFuture<void>(getRequests(requestsState));
    } else {
      return loadOtherRequestsFuture = ObservableFuture<void>(getRequests(requestsState));
    }
  }

  /// Retrieves requests from server.
  Future<void> getRequests(String requestsState,
      [PageLoadType pageLoadType = PageLoadType.initial]) async {
    var pageToRequest = 0;
    if (pageLoadType == PageLoadType.initial) {
      pageToRequest = 1;
    } else if (pageLoadType == PageLoadType.previous) {
      pageToRequest = unresolvedPresentPage - 1;
    } else if (pageLoadType == PageLoadType.next) {
      // If we are on a page
      // - marked as having more requests in the next pages
      // - and the number of requests in the page has decreased after signing them,
      // we will reload the same page
      // Loading next page would have the effect of skipping some requests.
      if (unresolvedHasMore && unresolvedRequests.length < _requestPageSize) {
        pageToRequest = unresolvedPresentPage;
      } else {
        pageToRequest = unresolvedPresentPage + 1;
      }
    }
    var response = await api.getSignRequests(requestsState, null, pageToRequest, _requestPageSize);
    var parsedResult = RequestListResponseParser.parse(utf8.decode(response.codeUnits));
    var requests = parsedResult.currentSignRequests;
    var totalRequests = parsedResult.totalSignRequests;
    if (requestsState == SignRequest.stateUnresolved) {
      unresolvedPresentPage = pageToRequest;
      unresolvedHasMore = pageToRequest * _requestPageSize < totalRequests;
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
      RequestDetail reqDetail = RequestDetail(request.id);
      reqDetail.statusOk = false;
      reqDetail.message = error;
      activeRequestDetail = reqDetail;
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
        // Remove requests from local unresolvedRequests in a synchronized way
        // since results arrive asynchronously from server
        _lock.synchronized(() {
          // If the status is ok (correctly processed), we remove the request from the list
          if (result.statusOk == true) {
            unresolvedRequests.remove(request);
          }
          requestsResult = result;
        });
      });
    });
  }

  // Signs a single request
  Future<void> signRequest(SignRequest request) {
    return TriSigner.sign(request, api).then((result) {
      // If the status is ok (correctly processed), we remove the request from the list
      if (result.statusOk == true) {
        for (var req in unresolvedRequests) {
          if (request.id == req.id) {
            unresolvedRequests.remove(req);
            break;
          }
        }
      }
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
          // Remove requests from local unresolvedRequests in a synchronized way
          // since results arrive asynchronously from parser
          _lock.synchronized(() async {
            if (result.statusOk == true) {
              for (var req in unresolvedRequests) {
                if (result.id == req.id) {
                  unresolvedRequests.remove(req);
                  break;
                }
              }
            }
            requestsResult = result;
          });
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
        // No need to synchronize as there will be just one result
        if (result.statusOk == true) {
          for (var req in unresolvedRequests) {
            if (result.id == req.id) {
              unresolvedRequests.remove(req);
              break;
            }
          }
        }
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
          // Remove requests from local unresolvedRequests in a synchronized way
          // since results arrive asynchronously from parser
          _lock.synchronized(() async {
            if (result.statusOk == true) {
              for (var req in unresolvedRequests) {
                if (result.id == req.id) {
                  unresolvedRequests.remove(req);
                  break;
                }
              }
            }
            requestsResult = result;
          });
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
        // No need to synchronize as there will be just one result
        if (result.statusOk == true) {
          for (var req in unresolvedRequests) {
            if (result.id == req.id) {
              unresolvedRequests.remove(req);
              break;
            }
          }
        }
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

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$RequestController on _RequestController, Store {
  late final _$unresolvedRequestsAtom =
      Atom(name: '_RequestController.unresolvedRequests', context: context);

  @override
  ObservableList<SignRequest> get unresolvedRequests {
    _$unresolvedRequestsAtom.reportRead();
    return super.unresolvedRequests;
  }

  @override
  set unresolvedRequests(ObservableList<SignRequest> value) {
    _$unresolvedRequestsAtom.reportWrite(value, super.unresolvedRequests, () {
      super.unresolvedRequests = value;
    });
  }

  late final _$loadUnresolvedRequestsFutureAtom = Atom(
      name: '_RequestController.loadUnresolvedRequestsFuture',
      context: context);

  @override
  ObservableFuture<dynamic>? get loadUnresolvedRequestsFuture {
    _$loadUnresolvedRequestsFutureAtom.reportRead();
    return super.loadUnresolvedRequestsFuture;
  }

  @override
  set loadUnresolvedRequestsFuture(ObservableFuture<dynamic>? value) {
    _$loadUnresolvedRequestsFutureAtom
        .reportWrite(value, super.loadUnresolvedRequestsFuture, () {
      super.loadUnresolvedRequestsFuture = value;
    });
  }

  late final _$requestResultAtom =
      Atom(name: '_RequestController.requestResult', context: context);

  @override
  RequestResult get requestResult {
    _$requestResultAtom.reportRead();
    return super.requestResult;
  }

  @override
  set requestResult(RequestResult value) {
    _$requestResultAtom.reportWrite(value, super.requestResult, () {
      super.requestResult = value;
    });
  }

  late final _$requestsResultAtom =
      Atom(name: '_RequestController.requestsResult', context: context);

  @override
  RequestResult get requestsResult {
    _$requestsResultAtom.reportRead();
    return super.requestsResult;
  }

  @override
  set requestsResult(RequestResult value) {
    _$requestsResultAtom.reportWrite(value, super.requestsResult, () {
      super.requestsResult = value;
    });
  }

  late final _$otherRequestsAtom =
      Atom(name: '_RequestController.otherRequests', context: context);

  @override
  ObservableList<SignRequest> get otherRequests {
    _$otherRequestsAtom.reportRead();
    return super.otherRequests;
  }

  @override
  set otherRequests(ObservableList<SignRequest> value) {
    _$otherRequestsAtom.reportWrite(value, super.otherRequests, () {
      super.otherRequests = value;
    });
  }

  late final _$loadOtherRequestsFutureAtom = Atom(
      name: '_RequestController.loadOtherRequestsFuture', context: context);

  @override
  ObservableFuture<dynamic>? get loadOtherRequestsFuture {
    _$loadOtherRequestsFutureAtom.reportRead();
    return super.loadOtherRequestsFuture;
  }

  @override
  set loadOtherRequestsFuture(ObservableFuture<dynamic>? value) {
    _$loadOtherRequestsFutureAtom
        .reportWrite(value, super.loadOtherRequestsFuture, () {
      super.loadOtherRequestsFuture = value;
    });
  }

  late final _$activeRequestDetailAtom =
      Atom(name: '_RequestController.activeRequestDetail', context: context);

  @override
  RequestDetail? get activeRequestDetail {
    _$activeRequestDetailAtom.reportRead();
    return super.activeRequestDetail;
  }

  @override
  set activeRequestDetail(RequestDetail? value) {
    _$activeRequestDetailAtom.reportWrite(value, super.activeRequestDetail, () {
      super.activeRequestDetail = value;
    });
  }

  late final _$_RequestControllerActionController =
      ActionController(name: '_RequestController', context: context);

  @override
  Future<void> loadInitialRequests(String requestsState) {
    final _$actionInfo = _$_RequestControllerActionController.startAction(
        name: '_RequestController.loadInitialRequests');
    try {
      return super.loadInitialRequests(requestsState);
    } finally {
      _$_RequestControllerActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
unresolvedRequests: ${unresolvedRequests},
loadUnresolvedRequestsFuture: ${loadUnresolvedRequestsFuture},
requestResult: ${requestResult},
requestsResult: ${requestsResult},
otherRequests: ${otherRequests},
loadOtherRequestsFuture: ${loadOtherRequestsFuture},
activeRequestDetail: ${activeRequestDetail}
    ''';
  }
}

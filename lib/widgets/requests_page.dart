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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/controllers/request_controller.dart';
import 'package:portafirmas/controllers/user_controller.dart';
import 'package:portafirmas/model/request_detail.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/utils.dart';
import 'package:portafirmas/widgets/drawer.dart';
import 'package:portafirmas/widgets/reactions_widget.dart';
import 'package:portafirmas/widgets/request_item.dart';
import 'package:portafirmas/widgets/request_page.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

typedef OnRequestsReceivedCallback = void Function(String requestsXml);

class RequestsPage extends StatefulWidget {
  static const String path = '/requests';

  const RequestsPage({Key? key}) : super(key: key);

  @override
  State createState() => RequestsPageState();
}

class RequestsPageState extends State<RequestsPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  UserController? _userController;
  RequestController? _requestController;

  late TabController _tabController;
  static const int unresolvedRequestsTab = 0;
  static const int signedRequestsTab = 1;
  static const int rejectedRequestsTab = 2;
  int _currentTabIndex = unresolvedRequestsTab;
  final List<Tab> myTabs = <Tab>[
    const Tab(text: 'Pendientes'),
    const Tab(text: 'Terminadas'),
    const Tab(text: 'Rechazadas'),
  ];

  String _currentState = SignRequest.stateUnresolved;

  final TextEditingController _rejectTextFieldController = TextEditingController();

  List<SignRequest> selectedRequests = <SignRequest>[];
  bool _allSelected = false;

  int remainingRequestsCount = 0;
  int errorRequestsCount = 0;
  bool processingDialog = false;

  static const int pageSize = 50;

  // Stream used by a request item to learn if it has been read and needs to update its ui
  final _readController = PublishSubject<String>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: myTabs.length);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context);
    if (_requestController == null) {
      _requestController = Provider.of<RequestController>(context);
      // Launch request to get the list of unresolved requests for tab 0
      _refreshList();
    }
  }

  void _onLogoutResult(RequestResult? result) {
    if (result != null) {
      // First dissmiss the processing dialog
      if (processingDialog) {
        Navigator.of(context).pop();
        processingDialog = false;
      }
      if (result.statusOk) {
        _userController!.api.reset();
        // Dismiss the request page itself
        Navigator.of(context).pop();
      } else {
        showMessage(
          context: context,
          title: 'Error',
          message: result.errorMsg!,
          modal: true,
        );
      }
    }
  }

  Future<void> _onRequestDetail(RequestDetail? requestDetail) async {
    if (processingDialog) {
      Navigator.of(context).pop();
      processingDialog = false;
    }
    if (requestDetail == null) return;

    // Tell the new items that the request has been read
    _readController.add(requestDetail.id);

    var result = await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => RequestPage(
          requestDetail: requestDetail,
          requestState: _currentState,
        ),
      ),
    );
    // If not null (back button) and true (correctly signed), reload the
    if (result != null && result == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showMessage(
          context: context,
          message: 'Petición procesada con ÉXITO',
          modal: true,
          showActions: false,
        );
        _refreshList();
        // Allow two seconds for the user to see the above result message
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop();
        });
      });
    }
  }

  void _onRequestUpdated(SignRequest changedRequest) {
    if (changedRequest.selected) {
      selectedRequests.add(changedRequest);
    } else {
      for (int i = 0; i < selectedRequests.length; i++) {
        if (selectedRequests[i].id == changedRequest.id) {
          selectedRequests.removeAt(i);
        }
      }
    }
    setState(() {});
  }

  void _onRequestsResult(RequestResult result) {
    remainingRequestsCount--;
    if (!result.statusOk) errorRequestsCount++;
    if (remainingRequestsCount <= 0) {
      if (processingDialog) {
        Navigator.of(context).pop();
        processingDialog = false;
      }
      String message =
          errorRequestsCount == 0 ? 'Peticiones procesadas con ÉXITO' : 'ERROR en alguna petición';

      showMessage(
        context: context,
        message: message,
        modal: true,
        showActions: false,
      );
      _refreshList();
      // Allow two seconds for the user to see the above result message
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    }
  }

  void _onRequestResult(RequestResult result) {
    if (processingDialog) {
      Navigator.of(context).pop();
      processingDialog = false;
    }
    if (!result.statusOk) {
      showMessage(
        context: context,
        title: 'Error',
        message: result.errorMsg!,
        modal: true,
      );
    }
  }

  // The list of unresolved requests is permanently stored in the request controller
  // and updated on single or group request handling. Hence, selections are not
  // cleared in that case
  Future<void> _refreshList() {
    return _requestController!.getRequests(_currentState).then((_) {
      setState(() {
        if (_currentState == SignRequest.stateUnresolved) {
          selectedRequests.clear();
          _allSelected = false;
        }
      });
      // ignore: avoid_types_on_closure_parameters
    }).catchError((Object e) {
      setState(() {
        if (_currentState == SignRequest.stateUnresolved) {
          selectedRequests.clear();
        }
      });
      if (e is NetworkException) {
        showMessage(context: context, title: 'Error', message: 'Error de red', modal: true);
      } else if (e is UnauthorizedException) {
        Navigator.of(context).pop();
        showMessage(context: context, title: 'Error', message: 'No autorizado', modal: true);
        _userController!.logout();
      } else {
        showMessage(context: context, title: 'Error', message: 'Error de descarga', modal: true);
      }
    }); //, test: (e) => e is NetworkException);
  }

  String _getContentForConfirmDialog() {
    int countApprove = 0, countSign = 0;

    for (SignRequest request in selectedRequests) {
      if (request.type == RequestType.approve) {
        countApprove++;
      } else {
        countSign++;
      }
    }

    String message = 'Se va a procesar:\n';

    // Peticiones de firma
    if (countSign == 1) {
      message = '$message\n1 petición de firma';
    } else if (countSign > 1) {
      message = '$message\n$countSign peticiones de firma';
    }

    if (countSign > 0 && countApprove > 0) message = '$message y';

    // Peticiones de visto bueno
    if (countApprove == 1) {
      message = '$message\n1 petición de visto bueno';
    } else if (countApprove > 1) {
      message = '$message\n$countApprove peticiones de visto bueno';
    }

    return message;
  }

  Future<String?> _showRejectDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _rejectTextFieldController.clear();
        return AlertDialog(
          title: const Text('Motivo de rechazo'),
          content: TextField(
            controller: _rejectTextFieldController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Motivo'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            TextButton(
              child: const Text('Continuar'),
              onPressed: () {
                Navigator.of(context).pop(_rejectTextFieldController.value.text.trim());
              },
            ),
          ],
        );
      },
    );
  }

  /// In a tab click the new index is set twice, once when the tab is pressed
  /// and again at the end of the animation.
  /// When flipping the page, the index is set just at the end of the animation
  /// In this mathod we try to react to just one change of the index
  /// The list is only refreshed for signed and rejected request. Unresolved
  /// requests list is not emptied when switching tabs
  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      _currentTabIndex = _tabController.index;
      switch (_currentTabIndex) {
        case unresolvedRequestsTab:
          _currentState = SignRequest.stateUnresolved;
          break;
        case signedRequestsTab:
          _currentState = SignRequest.stateSigned;
          break;
        default:
          _currentState = SignRequest.stateRejected;
      }
      // Reload requests other than unresolved ones
      if (_currentTabIndex != unresolvedRequestsTab) {
        _currentTabIndex = _tabController.index;
        //showProcessingDialog(context, 'Actualizando...');
        //processingDialog = true;
        _refreshList();
      }
    }
  }

  void _handleRequestPressed(SignRequest request) {
    showProcessingDialog(context, 'Descargando ...');
    processingDialog = true;
    _requestController!.requestDetail(request);
  }

  Future<void> _handleSign() async {
    if (await showConfirmDialog(context, 'Aviso', _getContentForConfirmDialog())) {
      List<SignRequest> signRequests = [];
      List<SignRequest> approveRequests = [];
      for (SignRequest request in selectedRequests) {
        if (request.type == RequestType.signature) {
          signRequests.add(request);
        } else {
          approveRequests.add(request);
        }
      }
      if (signRequests.isNotEmpty) {
        // ignore: unawaited_futures
        _requestController!.signRequests(signRequests);
      }
      if (approveRequests.isNotEmpty) {
        // ignore: unawaited_futures
        _requestController!.approveRequests(approveRequests);
      }
      remainingRequestsCount = selectedRequests.length;
      errorRequestsCount = 0;
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
    }
  }

  Future<void> _handleReject() async {
    String? reason = await _showRejectDialog(context);
    if (reason != null) {
      // ignore: unawaited_futures
      _requestController!.rejectRequests(selectedRequests, reason);
      remainingRequestsCount = selectedRequests.length;
      errorRequestsCount = 0;
      if (!mounted) return;
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
    }
  }

  void _handleSelectAll() {
    _allSelected = true;
    setState(() {
      selectedRequests.clear();
      for (SignRequest request in _requestController!.unresolvedRequests) {
        request.selected = true;
        selectedRequests.add(request);
      }
    });
  }

  void _handleUnselectAll() {
    _allSelected = false;
    setState(() {
      selectedRequests.clear();
      for (SignRequest request in _requestController!.unresolvedRequests) {
        request.selected = false;
      }
    });
  }

  Widget _buildUnresolvedRequestsPage() {
    return Observer(builder: (_) {
      var requests = _requestController!.unresolvedRequests;
      return Column(
        children: <Widget>[
          Expanded(
            child: () {
              if (_currentTabIndex != unresolvedRequestsTab) {
                return Container();
              } else if (_requestController!.eventsState == ServerRequestState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 4.0),
                );
              } else {
                return RefreshIndicator(
                  onRefresh: _refreshList,
                  child: Scrollbar(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        return RequestItem(
                          request: request,
                          onTap: () => _handleRequestPressed(request),
                          onRequestUpdated: _onRequestUpdated,
                          stream:
                              request.view == SignRequest.viewNew ? _readController.stream : null,
                        );
                      },
                    ),
                  ),
                );
              }
            }(),
          ),
          Container(
            color: Colors.grey[200],
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: selectedRequests.isNotEmpty ? () => _handleReject() : null,
                    style: selectedRequests.isNotEmpty
                        ? OutlinedButton.styleFrom(
                            side: const BorderSide(width: 1.0, color: Colors.teal),
                          )
                        : null,
                    child: const Text('Rechazar'),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(15.0),
                  ),
                  OutlinedButton(
                    onPressed: selectedRequests.isNotEmpty ? () => _handleSign() : null,
                    style: selectedRequests.isNotEmpty
                        ? OutlinedButton.styleFrom(
                            side: const BorderSide(width: 1.0, color: Colors.teal),
                          )
                        : null,
                    child: const Text('Firmar / VºBº'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Used for Signed and Rejected requests pages
  /// For this pages we don't show the [CircularProgressIndicator] because we show
  /// the [ProcessingDialog] when switching pages.
  Widget _buildSignedOrRejectedRequestsPage(int currentTabIndex) {
    return Observer(builder: (_) {
      var requests = _requestController!.otherRequests;
      return Column(
        children: <Widget>[
          Expanded(
            child: () {
              if (_currentTabIndex != currentTabIndex) {
                return Container();
              } else if (_requestController!.eventsState == ServerRequestState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 4.0),
                );
              } else {
                return RefreshIndicator(
                  onRefresh: _refreshList,
                  child: Scrollbar(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: requests.length,
                      itemBuilder: (_, index) {
                        final request = requests[index];
                        return RequestItem(
                          request: request,
                          onTap: () => _handleRequestPressed(request),
                          onRequestUpdated: null,
                        );
                      },
                    ),
                  ),
                );
              }
            }(),
          ),
        ],
      );
    });
  }

  Future<void> _confirmAndLogout() async {
    if (await showConfirmDialog(context, null, '¿Quieres cerrar la sesión?')) {
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
      // ignore: unawaited_futures
      _userController!.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactionsBuilder(
      builder: (context) {
        return [
          reaction(
            (_) => _userController!.logoutResult,
            // ignore: avoid_types_on_closure_parameters
            (RequestResult? result) {
              _onLogoutResult(result);
            },
          ),
          reaction(
            (_) => _requestController!.activeRequestDetail,
            // ignore: avoid_types_on_closure_parameters
            (RequestDetail? detail) {
              _onRequestDetail(detail);
            },
          ),
          reaction(
            (_) => _requestController!.requestsResult,
            // ignore: avoid_types_on_closure_parameters
            (RequestResult? result) {
              // Result will always be a real instance sent from RequestController
              _onRequestsResult(result!);
            },
          ),
          reaction(
            (_) => _requestController!.requestResult,
            // ignore: avoid_types_on_closure_parameters
            (RequestResult? result) {
              // Result will always be a real instance sent from RequestController
              _onRequestResult(result!);
            },
          ),
        ];
      },
      child: WillPopScope(
        onWillPop: () async {
          // ignore: unawaited_futures
          _confirmAndLogout();
          // Here we return false as it will be handled when receiving the logout event
          return false;
        },
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('Peticiones'),
            centerTitle: true,
            //systemOverlayStyle: SystemUiOverlayStyle.dark,
            elevation: 0.0,
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar',
                onPressed: () {
                  //showProcessingDialog(context, 'Actualizando ...');
                  //processingDialog = true;
                  _refreshList();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: myTabs,
              labelColor: Colors.white,
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildUnresolvedRequestsPage(),
              _buildSignedOrRejectedRequestsPage(signedRequestsTab),
              _buildSignedOrRejectedRequestsPage(rejectedRequestsTab),
            ],
          ),
          drawer: PortafirmasDrawer(
            onTapFilters: () {},
            onTapSelectAll: _allSelected ? null : _handleSelectAll,
            onTapUnselectAll: _allSelected ? _handleUnselectAll : null,
            onTapLogout: () async {
              Navigator.pop(context);
              // ignore: unawaited_futures
              _confirmAndLogout();
            },
            config: config!,
          ),
        ),
      ),
    );
  }
}

class KeepAlivePage extends StatefulWidget {
  final Widget? child;

  const KeepAlivePage({Key? key, this.child}) : super(key: key);

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin<KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child!;
  }
}

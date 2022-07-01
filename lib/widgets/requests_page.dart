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
import 'package:synchronized/synchronized.dart';

typedef OnRequestsReceivedCallback = void Function(String requestsXml);

const String addOperation = 'add';
const String removeOperation = 'remove';
const String clearOperation = 'clear';
const String selectAllOperation = 'select_all';

class RequestsPage extends StatefulWidget {
  static const String path = '/requests';

  const RequestsPage({Key? key}) : super(key: key);

  @override
  State createState() => RequestsPageState();
}

class RequestsPageState extends State<RequestsPage> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  var unresolvedRefreshkey = GlobalKey<RefreshIndicatorState>();
  var otherRefreshkey = GlobalKey<RefreshIndicatorState>();

  final _lock = Lock();

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

  final _selectedRequests = <SignRequest>[];
  final _previousSelectedRequests = <String>[];
  bool _allSelected = false;

  int remainingRequestsCount = 0;
  int errorRequestsCount = 0;
  bool processingDialog = false;

  // The page downloaded from server
  PageLoadType _pageLoadType = PageLoadType.initial;

  // When the list refresh is called from the RefreshIndicator itself by pulling down
  bool _refreshCalledFromRefreshIndicator = true;

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
      _requestController!.loadInitialRequests(SignRequest.stateUnresolved);
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

    if (requestDetail.statusOk == false) {
      await showMessage(
        context: context,
        title: 'Error',
        message: requestDetail.message,
        modal: true,
      );
      return;
    }

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
      setState(() {
        // remove from selected
        _maintainSelectedRequests(removeOperation, null, requestDetail.id);
      });
      unawaited(showMessage(
        context: context,
        message: 'Petición procesada con ÉXITO',
        modal: true,
        showActions: false,
      ));
      // Allow two seconds for the user to see the above result message
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    }
  }

  void _onRequestUpdated(SignRequest changedRequest) {
    setState(() {
      if (changedRequest.selected) {
        _maintainSelectedRequests(addOperation, changedRequest);
      } else {
        _maintainSelectedRequests(removeOperation, changedRequest);
      }
    });
  }

  void _onRequestsResult(RequestResult result) {
    // Do this in a synchronized way since results arrive asynchronously from controller
    _lock.synchronized(() {
      remainingRequestsCount--;
      // If correctly processed, remove the request form the selection
      if (result.statusOk) {
        _maintainSelectedRequests(removeOperation, null, result.id);
      } else {
        errorRequestsCount++;
      }
    });
    if (remainingRequestsCount <= 0) {
      if (processingDialog) {
        Navigator.of(context).pop();
        processingDialog = false;
      }
      String message = errorRequestsCount == 0
          ? (_selectedRequests.length == 1
              ? 'La petición se ha procesado correctamente'
              : 'Las peticiones se han procesado correctamente')
          : (_selectedRequests.length == 1
              ? 'Error al procesar la petición'
              : 'Error al procesar alguna de las peticiones');

      showMessage(
        context: context,
        message: message,
        modal: true,
        showActions: false,
      );
      // Allow two seconds for the user to see the above result message
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    }
  }

  void _maintainSelectedRequests(String operation, [SignRequest? request, String? requestId]) {
    if (operation == addOperation) {
      _selectedRequests.add(request!);
    } else if (operation == removeOperation) {
      for (int i = 0; i < _selectedRequests.length; i++) {
        String? id = requestId ?? request!.id;
        if (_selectedRequests[i].id == id) {
          _selectedRequests.removeAt(i);
        }
      }
    } else if (operation == selectAllOperation) {
      _allSelected = true;
      _selectedRequests.clear();
      for (SignRequest request in _requestController!.unresolvedRequests) {
        request.selected = true;
        _selectedRequests.add(request);
      }
    } else if (operation == clearOperation) {
      _allSelected = false;
      _selectedRequests.clear();
      for (SignRequest request in _requestController!.unresolvedRequests) {
        request.selected = false;
      }
    }
    _previousSelectedRequests.clear();
    for (var request in _selectedRequests) {
      _previousSelectedRequests.add(request.id);
    }
  }

  // Upon reloading requests from server, the selections are updated based
  // on the requests that were selected before the refresh
  void _reselectNewRequests() {
    _selectedRequests.clear();
    _allSelected = false;
    var requests = _requestController!.unresolvedRequests;
    // Set new selected requests based on previous selections
    for (var request in requests) {
      if (_previousSelectedRequests.contains(request.id)) {
        request.selected = true;
        _selectedRequests.add(request);
      }
    }
    // Reset previous selections
    // Previously selected requests might have independently disappeared on the server
    _previousSelectedRequests.clear();
    for (var request in _selectedRequests) {
      _previousSelectedRequests.add(request.id);
    }
  }

  void _onRefreshList({PageLoadType pageLoadType = PageLoadType.initial}) {
    if (_currentState == SignRequest.stateUnresolved) {
      _pageLoadType = pageLoadType;
      _refreshCalledFromRefreshIndicator = false;
      unresolvedRefreshkey.currentState!.show();
    } else {
      otherRefreshkey.currentState!.show();
    }
  }

  // The list of unresolved requests is permanently stored in the request controller
  // and updated on single or group request handling. Hence, selections are not
  // cleared in that case
  Future<void> _refreshList() {
    if (_refreshCalledFromRefreshIndicator) {
      _pageLoadType = PageLoadType.initial;
    }
    _refreshCalledFromRefreshIndicator = true;
    return _requestController!.getRequests(_currentState, _pageLoadType).then((_) {
      if (_currentState == SignRequest.stateUnresolved) {
        // Select the newly loaded requests based on the selections previously available
        _reselectNewRequests();
      }
      // ignore: avoid_types_on_closure_parameters
    }).catchError((Object e) {
      if (_currentState == SignRequest.stateUnresolved) {
        setState(() {
          _maintainSelectedRequests(clearOperation, null);
        });
      }
      if (e is NetworkException) {
        showMessage(context: context, title: 'Error', message: 'Error de red', modal: true);
      } else if (e is UnauthorizedException) {
        Navigator.of(context).pop();
        showMessage(context: context, title: 'Error', message: 'No autorizado', modal: true);
        _userController!.logout();
      } else {
        showMessage(context: context, title: 'Error', message: 'Error de descarga', modal: true);
      }
    });
  }

  String _getContentForConfirmDialog() {
    int countApprove = 0, countSign = 0;

    for (SignRequest request in _selectedRequests) {
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
        _requestController!.loadInitialRequests(_currentState);
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
      for (SignRequest request in _selectedRequests) {
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
      remainingRequestsCount = _selectedRequests.length;
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
      _requestController!.rejectRequests(_selectedRequests, reason);
      remainingRequestsCount = _selectedRequests.length;
      errorRequestsCount = 0;
      if (!mounted) return;
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
    }
  }

  void _handleSelectAll() {
    setState(() {
      _maintainSelectedRequests(selectAllOperation, null);
    });
  }

  void _handleUnselectAll() {
    setState(() {
      _maintainSelectedRequests(clearOperation, null);
    });
  }

  Widget _buildRequestItem(SignRequest request) {
    return RequestItem(
      request: request,
      onTap: () => _handleRequestPressed(request),
      onRequestUpdated: _onRequestUpdated,
      stream: request.view == SignRequest.viewNew ? _readController.stream : null,
    );
  }

  Widget _buildNavigationItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
      child: Row(
        children: [
          if (_requestController!.unresolvedPresentPage > 1) ...[
            ElevatedButton(
              onPressed: () {
                _onRefreshList(pageLoadType: PageLoadType.previous);
              },
              child: const Icon(Icons.keyboard_double_arrow_left),
            )
          ],
          Expanded(child: Container()),
          if (_requestController!.unresolvedHasMore) ...[
            ElevatedButton(
              onPressed: () {
                _onRefreshList(pageLoadType: PageLoadType.next);
              },
              child: const Icon(Icons.keyboard_double_arrow_right),
            )
          ],
        ],
      ),
    );
  }

  Widget _buildUnresolvedRequestsPage() {
    return Observer(builder: (_) {
      var requests = _requestController!.unresolvedRequests;
      var itemCount = requests.length;
      bool lastItemIsNavigation = false;
      // If navigation is shown, add a last item to the list
      if (_requestController!.unresolvedHasMore || _requestController!.unresolvedPresentPage > 1) {
        lastItemIsNavigation = true;
        itemCount = requests.length + 1;
      }
      return Column(
        children: <Widget>[
          Expanded(
            child: () {
              if (_currentTabIndex != unresolvedRequestsTab) {
                return Container();
              } else {
                switch (_requestController!.loadUnresolvedRequestsFuture!.status) {
                  case FutureStatus.pending:
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 4.0),
                    );
                  case FutureStatus.fulfilled:
                    return RefreshIndicator(
                      key: unresolvedRefreshkey,
                      onRefresh: _refreshList,
                      child: Scrollbar(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: itemCount,
                          itemBuilder: (_, index) {
                            return index < itemCount - 1 ||
                                    (index == itemCount - 1 && !lastItemIsNavigation)
                                ? _buildRequestItem(requests[index])
                                : _buildNavigationItem();
                          },
                        ),
                      ),
                    );
                  case FutureStatus.rejected:
                    return const Text('Oops something went wrong');
                }
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
                    onPressed: _selectedRequests.isNotEmpty ? () => _handleReject() : null,
                    style: _selectedRequests.isNotEmpty
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
                    onPressed: _selectedRequests.isNotEmpty ? () => _handleSign() : null,
                    style: _selectedRequests.isNotEmpty
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
              } else {
                switch (_requestController!.loadOtherRequestsFuture!.status) {
                  case FutureStatus.pending:
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 4.0),
                    );
                  case FutureStatus.fulfilled:
                    return RefreshIndicator(
                      key: otherRefreshkey,
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
                  case FutureStatus.rejected:
                    return const Text('Oops something went wrong');
                }
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
                  _onRefreshList();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: myTabs,
              labelColor: const Color.fromRGBO(255, 255, 255, 1),
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

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
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/controllers/request_controller.dart';
import 'package:portafirmas/model/request_detail.dart';
import 'package:portafirmas/model/request_document.dart';
import 'package:portafirmas/model/request_result.dart';
import 'package:portafirmas/model/sign_line.dart';
import 'package:portafirmas/model/sign_line_element.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/sign_request_document.dart';
import 'package:portafirmas/utils.dart';
import 'package:portafirmas/widgets/document_item.dart';
import 'package:portafirmas/widgets/reactions_widget.dart';
import 'package:provider/provider.dart';

typedef OnRequestsReceivedCallback = void Function(String requestsXml);

class RequestPage extends StatefulWidget {
  static const String path = '/request';

  final RequestDetail requestDetail;
  final String requestState;

  const RequestPage({
    Key? key,
    required this.requestDetail,
    required this.requestState,
  }) : super(key: key);

  @override
  State createState() => RequestPageState();
}

class RequestPageState extends State<RequestPage> {
  static const String signFormatPades = 'PAdES';
  static const String signFormatPdf = 'PDF';
  static const String signFormatXades = 'XAdES';

  static const String padesExtension = 'pdf';
  static const String cadesExtension = 'cades';
  static const String xadesExtension = 'xades';

  static const platform = MethodChannel('portafirmas.gob.es');

  RequestController? _requestController;

  final TextEditingController _rejectTextFieldController = TextEditingController();
  bool processingDialog = false;

  // Stores the task id of the last downloaded document.
  String? taskId;

  String? _downloadPath;
  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();

    _bindBackgroundIsolate();

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestController ??= Provider.of<RequestController>(context);
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    if (taskId != null) {
      FlutterDownloader.remove(taskId: taskId!, shouldDeleteContent: true);
    }
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      debugPrint('UI Isolate Callback: $data');
      var id = data[0] as String;
      var status = data[1] as DownloadTaskStatus;

      if (status == DownloadTaskStatus.complete) {
        if (processingDialog == true) Navigator.of(context).pop();
        FlutterDownloader.open(taskId: id);
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
    debugPrint(
        'Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
    send!.send([id, status, progress]);
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
        message: result.errorMsg!.isEmpty ? null : result.errorMsg!,
        modal: true,
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<String?> _showRejectDialog(BuildContext context) async {
    return showDialog<String?>(
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

  Future<void> _handleReject() async {
    String? reason = await _showRejectDialog(context);
    if (reason != null) {
      // ignore: unawaited_futures
      _requestController!.rejectRequest(widget.requestDetail, reason);
      if (!mounted) return;
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
    }
  }

  Future<void> _handleSign() async {
    String message;
    if (widget.requestDetail.type == RequestType.signature) {
      message = 'Se va a proceder a firmar esta petición. ¿Desea continuar?';
    } else {
      message = 'Se va a dar el visto bueno a esta petición. ¿Desea continuar?';
    }
    if (await showConfirmDialog(context, 'Aviso', message)) {
      // ignore: unawaited_futures
      showProcessingDialog(context, 'Procesando ...');
      processingDialog = true;
      if (widget.requestDetail.type == RequestType.signature) {
        // ignore: unawaited_futures
        _requestController!.signRequest(widget.requestDetail);
      } else {
        // ignore: unawaited_futures
        _requestController!.approveRequest(widget.requestDetail);
      }
    }
  }

  Widget _buildTitleSection(String title) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.only(top: 20.0, left: 10.0, bottom: 10.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16.0,
          color: Colors.teal[600],
        ),
      ),
    );
  }

  Widget _buildLightText(String text) {
    return Text(
      text,
      style: const TextStyle(color: Colors.black54),
    );
  }

  TableRow _buildInfoRow(String key, Widget value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: _buildLightText(key),
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: value,
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    var tableRows = <TableRow>[];
    tableRows.add(_buildInfoRow(
      'Asunto:',
      Text(
        widget.requestDetail.subject!,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ));
    var senders = <Widget>[];
    for (String sender in widget.requestDetail.senders) {
      senders.add(
        Text(sender, style: const TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    tableRows.add(_buildInfoRow(
      'De:',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: senders,
      ),
    ));
    tableRows.add(_buildInfoRow(
      'Fecha:',
      _buildLightText(widget.requestDetail.date!),
    ));
    String? expDate = widget.requestDetail.expDate;
    if (expDate != null && expDate != '') {
      tableRows.add(_buildInfoRow(
        'Caduca:',
        _buildLightText(expDate),
      ));
    }
    String? reference = widget.requestDetail.ref;
    if (reference != null && reference != '') {
      tableRows.add(_buildInfoRow(
        'Referencia:',
        _buildLightText(reference),
      ));
    }
    tableRows.add(_buildInfoRow(
      'Aplicación:',
      _buildLightText(widget.requestDetail.app!),
    ));
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Table(
        columnWidths: const <int, TableColumnWidth>{
          0: FixedColumnWidth(100.0),
        },
        children: tableRows,
      ),
    );
  }

  Widget _buildMessageSection() {
    String? message = widget.requestDetail.message;
    if (message != null && message != '') {
      var items = <Widget>[];
      items.add(_buildTitleSection('Mensaje'));
      items.add(Padding(
        padding: const EdgeInsets.only(
          top: 10.0,
          left: 15.0,
          right: 10.0,
          bottom: 20.0,
        ),
        child: Text(message.replaceAll('<br/>', '\n')),
      ));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      );
    } else {
      return Container();
    }
  }

  Future<void> _onDocumentItemPressed(String id, String name, DocumentType docType) async {
    if (!config!.storagePermissionReady) {
      config!.storagePermissionReady = await config!.checkStoragePermission();
    }
    if (config!.storagePermissionReady) {
      // Check if local temp path exists
      _downloadPath ??= await config!.tempStoragePath;

      // Get the correct url for the file type
      String url;
      if (docType == DocumentType.signature) {
        url = Api.getPreviewSignatureUrl(id);
      } else if (docType == DocumentType.report) {
        url = Api.getPreviewReportUrl(id);
      } else {
        url = Api.getPreviewDocumentUrl(id);
      }

      // For Android and iOS we use Flutter_Downloader plugin
      if (!Platform.isWindows) {
        if (docType == DocumentType.signature) {
          if (!mounted) return;
          if (!(await showConfirmDialog(
            context,
            '¿Desea descargar la firma',
            'La firma del documento se almacenará en su directorio '
                'de descargas.',
          ))) return;
          // In iOS we create a Download directory in application space
          if (Platform.isIOS) {
            _downloadPath = '${await config!.applicationPath}/Download';
            // In iOS the directory might not exist
            final dir = Directory(_downloadPath!);
            if (!dir.existsSync()) dir.createSync();
          }
          // In Android we get the global download directory
          else {
            _downloadPath = await platform.invokeMethod('getDownloadsDirectory');
            if (_downloadPath == null) {
              return;
            }
          }
        }
        if (!mounted) return;
        // ignore: unawaited_futures
        showProcessingDialog(context, 'Descargando...');
        processingDialog = true;

        // In Android, the operation fails if the same file (or another file with the same name)
        // has already been downloded previously (without leaving this screen)
        // To avoid this error (and simplify) we delete any previously downloaded document.
        // TODO(jmolins): Check if the file exists (and needs to be deleted) on first download.
        if (taskId != null) {
          await FlutterDownloader.remove(taskId: taskId!, shouldDeleteContent: true);
        }

        taskId = await FlutterDownloader.enqueue(
            url: url,
            fileName: name,
            headers: _requestController!.api.headers,
            savedDir: _downloadPath!,
            showNotification: false,
            openFileFromNotification: false);
      }
      // For Windows we use directly dart to download file
      else {
        if (docType == DocumentType.signature) {
          Directory? downloadsDirectory = await getExternalStorageDirectory();
          _downloadPath = downloadsDirectory!.path.trim();
        }
        String filePath = '$_downloadPath/$name';

        if (!mounted) return;
        // ignore: unawaited_futures
        showProcessingDialog(context, 'Descargando...');
        processingDialog = true;

        // ignore: unawaited_futures
        HttpClient().getUrl(Uri.parse(url)).then((request) {
          _requestController!.api.headers.forEach((key, value) {
            request.headers.add(key, value);
          });
          return request.close();
        }).then((response) async {
          await response.pipe(File(filePath).openWrite());
          if (!mounted) return;
          if (processingDialog) {
            Navigator.of(context).pop();
            processingDialog = false;
          }
          // ignore: unawaited_futures
          if (docType != DocumentType.signature) FlutterDownloader.open(taskId: filePath);
        });
      }
    }
  }

  Widget _buildDocumentsSection() {
    var items = <Widget>[];
    items.add(_buildTitleSection('Documentos'));
    List<SignRequestDocument> docs = widget.requestDetail.docs!;
    for (SignRequestDocument doc in docs) {
      items.add(DocumentItem(
        name: doc.name,
        mimetype: doc.mimeType,
        size: doc.size!,
        type: DocumentType.document,
        onTap: () {
          _onDocumentItemPressed(doc.id, doc.name, DocumentType.document);
        },
      ));
    }
    List<RequestDocument> attachments = widget.requestDetail.attached!;
    if (widget.requestDetail.attached!.isNotEmpty) {
      items.add(_builDocsHeader('Adjuntos'));
      for (RequestDocument attachment in attachments) {
        items.add(DocumentItem(
            name: attachment.name,
            mimetype: attachment.mimeType,
            size: attachment.size!,
            type: DocumentType.attachment,
            onTap: () {
              _onDocumentItemPressed(attachment.id, attachment.name, DocumentType.document);
            }));
      }
    }
    if (widget.requestState == SignRequest.stateSigned &&
        widget.requestDetail.type == RequestType.signature) {
      items.add(_builDocsHeader('Firmas'));
      for (SignRequestDocument doc in docs) {
        String name = '${doc.name}_firmado.${_getSignatureExtension(doc.signFormat)}';
        items.add(DocumentItem(
            name: name,
            mimetype: doc.mimeType,
            size: doc.size!,
            type: DocumentType.signature,
            onTap: () {
              _onDocumentItemPressed(doc.id, name, DocumentType.signature);
            }));
      }
      items.add(_builDocsHeader('Informes de firma'));
      for (SignRequestDocument doc in docs) {
        String name = 'report_${doc.name}.pdf';
        items.add(DocumentItem(
            name: name,
            mimetype: doc.mimeType,
            size: doc.size!,
            type: DocumentType.report,
            onTap: () {
              _onDocumentItemPressed(doc.id, name, DocumentType.report);
            }));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }

  String _getSignatureExtension(final String signFormat) {
    String ext;
    if (signFormat.toLowerCase() == signFormatPades.toLowerCase() ||
        signFormat.toLowerCase() == signFormatPdf.toLowerCase()) {
      ext = padesExtension;
    } else if (signFormat.toLowerCase() == signFormatXades.toLowerCase()) {
      ext = xadesExtension;
    } else {
      ext = cadesExtension;
    }
    return ext;
  }

  Widget _builDocsHeader(String title) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0, left: 10.0, bottom: 5.0),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal[600],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiversSection() {
    var items = <Widget>[];
    items.add(
      Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Text('Firma en ${widget.requestDetail.signlinestype}'),
      ),
    );
    var lines = widget.requestDetail.signLines!;
    int lineCount = 0;
    for (SignLine line in lines) {
      lineCount++;
      items.add(Padding(
        padding: const EdgeInsets.only(top: 15.0),
        child: Text(
          'Línea $lineCount de ${line.type}',
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
        ),
      ));
      items.add(Container(height: 1.0, color: Colors.grey[400]));
      var signers = line.signers;
      for (SignLineElement signElement in signers) {
        items.add(Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.person, color: Colors.teal),
              ),
              Text(signElement.getSigner()),
            ],
          ),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReactionsBuilder(
      builder: (context) {
        return [
          reaction(
            (_) => _requestController!.requestResult,
            // ignore: avoid_types_on_closure_parameters
            (RequestResult? result) {
              // Result will always be a real instance sent from RequestController
              _onRequestResult(result!);
            },
          )
        ];
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de la petición'),
          centerTitle: true,
          //systemOverlayStyle: SystemUiOverlayStyle.dark,
          elevation: 0.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: ListView(children: <Widget>[
                    _buildInfoSection(),
                    _buildMessageSection(),
                    _buildDocumentsSection(),
                    _buildTitleSection('Destinatarios'),
                    _buildReceiversSection(),
                    Container(height: 30.0),
                  ]),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: const Border(
                    top: BorderSide(width: 1.0, color: Color(0xFFDFDFDF)),
                  )),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: _handleReject,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(width: 1.0, color: Colors.teal),
                      ),
                      child: const Text('Rechazar'),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(15.0),
                    ),
                    OutlinedButton(
                      onPressed: _handleSign,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(width: 1.0, color: Colors.teal),
                      ),
                      child: const Text('Firmar / VºBº'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

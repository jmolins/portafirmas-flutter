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

import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:portafirmas/controllers/user_controller.dart';
import 'package:portafirmas/utils.dart';
import 'package:provider/provider.dart';

import 'ios_certificate_password.dart';

class IOSCertificateFiles extends StatefulWidget {
  const IOSCertificateFiles({Key? key}) : super(key: key);

  @override
  IOSCertificateFilesState createState() => IOSCertificateFilesState();
}

class IOSCertificateFilesState extends State<IOSCertificateFiles> {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  UserController? _userController;

  // iOS version 11 allows to browse local folders for certificate files
  bool localBrowsingAllowed = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context);
    // Launch request to get the list of available certificates
    _userController!.getAddedIosCertificates();
    // Launch request to get the list of available certificates
    deviceInfo.iosInfo.then((iosInfo) {
      localBrowsingAllowed = iosInfo.systemVersion.split('.')[0].compareTo('11') >= 0;
      _userController!.getCertificateFiles();
    });
  }

  Future<void> _handleSubmitted(String filename) async {
    String? result = await Navigator.push(
        context,
        MaterialPageRoute<String>(
          builder: (context) => IOSCertificatePassword(
            filename: filename,
          ),
        ));
    if (result != null && mounted) {
      // ignore: unawaited_futures
      showMessage(context: context, title: '', message: result, modal: true);
    }
  }

  Widget _buildNoFilesContent() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
              'La aplicación está solicitando acceso a su almacén de '
              'certificados y no dispone de ninguno registrado.',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 15.0),
              child: localBrowsingAllowed
                  ? const Text('Opción 1:',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700))
                  : Container()),
          const Text('1. Conecte su dispositivo a su PC o Mac.'),
          const Text('2. Localice el certifiado que desea instalar'
              ' ...(debe conocer el pin del certificado).'),
          const Text('3. En iTunes seleccione su certificado y '
              'arrástrelo a la ventana de documentos.'),
          const Text('4. Vuelva a esta pantalla y regístrelo en el '
              'almacén del dispositivo.'),
          localBrowsingAllowed
              ? const Padding(
                  padding: EdgeInsets.only(top: 20.0, bottom: 15.0),
                  child: Text('Opción 2:',
                      style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700)),
                )
              : Container(),
          localBrowsingAllowed ? const Text('Browse files') : Container(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: <Widget>[
        Observer(
          builder: (_) {
            var files = _userController!.files;
            if (files == null) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 4.0),
              );
            } else {
              if (files.isEmpty) {
                return _buildNoFilesContent();
              } else {
                return Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: <Widget>[
                      const Text(
                          'Lista de certificados almacenados en su dispositivo. '
                          'Seleccione el certificado que desea registrar.',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const Padding(padding: EdgeInsets.all(10.0)),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: GestureDetector(
                                onTap: () => _handleSubmitted(files[index]),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.black26,
                                        //width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(15.0),
                                    child: Row(
                                      children: <Widget>[
                                        Text(files[index]),
                                        const Spacer(),
                                        const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                )),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select certificate file'),
      ),
      body: _buildBody(),
    );
  }
}

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
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobx/mobx.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/controllers/user_controller.dart';
import 'package:portafirmas/model/validation_login_result.dart';
import 'package:portafirmas/utils.dart';
import 'package:portafirmas/widgets/ios/ios_certificates.dart';
import 'package:portafirmas/widgets/reactions_widget.dart';
import 'package:portafirmas/widgets/requests_page.dart';
import 'package:portafirmas/widgets/servers_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String noCertificate = ' PULSA PARA SELECCIONAR ...';

  UserController? _userController;

  String? _certificateSubject = noCertificate;

  bool _accessButtonEnabled = true;

  bool processingDialogShown = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) _checkIosCertificate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context);
  }

  void _checkIosCertificate() {
    _certificateSubject = config!.prefs.getString(Config.certificateSubjectKey);
    _accessButtonEnabled = true;
    if (_certificateSubject == null) {
      _certificateSubject = noCertificate;
      _accessButtonEnabled = false;
    }
  }

  Future<void> _onLogin(ValidationLoginResult result) async {
    if (result.statusOk) {
      // This is called after the certificate has been loaded
      if (result.errorMsg == 'certificate_loaded') {
        // ignore: unawaited_futures
        showProcessingDialog(context, 'Conectando...');
        processingDialogShown = true;
      }
      // And this is after successful login
      else {
        if (processingDialogShown) {
          Navigator.of(context).pop();
        }
        // When login successful, load the requests page
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) {
            return const RequestsPage();
          },
        ));
      }
    } else {
      if (processingDialogShown) {
        Navigator.of(context).pop();
      }
      await showMessage(
        context: context,
        title: 'Error',
        message: result.errorMsg!,
        modal: true,
      );
    }
    setState(() {});
  }

  Future<void> _handleSelectServer() async {
    await Navigator.push(
        context,
        MaterialPageRoute<String>(
          builder: (context) => const ServersPage(),
        ));
    setState(() {});
  }

  Future<void> _handleSelectIOSCertificate() async {
    String? result = await Navigator.push(
        context,
        MaterialPageRoute<String>(
          settings: const RouteSettings(name: 'ioscertificates'),
          builder: (context) => const IOSCertificates(),
        ));
    if (result != null) {
      setState(() {
        _checkIosCertificate();
      });
    }
  }

  Widget _buildConfigItem(
      BuildContext context, String title, String? contentText, GestureTapCallback tap) {
    return Padding(
      padding: const EdgeInsets.only(top: 25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w400)),
          Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
            child: GestureDetector(
              onTap: tap,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFDDDDDD)),
                    bottom: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 12.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          contentText!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget? _buildIOSCertificate(BuildContext context) {
    if (Platform.isIOS) {
      return _buildConfigItem(
          context, 'Certificado:', _certificateSubject, _handleSelectIOSCertificate);
    } else {
      return null;
    }
  }

  Widget _buildAccessButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 45.0),
      child: ElevatedButton(
        onPressed: _accessButtonEnabled ? () => _userController!.login() : null,
        child: const Text('Acceder'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReactionsBuilder(
      builder: (context) {
        return [
          reaction(
            (_) => _userController!.loginResult,
            // ignore: avoid_types_on_closure_parameters
            (ValidationLoginResult? result) {
              _onLogin(result!);
            },
          ),
        ];
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portafirmas'),
          centerTitle: true,
          elevation: 0.0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: <Widget>[
              const Padding(padding: EdgeInsets.all(10.0)),
              _buildConfigItem(context, 'Servidor:', config!.serverName, _handleSelectServer),
              _buildIOSCertificate(context) ?? Container(),
              _buildAccessButton(),
            ],
          ),
        ),
      ),
    );
  }
}

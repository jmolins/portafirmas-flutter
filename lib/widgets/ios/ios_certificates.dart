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

import 'package:portafirmas/config.dart';
import 'package:portafirmas/controllers/user_controller.dart';

import 'package:portafirmas/utils.dart';
import 'package:provider/provider.dart';
import 'ios_certificate_files.dart';

class IOSCertificates extends StatefulWidget {
  const IOSCertificates({Key? key}) : super(key: key);

  @override
  IOSCertificatesState createState() => IOSCertificatesState();
}

class IOSCertificatesState extends State<IOSCertificates> {
  UserController? _userController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context);
    // Launch request to get the list of available certificates
    _userController!.getAddedIosCertificates();
  }

  void _refreshCertificateList() {
    setState(() {
      _userController!.getAddedIosCertificates();
    });
  }

  Future _onAddCertificate() async {
    String? result = await Navigator.push(
        context,
        MaterialPageRoute<String>(
          builder: (context) => const IOSCertificateFiles(),
        ));
    if (result == null) {
      _refreshCertificateList();
    }
  }

  Widget _buildBody() {
    return Column(
      children: <Widget>[
        Observer(
          builder: (_) {
            var certificates = _userController!.certificates;
            if (certificates == null) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 4.0),
              );
            } else {
              return ListView.builder(
                shrinkWrap: true,
                itemCount: certificates.length,
                itemBuilder: (context, index) {
                  return CertificateCard(
                    userController: _userController!,
                    certificate: certificates[index],
                    refreshCallback: _refreshCertificateList,
                  );
                },
              );
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
        title: const Text('Certificados'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _onAddCertificate,
          ),
          const Padding(
            padding: EdgeInsets.all(10.0),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}

class CertificateCard extends StatefulWidget {
  final Map<String, String> certificate;

  final UserController userController;

  final VoidCallback refreshCallback;

  const CertificateCard({
    Key? key,
    required this.userController,
    required this.certificate,
    required this.refreshCallback,
  }) : super(key: key);

  @override
  State<CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<CertificateCard> {
  Future _onDeleteCertificate(BuildContext context) async {
    if (await showConfirmDialog(context, '', '¿Quieres eliminar el certificado?')) {
      String? result = await widget.userController.deleteIosCertificate(widget.certificate);
      if (result == null) {
        widget.refreshCallback();
        // If the certificate is the one selected in the configuration, reset it
        if (config!.prefs.getString(Config.certificateIssuerKey) == widget.certificate['issuer'] &&
            config!.prefs.getString(Config.certificateSerialKey) == widget.certificate['serial']) {
          // ignore: unawaited_futures
          config!.prefs.remove(Config.certificateSubjectKey);
          // ignore: unawaited_futures
          config!.prefs.remove(Config.certificateIssuerKey);
          // ignore: unawaited_futures
          config!.prefs.remove(Config.certificateSerialKey);
        }
      } else {
        if (!mounted) return;
        await showMessage(
          context: context,
          title: '',
          message: 'Error al eliminar el certificado',
          modal: true,
        );
      }
    }
  }

  Future _onSelectCertificate(BuildContext context) async {
    await config!.prefs.setString(Config.certificateSubjectKey, widget.certificate['subject']!);
    await config!.prefs.setString(Config.certificateIssuerKey, widget.certificate['issuer']!);
    await config!.prefs.setString(Config.certificateSerialKey, widget.certificate['serial']!);
    if (!mounted) return;
    Navigator.of(context).pop('updated');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      child: GestureDetector(
        onTap: () {
          _onSelectCertificate(context);
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 5.0,
              right: 5.0,
              left: 12.0,
              bottom: 12.0,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(widget.certificate['subject']!,
                          style: const TextStyle(
                            //fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  GestureDetector(
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.delete, color: Colors.black54),
                    ),
                    onTap: () => _onDeleteCertificate(context),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
              ),
              Row(
                children: <Widget>[
                  const Text('Issuer:',
                      style: TextStyle(
                        //fontSize: 16.0,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey,
                      )),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                  ),
                  Expanded(
                    child: Text(
                      widget.certificate['issuer']!,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4.0),
              ),
              Row(
                children: <Widget>[
                  const Text('Serial:',
                      style: TextStyle(
                        //fontSize: 16.0,
                        fontWeight: FontWeight.w300,
                        color: Colors.grey,
                      )),
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                  ),
                  Text(
                    widget.certificate['serial']!,
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

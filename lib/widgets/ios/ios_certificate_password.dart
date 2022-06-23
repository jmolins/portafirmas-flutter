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
import 'package:portafirmas/controllers/user_controller.dart';
import 'package:portafirmas/utils.dart';
import 'package:provider/provider.dart';

class IOSCertificatePassword extends StatefulWidget {
  final String filename;

  const IOSCertificatePassword({
    Key? key,
    required this.filename,
  }) : super(key: key);

  @override
  IOSCertificatePasswordState createState() => IOSCertificatePasswordState();
}

class IOSCertificatePasswordState extends State<IOSCertificatePassword> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  UserController? _userController;

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  var password = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context);
    // Launch request to get the list of available certificates
    _userController!.getCertificateFiles();
  }

  Future _handleSubmitted() async {
    final FormState? form = _formKey.currentState;
    if (!form!.validate()) {
      _autovalidateMode = AutovalidateMode.always; // Start validating on every change.
    } else {
      form.save();
      String? result = await _userController!.loadIosCertificate(widget.filename, password);
      if (!mounted) return;
      if (result != null) {
        if (result == 'Contraseña incorrecta') {
          await showMessage(context: context, title: '', message: result, modal: true);
        } else {
          Navigator.of(context).pop(result);
        }
      } else {
        await showMessage(context: context, message: 'Certificado registrado', modal: true);
        if (!mounted) return;
        Navigator.of(context).popUntil(ModalRoute.withName('ioscertificates'));
      }
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'El password no puede estar vacío';
    return null;
  }

  Widget _buildBody() {
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: <Widget>[
            const Text('Introduzca la contraseña del certificado que desea registrar'),
            SizedBox(
              width: 250.0,
              child: TextFormField(
                obscureText: true,
                onSaved: (value) {
                  password = value!;
                },
                validator: _validatePassword,
              ),
            ),
            Container(padding: const EdgeInsets.symmetric(vertical: 15.0)),
            Center(
              child: TextButton(
                onPressed: _handleSubmitted,
                child: const Text('REGISTRAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar certificado'),
      ),
      body: _buildBody(),
    );
  }
}

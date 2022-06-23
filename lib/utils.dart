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

Future<void> showMessage({
  required BuildContext context,
  String? title,
  String? message,
  bool modal = false,
  bool showActions = true,
}) async {
  ThemeData theme = Theme.of(context);
  TextStyle style = theme.textTheme.button!.copyWith(
    color: theme.colorScheme.secondary,
    fontSize: 16.0,
  );
  await showDialog<String>(
    context: context,
    barrierDismissible: modal ? false : true,
    builder: (context) => AlertDialog(
      title: title != null ? Text(title) : null,
      content: message != null ? Text(message) : null,
      actions: showActions
          ? <Widget>[
              TextButton(
                child: Text('Ok', style: style),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ]
          : null,
    ),
  );
}

Future<bool> showConfirmDialog(BuildContext context, String? title, String message) async {
  ThemeData theme = Theme.of(context);
  TextStyle style = theme.textTheme.button!.copyWith(
    color: theme.colorScheme.secondary,
    fontSize: 16.0,
  );
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: title != null ? Text(title) : null,
          content: Text(
            message,
          ),
          actions: <Widget>[
            TextButton(
              child:
                  const Text('Cancelar', style: TextStyle(fontSize: 16.0, color: Colors.black54)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Continuar', style: style),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showProcessingDialog(BuildContext context, String message) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(message),
            ),
            const SizedBox(
              height: 50.0,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

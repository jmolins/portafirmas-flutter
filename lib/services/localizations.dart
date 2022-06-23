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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PortafirmasTextOverride extends DefaultMaterialLocalizations {
  PortafirmasTextOverride(Locale locale) : super();

  @override
  String get backButtonTooltip => 'Volver';

  @override
  String get openAppDrawerTooltip => '';
}

class PortafirmasTextDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const PortafirmasTextDelegate();

  @override
  Future<PortafirmasTextOverride> load(Locale locale) {
    return SynchronousFuture(PortafirmasTextOverride(locale));
  }

  @override
  bool shouldReload(PortafirmasTextDelegate old) => false;

  @override
  bool isSupported(Locale locale) => true;
}

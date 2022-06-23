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

import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'digital_certificates_method_channel.dart';

abstract class DigitalCertificatesPlatform extends PlatformInterface {
  /// Constructs a DigitalCertificatesPlatform.
  DigitalCertificatesPlatform() : super(token: _token);

  static final Object _token = Object();

  static DigitalCertificatesPlatform _instance = MethodChannelDigitalCertificates();

  /// The default instance of [DigitalCertificatesPlatform] to use.
  ///
  /// Defaults to [MethodChannelDigitalCertificates].
  static DigitalCertificatesPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DigitalCertificatesPlatform] when
  /// they register themselves.
  static set instance(DigitalCertificatesPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> selectCertificate() async {
    throw UnimplementedError('certificateSubject() has not been implemented.');
  }

  Future<Uint8List?> signData(Uint8List data, [String? algorithm]) async {
    throw UnimplementedError('certificateSubject() has not been implemented.');
  }

  Future<String?> certificateSubject() {
    throw UnimplementedError('certificateSubject() has not been implemented.');
  }
}

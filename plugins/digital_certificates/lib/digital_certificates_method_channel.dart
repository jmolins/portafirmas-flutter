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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'digital_certificates_platform_interface.dart';

/// An implementation of [DigitalCertificatesPlatform] that uses method channels.
class MethodChannelDigitalCertificates extends DigitalCertificatesPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('digital_certificates');

  @override
  Future<String?> selectCertificate() async {
    final certificate =
        await methodChannel.invokeMethod<String>('selectCertificate', <String, dynamic>{});
    return certificate;
  }

  @override
  Future<Uint8List?> signData(Uint8List data, [String? algorithm]) async {
    return await methodChannel
        .invokeMethod<Uint8List>('signData', {'data': data, 'algorithm': algorithm});
  }

  /// Gets the subject of the selected certificate
  @override
  Future<String?> certificateSubject() async {
    final subject =
        await methodChannel.invokeMethod<String>('certificateSubject', <String, dynamic>{});
    return subject;
  }
}

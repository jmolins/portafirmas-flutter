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
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:portafirmas/api/xml_request_factory.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/model/sign_request.dart';
import 'package:portafirmas/model/triphase_request.dart';
import 'package:xml/xml.dart';

enum HttpVerb {
  get,
  post,
  put,
}

class Api {
  static const String operationPresign = '0';
  static const String operationPostsign = '1';
  static const String operationRequest = '2';
  static const String operationReject = '3';
  static const String operationDetail = '4';
  static const String operationPreviewDocument = '5';
  static const String operationApprove = '7';
  static const String operationPreviewSignature = '8';
  static const String operationPreviewReport = '9';
  static const String operationLoginRequest = '10';
  static const String operationLoginValidation = '11';
  static const String operationLogoutRequest = '12';

  static const String xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>';

  String _sessionCookies = '';

  String? certB64;
  String? dni;

  final Logger log = Logger('Api');

  Api() {
    config!.applicationPath.then((appPath) {
      String path = '$appPath/network.log';
      File file = File(path);
      // Start the application with a blank log file
      if (file.existsSync()) file.deleteSync();
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((rec) {
        file.writeAsStringSync(
          '${rec.level.name}: ${rec.time}: ${rec.message}\n',
          mode: FileMode.writeOnlyAppend,
        );
      });
    });
  }

  void reset() {
    certB64 = null;
    dni = null;
    _sessionCookies = '';
  }

  /// Request a challenge token from the server.
  /// The request body is of the form:
  ///   "op=10&dat=$encodedXml",
  ///   where encodedXml is "<lgnrq />" base64 encoded
  /// Returns something of the form:
  ///   <?xml version="1.0" encoding="UTF-8"?>
  ///   <lgnrq id='AE9CCC568A94AE42670D36204D51E69E.portafirmas_poolB1_node2'>
  ///     MTUyNDY3NDcxMjg5NXw2OWRhNDRjZC1lY2EwLTRkYzMtOTA5OC1kZGIyNmJmZmQ3YjQ=
  ///   </lgnrq>
  /// The response Set-Cookie header contains the JSESSIONID which is used to
  /// keep track of the user session.
  /// This cookie needs to be sent back in the Cookie header in every request
  /// to the server.
  Future<String> loginRequest() async {
    var bytes = utf8.encode('<lgnrq />');
    String encodedXml = base64UrlEncode(bytes);
    try {
      // Before logging in, clear the cookie in case there was a previous login
      _sessionCookies = '';
      log.info('REQUEST XML: <lgnrq />');
      log.info('REQUEST HEADERS: ${_getHeaders()}');
      log.info('REQUEST BODY: op=$operationLoginRequest&dat=$encodedXml');
      http.Response response = await http.post(
        Uri.parse(config!.serverURL),
        body: 'op=$operationLoginRequest&dat=$encodedXml',
        headers: _getHeaders(),
      );
      log.info('RESPONSE HEADERS: ${response.headers}');
      log.info('RESPONSE BDOY: ${response.body}');
      if (response.statusCode == 200) {
        var document = XmlDocument.parse(response.body);
        var error = document.findAllElements('err');
        assert(error.isEmpty,
            'Error received as main node in the response body'); // An error here means a bad request
        // Keep the cookies for later
        Map<String, String> headers = response.headers;
        _sessionCookies = headers['set-cookie'] ?? '';
        return response.body;
      }
      // ignore: empty_catches
    } on Exception {}
    throw const NetworkException();
  }

  /// Send the challenge token received in loginRequest signed with the
  /// key of the user
  Future<String> login(String pkcs1) async {
    String xml = '<rqtvl><cert>$certB64</cert><pkcs1>$pkcs1</pkcs1></rqtvl>';
    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    log.info('REQUEST XML: $xml');
    log.info('REQUEST HEADERS: ${_getHeaders()}');
    log.info('REQUEST BODY: op=$operationLoginValidation&dat=$encodedXml');

    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationLoginValidation&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Future<String> logout() async {
    String xml = '<lgorq />';
    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationLogoutRequest&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Future<String> getSignRequests(
      String state, List<String>? filters, int numPage, int pageSize) async {
    // Create xml request
    String xml = XmlRequestFactory.createRequestListRequest(state, filters, numPage, pageSize);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    log.info('REQUEST XML: $xml');
    log.info('REQUEST HEADERS: ${_getHeaders()}');
    log.info('REQUEST BODY: op=$operationLoginValidation&dat=$encodedXml');

    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationRequest&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Future<String> preSignRequest(SignRequest request) async {
    final String xml = XmlRequestFactory.createPresignRequest(request);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationPresign&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Future<String> postSignRequests(List<TriphaseRequest> requests) async {
    final String xml = XmlRequestFactory.createPostsignRequest(requests);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationPostsign&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  /// Obtiene los datos de un documento.
  Future<String> getRequestDetail(final String requestId) async {
    String xml = XmlRequestFactory.createDetailRequest(requestId);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    log.info('REQUEST XML: $xml');
    log.info('REQUEST HEADERS: ${_getHeaders()}');
    log.info('REQUEST BODY: op=$operationLoginValidation&dat=$encodedXml');

    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationDetail&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Future<String> approveRequests(List<String> requestIds) async {
    final String xml = XmlRequestFactory.createApproveRequest(requestIds);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationApprove&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  static String getPreviewDocumentUrl(final String documentId) {
    final String xml = XmlRequestFactory.createPreviewRequest(documentId);

    var bytes = utf8.encode(xml);
    String encodedXml = Api.base64UrlSafeEncode(Uint8List.fromList(bytes));
    return '${config!.serverURL}'
        '?op=${Api.operationPreviewDocument}&dat=$encodedXml';
  }

  static String getPreviewSignatureUrl(final String documentId) {
    final String xml = XmlRequestFactory.createPreviewRequest(documentId);

    var bytes = utf8.encode(xml);
    String encodedXml = Api.base64UrlSafeEncode(Uint8List.fromList(bytes));
    return '${config!.serverURL}'
        '?op=${Api.operationPreviewSignature}&dat=$encodedXml';
  }

  static String getPreviewReportUrl(final String documentId) {
    final String xml = XmlRequestFactory.createPreviewRequest(documentId);

    var bytes = utf8.encode(xml);
    String encodedXml = Api.base64UrlSafeEncode(Uint8List.fromList(bytes));
    return '${config!.serverURL}'
        '?op=${Api.operationPreviewReport}&dat=$encodedXml';
  }

  Future<String> rejectRequests(List<String> requestIds, String reason) async {
    final String xml = XmlRequestFactory.createRejectRequest(requestIds, reason);

    var bytes = utf8.encode(xml);
    String encodedXml = base64UrlSafeEncode(Uint8List.fromList(bytes));
    var responseBody = await _getResponseBody(
      httpVerb: HttpVerb.post,
      uri: Uri.parse(config!.serverURL),
      requestBody: 'op=$operationReject&dat=$encodedXml',
      headers: _getHeaders(),
    );
    return responseBody;
  }

  Map<String, String> _getHeaders() {
    return {
      'Accept': 'application/xml',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cookie': _sessionCookies,
    };
  }

  Map<String, String> get headers {
    return _getHeaders();
  }

  static String base64UrlSafeEncode(Uint8List source) {
    String next = base64Encode(source);
    return next.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '%3D');
  }

  Future<String> _getResponseBody({
    required HttpVerb httpVerb,
    required Uri uri,
    String? requestBody,
    required Map<String, String> headers,
  }) async {
    String resultError = 'no_error';
    String resultErrorMessage = '';
    String resultBody = '';

    try {
      http.Response response;
      switch (httpVerb) {
        case HttpVerb.get:
          response = await http.get(uri, headers: headers);
          break;
        case HttpVerb.post:
          assert(requestBody != null);
          response = await http.post(uri, body: requestBody, headers: headers);
          break;
        case HttpVerb.put:
          assert(requestBody != null);
          response = await http.put(uri, body: requestBody, headers: headers);
          break;
      }
      log.info('RESPONSE HEADERS: ${response.headers}');
      log.info('RESPONSE BODY: ${response.body}');
      if (response.statusCode == 200) {
        var document = XmlDocument.parse(response.body);
        List<XmlElement> errors = document.findAllElements('err').toList();
        if (errors.isNotEmpty) {
          resultError = 'error_body';
          resultErrorMessage = errors[0].text;
        }
        resultBody = response.body;
      }
      // Bad Request
      else if (response.statusCode == 400) {
        // Assert that will always fail on a bad request
        assert(() {
          return false;
        }(), 'API call has failed');
      } else if (response.statusCode == 401) {
        resultError = 'unauthorized';
      }
    } on Exception {
      throw const NetworkException();
    }
    if (resultError == 'unauthorized') {
      throw const UnauthorizedException();
    }
    if (resultError == 'error_body') {
      throw ErrorMessageException(resultErrorMessage);
    }
    return resultBody;
  }
}

class PortafirmasException implements Exception {
  /// A message describing the format error.
  final String? message;

  const PortafirmasException([this.message = '']);

  @override
  String toString() {
    String report = 'PortafirmasException';
    if (message != null && '' != message) {
      report = '$Exception: $message';
    }
    return report;
  }
}

class NetworkException extends PortafirmasException {
  const NetworkException([String message = 'NetworkException']) : super(message);
}

class UnauthorizedException extends PortafirmasException {
  const UnauthorizedException([String message = 'UnauthorizedException']) : super(message);
}

class ErrorMessageException extends PortafirmasException {
  const ErrorMessageException([String message = 'ErrorMessageException']) : super(message);
}

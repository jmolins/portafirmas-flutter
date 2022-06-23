// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_controller.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$UserController on _UserController, Store {
  late final _$loginResultAtom =
      Atom(name: '_UserController.loginResult', context: context);

  @override
  ValidationLoginResult? get loginResult {
    _$loginResultAtom.reportRead();
    return super.loginResult;
  }

  @override
  set loginResult(ValidationLoginResult? value) {
    _$loginResultAtom.reportWrite(value, super.loginResult, () {
      super.loginResult = value;
    });
  }

  late final _$logoutResultAtom =
      Atom(name: '_UserController.logoutResult', context: context);

  @override
  RequestResult? get logoutResult {
    _$logoutResultAtom.reportRead();
    return super.logoutResult;
  }

  @override
  set logoutResult(RequestResult? value) {
    _$logoutResultAtom.reportWrite(value, super.logoutResult, () {
      super.logoutResult = value;
    });
  }

  late final _$certificatesAtom =
      Atom(name: '_UserController.certificates', context: context);

  @override
  ObservableList<Map<String, String>>? get certificates {
    _$certificatesAtom.reportRead();
    return super.certificates;
  }

  @override
  set certificates(ObservableList<Map<String, String>>? value) {
    _$certificatesAtom.reportWrite(value, super.certificates, () {
      super.certificates = value;
    });
  }

  late final _$filesAtom =
      Atom(name: '_UserController.files', context: context);

  @override
  ObservableList<String>? get files {
    _$filesAtom.reportRead();
    return super.files;
  }

  @override
  set files(ObservableList<String>? value) {
    _$filesAtom.reportWrite(value, super.files, () {
      super.files = value;
    });
  }

  late final _$loginAsyncAction =
      AsyncAction('_UserController.login', context: context);

  @override
  Future<void> login() {
    return _$loginAsyncAction.run(() => super.login());
  }

  late final _$logoutAsyncAction =
      AsyncAction('_UserController.logout', context: context);

  @override
  Future<void> logout() {
    return _$logoutAsyncAction.run(() => super.logout());
  }

  late final _$selectIosCertificateAsyncAction =
      AsyncAction('_UserController.selectIosCertificate', context: context);

  @override
  Future<String?> selectIosCertificate(Map<String, String> certificate) {
    return _$selectIosCertificateAsyncAction
        .run(() => super.selectIosCertificate(certificate));
  }

  late final _$getCertificateFilesAsyncAction =
      AsyncAction('_UserController.getCertificateFiles', context: context);

  @override
  Future<void> getCertificateFiles() {
    return _$getCertificateFilesAsyncAction
        .run(() => super.getCertificateFiles());
  }

  late final _$getAddedIosCertificatesAsyncAction =
      AsyncAction('_UserController.getAddedIosCertificates', context: context);

  @override
  Future<void> getAddedIosCertificates() {
    return _$getAddedIosCertificatesAsyncAction
        .run(() => super.getAddedIosCertificates());
  }

  late final _$loadIosCertificateAsyncAction =
      AsyncAction('_UserController.loadIosCertificate', context: context);

  @override
  Future<String?> loadIosCertificate(String filename, String password) {
    return _$loadIosCertificateAsyncAction
        .run(() => super.loadIosCertificate(filename, password));
  }

  late final _$deleteIosCertificateAsyncAction =
      AsyncAction('_UserController.deleteIosCertificate', context: context);

  @override
  Future<String?> deleteIosCertificate(Map<String, String> certificate) {
    return _$deleteIosCertificateAsyncAction
        .run(() => super.deleteIosCertificate(certificate));
  }

  @override
  String toString() {
    return '''
loginResult: ${loginResult},
logoutResult: ${logoutResult},
certificates: ${certificates},
files: ${files}
    ''';
  }
}

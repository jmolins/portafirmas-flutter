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

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:portafirmas/api/api.dart';
import 'package:portafirmas/config.dart';
import 'package:portafirmas/controllers/request_controller.dart';
import 'package:portafirmas/controllers/user_controller.dart';
import 'package:portafirmas/services/localizations.dart';
import 'package:portafirmas/widgets/home.dart';
import 'package:provider/provider.dart';

/// If the current platform is a desktop platform that isn't yet supported by
/// TargetPlatform, override the default platform to one that is.
/// Otherwise, do nothing.
void _setTargetPlatformForDesktop() {
  // No need to handle macOS, as it has now been added to TargetPlatform.
  if (Platform.isLinux || Platform.isWindows) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

Future main() async {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  _setTargetPlatformForDesktop();

  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDownloader.initialize();

  config = Config();
  await config!.init();
  final api = Api();

  // Add some delay to allow for the application to initialize
  // Otherwise, the application starts with a black screen
  await Future<void>.delayed(const Duration(milliseconds: 100));

  runApp(MyApp(api: api));
}

class MyApp extends StatelessWidget {
  final Api api;

  final ThemeData base = ThemeData.light();

  MyApp({Key? key, required this.api}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ListenableProvider<UserController>(
          create: (context) => UserController(api),
        ),
        Provider<RequestController>(
          create: (context) => RequestController(api),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.teal,
          primaryColor: Colors.grey[200],
          scaffoldBackgroundColor: Colors.grey[100],
          primaryIconTheme: const IconThemeData(color: Color(0xFF777777), size: 24.0),
          /* primaryTextTheme: base.primaryTextTheme.apply(
              bodyColor: Colors.grey[700],
              // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
              fontFamily: 'Roboto',
            ),*/
          fontFamily: 'Roboto',
        ),
        localizationsDelegates: const [
          PortafirmasTextDelegate(),
        ],
        home: const HomePage(),
      ),
    );
  }
}

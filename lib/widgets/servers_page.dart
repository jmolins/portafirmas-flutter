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

import 'package:flutter/material.dart';
import 'package:portafirmas/config.dart';

class ServersPage extends StatefulWidget {
  const ServersPage({Key? key}) : super(key: key);

  @override
  ServersPageState createState() => ServersPageState();
}

class ServersPageState extends State<ServersPage> {
  @override
  void initState() {
    super.initState();
    radioValue = config!.serverName;
  }

  @override
  void dispose() {
    super.dispose();
  }

  String? radioValue;

  void handleRadioValueChanged(String? value) {
    setState(() {
      radioValue = value;
      switch (radioValue) {
        case Config.serverAgeName:
          config!.prefs.setString(Config.serverNameKey, Config.serverAgeName);
          config!.prefs.setString(Config.serverUrlKey, Config.serverAgeUrl);
          break;
        case Config.serverRedsaraName:
          config!.prefs.setString(Config.serverNameKey, Config.serverRedsaraName);
          config!.prefs.setString(Config.serverUrlKey, Config.serverRedsaraUrl);
          break;
      }
      // Reload configuration
      config!.init();
    });
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: <Widget>[
          RadioListTile<String>(
            value: Config.serverAgeName,
            groupValue: radioValue,
            onChanged: handleRadioValueChanged,
            title: const Text(Config.serverAgeName),
            subtitle: const Text(Config.serverAgeUrl),
          ),
          const Padding(padding: EdgeInsets.all(10.0)),
          RadioListTile(
            value: Config.serverRedsaraName,
            groupValue: radioValue,
            onChanged: handleRadioValueChanged,
            title: const Text(Config.serverRedsaraName),
            subtitle: const Text(Config.serverRedsaraUrl),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servidores'),
      ),
      body: _buildBody(),
    );
  }
}

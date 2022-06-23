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

class PortafirmasDrawer extends StatefulWidget {
  final VoidCallback onTapFilters;
  final VoidCallback? onTapSelectAll;
  final VoidCallback? onTapUnselectAll;
  final VoidCallback onTapLogout;
  final Config config;

  const PortafirmasDrawer({
    Key? key,
    required this.onTapFilters,
    required this.onTapSelectAll,
    required this.onTapUnselectAll,
    required this.onTapLogout,
    required this.config,
  }) : super(key: key);

  @override
  State<PortafirmasDrawer> createState() => _PortafirmasDrawerState();
}

class _PortafirmasDrawerState extends State<PortafirmasDrawer> {
  @override
  Widget build(BuildContext context) {
    final List<Widget> allDrawerItems = <Widget>[
      const PortafirmasDrawerHeader(),
      /*ListTile(
          leading: Icon(Icons.filter),
          title: Text("Filtros"),
          onTap: widget.onTapFilters),*/
      ListTile(
        leading: const Icon(Icons.check_box),
        title: widget.onTapSelectAll != null
            ? const Text('Seleccionar todas')
            : const Text('Quitar selección'),
        onTap: () {
          if (widget.onTapSelectAll != null) {
            widget.onTapSelectAll!();
          } else if (widget.onTapUnselectAll != null) {
            widget.onTapUnselectAll!();
          }
          Navigator.of(context).pop();
        },
      ),
      const Divider(),
      ListTile(
          leading: const Icon(Icons.exit_to_app),
          title: const Text('Salir'),
          onTap: widget.onTapLogout),
      const Divider(),
      DrawerFooter(onTapLogout: widget.onTapLogout),
    ];

    return Drawer(child: ListView(primary: false, children: allDrawerItems));
  }
}

class PortafirmasDrawerHeader extends StatelessWidget {
  const PortafirmasDrawerHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String? subject = config!.prefs.getString(Config.certificateSubjectKey);
    return DrawerHeader(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/logo_1024_teal_shadow.png'), fit: BoxFit.cover),
      ),
      child: Stack(children: <Widget>[
        Positioned(
          bottom: 10.0,
          left: 0.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                config!.serverName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(4.0),
              ),
              Text(
                subject ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12.0),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class DrawerFooter extends StatelessWidget {
  static const int closeDrawerTimeout = 300;

  final VoidCallback onTapLogout;

  const DrawerFooter({Key? key, required this.onTapLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20.0),
          const Text(
            'Portafirmas 1.0',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12.0),
          ),
          const SizedBox(height: 7.0),
          const Text(
            '© 2022 Chema Molins',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12.0),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: const [
              Text(
                'Hecho con Flutter',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
              ),
              SizedBox(width: 7.0),
              FlutterLogo(),
            ],
          ),
        ],
      ),
    );
  }
}

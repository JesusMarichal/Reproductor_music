import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.palette), title: Text('Tema')),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notificaciones'),
          ),
          ListTile(leading: Icon(Icons.info), title: Text('Acerca de')),
        ],
      ),
    );
  }
}

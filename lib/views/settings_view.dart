import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final keys = themeCtrl.availableKeys;
    final names = <String, String>{
      'default': 'Clásico (Morado)',
      'dark': 'Oscuro',
      'red_black': 'Rojo & Negro',
      'blue_light': 'Azul (Claro)',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: Icon(Icons.palette),
            title: Text('Tema'),
            subtitle: Text('Personaliza los colores de la app'),
          ),
          ...keys.map((k) {
            return RadioListTile<String>(
              value: k,
              groupValue: themeCtrl.currentKey,
              onChanged: (v) {
                if (v != null) themeCtrl.setTheme(v);
              },
              title: Text(names[k] ?? k),
              secondary: _ThemePreviewDot(keyName: k),
            );
          }),

          const Divider(),
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notificaciones'),
            subtitle: Text('Configuración del sistema'),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Acerca de'),
            subtitle: Text('Versión 0.0.1'),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewDot extends StatelessWidget {
  final String keyName;
  const _ThemePreviewDot({required this.keyName});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (keyName) {
      case 'red_black':
        color = const Color(0xFFD50000);
        break;
      case 'blue_light':
        color = Colors.blue;
        break;
      case 'dark':
        color = Colors.indigo;
        break;
      default:
        color = Colors.deepPurple;
    }
    return CircleAvatar(radius: 10, backgroundColor: color);
  }
}

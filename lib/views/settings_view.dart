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
      'deep_space': 'Espacio Profundo',
      'sunset': 'Atardecer',
      'ocean': 'Océano',
      'forest_green': 'Bosque Verde',
      'minimal_gray': 'Gris Minimalista',
      'rose_gold': 'Rosa Dorado',
      'lavender_dream': 'Sueño Lavanda',
      'mint_fresh': 'Menta Fresca',
      'peach_blossom': 'Flor de Durazno',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpansionTile(
            leading: const Icon(Icons.palette),
            title: const Text('Tema'),
            subtitle: Text(names[themeCtrl.currentKey] ?? 'Seleccionar'),
            children: keys.map((k) {
              final isSelected = themeCtrl.currentKey == k;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 32, right: 24),
                // leading removed as requested
                title: Text(
                  names[k] ?? k,
                  style: const TextStyle(fontSize: 13), // Texto pequeño
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  themeCtrl.setTheme(k);
                },
              );
            }).toList(),
          ),

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

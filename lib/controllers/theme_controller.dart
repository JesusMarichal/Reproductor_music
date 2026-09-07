import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Selecciona la paleta activa y la persiste.
///
/// El controlador ya no define colores: sólo elige una [AppPalette] y deja
/// que [buildAppTheme] derive el resto, de modo que todos los temas quedan
/// igual de completos.
class ThemeController extends ChangeNotifier {
  ThemeController({String? initialKey})
      : _palette = AppPalettes.byKey(initialKey);

  AppPalette _palette;

  AppPalette get palette => _palette;

  String get currentKey => _palette.key;

  /// Claves en el orden en que se muestran en el selector.
  List<String> get availableKeys =>
      AppPalettes.all.map((p) => p.key).toList(growable: false);

  ThemeData get theme => buildAppTheme(_palette);

  /// Nombre legible de un tema, para el selector.
  String themeName(String key) => AppPalettes.byKey(key).name;

  /// Color representativo con el que se dibuja la muestra del selector.
  Color getThemeColor(String key) => AppPalettes.byKey(key).primary;

  /// Fondo del tema, para que la muestra enseñe también el contraste.
  Color getThemeBackground(String key) => AppPalettes.byKey(key).background;

  bool isDarkTheme(String key) => AppPalettes.byKey(key).isDark;

  /// Tonos completos de un tema, para dibujar su vista previa.
  PaletteTones tonesFor(String key) => tonesOf(AppPalettes.byKey(key));

  Future<void> setTheme(String key) async {
    if (key == _palette.key) return;
    final next = AppPalettes.byKey(key);
    if (next.key != key) return; // clave desconocida: no cambiamos nada
    _palette = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_key', key);
  }
}

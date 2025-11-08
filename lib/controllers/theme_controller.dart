import 'package:flutter/material.dart';

/// Define una serie de temas preconfigurados para que el usuario pueda
/// personalizar la apariencia del reproductor.
class ThemeController extends ChangeNotifier {
  ThemeController();

  /// Identificador del tema actual.
  String _currentKey = 'red_black';

  String get currentKey => _currentKey;

  /// Mapa de temas disponibles.
  final Map<String, ThemeData> _themes = {
    'default': ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    'dark': ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    'red_black': ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFD50000),
        onPrimary: Colors.white,
        secondary: Color(0xFFFF1744),
        onSecondary: Colors.white,
        surface: Color(0xFF121212),
        onSurface: Colors.white70,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white70,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black87),
    ),
    'blue_light': ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
  };

  List<String> get availableKeys => _themes.keys.toList(growable: false);

  ThemeData get theme => _themes[_currentKey] ?? _themes['default']!;

  void setTheme(String key) {
    if (key == _currentKey) return;
    if (_themes.containsKey(key)) {
      _currentKey = key;
      notifyListeners();
    }
  }
}

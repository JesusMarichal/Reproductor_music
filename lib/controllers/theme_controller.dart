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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black87,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Colors.transparent),
        ),
        tileColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Colors.transparent),
        ),
        elevation: 6,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.transparent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ).copyWith(
              overlayColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.pressed)) {
                  return Colors.white.withOpacity(0.12);
                }
                return null;
              }),
            ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        hintStyle: const TextStyle(color: Colors.white38),
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white70, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    ),
    'blue_light': ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
  };

  // Sólo exponer por ahora los dos temas solicitados: 'red_black' y 'dark'.
  List<String> get availableKeys {
    final allowed = ['red_black', 'dark'];
    return allowed.where((k) => _themes.containsKey(k)).toList(growable: false);
  }

  ThemeData get theme => _themes[_currentKey] ?? _themes['default']!;

  void setTheme(String key) {
    if (key == _currentKey) return;
    if (_themes.containsKey(key)) {
      _currentKey = key;
      notifyListeners();
    }
  }
}

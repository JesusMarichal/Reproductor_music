import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Define una serie de temas preconfigurados para que el usuario pueda
/// personalizar la apariencia del reproductor.
class ThemeController extends ChangeNotifier {
  ThemeController({String? initialKey}) {
    if (initialKey != null && _themes.containsKey(initialKey)) {
      _currentKey = initialKey;
    }
  }

  /// Identificador del tema actual.
  String _currentKey = 'red_black';

  String get currentKey => _currentKey;

  // _loadTheme removed as we pass it in constructor for immediate availability

  /// Mapa de temas disponibles.
  final Map<String, ThemeData> _themes = {
    'default': ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    'dark': ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFBB86FC),
        onPrimary: Colors.black,
        secondary: Color(0xFF03DAC6),
        onSecondary: Colors.black,
        surface: Color(0xFF121212),
        onSurface: Colors.white70,
        background: Color(0xFF121212),
        onBackground: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
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
      scaffoldBackgroundColor: const Color(0xFF000000), // Pure black for AMOLED
      textTheme: Typography.whiteMountainView.apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white70,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1C),
        elevation: 4,
        surfaceTintColor: Colors.redAccent.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    ),
    'sunset': ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF6F00), // Amber darker
        onPrimary: Colors.white,
        secondary: Color(0xFFFFD180),
        onSecondary: Colors.black,
        surface: Color(0xFF260E04), // Deep warm brown/black
        onSurface: Colors.white,
        background: Color(0xFF1A0500),
      ),
      scaffoldBackgroundColor: const Color(0xFF1A0500),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF260E04),
        elevation: 0,
      ),
    ),
    'ocean': ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00B0FF),
        onPrimary: Colors.black,
        secondary: Color(0xFF69E2FF),
        onSecondary: Colors.black,
        surface: Color(0xFF001F2A), // Dark teal/blue
        onSurface: Colors.white,
        background: Color(0xFF001016),
      ),
      scaffoldBackgroundColor: const Color(0xFF001016),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF001F2A),
        elevation: 0,
      ),
    ),
    'deep_space': ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE040FB), // PurpleAccent 200
        onPrimary: Colors.white,
        secondary: Color(0xFF7C4DFF), // DeepPurpleAccent 200
        onSecondary: Colors.white,
        surface: Color(0xFF0F0524), // Very dark purple
        onSurface: Colors.white,
        background: Color(0xFF050109), // Almost black
      ),
      scaffoldBackgroundColor: const Color(0xFF050109),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0524),
        elevation: 0,
      ),
    ),
    'blue_light': ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 2),
    ),
  };

  List<String> get availableKeys {
    // Ordenamos para mostrar primero los más interesantes
    final allowed = [
      'red_black',
      'deep_space',
      'sunset',
      'ocean',
      'dark',
      'blue_light',
    ];
    return allowed.where((k) => _themes.containsKey(k)).toList(growable: false);
  }

  ThemeData get theme => _themes[_currentKey] ?? _themes['default']!;

  Future<void> setTheme(String key) async {
    if (key == _currentKey) return;
    if (_themes.containsKey(key)) {
      _currentKey = key;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_key', key);
    }
  }
}

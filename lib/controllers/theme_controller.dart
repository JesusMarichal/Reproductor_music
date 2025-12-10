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
    'minimal_gray': ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF424242), // Dark gray
        onPrimary: Colors.white,
        secondary: Color(0xFF757575),
        onSecondary: Colors.white,
        surface: Color(0xFFF5F5F5), // Very light gray
        onSurface: Color(0xFF212121),
        background: Colors.white,
        onBackground: Color(0xFF212121),
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        foregroundColor: Color(0xFF212121),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFAFAFA),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    'rose_gold': ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE91E63), // Pink
        onPrimary: Colors.white,
        secondary: Color(0xFFF8BBD0), // Light pink
        onSecondary: Color(0xFF880E4F),
        surface: Color(0xFFFCE4EC), // Very light pink
        onSurface: Color(0xFF880E4F),
        background: Color(0xFFFFF5F7),
        onBackground: Color(0xFF880E4F),
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF5F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFCE4EC),
        foregroundColor: Color(0xFF880E4F),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFCE4EC),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    'lavender_dream': ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF9C27B0), // Purple
        onPrimary: Colors.white,
        secondary: Color(0xFFE1BEE7), // Light purple
        onSecondary: Color(0xFF4A148C),
        surface: Color(0xFFF3E5F5), // Very light purple
        onSurface: Color(0xFF4A148C),
        background: Color(0xFFFAF5FF),
        onBackground: Color(0xFF4A148C),
      ),
      scaffoldBackgroundColor: const Color(0xFFFAF5FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF3E5F5),
        foregroundColor: Color(0xFF4A148C),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF3E5F5),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    'mint_fresh': ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF00BFA5), // Teal
        onPrimary: Colors.white,
        secondary: Color(0xFF80CBC4), // Light teal
        onSecondary: Color(0xFF004D40),
        surface: Color(0xFFE0F2F1), // Very light teal
        onSurface: Color(0xFF004D40),
        background: Color(0xFFF1F8F7),
        onBackground: Color(0xFF004D40),
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F8F7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFE0F2F1),
        foregroundColor: Color(0xFF004D40),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFE0F2F1),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    'peach_blossom': ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFFF6F00), // Deep orange
        onPrimary: Colors.white,
        secondary: Color(0xFFFFCCBC), // Light orange
        onSecondary: Color(0xFFBF360C),
        surface: Color(0xFFFFF3E0), // Very light orange
        onSurface: Color(0xFFBF360C),
        background: Color(0xFFFFFAF5),
        onBackground: Color(0xFFBF360C),
      ),
      scaffoldBackgroundColor: const Color(0xFFFFFAF5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFF3E0),
        foregroundColor: Color(0xFFBF360C),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFF3E0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    'forest_green': ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF66BB6A), // Green
        onPrimary: Colors.black,
        secondary: Color(0xFF81C784),
        onSecondary: Colors.black,
        surface: Color(0xFF1B5E20), // Dark green
        onSurface: Colors.white,
        background: Color(0xFF0D2818),
        onBackground: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0D2818),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1B5E20),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1B5E20),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  };

  List<String> get availableKeys {
    // Ordenamos para mostrar primero los más interesantes
    final allowed = [
      'red_black',
      'deep_space',
      'sunset',
      'ocean',
      'forest_green',
      'dark',
      'minimal_gray',
      'rose_gold',
      'lavender_dream',
      'mint_fresh',
      'peach_blossom',
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

  Color getThemeColor(String key) {
    return _themes[key]?.colorScheme.primary ?? Colors.blue;
  }
}

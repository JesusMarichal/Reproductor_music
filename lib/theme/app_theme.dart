import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Escala de espaciado. Todo el layout se construye con múltiplos de 4 para
/// que los márgenes sean coherentes entre pantallas.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Radios de esquina. Un solo lenguaje de formas para tarjetas, campos,
/// hojas modales y botones.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// Duraciones de animación. Cortas para feedback táctil, medias para
/// transiciones de layout.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
}

/// Una paleta es la *única* fuente de color de un tema. El resto de tonos
/// (contenedores, bordes, texto secundario) se derivan de estos cuatro
/// valores, de modo que añadir un tema nuevo no puede desalinear la UI.
class AppPalette {
  const AppPalette({
    required this.key,
    required this.name,
    required this.brightness,
    required this.primary,
    required this.accent,
    required this.background,
  });

  /// Clave persistida en SharedPreferences.
  final String key;

  /// Nombre mostrado en el selector de temas.
  final String name;

  final Brightness brightness;

  /// Color de marca: acciones principales, estado activo, progreso.
  final Color primary;

  /// Color de apoyo para degradados y acentos secundarios.
  final Color accent;

  /// Fondo de la aplicación. El resto de superficies se derivan de él.
  ///
  /// Nunca es negro puro: los temas oscuros parten de un gris con algo de
  /// luz para que las superficies elevadas se distingan del fondo y la
  /// pantalla no se vea como un agujero.
  final Color background;

  bool get isDark => brightness == Brightness.dark;
}

/// Paletas disponibles. Todas comparten la misma estructura, así que
/// cualquiera de ellas produce una interfaz igual de acabada.
abstract final class AppPalettes {
  static const AppPalette midnight = AppPalette(
    key: 'midnight',
    name: 'Medianoche',
    brightness: Brightness.dark,
    primary: Color(0xFFFF4438),
    accent: Color(0xFFFF8A3D),
    background: Color(0xFF1A1A1F),
  );

  static const AppPalette ember = AppPalette(
    key: 'ember',
    name: 'Brasa',
    brightness: Brightness.dark,
    primary: Color(0xFFFF8A1A),
    accent: Color(0xFFFFC46B),
    background: Color(0xFF1F1813),
  );

  static const AppPalette indigo = AppPalette(
    key: 'indigo',
    name: 'Índigo',
    brightness: Brightness.dark,
    primary: Color(0xFF7C8DFF),
    accent: Color(0xFFB39DFF),
    background: Color(0xFF171826),
  );

  static const AppPalette ocean = AppPalette(
    key: 'ocean',
    name: 'Océano',
    brightness: Brightness.dark,
    primary: Color(0xFF2DD4BF),
    accent: Color(0xFF60C8FF),
    background: Color(0xFF12222C),
  );

  static const AppPalette violet = AppPalette(
    key: 'violet',
    name: 'Violeta',
    brightness: Brightness.dark,
    primary: Color(0xFFA78BFA),
    accent: Color(0xFFF0ABFC),
    background: Color(0xFF1B1724),
  );

  static const AppPalette forest = AppPalette(
    key: 'forest',
    name: 'Bosque',
    brightness: Brightness.dark,
    primary: Color(0xFF34D399),
    accent: Color(0xFFA3E635),
    background: Color(0xFF13221D),
  );

  static const AppPalette daylight = AppPalette(
    key: 'daylight',
    name: 'Claro',
    brightness: Brightness.light,
    primary: Color(0xFFD92D20),
    accent: Color(0xFFF97316),
    background: Color(0xFFFAFAFB),
  );

  static const AppPalette paper = AppPalette(
    key: 'paper',
    name: 'Papel',
    brightness: Brightness.light,
    primary: Color(0xFF9A3412),
    accent: Color(0xFFC2410C),
    background: Color(0xFFFBF7F2),
  );

  /// Orden en que aparecen en el selector.
  static const List<AppPalette> all = [
    midnight,
    ember,
    indigo,
    ocean,
    violet,
    forest,
    daylight,
    paper,
  ];

  static AppPalette byKey(String? key) {
    for (final p in all) {
      if (p.key == key) return p;
    }
    return midnight;
  }
}

/// Tonos derivados de la paleta. Se exponen por `Theme.of(context)` a través
/// de [AppColors] para que las vistas nunca escriban un color literal.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.accent,
    required this.artworkPlaceholder,
  });

  /// Fondo de tarjetas y filas elevadas un nivel sobre el scaffold.
  final Color surface1;

  /// Contenedores dentro de una tarjeta (campos, chips).
  final Color surface2;

  /// Nivel máximo: hojas modales, menús emergentes.
  final Color surface3;

  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color primary;
  final Color accent;

  /// Relleno de una carátula que no existe. Se adapta al tema, a diferencia
  /// de un `Colors.grey[850]` fijo.
  final Color artworkPlaceholder;

  /// Degradado de marca, usado con moderación: cabeceras y carátula grande.
  LinearGradient get brandGradient => LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  AppColors copyWith({
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? accent,
    Color? artworkPlaceholder,
  }) {
    return AppColors(
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      artworkPlaceholder: artworkPlaceholder ?? this.artworkPlaceholder,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      artworkPlaceholder:
          Color.lerp(artworkPlaceholder, other.artworkPlaceholder, t)!,
    );
  }
}

/// Acceso corto a los tonos derivados: `context.colors.textSecondary`.
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get texts => Theme.of(this).textTheme;
}

/// Tonos derivados de una paleta.
///
/// Los usan tanto [buildAppTheme] como las vistas previas del selector de
/// temas, así que una miniatura no puede acabar enseñando colores distintos
/// a los del tema real.
class PaletteTones {
  const PaletteTones({
    required this.palette,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final AppPalette palette;

  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  Color get background => palette.background;
  Color get primary => palette.primary;
  Color get accent => palette.accent;
  bool get isDark => palette.isDark;
}

/// Deriva los tonos de una paleta.
///
/// Las superficies se elevan mezclando el fondo hacia blanco (temas oscuros)
/// o hacia negro (temas claros). Mantiene el matiz del tema en vez de
/// introducir grises neutros que se ven sucios sobre color.
PaletteTones tonesOf(AppPalette palette) {
  final isDark = palette.isDark;
  final bg = palette.background;

  final Color elevateTarget = isDark ? Colors.white : Colors.black;
  Color elevate(double amount) => Color.lerp(bg, elevateTarget, amount)!;

  final textPrimary =
      isDark ? const Color(0xFFF5F5F7) : const Color(0xFF16181D);

  return PaletteTones(
    palette: palette,
    surface1: elevate(isDark ? 0.055 : 0.030),
    surface2: elevate(isDark ? 0.090 : 0.055),
    surface3: elevate(isDark ? 0.130 : 0.080),
    border: elevate(isDark ? 0.150 : 0.120),
    textPrimary: textPrimary,
    textSecondary: Color.lerp(textPrimary, bg, isDark ? 0.35 : 0.42)!,
    textTertiary: Color.lerp(textPrimary, bg, isDark ? 0.55 : 0.60)!,
  );
}

/// Construye el [ThemeData] completo a partir de una paleta.
///
/// Todos los temas pasan por aquí, así que un ajuste de radios o de
/// tipografía se aplica a los ocho a la vez.
ThemeData buildAppTheme(AppPalette palette) {
  final isDark = palette.isDark;
  final bg = palette.background;

  final tones = tonesOf(palette);
  final surface1 = tones.surface1;
  final surface2 = tones.surface2;
  final surface3 = tones.surface3;
  final border = tones.border;
  final textPrimary = tones.textPrimary;
  final textSecondary = tones.textSecondary;
  final textTertiary = tones.textTertiary;

  Color elevate(double amount) =>
      Color.lerp(bg, isDark ? Colors.white : Colors.black, amount)!;

  final colorScheme = ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: _onColor(palette.primary),
    primaryContainer: Color.lerp(palette.primary, bg, isDark ? 0.72 : 0.82)!,
    onPrimaryContainer: isDark ? textPrimary : _darken(palette.primary, 0.35),
    secondary: palette.accent,
    onSecondary: _onColor(palette.accent),
    secondaryContainer: Color.lerp(palette.accent, bg, isDark ? 0.75 : 0.85)!,
    onSecondaryContainer: isDark ? textPrimary : _darken(palette.accent, 0.35),
    surface: bg,
    onSurface: textPrimary,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface1,
    surfaceContainer: surface1,
    surfaceContainerHigh: surface2,
    surfaceContainerHighest: surface3,
    onSurfaceVariant: textSecondary,
    outline: border,
    outlineVariant: elevate(isDark ? 0.10 : 0.08),
    error: const Color(0xFFEF4444),
    onError: Colors.white,
    errorContainer: Color.lerp(const Color(0xFFEF4444), bg, 0.80)!,
    onErrorContainer: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF7F1D1D),
    inverseSurface: textPrimary,
    onInverseSurface: bg,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  final baseText = isDark
      ? Typography.material2021().white
      : Typography.material2021().black;

  // Títulos con tracking negativo (se leen más compactos y modernos),
  // cuerpo con tracking neutro para legibilidad.
  final textTheme = baseText
      .copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: baseText.bodyLarge?.copyWith(height: 1.35),
        bodyMedium: baseText.bodyMedium?.copyWith(height: 1.35),
        bodySmall: baseText.bodySmall?.copyWith(height: 1.30),
        labelLarge: baseText.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      )
      .apply(bodyColor: textPrimary, displayColor: textPrimary);

  final shapeMd = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  final shapeLg = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    splashFactory: InkSparkle.splashFactory,
    textTheme: textTheme,
    extensions: [
      AppColors(
        surface1: surface1,
        surface2: surface2,
        surface3: surface3,
        border: border,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
        primary: palette.primary,
        accent: palette.accent,
        artworkPlaceholder: surface3,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      actionsIconTheme: IconThemeData(color: textPrimary, size: 24),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: surface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shapeLg,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textSecondary,
      textColor: textPrimary,
      titleTextStyle: textTheme.titleMedium,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: textSecondary),
      shape: shapeMd,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      minVerticalPadding: AppSpacing.sm,
    ),
    dividerTheme: DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: textSecondary, size: 24),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface1,
      surfaceTintColor: Colors.transparent,
      indicatorColor: palette.primary.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? palette.primary : textTertiary,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium!.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? palette.primary : textTertiary,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      prefixIconColor: textTertiary,
      suffixIconColor: textTertiary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: palette.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: _onColor(palette.primary),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: _onColor(palette.primary),
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.primary,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: shapeMd,
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textSecondary,
        highlightColor: palette.primary.withValues(alpha: 0.12),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.primary,
      inactiveTrackColor: border,
      thumbColor: palette.primary,
      overlayColor: palette.primary.withValues(alpha: 0.14),
      trackHeight: 4,
      trackShape: const RoundedRectSliderTrackShape(),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      valueIndicatorColor: surface3,
      valueIndicatorTextStyle: textTheme.labelSmall?.copyWith(
        color: textPrimary,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: palette.primary,
      foregroundColor: _onColor(palette.primary),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: border,
      circularTrackColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface3,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface3,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: border,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface3,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      actionTextColor: palette.primary,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: shapeMd,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface2,
      selectedColor: palette.primary.withValues(alpha: 0.18),
      side: BorderSide(color: border),
      labelStyle: textTheme.labelLarge?.copyWith(color: textPrimary),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface3,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: shapeMd,
      textStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surface3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? _onColor(palette.primary)
            : textTertiary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? palette.primary : surface2,
      ),
      trackOutlineColor: WidgetStateProperty.all(border),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(border),
      radius: const Radius.circular(AppRadius.xs),
      thickness: WidgetStateProperty.all(4),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Blanco o negro según el contraste real del color de fondo, para que el
/// texto sobre `primary` siga siendo legible en paletas claras y oscuras.
Color _onColor(Color background) {
  return background.computeLuminance() > 0.55 ? Colors.black : Colors.white;
}

Color _darken(Color c, double amount) => Color.lerp(c, Colors.black, amount)!;

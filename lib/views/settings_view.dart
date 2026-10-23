import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/youtube_key_dialog.dart';

/// Opciones de la app en una lista plana con icono, al estilo de la pantalla
/// "Cuenta" de YouTube Music.
///
/// Va incrustada en el perfil, debajo de la cabecera: antes era una pantalla
/// aparte que repetía el avatar y el nombre, y parecía abrir otro perfil.
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.read<HomeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuItem(
          icon: Icons.palette_outlined,
          label: 'Apariencia',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const _AppearanceView()),
          ),
        ),
        _MenuItem(
          icon: Icons.travel_explore_rounded,
          label: 'Descubrir música',
          onTap: () => Navigator.pushNamed(context, '/discovery'),
        ),
        _MenuItem(
          icon: Icons.smart_display_outlined,
          label: 'Conectar con YouTube',
          onTap: () => showYouTubeKeyDialog(context),
        ),
        _MenuItem(
          icon: Icons.refresh_rounded,
          label: 'Volver a leer la biblioteca',
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            await home.loadSongs();
            messenger.showSnackBar(
              SnackBar(
                content: Text('${home.songs.length} canciones encontradas'),
              ),
            );
          },
        ),
        const _MenuItem(
          icon: Icons.shield_outlined,
          label: 'Permisos y notificaciones',
          onTap: openAppSettings,
        ),
        _MenuItem(
          icon: Icons.help_outline_rounded,
          label: 'Acerca de Kiss Music',
          onTap: () => showAboutAppDialog(context),
        ),
      ],
    );
  }
}

/// Fila de menú plana: icono de línea y texto, sin tarjeta ni subtítulo.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg + AppSpacing.xs,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: context.colors.textPrimary),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Text(
                label,
                style: context.texts.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subpágina con el selector de temas.
class _AppearanceView extends StatelessWidget {
  const _AppearanceView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: const [_ThemeSection()],
      ),
    );
  }
}

/// Selector de temas: una rejilla de miniaturas que reproducen la interfaz
/// real con los colores de cada paleta.
///
/// Enseña el resultado en vez de nombrarlo, que es lo que se espera poder
/// comparar de un vistazo.
class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final keys = themeCtrl.availableKeys;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.86,
      ),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        return _ThemeCard(
          tones: themeCtrl.tonesFor(key),
          name: themeCtrl.themeName(key),
          selected: themeCtrl.currentKey == key,
          onTap: () => themeCtrl.setTheme(key),
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.tones,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final PaletteTones tones;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      selected: selected,
      button: true,
      label: 'Tema $name',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _ThemePreview(tones: tones)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleSmall,
                    ),
                  ),
                  AnimatedScale(
                    duration: AppDuration.fast,
                    scale: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              Text(
                tones.isDark ? 'Oscuro' : 'Claro',
                style: context.texts.bodySmall?.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Maqueta en miniatura: fondo, cabecera, dos filas de lista y la barra
/// inferior con su botón. Pintada con los tonos reales de la paleta.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.tones});

  final PaletteTones tones;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ColoredBox(
        color: tones.background,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título de pantalla.
              _Bar(color: tones.textPrimary, width: 34, height: 5),
              const SizedBox(height: AppSpacing.xs),
              _Bar(color: tones.textTertiary, width: 20, height: 3),
              const SizedBox(height: AppSpacing.sm),
              // Dos filas de canción.
              _PreviewRow(tones: tones),
              const SizedBox(height: AppSpacing.xs + 1),
              _PreviewRow(tones: tones),
              const Spacer(),
              // Barra inferior con la muesca del botón central.
              SizedBox(
                height: 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: tones.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(5),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: tones.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tones.background,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.tones});

  final PaletteTones tones;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: tones.surface2,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Bar(color: tones.textSecondary, width: 40, height: 3),
              const SizedBox(height: 3),
              _Bar(color: tones.textTertiary, width: 24, height: 3),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.width, required this.height});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height),
      ),
    );
  }
}

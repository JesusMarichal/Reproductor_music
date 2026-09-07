import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/theme_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/about_dialog.dart';

/// Ajustes. Se abre desde el perfil, así que aporta su propia barra superior.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: const [
        _SectionTitle('Apariencia'),
        _ThemeSection(),
        SizedBox(height: AppSpacing.xl),
        _SectionTitle('Biblioteca'),
        _LibrarySection(),
        SizedBox(height: AppSpacing.xl),
        _SectionTitle('Explorar'),
        _DiscoverySection(),
        SizedBox(height: AppSpacing.xl),
        _SectionTitle('Aplicación'),
        _AboutSection(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.texts.labelSmall
            ?.copyWith(color: context.colors.textTertiary),
      ),
    );
  }
}

/// Tarjeta contenedora con el estilo de superficie del tema.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
                style: context.texts.bodySmall
                    ?.copyWith(color: colors.textTertiary, fontSize: 11),
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
                          border: Border.all(color: tones.background, width: 1.5),
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
  const _Bar({
    required this.color,
    required this.width,
    required this.height,
  });

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

class _LibrarySection extends StatelessWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();

    return _Card(
      children: [
        ListTile(
          leading: const Icon(Icons.refresh_rounded),
          title: const Text('Volver a leer la biblioteca'),
          subtitle: Text(
            home.songs.isEmpty
                ? 'Sin canciones indexadas'
                : '${home.songs.length} canciones indexadas',
          ),
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
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text('Permisos y notificaciones'),
          subtitle: const Text('Se gestionan desde los ajustes del sistema'),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: openAppSettings,
        ),
      ],
    );
  }
}

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore_rounded),
          title: const Text('Descubrir música'),
          subtitle: const Text('Buscar artistas y canciones en Spotify'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.pushNamed(context, '/discovery'),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('Acerca de Kiss Music'),
          subtitle: const Text('Versión $kAppVersion'),
          onTap: () => showAboutAppDialog(context),
        ),
      ],
    );
  }
}

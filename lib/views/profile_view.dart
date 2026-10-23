import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/profile_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/profile_avatar.dart';
import 'settings_view.dart';

/// Perfil de la persona: identidad, resumen de su biblioteca y acceso a los
/// ajustes.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final playlists = context.watch<PlaylistController>().playlists;
    final colors = context.colors;

    final favoriteSongs = home.songs
        .where((s) => s.id.isNotEmpty && home.favorites.contains(s.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                const _ProfileHeader(),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.library_music_rounded,
                      value: '${home.songs.length}',
                      label: home.songs.length == 1 ? 'Canción' : 'Canciones',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _StatCard(
                      icon: Icons.favorite_rounded,
                      value: '${favoriteSongs.length}',
                      label: favoriteSongs.length == 1
                          ? 'Favorito'
                          : 'Favoritos',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _StatCard(
                      icon: Icons.queue_music_rounded,
                      value: '${playlists.length}',
                      label: playlists.length == 1 ? 'Lista' : 'Listas',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, thickness: 1, color: colors.border),
          const SizedBox(height: AppSpacing.sm),
          // Los ajustes van aquí mismo, sin otra pantalla que repita el
          // avatar y el nombre.
          const SettingsMenu(),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Kiss Music  •  Versión $kAppVersion',
              style: context.texts.bodyMedium?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final colors = context.colors;

    return Row(
      children: [
        Stack(
          children: [
            const ProfileAvatar(size: 84),
            // Botón de cámara superpuesto: el punto de entrada para cambiar
            // la foto está donde la persona espera tocarla.
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                color: colors.surface3,
                shape: CircleBorder(
                  side: BorderSide(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _changeAvatar(context),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs + 1),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => _editName(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 15,
                        color: colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        profile.name.isEmpty ? 'Poner mi nombre' : 'Editar',
                        style: context.texts.labelLarge?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context) async {
    final profile = context.read<ProfileController>();
    final textController = TextEditingController(text: profile.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: '¿Cómo te llamas?'),
          onSubmitted: (_) => Navigator.pop(dialogContext, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await profile.setName(textController.text);
    }
    textController.dispose();
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final profile = context.read<ProfileController>();
    final messenger = ScaffoldMessenger.of(context);
    final hasAvatar = profile.avatarFile != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'remove') {
      await profile.setAvatarPath(null);
      return;
    }

    try {
      final picked = await ImagePicker().pickImage(
        source: action == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (picked == null) return;

      // image_picker deja el fichero en la caché, que el sistema puede
      // vaciar. Lo copiamos al directorio de la app para que la foto
      // sobreviva.
      final directory = await getApplicationDocumentsDirectory();
      final destination = File(
        '${directory.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await destination.writeAsBytes(await picked.readAsBytes());

      final previous = profile.avatarFile;
      await profile.setAvatarPath(destination.path);
      // La foto anterior ya no se usa: no dejamos ficheros huérfanos.
      if (previous != null && previous.path != destination.path) {
        try {
          await previous.delete();
        } catch (e) {
          debugPrint('No se pudo borrar el avatar anterior: $e');
        }
      }
    } catch (e) {
      debugPrint('Error eligiendo la foto de perfil: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar la foto')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: context.texts.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

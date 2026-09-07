import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/playlist_controller.dart';
import '../models/playlist.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/music_loader.dart';
import '../widgets/playlist_cover.dart';
import 'playlist_detail_view.dart';
import 'playlist_forms.dart';

/// Índice de listas de reproducción.
///
/// Sólo lista y abre: crear, editar, añadir canciones o borrar son acciones
/// que ocurren en la pantalla de cada lista o en su propio formulario, no
/// incrustadas en el índice.
class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlaylistController>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaylistController>();

    if (controller.loading) {
      return const Center(child: MusicLoader(label: 'Cargando tus listas…'));
    }

    if (controller.playlists.isEmpty) {
      return AppEmptyState(
        icon: Icons.queue_music_outlined,
        title: 'Todavía no tienes listas',
        message: 'Crea una lista para agrupar la música que te gusta.',
        actionLabel: 'Crear lista',
        onAction: () => showCreatePlaylistSheet(context),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      itemCount: controller.playlists.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return const _CreateRow();
        return _PlaylistRow(playlist: controller.playlists[index - 1]);
      },
    );
  }
}

/// Primera fila del índice: crear. Comparte el formato de una lista para que
/// la columna de portadas quede alineada.
class _CreateRow extends StatelessWidget {
  const _CreateRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => showCreatePlaylistSheet(context),
          onLongPress: () => showCreateMixedPlaylistSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(Icons.add_rounded, color: colors.textSecondary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Crear lista', style: context.texts.titleSmall),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Mantén pulsado para una lista mixta',
                        style: context.texts.bodySmall
                            ?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaylistController>();
    final colors = context.colors;
    final count = controller.aggregatedSongs(playlist).length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PlaylistDetailView(playlistId: playlist.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                PlaylistCover(playlist: playlist, size: 60),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          if (playlist.isMixed) 'Lista mixta' else 'Lista',
                          count == 1 ? '1 canción' : '$count canciones',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall
                            ?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

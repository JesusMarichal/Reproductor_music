
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/music_loader.dart';
import '../widgets/now_playing_indicator.dart';
import '../widgets/song_artwork.dart';
import 'player_view.dart';

/// Formatea milisegundos como `m:ss`. Compartido por varias vistas.
String formatDuration(int? ms) {
  if (ms == null || ms <= 0) return '';
  final totalSeconds = (ms / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeController>().loadSongs();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();

    if (controller.isLoading) {
      return const Center(child: MusicLoader());
    }

    if (!controller.permissionGranted) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sin acceso a tu música',
        message:
            'Kiss Music necesita permiso para leer los archivos de audio '
            'del dispositivo. Puedes concederlo desde los ajustes del sistema.',
        actionLabel: 'Conceder permiso',
        onAction: controller.loadSongs,
      );
    }

    if (controller.songs.isEmpty) {
      return AppEmptyState(
        icon: Icons.library_music_outlined,
        title: 'Tu biblioteca está vacía',
        message:
            'No encontramos canciones en este dispositivo. Copia algo de '
            'música y vuelve a buscar.',
        actionLabel: 'Buscar de nuevo',
        onAction: controller.loadSongs,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.loadSongs,
      child: Scrollbar(
        controller: _scrollController,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _LibraryHeader(controller: controller)),
            SliverList.builder(
              itemCount: controller.songs.length,
              itemBuilder: (context, index) => _SongTile(
                song: controller.songs[index],
                index: index,
                controller: controller,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      ),
    );
  }
}

/// Cabecera de la biblioteca: recuento y acciones rápidas.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = controller.songs.length;
    final shuffleOn = controller.audioService.player.shuffleModeEnabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tu biblioteca', style: context.texts.headlineSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  count == 1 ? '1 canción' : '$count canciones',
                  style: context.texts.bodySmall
                      ?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: shuffleOn ? 'Desactivar aleatorio' : 'Reproducir aleatorio',
            isSelected: shuffleOn,
            color: shuffleOn ? colors.primary : colors.textSecondary,
            onPressed: () async {
              await controller.toggleShuffle();
              if (controller.currentIndex == -1 &&
                  controller.songs.isNotEmpty) {
                await controller.playAt(0);
              }
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          FilledButton.icon(
            onPressed: () => controller.playAt(0),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Reproducir'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.index,
    required this.controller,
  });

  final Song song;
  final int index;
  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCurrent = index == controller.currentIndex;
    final isPlaying = isCurrent && controller.audioService.player.playing;
    final isFavorite = controller.isFavorite(song.id);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: isCurrent ? colors.primary.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _onTap(context),
          onLongPress: () => _showOptions(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SongArtwork(song: song, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          color:
                              isCurrent ? colors.primary : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        song.artist?.trim().isNotEmpty == true
                            ? song.artist!
                            : 'Artista desconocido',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall
                            ?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Ancho reservado para que la fila no salte al empezar a sonar.
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: isPlaying
                        ? NowPlayingIndicator(
                            isPlaying: true,
                            barWidth: 2.5,
                            minHeight: 4,
                            maxHeight: 14,
                            color: colors.primary,
                          )
                        : Text(
                            formatDuration(song.duration),
                            style: context.texts.bodySmall?.copyWith(
                              color: colors.textTertiary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                  ),
                ),
                if (isFavorite)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  iconSize: 20,
                  tooltip: 'Opciones',
                  color: colors.textTertiary,
                  onPressed: () => _showOptions(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final isSame = index == controller.currentIndex;
    final playing = controller.audioService.player.playing;

    // Con el reproductor a pantalla completa abierto, tocar la pista actual no
    // debe pausarla: sólo cambiamos de canción si es otra.
    if (PlayerView.isOpen || controller.playerViewOpen) {
      if (!isSame) {
        await controller.playAt(index);
      } else if (!playing) {
        await controller.togglePlayPause();
      }
      return;
    }

    if (isSame) {
      await controller.togglePlayPause();
    } else {
      await controller.playAt(index);
    }
  }

  void _showOptions(BuildContext context) {
    final isFavorite = controller.isFavorite(song.id);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  SongArtwork(song: song, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          song.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: sheetContext.texts.titleSmall,
                        ),
                        Text(
                          song.artist ?? 'Artista desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sheetContext.texts.bodySmall
                              ?.copyWith(color: sheetContext.colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: sheetContext.colors.border),
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Reproducir'),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.playAt(index);
              },
            ),
            ListTile(
              leading: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavorite ? sheetContext.colors.primary : null,
              ),
              title: Text(
                isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.toggleFavoriteById(song.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Renombrar'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRenameDialog(context);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final textController = TextEditingController(text: song.title);

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renombrar canción'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Título'),
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
    ).then((confirmed) {
      final newTitle = textController.text.trim();
      if (confirmed == true && newTitle.isNotEmpty && newTitle != song.title) {
        controller.renameSong(song.id, newTitle);
      }
      textController.dispose();
    });
  }
}

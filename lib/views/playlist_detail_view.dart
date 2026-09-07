import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/now_playing_indicator.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/song_artwork.dart';
import 'home_view.dart' show formatDuration;
import 'add_songs_view.dart';
import 'playlist_forms.dart';

/// Pantalla de una lista de reproducción.
///
/// La portada grande se encoge al desplazar hasta convertirse en el título de
/// la barra superior. Añadir canciones se hace desde aquí, que es donde la
/// acción tiene contexto.
class PlaylistDetailView extends StatelessWidget {
  const PlaylistDetailView({super.key, required this.playlistId});

  /// Se guarda el id y no la lista: así la pantalla se redibuja con los
  /// datos frescos después de editarla o de añadirle canciones.
  final String playlistId;

  Playlist? _find(List<Playlist> playlists) {
    for (final candidate in playlists) {
      if (candidate.id == playlistId) return candidate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaylistController>();
    // Variable final: sólo así Dart mantiene la promoción a no-nulo dentro de
    // los closures de más abajo.
    final playlist = _find(controller.playlists);

    // La lista puede haberse borrado desde el menú mientras esta pantalla
    // seguía en pila.
    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const AppEmptyState(
          icon: Icons.playlist_remove_rounded,
          title: 'Esta lista ya no existe',
        ),
      );
    }

    final songs = controller.aggregatedSongs(playlist);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _PlaylistHeader(playlist: playlist, songCount: songs.length),
          SliverToBoxAdapter(
            child: _ActionBar(playlist: playlist, songs: songs),
          ),
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.music_note_outlined,
                title: 'Esta lista está vacía',
                message: playlist.isMixed
                    ? 'Las listas que la componen todavía no tienen canciones.'
                    : 'Añade canciones de tu biblioteca para empezar.',
                actionLabel: playlist.isMixed ? null : 'Añadir canciones',
                onAction: playlist.isMixed
                    ? null
                    : () => openAddSongsView(context, playlist),
              ),
            )
          else
            SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) => _TrackTile(
                song: songs[index],
                index: index,
                playlist: playlist,
                songs: songs,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

/// Cabecera colapsable: portada grande arriba, título en la barra al bajar.
class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.playlist, required this.songCount});

  final Playlist playlist;
  final int songCount;

  static const double _expandedHeight = 340;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight,
      backgroundColor: colors.surface1,
      actions: [
        _PlaylistMenu(playlist: playlist),
        const SizedBox(width: AppSpacing.xs),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final minHeight =
              MediaQuery.paddingOf(context).top + kToolbarHeight;
          // 0 = totalmente desplegada, 1 = colapsada.
          final t = ((_expandedHeight - top) /
                  (_expandedHeight - minHeight))
              .clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            centerTitle: true,
            titlePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.huge,
              vertical: AppSpacing.md,
            ),
            // El título sólo aparece cuando la portada ya casi no se ve, para
            // que no se solapen.
            title: Opacity(
              opacity: t > 0.72 ? (t - 0.72) / 0.28 : 0,
              child: Text(
                playlist.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.titleMedium,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withValues(alpha: 0.28),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Opacity(
                  opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: PlaylistCover(
                          playlist: playlist,
                          size: 172,
                          radius: AppRadius.md,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        child: Column(
                          children: [
                            Text(
                              playlist.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              [
                                if (playlist.isMixed) 'Lista mixta',
                                songCount == 1
                                    ? '1 canción'
                                    : '$songCount canciones',
                              ].join(' · '),
                              style: context.texts.bodySmall
                                  ?.copyWith(color: colors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fila de acciones: añadir, aleatorio y el botón grande de reproducir.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.playlist, required this.songs});

  final Playlist playlist;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = songs.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          if (playlist.description.isNotEmpty)
            Expanded(
              child: Text(
                playlist.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall
                    ?.copyWith(color: colors.textSecondary),
              ),
            )
          else
            const Spacer(),
          if (!playlist.isMixed)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Añadir canciones',
              color: colors.textSecondary,
              onPressed: () => openAddSongsView(context, playlist),
            ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Reproducir en aleatorio',
            color: colors.textSecondary,
            onPressed: enabled ? () => _play(context, shuffle: true) : null,
          ),
          const SizedBox(width: AppSpacing.xs),
          _PlayButton(
            onPressed: enabled ? () => _play(context) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _play(BuildContext context, {bool shuffle = false}) async {
    final home = context.read<HomeController>();
    final queue = shuffle ? ([...songs]..shuffle()) : songs;
    await home.playSubset(
      queue,
      0,
      mixed: playlist.isMixed,
      mixedId: playlist.isMixed ? playlist.id : null,
      mixedTitle: playlist.isMixed ? playlist.title : null,
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = onPressed != null;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active ? colors.brandGradient : null,
        color: active ? null : colors.surface2,
        boxShadow: active
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: 'Reproducir',
          icon: const Icon(Icons.play_arrow_rounded),
          iconSize: 32,
          color: active
              ? Theme.of(context).colorScheme.onPrimary
              : colors.textTertiary,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _PlaylistMenu extends StatelessWidget {
  const _PlaylistMenu({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'Opciones de la lista',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!playlist.isMixed)
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Añadir canciones'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openAddSongsView(context, playlist);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar lista'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showEditPlaylistSheet(context, playlist);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Eliminar lista',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final navigator = Navigator.of(context);
                  final deleted = await confirmDeletePlaylist(
                    context,
                    playlist,
                  );
                  // Al borrarla, esta pantalla ya no tiene nada que mostrar.
                  if (deleted && navigator.canPop()) navigator.pop();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.song,
    required this.index,
    required this.playlist,
    required this.songs,
  });

  final Song song;
  final int index;
  final Playlist playlist;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final colors = context.colors;

    final isCurrent = home.currentSong?.id == song.id;
    final isPlaying = isCurrent && home.audioService.player.playing;

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
          onTap: () => context.read<HomeController>().playSubset(
                songs,
                index,
                mixed: playlist.isMixed,
                mixedId: playlist.isMixed ? playlist.id : null,
                mixedTitle: playlist.isMixed ? playlist.title : null,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                SongArtwork(song: song, size: 48),
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
                SizedBox(
                  width: 40,
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
                            style: context.texts.bodySmall
                                ?.copyWith(color: colors.textTertiary),
                          ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  iconSize: 20,
                  tooltip: 'Quitar de la lista',
                  color: colors.textTertiary,
                  onPressed: () => _remove(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final controller = context.read<PlaylistController>();
    final messenger = ScaffoldMessenger.of(context);

    // En una lista mixta la canción pertenece a otra lista: se excluye de la
    // vista combinada en vez de borrarla de su lista de origen.
    if (playlist.isMixed) {
      await controller.excludeSongFromMixed(playlist.id, song.id);
    } else {
      await controller.removeSongFromPlaylist(playlist.id, song.id);
    }

    messenger.showSnackBar(
      SnackBar(content: Text('«${song.title}» quitada de la lista')),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/music_loader.dart';
import '../widgets/song_artwork.dart';
import 'home_view.dart' show formatDuration;

/// Búsqueda dentro de la biblioteca, con selección múltiple para añadir
/// varias canciones a una lista de una vez.
///
/// Es una pestaña del contenedor principal: no define barra superior propia
/// ni cierra la pantalla al reproducir.
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _queryController = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<Song> _filter(List<Song> songs) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return songs;
    return songs.where((s) {
      return s.title.toLowerCase().contains(query) ||
          (s.artist ?? '').toLowerCase().contains(query) ||
          (s.album ?? '').toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final colors = context.colors;

    if (home.isLoading) {
      return const Center(child: MusicLoader());
    }

    final results = _filter(home.songs);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Título, artista o álbum',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _queryController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        // Barra contextual de selección: sustituye a la acción que antes
        // vivía en la barra superior, que esta vista ya no controla.
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.length == 1
                          ? '1 seleccionada'
                          : '${_selected.length} seleccionadas',
                      style: context.texts.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Quitar'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    onPressed: () => _addToPlaylist(_selected.toList()),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: const Text('Añadir'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? AppEmptyState(
                  icon: _query.isEmpty
                      ? Icons.search_rounded
                      : Icons.search_off_rounded,
                  title: _query.isEmpty
                      ? 'Busca en tu biblioteca'
                      : 'Sin resultados',
                  message: _query.isEmpty
                      ? 'Escribe el título de una canción, un artista o un '
                            'álbum.'
                      : 'No hay ninguna canción que coincida con «$_query».',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final song = results[i];
                    return _ResultTile(
                      song: song,
                      isCurrent: home.currentSong?.id == song.id,
                      selected: _selected.contains(song.id),
                      onToggleSelection: () => _toggleSelection(song.id),
                      onPlay: () {
                        final index = home.songs.indexWhere(
                          (s) => s.id == song.id,
                        );
                        if (index != -1) home.playAt(index);
                      },
                      onAddToPlaylist: () => _addToPlaylist([song.id]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addToPlaylist(List<String> songIds) async {
    final playlistController = context.read<PlaylistController>();
    await playlistController.init();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final playlists = playlistController.playlists;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  songIds.length == 1
                      ? 'Añadir a una lista'
                      : 'Añadir ${songIds.length} canciones',
                  style: sheetContext.texts.titleMedium,
                ),
              ),
              if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Text(
                    'Todavía no hay listas. Crea una desde la pestaña Listas.',
                    style: sheetContext.texts.bodyMedium?.copyWith(
                      color: sheetContext.colors.textSecondary,
                    ),
                  ),
                ),
              for (final playlist in playlists)
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.title),
                  subtitle: Text('${playlist.songIds.length} canciones'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(sheetContext).pop();
                    await playlistController.addSongsToPlaylist(
                      playlist.id,
                      songIds,
                    );
                    if (!mounted) return;
                    setState(_selected.clear);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Añadido a «${playlist.title}»')),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.song,
    required this.isCurrent,
    required this.selected,
    required this.onToggleSelection,
    required this.onPlay,
    required this.onAddToPlaylist,
  });

  final Song song;

  /// La que está sonando: se resalta igual que en la biblioteca.
  final bool isCurrent;
  final bool selected;
  final VoidCallback onToggleSelection;
  final VoidCallback onPlay;
  final VoidCallback onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.12)
            : isCurrent
            ? colors.primary.withValues(alpha: 0.10)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPlay,
          onLongPress: onToggleSelection,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                // Mismo tamaño que en la biblioteca: la carátula marca el alto
                // de la fila y, si no, la lista encoge al cambiar de pestaña.
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
                          color: isCurrent
                              ? colors.primary
                              : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          song.artist?.trim().isNotEmpty == true
                              ? song.artist!.trim()
                              : 'Artista desconocido',
                          if (song.album?.trim().isNotEmpty == true)
                            song.album!.trim(),
                          if (formatDuration(song.duration).isNotEmpty)
                            formatDuration(song.duration),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add_rounded),
                  iconSize: 20,
                  tooltip: 'Añadir a una lista',
                  color: colors.textTertiary,
                  onPressed: onAddToPlaylist,
                ),
                IconButton(
                  icon: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                  ),
                  iconSize: 20,
                  tooltip: selected ? 'Quitar de la selección' : 'Seleccionar',
                  color: selected ? colors.primary : colors.textTertiary,
                  onPressed: onToggleSelection,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

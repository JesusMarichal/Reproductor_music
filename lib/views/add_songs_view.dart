import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/song_artwork.dart';
import 'home_view.dart' show formatDuration;

/// Abre la pantalla para añadir canciones a [playlist].
Future<void> openAddSongsView(BuildContext context, Playlist playlist) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => AddSongsView(playlist: playlist)),
  );
}

/// Pantalla completa para elegir qué canciones se añaden a una lista.
///
/// Es una vista propia y no una hoja modal: buscar entre toda la biblioteca
/// y marcar varias canciones necesita alto de pantalla y un teclado que no
/// tape la selección.
class AddSongsView extends StatefulWidget {
  const AddSongsView({super.key, required this.playlist});

  final Playlist playlist;

  @override
  State<AddSongsView> createState() => _AddSongsViewState();
}

class _AddSongsViewState extends State<AddSongsView> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _selected = {};

  String _search = '';
  bool _saving = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Canciones de la biblioteca que aún no están en la lista, filtradas por
  /// el texto de búsqueda.
  List<Song> _candidates(List<Song> library) {
    final already = widget.playlist.songIds.toSet();
    final query = _search.trim().toLowerCase();

    return library.where((song) {
      if (already.contains(song.id)) return false;
      if (query.isEmpty) return true;
      return song.title.toLowerCase().contains(query) ||
          (song.artist ?? '').toLowerCase().contains(query) ||
          (song.album ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final controller = context.read<PlaylistController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final count = _selected.length;

    await controller.addSongsToPlaylist(
      widget.playlist.id,
      _selected.toList(),
    );

    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Canción añadida a «${widget.playlist.title}»'
              : '$count canciones añadidas a «${widget.playlist.title}»',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final colors = context.colors;
    final candidates = _candidates(home.songs);
    final allSelected = candidates.isNotEmpty &&
        candidates.every((s) => _selected.contains(s.id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Añadir canciones'),
            Text(
              widget.playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        actions: [
          if (candidates.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.removeAll(candidates.map((s) => s.id));
                } else {
                  _selected.addAll(candidates.map((s) => s.id));
                }
              }),
              child: Text(allSelected ? 'Ninguna' : 'Todas'),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por título, artista o álbum',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Limpiar',
                        onPressed: () {
                          _query.clear();
                          setState(() => _search = '');
                        },
                      ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
        ),
      ),
      body: candidates.isEmpty
          ? AppEmptyState(
              icon: _search.isEmpty
                  ? Icons.library_add_check_rounded
                  : Icons.search_off_rounded,
              title: _search.isEmpty
                  ? 'No queda nada por añadir'
                  : 'Sin resultados',
              message: _search.isEmpty
                  ? 'Todas las canciones de tu biblioteca ya están en esta '
                      'lista.'
                  : 'Ninguna canción coincide con «$_search».',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              itemCount: candidates.length,
              itemBuilder: (context, i) {
                final song = candidates[i];
                return _SelectableSongTile(
                  song: song,
                  selected: _selected.contains(song.id),
                  onTap: () => setState(() {
                    if (!_selected.remove(song.id)) _selected.add(song.id);
                  }),
                );
              },
            ),
      bottomNavigationBar: _ConfirmBar(
        count: _selected.length,
        saving: _saving,
        onClear: () => setState(_selected.clear),
        onConfirm: _save,
      ),
    );
  }
}

/// Barra inferior de confirmación. Sólo ocupa espacio cuando hay algo
/// seleccionado, para no robar alto a la lista mientras se busca.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.count,
    required this.saving,
    required this.onClear,
    required this.onConfirm,
  });

  final int count;
  final bool saving;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedSize(
      duration: AppDuration.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface1,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          count == 1
                              ? '1 canción seleccionada'
                              : '$count canciones seleccionadas',
                          style: context.texts.titleSmall,
                        ),
                      ),
                      TextButton(
                        onPressed: saving ? null : onClear,
                        child: const Text('Quitar'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FilledButton(
                        onPressed: saving ? null : onConfirm,
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Añadir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _SelectableSongTile extends StatelessWidget {
  const _SelectableSongTile({
    required this.song,
    required this.selected,
    required this.onTap,
  });

  final Song song;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        color: selected ? colors.primary.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
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
                        style: context.texts.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        [
                          song.artist?.trim().isNotEmpty == true
                              ? song.artist!.trim()
                              : 'Artista desconocido',
                          if (formatDuration(song.duration).isNotEmpty)
                            formatDuration(song.duration),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall
                            ?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? colors.primary : colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

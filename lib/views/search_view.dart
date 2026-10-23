import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../models/song.dart';
import '../models/youtube_track.dart';
import '../services/preview_service.dart';
import '../services/youtube_service.dart';
import '../utils/text_fold.dart';
import '../theme/app_theme.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/music_loader.dart';
import '../widgets/song_artwork.dart';
import '../widgets/youtube_key_dialog.dart';
import 'home_view.dart' show formatDuration;

/// Búsqueda con dos pestañas deslizables y un buscador común:
///
/// - **Biblioteca**: tus canciones, con selección múltiple para añadir
///   varias a una lista de una vez.
/// - **Nube**: canciones de Internet (resultados de YouTube) con vista previa
///   de 30 s.
///
/// En Nube se busca sola: al llegar a la pestaña con texto escrito y al dejar
/// de teclear un momento. Cada búsqueda gasta cuota de la API (unas 100 al
/// día gratis), así que se espera a que haya al menos [_minCloudQuery] letras
/// y nunca se repite una búsqueda ya hecha.
///
/// Es una pestaña del contenedor principal: no define barra superior propia
/// ni cierra la pantalla al reproducir.
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

const int _minCloudQuery = 3;

class _SearchViewState extends State<SearchView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);
  final Set<String> _selected = {};
  String _query = '';

  /// Espera tras la última tecla antes de buscar en la nube.
  Timer? _debounce;

  /// Estado de la búsqueda en la nube para [_ytQuery].
  String? _ytQuery;
  List<YouTubeTrack>? _ytResults;
  YouTubeException? _ytError;
  bool _ytLoading = false;

  bool get _onCloud => _tabs.index == 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _tabs.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // El índice cambia al empezar la animación y otra vez al acabar; basta
    // con reaccionar una vez.
    if (_tabs.indexIsChanging) return;
    setState(() {});
    if (_onCloud) _searchCloud(auto: true);
  }

  List<Song> _filter(List<Song> songs) {
    // Cada palabra puede estar en un campo distinto: "angele oui ou non"
    // encuentra el título "Oui ou non" de la artista "Angèle".
    final words = foldText(
      _query.trim(),
    ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return songs;
    return songs.where((s) {
      final haystack = foldText(
        '${s.title} ${s.artist ?? ''} ${s.album ?? ''}',
      );
      return words.every(haystack.contains);
    }).toList();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      // Si esa búsqueda ya se hizo, se enseña sin gastar cuota.
      final cached = YouTubeService.instance.cached(value);
      _ytQuery = cached == null ? null : value.trim();
      _ytResults = cached;
      _ytError = null;
    });
    _debounce?.cancel();
    if (_onCloud) {
      _debounce = Timer(
        const Duration(seconds: 1),
        () => _searchCloud(auto: true),
      );
    }
  }

  /// Busca en la nube. Las búsquedas automáticas (cambio de pestaña, pausa
  /// al teclear) exigen un mínimo de letras; la del teclado, no.
  Future<void> _searchCloud({bool auto = false}) async {
    _debounce?.cancel();
    final query = _query.trim();
    if (query.isEmpty || _ytLoading) return;
    if (auto && query.length < _minCloudQuery) return;
    // Ya buscada (con resultados o con un error que no se arregla solo).
    if (_ytQuery == query && (_ytResults != null || auto)) return;

    setState(() {
      _ytLoading = true;
      _ytError = null;
      _ytQuery = query;
    });
    try {
      final results = await YouTubeService.instance.search(query);
      if (!mounted || _ytQuery != query) return;
      setState(() => _ytResults = results);
    } on YouTubeException catch (e) {
      if (!mounted || _ytQuery != query) return;
      setState(() => _ytError = e);
    } finally {
      if (mounted) setState(() => _ytLoading = false);
    }
  }

  Future<void> _configureYouTube() async {
    final changed = await showYouTubeKeyDialog(context);
    if (changed && mounted && _query.trim().isNotEmpty) {
      setState(() => _ytQuery = null);
      _searchCloud();
    }
  }

  Future<void> _togglePreview(YouTubeTrack track) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await PreviewService.instance.toggle(track);
    if (!ok) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No hay vista previa disponible para esta canción'),
        ),
      );
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();

    if (home.isLoading) {
      return const Center(child: MusicLoader());
    }

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
              hintText: _onCloud
                  ? 'Canciones o artistas en Internet'
                  : 'Título, artista o álbum',
              prefixIcon: Icon(
                _onCloud ? Icons.cloud_outlined : Icons.search_rounded,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _queryController.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (_) {
              if (_onCloud) _searchCloud();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: _SourceTabs(controller: _tabs),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_libraryTab(home), _cloudTab()],
          ),
        ),
      ],
    );
  }

  Widget _libraryTab(HomeController home) {
    final colors = context.colors;
    final results = _filter(home.songs);

    return Column(
      children: [
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
                  icon: _query.trim().isEmpty
                      ? Icons.search_rounded
                      : Icons.search_off_rounded,
                  title: _query.trim().isEmpty
                      ? 'Busca en tu biblioteca'
                      : 'Sin resultados',
                  message: _query.trim().isEmpty
                      ? 'Escribe el título de una canción, un artista o un '
                            'álbum.'
                      : 'No hay ninguna canción que coincida con «${_query.trim()}». '
                            'Desliza a Nube para buscarla en Internet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _libraryTile(home, results[i]),
                ),
        ),
      ],
    );
  }

  Widget _libraryTile(HomeController home, Song song) {
    return _ResultTile(
      song: song,
      isCurrent: home.currentSong?.id == song.id,
      selected: _selected.contains(song.id),
      onToggleSelection: () => _toggleSelection(song.id),
      onPlay: () {
        final index = home.songs.indexWhere((s) => s.id == song.id);
        if (index != -1) home.playAt(index);
      },
      onAddToPlaylist: () => _addToPlaylist([song.id]),
    );
  }

  Widget _cloudTab() {
    if (_query.trim().isEmpty) {
      return const AppEmptyState(
        icon: Icons.cloud_outlined,
        title: 'Busca en la nube',
        message:
            'Escribe una canción o un artista y escucha una vista previa de '
            '30 segundos.',
      );
    }
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: _SectionHeader(
            'Internet',
            icon: Icons.download_rounded,
            caption: 'Vista previa · 30 s',
          ),
        ),
        ..._cloudSlivers(),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
      ],
    );
  }

  List<Widget> _cloudSlivers() {
    final query = _query.trim();
    final searched = _ytQuery == query;

    if (_ytLoading && searched) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
          ),
        ),
      ];
    }

    final error = searched ? _ytError : null;
    if (error != null) {
      return [
        SliverToBoxAdapter(
          child: _YouTubeMessage(
            icon: error.needsKey
                ? Icons.key_rounded
                : Icons.error_outline_rounded,
            text: error.message,
            action: error.needsKey ? 'Configurar' : 'Reintentar',
            onAction: error.needsKey ? _configureYouTube : _searchCloud,
          ),
        ),
      ];
    }

    final results = searched ? _ytResults : null;
    if (results == null) {
      // Aún sin buscar: texto demasiado corto para la búsqueda automática.
      return [
        SliverToBoxAdapter(
          child: _YouTubeSearchRow(query: query, onTap: _searchCloud),
        ),
      ];
    }

    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _YouTubeMessage(
            icon: Icons.search_off_rounded,
            text: 'No hay resultados en Internet para «$query».',
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => _YouTubeTile(
          track: results[i],
          onTap: () => _togglePreview(results[i]),
        ),
      ),
    ];
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, {this.icon, this.caption});

  final String text;
  final IconData? icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: context.colors.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(text, style: context.texts.titleMedium),
          if (caption != null) ...[
            const Spacer(),
            Text(
              caption!,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila que lanza la búsqueda en YouTube, con el mismo alto que una canción.
class _YouTubeSearchRow extends StatelessWidget {
  const _YouTubeSearchRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _TileFrame(
      onTap: onTap,
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(Icons.search_rounded, color: colors.primary),
      ),
      title: 'Buscar «$query» en Internet',
      subtitle: 'O pulsa buscar en el teclado',
      trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
    );
  }
}

class _YouTubeTile extends StatelessWidget {
  const _YouTubeTile({required this.track, required this.onTap});

  final YouTubeTrack track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = track.duration;
    return _TileFrame(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.network(
          track.thumbnailUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 52,
            height: 52,
            color: colors.surface2,
            child: Icon(Icons.music_note_rounded, color: colors.textTertiary),
          ),
        ),
      ),
      title: track.title,
      subtitle: [
        if (track.channel.isNotEmpty) track.channel,
        if (duration != null) formatDuration(duration.inMilliseconds),
      ].join(' · '),
      trailing: ListenableBuilder(
        listenable: PreviewService.instance,
        builder: (context, _) => _PreviewIndicator(
          status: PreviewService.instance.statusOf(track.videoId),
        ),
      ),
    );
  }
}

/// Estado de la vista previa en la fila: reproducir, cargando, el avance de
/// los 30 s alrededor de un botón de parar, o sin vista previa.
class _PreviewIndicator extends StatelessWidget {
  const _PreviewIndicator({required this.status});

  final PreviewStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = 24.0;
    return SizedBox.square(
      dimension: size,
      child: switch (status) {
        PreviewStatus.idle => Icon(
          Icons.play_arrow_rounded,
          color: colors.textTertiary,
        ),
        PreviewStatus.unavailable => Icon(
          Icons.music_off_rounded,
          size: 20,
          color: colors.textTertiary.withValues(alpha: 0.5),
        ),
        PreviewStatus.loading => Padding(
          padding: const EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
        PreviewStatus.playing => StreamBuilder<double>(
          stream: PreviewService.instance.progress,
          builder: (context, snapshot) => Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: snapshot.data ?? 0,
                strokeWidth: 2.5,
                color: colors.primary,
                backgroundColor: colors.primary.withValues(alpha: 0.2),
              ),
              Icon(Icons.stop_rounded, size: 14, color: colors.primary),
            ],
          ),
        ),
      },
    );
  }
}

/// Misma caja que [_ResultTile] (márgenes, radio, carátula de 52) para que
/// las filas de YouTube no cambien de tamaño respecto a las de la biblioteca.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: trailing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso dentro de la sección de YouTube (error, sin key, sin resultados).
class _YouTubeMessage extends StatelessWidget {
  const _YouTubeMessage({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: context.texts.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonal(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

/// Selector Biblioteca / Nube en forma de píldora, deslizable junto con las
/// páginas.
class _SourceTabs extends StatelessWidget {
  const _SourceTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        indicator: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: context.texts.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        splashBorderRadius: BorderRadius.circular(AppRadius.pill),
        tabs: const [
          _SourceTab(icon: Icons.library_music_rounded, label: 'Biblioteca'),
          _SourceTab(icon: Icons.cloud_rounded, label: 'Nube'),
        ],
      ),
    );
  }
}

class _SourceTab extends StatelessWidget {
  const _SourceTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(label),
        ],
      ),
    );
  }
}

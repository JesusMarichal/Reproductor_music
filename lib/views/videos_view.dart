import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/video_controller.dart';
import '../widgets/music_loader.dart';

class VideosView extends StatefulWidget {
  const VideosView({super.key});

  @override
  State<VideosView> createState() => _VideosViewState();
}

class _VideosViewState extends State<VideosView> {
  String _selectedCategory = 'Destacados';
  final ScrollController _scrollCtrl = ScrollController();
  DateTime? _lastScrollCall;
  late final List<String> _categoryKeys;

  @override
  void initState() {
    super.initState();
    // Carga inicial usando cache/paginación del controlador
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoController>().ensureCategoryLoaded(_selectedCategory);
    });
    _categoryKeys = VideoController.categories.keys.toList(growable: false);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final offset = _scrollCtrl.offset;
    if (max - offset < 400) {
      // Debounce para evitar ráfagas de llamadas al final
      final now = DateTime.now();
      if (_lastScrollCall == null ||
          now.difference(_lastScrollCall!) >
              const Duration(milliseconds: 600)) {
        _lastScrollCall = now;
        context.read<VideoController>().loadMoreCategory(_selectedCategory);
      }
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración de video',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('Opciones disponibles en próximas versiones.'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
            tooltip: 'Configuración de video',
          ),
        ],
      ),
      body: Column(
        children: [
          // Reproductor compartido
          const _VideoPlayerDock(),
          const SizedBox(height: 8),

          // Chips de categorías
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, idx) {
                final cat = _categoryKeys[idx];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (v) async {
                    if (!v) return;
                    setState(() => _selectedCategory = cat);
                    await context.read<VideoController>().ensureCategoryLoaded(
                      cat,
                    );
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _categoryKeys.length,
            ),
          ),

          // Lista con caché + paginación (optimizada)
          Expanded(
            child: Builder(
              builder: (context) {
                // Usar context.select para reconstruir sólo cuando cambian
                // las piezas que nos interesan.
                final list = context.select<VideoController, List<VideoItem>>(
                  (vc) => vc.categoryItems(_selectedCategory),
                );
                final isLoadingCategory = context.select<VideoController, bool>(
                  (vc) => vc.isLoadingCategory(_selectedCategory),
                );
                final isLoadingMore = context.select<VideoController, bool>(
                  (vc) => vc.isLoadingMore(_selectedCategory),
                );

                if (list.isEmpty && isLoadingCategory) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(height: 8),
                        SizedBox(width: 140, height: 36, child: MusicLoader()),
                        SizedBox(height: 12),
                        Text(
                          'Cargando Contenido',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                if (list.isEmpty && isLoadingMore) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }

                // fijar itemExtent mejora rendimiento cuando los items tienen altura constante
                return ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  cacheExtent: 800,
                  itemCount: list.length + (isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (isLoadingMore && index == list.length) {
                      return const _LoadingMoreTile();
                    }
                    final vid = list[index];

                    return SizedBox(
                      height: 100,
                      child: RepaintBoundary(
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => context.read<VideoController>().load(
                              vid.id,
                              title: vid.title,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: vid.thumbUrl,
                                    width: 140,
                                    height: 78,
                                    fit: BoxFit.cover,
                                    placeholder: (context, _) => Container(
                                      width: 140,
                                      height: 78,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                    ),
                                    errorWidget: (context, _, __) => Container(
                                      width: 140,
                                      height: 78,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceVariant,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        vid.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (vid.channel != null)
                                        Text(
                                          vid.channel!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.play_circle_fill),
                                  onPressed: () => context
                                      .read<VideoController>()
                                      .load(vid.id, title: vid.title),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerDock extends StatelessWidget {
  const _VideoPlayerDock();
  @override
  Widget build(BuildContext context) {
    // Reconstruir cuando la versión del controller cambie, y leer el controller actual
    final version = context.select<VideoController, int>(
      (c) => c.controllerVersion,
    );
    final yt = context.read<VideoController>().ytController;
    return RepaintBoundary(
      child: YoutubePlayer(
        key: ValueKey<int>(version),
        controller: yt,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _LoadingMoreTile extends StatelessWidget {
  const _LoadingMoreTile();
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(width: 10),
          Text('Cargando más…', style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

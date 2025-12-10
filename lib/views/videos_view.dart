import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/video_controller.dart';
import 'player_view.dart';
import '../widgets/music_loader.dart';

class VideosView extends StatefulWidget {
  const VideosView({super.key});

  @override
  State<VideosView> createState() => _VideosViewState();
}

class _VideosViewState extends State<VideosView> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _query = '';
  // Categoría seleccionada por defecto
  String _selectedCategory = 'Destacados';
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Cargar categoría inicial al arrancar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategory(_selectedCategory);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadCategory(String cat) {
    setState(() => _selectedCategory = cat);
    // Solicitamos al controller que asegure la carga
    context.read<VideoController>().ensureCategoryLoaded(cat);
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = v.trim();
      setState(() {
        _query = q;
        _isSearching = q.isNotEmpty;
      });
      if (q.isNotEmpty) {
        context.read<VideoController>().search(q).whenComplete(() {
          if (mounted) setState(() => _isSearching = false);
        });
      }
    });
  }

  Future<void> _playVideo(VideoItem vid) async {
    // Cargar en el controlador global
    await context.read<VideoController>().load(vid.id, title: vid.title);
    // Navegar al PlayerView (Fullscreen)
    if (!mounted) return;
    if (!PlayerView.isOpen) {
      // Usamos la ruta global definida en player_view o push directo
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PlayerView()));
    }
  }

  Widget _buildCategorySelector() {
    final theme = Theme.of(context);
    final cats = VideoController.categories.keys.toList();

    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = cats[index];
          final isSelected = cat == _selectedCategory;
          return FilterChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) {
              _loadCategory(cat);
              _scrollCtrl.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            backgroundColor: theme.canvasColor,
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : theme.dividerColor.withOpacity(0.1),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildVideoList(List<VideoItem> videos, {bool isLoading = false}) {
    if (isLoading && videos.isEmpty) {
      return const Center(child: MusicLoader());
    }
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.ondemand_video,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            const Text('No hay videos disponibles'),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: videos.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= videos.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final vid = videos[index];
        return _VideoCardLarge(video: vid, onTap: () => _playVideo(vid));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.watch<VideoController>();
    final isSearching = _query.isNotEmpty;

    // Decidir qué lista mostrar
    List<VideoItem> displayList;
    bool isLoading;

    if (isSearching) {
      displayList = vc.searchResults;
      isLoading = _isSearching;
    } else {
      displayList = vc.categoryItems(_selectedCategory);
      isLoading = vc.isLoadingCategory(_selectedCategory);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // -- Search Bar --
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar en TV...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                              // Volver a categoría
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),

            // -- Category Selector (Solo si no busca) --
            if (!isSearching) ...[
              const SizedBox(height: 4),
              _buildCategorySelector(),
              const SizedBox(height: 8),
            ],

            // -- Content --
            Expanded(child: _buildVideoList(displayList, isLoading: isLoading)),
          ],
        ),
      ),
    );
  }
}

class _VideoCardLarge extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;

  const _VideoCardLarge({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail 16:9
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: video.thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: theme.colorScheme.surfaceVariant),
                      errorWidget: (_, __, ___) => Container(
                        color: theme.colorScheme.surfaceVariant,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
                ),
                // Duration badge (if available) can go here
                if (video.duration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(video.duration!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Info Row with generic avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.person,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        video.channel ?? 'Desconocido',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

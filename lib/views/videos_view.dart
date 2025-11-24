import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Ya no usamos el player embebido en esta vista; el PlayerView se abre en una ruta separada.

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
  String _query = '';
  Timer? _debounce;
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final q = v.trim();
      if (q.isEmpty) return;
      setState(() {
        _query = q;
        _isSearching = true;
      });
      context.read<VideoController>().search(q).whenComplete(() {
        if (mounted) setState(() => _isSearching = false);
      });
    });
  }

  void _performSearch() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    setState(() {
      _query = q;
      _isSearching = true;
    });
    context.read<VideoController>().search(q).whenComplete(() {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(height: 8),
          SizedBox(width: 140, height: 36, child: MusicLoader()),
          SizedBox(height: 12),
          Text('Ingrese un término para buscar videos'),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Builder(
      builder: (context) {
        final searchResults = context.select<VideoController, List<VideoItem>>(
          (vc) => vc.searchResults,
        );

        if (searchResults.isEmpty) {
          if (_isSearching)
            return const Center(child: CircularProgressIndicator());
          return const Center(child: Text('Sin resultados'));
        }

        return ListView.separated(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          cacheExtent: 800,
          itemCount: searchResults.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final vid = searchResults[index];

            return SizedBox(
              height: 100,
              child: RepaintBoundary(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () async {
                      await context.read<VideoController>().load(
                        vid.id,
                        title: vid.title,
                      );
                      if (!PlayerView.isOpen)
                        Navigator.of(context).push(buildPlayerRoute());
                    },
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
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                          onPressed: () async {
                            await context.read<VideoController>().load(
                              vid.id,
                              title: vid.title,
                            );
                            if (!PlayerView.isOpen)
                              Navigator.of(context).push(buildPlayerRoute());
                          },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar videos o canales',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _query = '';
                                  });
                                  // Limpiar resultados en el controller y UI local
                                  final vc = context.read<VideoController>();
                                  vc.searchResults = const [];
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Mostramos solo la lista de resultados (sin reproductor embebido)
            Expanded(
              child: _query.isEmpty ? _buildPlaceholder() : _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }
}

// _LoadingMoreTile removed: ya no se usa en la versión de solo búsqueda

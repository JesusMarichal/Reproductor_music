import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../controllers/home_controller.dart';
import '../widgets/player_bar.dart';
import 'home_view.dart' show formatDuration;

class FavoritesView extends StatefulWidget {
  const FavoritesView({super.key});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildPlaybackIndicator() {
    return SizedBox(
      width: 28,
      height: 14,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final v = _pulse.value;
          final h1 = 4.0 + 6.0 * v; // 4..10
          final h2 = 6.0 + 6.0 * (1.0 - v); // 6..12
          final h3 = 5.0 + 6.0 * (0.5 + 0.5 * v); // 5..11
          final color = Theme.of(context).colorScheme.primary;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 4,
                height: h1,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 4,
                height: h2,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 4,
                height: h3,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final favs = controller.favorites;
    final favoriteSongs = controller.songs
        .where((s) => s.id.isNotEmpty && favs.contains(s.id))
        .toList();

    if (favoriteSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_border, size: 72, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay favoritos', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Header card con acción reproducir todo
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reproducir favoritos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${favoriteSongs.length} canciones',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Reproducir'),
                      onPressed: () async {
                        try {
                          // Pausar video si está activo
                          try {
                            final vc = VideoControllerAccess.instanceOrNull();
                            if (vc?.pauseIfPlaying != null)
                              vc!.pauseIfPlaying!();
                          } catch (_) {}
                          await controller.audioService.setQueueFromSongs(
                            favoriteSongs,
                          );
                          await controller.audioService.playIndex(0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Reproduciendo ${favoriteSongs.length} favoritos',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al reproducir favoritos'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Lista de favoritos (estilo igual al Home: artwork, título, artista, duración)
              ...favoriteSongs.map((song) {
                // `isCandidate` indica que la canción en el controlador coincide
                // con este item; no implica que esté reproduciéndose.
                final isCandidate = controller.currentSong?.id == song.id;
                final intSongId = int.tryParse(song.id) ?? 0;

                final card = Padding(
                  // Un poco más de espacio vertical para distinguir cartas
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        // Pausar video si está activo
                        try {
                          final vc = VideoControllerAccess.instanceOrNull();
                          if (vc?.pauseIfPlaying != null) vc!.pauseIfPlaying!();
                        } catch (_) {}

                        // Construir la cola SOLO con favoritos y empezar en este índice.
                        final startIndex = favoriteSongs.indexWhere(
                          (s) => s.id == song.id,
                        );
                        if (startIndex == -1) return;
                        try {
                          await controller.audioService.setQueueFromSongs(
                            favoriteSongs,
                          );
                          await controller.audioService.playIndex(startIndex);
                        } catch (e) {
                          // Fallback: reproducir esta URI directamente si falla la cola.
                          if (song.uri != null && song.uri!.isNotEmpty) {
                            await controller.audioService.playUri(song.uri!);
                          }
                        }
                      },
                      child: SizedBox(
                        height: 68,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: QueryArtworkWidget(
                                  id: intSongId,
                                  type: ArtworkType.AUDIO,
                                  artworkBorder: BorderRadius.zero,
                                  keepOldArtwork: true,
                                  nullArtworkWidget: Container(
                                    width: 56,
                                    height: 56,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.12),
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 28,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  size: 56,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${song.artist ?? 'Desconocido'}${(song.album != null && song.album!.isNotEmpty) ? ' • ${song.album}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Text(
                                formatDuration(song.duration),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                // Si este item corresponde a la canción actual (isCandidate), lo
                // envolvemos en un StreamBuilder para decidir visualmente si mostrar
                // el pulso y las barras sólo cuando realmente esté reproduciéndose.
                if (isCandidate) {
                  return StreamBuilder<bool>(
                    stream: controller.audioService.player.playingStream,
                    initialData: controller.audioService.player.playing,
                    builder: (context, snap) {
                      final playing = snap.data ?? false;
                      // Control de animación fuera del build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (playing) {
                          if (!_animController.isAnimating)
                            _animController.repeat(reverse: true);
                        } else {
                          if (_animController.isAnimating)
                            _animController.stop();
                        }
                      });

                      // Si no está reproduciéndose, devolvemos el card sin pulso
                      // ni barras (evita que se muestre activo por defecto).
                      if (!playing) return card;

                      return AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final p = _pulse.value;
                          final base = Theme.of(context).colorScheme.primary;
                          final innerAlpha = 0.10 + 0.18 * p;
                          final radius = 0.9 + 0.25 * p;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 6.0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: RadialGradient(
                                        center: const Alignment(-0.2, -0.1),
                                        radius: radius,
                                        colors: [
                                          base.withOpacity(innerAlpha),
                                          base.withOpacity(0.0),
                                        ],
                                        stops: const [0.0, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(child: card),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: _buildPlaybackIndicator(),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                }

                return card;
              }).toList(),
            ],
          ),
        ),

        // Player bar fijo al fondo si hay una canción seleccionada
        if (controller.currentIndex != -1) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const PlayerBar(),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:on_audio_query/on_audio_query.dart';
import '../controllers/home_controller.dart';
import '../widgets/player_bar.dart';
import '../widgets/music_loader.dart';
import '../widgets/now_playing_indicator.dart';
import 'player_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

// Utility para formatear duración en mm:ss. Extraído fuera del builder para evitar recrearlo por item.
String formatDuration(int? ms) {
  if (ms == null) return '';
  final seconds = (ms / 1000).round();
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '${minutes.toString()}:${remaining.toString().padLeft(2, "0")}';
}

class HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animController;
  // _pulse removed as it was unused in new design

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<HomeController>();
      controller.loadSongs();
    });

    _scrollController = ScrollController();
    // _scrollOffset removed

    // Animation para destacar la pista en reproducción (pulso + ligero tilt)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // _pulse definition removed
    // La animación se controlará dinámicamente según el estado de reproducción
    // (se inicia/paraliza en el StreamBuilder de cada item).
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Pequeño indicador visual junto a la duración que pulsa cuando la pista
  // está en reproducción. Reutiliza la animación `_pulse` ya definida.
  @override
  // Pequeño indicador visual junto a la duración que pulsa cuando la pista
  // está en reproducción. Reutiliza la animación `_pulse` ya definida.
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    if (controller.isLoading) return const Center(child: MusicLoader());

    if (!controller.permissionGranted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Necesitamos permiso para acceder a tus canciones.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => controller.loadSongs(),
              child: const Text('Conceder permiso'),
            ),
          ],
        ),
      );
    }

    if (controller.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se encontraron canciones en el dispositivo.'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => controller.loadSongs(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await controller.loadSongs();
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              radius: const Radius.circular(8),
              thickness: 4,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                itemCount: controller.songs.length,
                itemBuilder: (context, index) {
                  final song = controller.songs[index];
                  final intSongId = int.tryParse(song.id) ?? 0;
                  final isPlaying = index == controller.currentIndex;
                  final isActuallyPlaying =
                      isPlaying && controller.audioService.player.playing;

                  return InkWell(
                    onTap: () async {
                      try {
                        final vc = VideoControllerAccess.instanceOrNull();
                        if (vc?.pauseIfPlaying != null) vc!.pauseIfPlaying!();
                      } catch (_) {}
                      final navigator = Navigator.of(context);
                      final isSame = index == controller.currentIndex;
                      final playing = controller.audioService.player.playing;

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
                    },
                    child: Container(
                      height: 64, // Altura compacta estilo Spotify
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Album Art
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: song.artworkUrl != null
                                ? Image.network(
                                    song.artworkUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        QueryArtworkWidget(
                                          id: intSongId,
                                          type: ArtworkType.AUDIO,
                                          artworkBorder: BorderRadius.zero,
                                          nullArtworkWidget: Container(
                                            width: 48,
                                            height: 48,
                                            color: Colors.grey[850],
                                            child: const Icon(
                                              Icons.music_note,
                                              size: 24,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          size: 48,
                                        ),
                                  )
                                : QueryArtworkWidget(
                                    id: intSongId,
                                    type: ArtworkType.AUDIO,
                                    artworkBorder: BorderRadius.zero,
                                    keepOldArtwork: true,
                                    nullArtworkWidget: Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[850],
                                      child: const Icon(
                                        Icons.music_note,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    size: 48,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          // Title & Artist
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: isPlaying
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${song.artist ?? 'Desconocido'}', // Simplificado, sin album para look más limpio
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Playing Indicator or Options
                          if (isActuallyPlaying) ...[
                            const SizedBox(width: 8),
                            NowPlayingIndicator(
                              isPlaying: true,
                              barWidth: 2,
                              minHeight: 4,
                              maxHeight: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                          ],

                          IconButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                            onPressed: () {
                              // TODO: Show modal bottom sheet with options
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (controller.currentIndex != -1) ...[
          const SizedBox(height: 8),
          const PlayerBar(),
        ],
      ],
    );
  }
}

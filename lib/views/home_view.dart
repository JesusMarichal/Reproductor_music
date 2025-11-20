import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:on_audio_query/on_audio_query.dart';
import '../controllers/home_controller.dart';
import '../widgets/player_bar.dart';
import '../widgets/music_loader.dart';
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
  late final ValueNotifier<double> _scrollOffset;
  late final AnimationController _animController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<HomeController>();
      controller.loadSongs();
    });

    _scrollController = ScrollController();
    _scrollOffset = ValueNotifier<double>(0.0);
    _scrollController.addListener(_onScroll);

    // Animation para destacar la pista en reproducción (pulso + ligero tilt)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    // La animación se controlará dinámicamente según el estado de reproducción
    // (se inicia/paraliza en el StreamBuilder de cada item).
  }

  void _onScroll() {
    _scrollOffset.value = _scrollController.offset;
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  // Pequeño indicador visual junto a la duración que pulsa cuando la pista
  // está en reproducción. Reutiliza la animación `_pulse` ya definida.
  Widget _buildPlaybackIndicator(bool playing) {
    return SizedBox(
      width: 28,
      height: 14,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final v = playing ? _pulse.value : 0.0;
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
          child: ListView.builder(
            controller: _scrollController,
            itemCount: controller.songs.length,
            itemExtent: 84,
            itemBuilder: (context, index) {
              final song = controller.songs[index];
              final intSongId = int.tryParse(song.id) ?? 0;

              final card = Padding(
                // Un poco más de espacio vertical para distinguir cartas
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 6.0,
                ),
                child: RepaintBoundary(
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        // Pausar video si estuviera reproduciendo
                        try {
                          final vc = VideoControllerAccess.instanceOrNull();
                          if (vc?.pauseIfPlaying != null) vc!.pauseIfPlaying!();
                        } catch (_) {}
                        final navigator = Navigator.of(context);
                        final isSame = index == controller.currentIndex;
                        final isPlaying =
                            controller.audioService.player.playing;
                        // Si ya está abierta, sólo ajustar reproducción
                        if (PlayerView.isOpen || controller.playerViewOpen) {
                          if (!isSame) {
                            await controller.playAt(index);
                          } else if (!isPlaying) {
                            await controller.togglePlayPause();
                          }
                          return;
                        }
                        if (isSame) {
                          if (!isPlaying) await controller.togglePlayPause();
                        } else {
                          await controller.playAt(index);
                        }
                        if (!mounted) return;
                        controller.playerViewOpen =
                            true; // marcar antes de push
                        navigator.push(buildPlayerRoute()).then((_) {
                          // Al cerrar la vista restablecer flag
                          controller.playerViewOpen = false;
                        });
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
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    formatDuration(song.duration),
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Indicador solo visible para la pista actual; para evitar
                                  // reflujo, mostramos un SizedBox en caso contrario.
                                  if (index == controller.currentIndex)
                                    StreamBuilder<bool>(
                                      stream: controller
                                          .audioService
                                          .player
                                          .playingStream,
                                      initialData: controller
                                          .audioService
                                          .player
                                          .playing,
                                      builder: (context, snap) {
                                        final playing = snap.data ?? false;
                                        // Controlamos el inicio/parada de la animación
                                        // fuera del flujo de render para evitar efectos
                                        // secundarios durante el build.
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              if (playing) {
                                                if (!_animController
                                                    .isAnimating) {
                                                  _animController.repeat(
                                                    reverse: true,
                                                  );
                                                }
                                              } else {
                                                if (_animController
                                                    .isAnimating) {
                                                  _animController.stop();
                                                }
                                              }
                                            });

                                        return playing
                                            ? _buildPlaybackIndicator(playing)
                                            : const SizedBox(width: 28);
                                      },
                                    )
                                  else
                                    const SizedBox(width: 28),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

              Widget decorated = card;
              if (index == controller.currentIndex &&
                  controller.audioService.player.playing) {
                decorated = AnimatedBuilder(
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
                        child!,
                      ],
                    );
                  },
                  child: card,
                );
              }

              return ValueListenableBuilder<double>(
                valueListenable: _scrollOffset,
                builder: (context, offset, _) {
                  final viewport = MediaQuery.of(context).size.height;
                  const itemH = 84.0;
                  final itemTop = index * itemH;
                  final itemCenter = itemTop + itemH / 2;
                  final screenCenter = offset + viewport / 2;
                  final dist = (itemCenter - screenCenter).abs();
                  final norm = (dist / viewport).clamp(0.0, 1.0);
                  final translateY = norm * 18; // pixels
                  final scale = 1 - math.min(norm * 0.06, 0.06).toDouble();
                  final opacity = 1 - math.min(norm * 0.6, 0.6).toDouble();
                  return Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: decorated,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (controller.currentIndex != -1) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const PlayerBar(),
        ],
      ],
    );
  }
}

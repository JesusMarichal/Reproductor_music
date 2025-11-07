import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({Key? key}) : super(key: key);

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  String _format(Duration? d) {
    if (d == null) return '0:00';
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final song = controller.currentSong;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor')),
        body: const Center(child: Text('No hay canción seleccionada')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reproductor')),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Artwork (ahora un poco más pequeño)
          Expanded(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: QueryArtworkWidget(
                    id: int.tryParse(song.id) ?? 0,
                    type: ArtworkType.AUDIO,
                    artworkFit: BoxFit.cover,
                    size: 1024,
                    nullArtworkWidget: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.06),
                      child: const Center(
                        child: Icon(
                          Icons.music_note,
                          size: 96,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Info y progreso
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  song.artist ?? 'Desconocido',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),

                // Slider con tiempos claramente visibles
                StreamBuilder<Duration?>(
                  stream: controller.audioService.player.durationStream,
                  builder: (context, snapDuration) {
                    final duration = snapDuration.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: controller.audioService.player.positionStream,
                      builder: (context, snapPosition) {
                        final position = snapPosition.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1.0;
                        final valueMs = position.inMilliseconds
                            .toDouble()
                            .clamp(0.0, maxMs);
                        return Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 8,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 10,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 18,
                                          ),
                                      activeTrackColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      inactiveTrackColor: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.14),
                                      thumbColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    child: Slider(
                                      value: valueMs,
                                      max: maxMs,
                                      onChanged: (v) async {
                                        final pos = Duration(
                                          milliseconds: v.round(),
                                        );
                                        await controller.audioService.seek(pos);
                                      },
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _format(position),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        _format(duration),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  iconSize: 40,
                                  onPressed: () async =>
                                      await controller.previous(),
                                  icon: const Icon(Icons.skip_previous),
                                ),
                                const SizedBox(width: 12),
                                StreamBuilder<bool>(
                                  stream: controller
                                      .audioService
                                      .player
                                      .playingStream,
                                  initialData:
                                      controller.audioService.player.playing,
                                  builder: (context, snap) {
                                    final playing = snap.data ?? false;
                                    return FloatingActionButton(
                                      onPressed: () async =>
                                          await controller.togglePlayPause(),
                                      child: Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  iconSize: 40,
                                  onPressed: () async =>
                                      await controller.next(),
                                  icon: const Icon(Icons.skip_next),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

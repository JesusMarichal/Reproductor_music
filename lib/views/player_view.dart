import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({Key? key}) : super(key: key);

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _pulseRunning = false;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  int? _artworkSongId;
  bool _hasArtwork = false;
  Uint8List? _artworkBytes;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      // Periodo un poco más largo no reduce frames por segundo, pero hace el pulso más suave
      duration: const Duration(milliseconds: 1500),
    );
  }

  void _updatePulse(bool playing) {
    if (playing && !_pulseRunning) {
      _pulseCtrl.repeat(reverse: true);
      _pulseRunning = true;
    } else if (!playing && _pulseRunning) {
      _pulseCtrl.stop();
      _pulseRunning = false;
    }
  }

  Future<void> _checkArtwork(int songId) async {
    try {
      final art = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1024,
      );
      if (!mounted) return;
      setState(() {
        if (art != null && art.isNotEmpty) {
          _artworkBytes = art;
          _hasArtwork = true;
        } else {
          _artworkBytes = null;
          _hasArtwork = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkBytes = null;
        _hasArtwork = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxSide = MediaQuery.of(context).size.width * 0.65;
                final double side = maxSide.clamp(220.0, 360.0);
                final int songId = int.tryParse(song.id) ?? 0;
                if (_artworkSongId != songId) {
                  // Detecta cambio de canción y comprueba si tiene carátula
                  _artworkSongId = songId;
                  _hasArtwork = false;
                  // Lanzamos verificación asíncrona (una sola vez por canción)
                  _checkArtwork(songId);
                }
                return Center(
                  child: StreamBuilder<bool>(
                    stream: controller.audioService.player.playingStream,
                    initialData: controller.audioService.player.playing,
                    builder: (context, snapPlaying) {
                      final playing = snapPlaying.data ?? false;
                      _updatePulse(playing);
                      return AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          // Si hay carátula real, desactivar pulso rojo para evitar parpadeo
                          final bool shouldPulse = playing && !_hasArtwork;
                          final t = shouldPulse
                              ? _pulseCtrl.value
                              : 0.0; // 0..1
                          final primary = Theme.of(context).colorScheme.primary;
                          // Reducimos intensidad para menor distracción y menor costo
                          final glowOpacity = 0.08 + 0.10 * t; // 0.08..0.18
                          final blur =
                              26.0; // fijo para evitar reprocesado costoso del blur en cada frame
                          final spread = 0.8; // fijo

                          // Separar el artwork (estático) y la capa de brillo (animada)
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Artwork: usamos bytes cacheados para evitar reconsultas/reloads
                                  RepaintBoundary(
                                    child: _artworkBytes != null
                                        ? Image.memory(
                                            _artworkBytes!,
                                            key: ValueKey('artwork-${song.id}'),
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            // Fondo sutil para que el logo redondee igual que las fotos
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.06),
                                            child: Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  20,
                                                ),
                                                child: Image.asset(
                                                  'assets/logo_music_app.png',
                                                  key: ValueKey(
                                                    'logo-fallback-${song.id}',
                                                  ),
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),

                                  // Capa superior: solo esta parte se redibuja en el pulso
                                  IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _pulseCtrl,
                                      builder: (context, _) {
                                        final glow = shouldPulse
                                            ? primary.withOpacity(glowOpacity)
                                            : Colors.transparent;
                                        return Container(
                                          decoration: BoxDecoration(
                                            // Necesitamos boxShadow; el Container es transparente
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.22,
                                                ),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                              if (shouldPulse)
                                                BoxShadow(
                                                  color: glow,
                                                  blurRadius: blur,
                                                  spreadRadius: spread,
                                                  offset: const Offset(0, 0),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
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

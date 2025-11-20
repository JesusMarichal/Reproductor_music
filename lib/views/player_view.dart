import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';

class PlayerView extends StatefulWidget {
  /// Bandera estática para saber si el PlayerView está actualmente visible
  /// en la pila de rutas. Usada como guardia antes de intentar abrir otra
  /// instancia desde widgets que no tienen acceso directo al Route.
  static bool isOpen = false;

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
    // Marcar la vista como abierta para evitar duplicados.
    PlayerView.isOpen = true;
    try {
      context.read<HomeController>().playerViewOpen = true;
    } catch (_) {}
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
    // Limpiar banderas de visibilidad
    PlayerView.isOpen = false;
    try {
      context.read<HomeController>().playerViewOpen = false;
    } catch (_) {}
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
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: const Center(child: Text('No hay canción seleccionada')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        // Flecha hacia abajo para cerrar con la animación de la ruta
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          // Favoritos (corazón)
          Builder(
            builder: (context) {
              final controller = context.watch<HomeController>();
              final id = controller.currentSong?.id ?? '';
              final isFav = id.isNotEmpty && controller.isFavorite(id);
              return IconButton(
                tooltip: 'Favorito',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.white,
                ),
                onPressed: () async {
                  if (id.isEmpty) return;
                  await controller.toggleFavoriteById(id);
                },
              );
            },
          ),
          // Menú de tres puntos
          PopupMenuButton<String>(
            onSelected: (value) {
              // Placeholder actions: se pueden implementar compartir, detalles, etc.
              if (value == 'add_to_playlist') {
                _showAddToPlaylistSheet(context);
              } else if (value == 'share') {
                // TODO: implementar compartir
              } else if (value == 'details') {
                // TODO: mostrar detalles
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add_to_playlist',
                child: Text('Añadir a playlist'),
              ),
              PopupMenuItem(value: 'share', child: Text('Compartir')),
              PopupMenuItem(value: 'details', child: Text('Detalles')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          if (controller.currentMixedPlaylistTitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.all_inclusive,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Reproduciendo lista mixta: ${controller.currentMixedPlaylistTitle}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
                                  // Mostramos el tiempo actual y el tiempo total.
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

                            // Controls: shuffle, prev, play/pause, next, repeat
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Shuffle
                                StreamBuilder<bool>(
                                  stream: controller
                                      .audioService
                                      .player
                                      .shuffleModeEnabledStream,
                                  initialData: controller
                                      .audioService
                                      .player
                                      .shuffleModeEnabled,
                                  builder: (context, snap) {
                                    final shuffling = snap.data ?? false;
                                    return IconButton(
                                      iconSize: 28,
                                      onPressed: () async =>
                                          await controller.toggleShuffle(),
                                      icon: Icon(
                                        Icons.shuffle,
                                        color: shuffling
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.grey,
                                      ),
                                    );
                                  },
                                ),
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
                                // Repeat
                                StreamBuilder<LoopMode>(
                                  stream: controller
                                      .audioService
                                      .player
                                      .loopModeStream,
                                  initialData:
                                      controller.audioService.player.loopMode,
                                  builder: (context, snap) {
                                    final mode =
                                        snap.data ??
                                        controller.audioService.player.loopMode;
                                    IconData icon;
                                    Color color = Colors.grey;
                                    if (mode == LoopMode.one) {
                                      icon = Icons.repeat_one;
                                      color = Theme.of(
                                        context,
                                      ).colorScheme.primary;
                                    } else if (mode == LoopMode.all) {
                                      icon = Icons.repeat;
                                      color = Theme.of(
                                        context,
                                      ).colorScheme.primary;
                                    } else {
                                      icon = Icons.repeat;
                                    }
                                    return IconButton(
                                      iconSize: 28,
                                      onPressed: () async =>
                                          await controller.cycleRepeatMode(),
                                      icon: Icon(icon, color: color),
                                    );
                                  },
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

/// Ruta con transición deslizante vertical (entra desde abajo y sale hacia abajo)
PageRoute<void> buildPlayerRoute() {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => const PlayerView(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offsetTween = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      );
      return SlideTransition(
        position: offsetTween.animate(curved),
        child: child,
      );
    },
  );
}

void _showAddToPlaylistSheet(BuildContext context) {
  final pc = context.read<PlaylistController>();
  final playlists = pc.playlists;
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      if (playlists.isEmpty) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No hay playlists'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    // Abrir PlaylistsView tab para crear
                    // (el usuario puede ir a la pestaña Listas y crear una)
                  },
                  child: const Text('Crear playlist'),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.builder(
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final p = playlists[index];
          return ListTile(
            leading: const Icon(Icons.queue_music),
            title: Text(p.title),
            subtitle: Text(
              p.description.isEmpty ? 'Sin descripción' : p.description,
            ),
            onTap: () async {
              await pc.addSongToPlaylist(p.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          );
        },
      );
    },
  );
}

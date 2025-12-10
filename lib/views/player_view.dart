import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:typed_data';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/video_controller.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class PlayerView extends StatefulWidget {
  static bool isOpen = false;

  const PlayerView({Key? key}) : super(key: key);

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _pulseRunning = false;
  final OnAudioQuery _audioQuery = OnAudioQuery();
  int? _artworkSongId;
  Uint8List? _artworkBytes;

  // Variables for smooth seeker
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
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

  Future<void> _checkArtwork(int songId, String? url) async {
    // Si tenemos URL de red, no hacemos query local
    if (url != null && url.isNotEmpty) {
      if (_artworkBytes != null) {
        if (!mounted) return;
        setState(() {
          _artworkBytes = null;
        });
      }
      return;
    }

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
        } else {
          _artworkBytes = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _artworkBytes = null;
      });
    }
  }

  @override
  void dispose() {
    PlayerView.isOpen = false;
    try {
      context.read<HomeController>().playerViewOpen = false;
    } catch (_) {}

    // Pausar video al cerrar para liberar recursos (Mejora Rendimiento)
    try {
      final vc = context.read<VideoController>();
      if (vc.isPlaying) vc.pause();
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
    final videoCtrl = context.watch<VideoController>();
    final song = controller.currentSong;
    final isVideo = videoCtrl.currentId != null;

    if (song == null && !isVideo) {
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

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          Builder(
            builder: (context) {
              final controller = context.watch<HomeController>();
              final id = controller.currentSong?.id ?? '';
              final isFav = id.isNotEmpty && controller.isFavorite(id);
              if (isVideo)
                return const SizedBox.shrink(); // No favs for video yet
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
          if (!isVideo)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'add_to_playlist') {
                  _showAddToPlaylistSheet(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'add_to_playlist',
                  child: Text('Añadir a playlist'),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background "Alive" Effect
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primaryColor.withOpacity(0.15 + 0.1 * _pulseCtrl.value),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                if (controller.currentMixedPlaylistTitle != null && !isVideo)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Lista: ${controller.currentMixedPlaylistTitle}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Centered Artwork / Video and Info
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Artwork or Video
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final double side = (constraints.maxWidth * 0.75)
                                  .clamp(240.0, 380.0);
                              final int songId = song != null
                                  ? int.tryParse(song.id) ?? 0
                                  : 0;
                              if (song != null && _artworkSongId != songId) {
                                _artworkSongId = songId;
                                _checkArtwork(songId, song.artworkUrl);
                              }

                              if (isVideo) {
                                // For video, we don't pulse, just show player
                                return SizedBox(
                                  width: constraints.maxWidth * 0.95,
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: YoutubePlayer(
                                        controller: videoCtrl.ytController,
                                        showVideoProgressIndicator: true,
                                        progressIndicatorColor: primaryColor,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return StreamBuilder<bool>(
                                stream: controller
                                    .audioService
                                    .player
                                    .playingStream,
                                initialData:
                                    controller.audioService.player.playing,
                                builder: (context, snapPlaying) {
                                  final playing = snapPlaying.data ?? false;
                                  _updatePulse(playing);
                                  return AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (context, _) {
                                      final t = _pulseCtrl.value;
                                      final scale = playing
                                          ? (0.98 + 0.04 * t)
                                          : 1.0;
                                      final elevation = playing
                                          ? (8.0 + 12.0 * t)
                                          : 6.0;

                                      Widget artContent;
                                      if (song?.artworkUrl != null) {
                                        artContent = Image.network(
                                          song!.artworkUrl!,
                                          key: ValueKey('net-art-${song.id}'),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                color: Colors.grey[900],
                                                child: Icon(
                                                  Icons.music_note,
                                                  color: Colors.white54,
                                                  size: side * 0.4,
                                                ),
                                              ),
                                        );
                                      } else if (_artworkBytes != null) {
                                        artContent = Image.memory(
                                          _artworkBytes!,
                                          key: ValueKey('artwork-${song?.id}'),
                                          fit: BoxFit.cover,
                                        );
                                      } else {
                                        artContent = Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primaryColor.withOpacity(0.8),
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.music_note_rounded,
                                                  size: side * 0.4,
                                                  color: Colors.white,
                                                ),
                                                Text(
                                                  'Primek',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: side * 0.1,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }

                                      return Transform.scale(
                                        scale: scale,
                                        child: Container(
                                          width: side,
                                          height: side,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: elevation * 2,
                                                offset: Offset(0, elevation),
                                              ),
                                              if (playing)
                                                BoxShadow(
                                                  color: primaryColor
                                                      .withOpacity(
                                                        0.2 + 0.1 * t,
                                                      ),
                                                  blurRadius: 40,
                                                  spreadRadius: -5,
                                                ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            child: artContent,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Title & Artist
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  isVideo
                                      ? (videoCtrl.currentTitle ?? 'Video')
                                      : (song?.title ?? ''),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black87
                                        : Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isVideo
                                      ? (videoCtrl.currentId ?? '')
                                      : (song?.artist ?? 'Desconocido'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.black54
                                        : Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Controls Area
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20,
                  ),
                  child: isVideo
                      ? _buildVideoControls(context, videoCtrl, primaryColor)
                      : _buildAudioControls(context, controller, primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControls(
    BuildContext context,
    VideoController videoCtrl,
    Color primaryColor,
  ) {
    final inactiveTrackColor = Theme.of(context).brightness == Brightness.light
        ? Colors.black12
        : Colors.white.withOpacity(0.15);
    final thumbColor = Theme.of(context).brightness == Brightness.light
        ? primaryColor
        : Colors.white;

    return ValueListenableBuilder<YoutubePlayerValue>(
      valueListenable: videoCtrl.ytController,
      builder: (context, value, _) {
        final position = value.position;
        final duration = value.metaData.duration;
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        double sliderValue = position.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs,
        );

        if (_isDragging) {
          sliderValue = _dragValue.clamp(0.0, maxMs);
        }

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8,
                  elevation: 4,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor: primaryColor,
                inactiveTrackColor: inactiveTrackColor,
                thumbColor: thumbColor,
              ),
              child: Slider(
                value: sliderValue,
                max: maxMs,
                onChanged: (v) {
                  if (!_isDragging) setState(() => _isDragging = true);
                  setState(() => _dragValue = v);
                },
                onChangeEnd: (v) {
                  videoCtrl.ytController.seekTo(
                    Duration(milliseconds: v.round()),
                  );
                  setState(() => _isDragging = false);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black54
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    _format(duration),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black54
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Video Controls (Rewind, Play/Pause, Forward)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.replay_10_rounded),
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white,
                  onPressed: () {
                    var p = value.position - const Duration(seconds: 10);
                    if (p < Duration.zero) p = Duration.zero;
                    videoCtrl.ytController.seekTo(p);
                  },
                ),
                const SizedBox(width: 24),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconButton(
                    iconSize: 36,
                    color: Theme.of(context).colorScheme.onPrimary,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () {
                      if (value.isPlaying) {
                        videoCtrl.ytController.pause();
                      } else {
                        videoCtrl.ytController.play();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.forward_10_rounded),
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white,
                  onPressed: () {
                    var p = value.position + const Duration(seconds: 10);
                    if (p > duration) p = duration;
                    videoCtrl.ytController.seekTo(p);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildAudioControls(
    BuildContext context,
    HomeController controller,
    Color primaryColor,
  ) {
    final inactiveTrackColor = Theme.of(context).brightness == Brightness.light
        ? Colors.black12
        : Colors.white.withOpacity(0.15);
    final thumbColor = Theme.of(context).brightness == Brightness.light
        ? primaryColor
        : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress Bar
        StreamBuilder<Duration?>(
          stream: controller.audioService.player.durationStream,
          builder: (context, snapDuration) {
            final duration = snapDuration.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: controller.audioService.player.positionStream,
              builder: (context, snapPosition) {
                var position = snapPosition.data ?? Duration.zero;
                final maxMs = duration.inMilliseconds > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0;

                double sliderValue = position.inMilliseconds.toDouble().clamp(
                  0.0,
                  maxMs,
                );
                if (_isDragging) {
                  sliderValue = _dragValue.clamp(0.0, maxMs);
                }

                return Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                          elevation: 4,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        activeTrackColor: primaryColor,
                        inactiveTrackColor: inactiveTrackColor,
                        thumbColor: thumbColor,
                      ),
                      child: Slider(
                        value: sliderValue,
                        max: maxMs,
                        onChanged: (v) {
                          if (!_isDragging) {
                            setState(() {
                              _isDragging = true;
                            });
                          }
                          setState(() {
                            _dragValue = v;
                          });
                        },
                        onChangeEnd: (v) async {
                          await controller.audioService.seek(
                            Duration(milliseconds: v.round()),
                          );
                          setState(() {
                            _isDragging = false;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _format(
                              _isDragging
                                  ? Duration(milliseconds: _dragValue.round())
                                  : position,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.black54
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            _format(duration),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.black54
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 20),

        // Playback Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder<bool>(
              stream: controller.audioService.player.shuffleModeEnabledStream,
              initialData: controller.audioService.player.shuffleModeEnabled,
              builder: (context, snap) {
                final shuffling = snap.data ?? false;
                return IconButton(
                  onPressed: controller.toggleShuffle,
                  icon: Icon(
                    Icons.shuffle,
                    color: shuffling
                        ? primaryColor
                        : (Theme.of(context).brightness == Brightness.light
                              ? Colors.black54
                              : Colors.white60),
                  ),
                  tooltip: 'Aleatorio',
                );
              },
            ),
            IconButton(
              iconSize: 42,
              onPressed: controller.previous,
              icon: const Icon(Icons.skip_previous_rounded),
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white,
            ),

            StreamBuilder<bool>(
              stream: controller.audioService.player.playingStream,
              initialData: controller.audioService.player.playing,
              builder: (context, snap) {
                final playing = snap.data ?? false;
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconButton(
                    iconSize: 36,
                    onPressed: controller.togglePlayPause,
                    icon: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    ),
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                );
              },
            ),

            IconButton(
              iconSize: 42,
              onPressed: controller.next,
              icon: const Icon(Icons.skip_next_rounded),
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black87
                  : Colors.white,
            ),

            StreamBuilder<LoopMode>(
              stream: controller.audioService.player.loopModeStream,
              initialData: controller.audioService.player.loopMode,
              builder: (context, snap) {
                final mode = snap.data ?? LoopMode.off;
                IconData icon;
                Color color = (Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white60);
                if (mode == LoopMode.one) {
                  icon = Icons.repeat_one_rounded;
                  color = primaryColor;
                } else if (mode == LoopMode.all) {
                  icon = Icons.repeat_rounded;
                  color = primaryColor;
                } else {
                  icon = Icons.repeat_rounded;
                }
                return IconButton(
                  onPressed: controller.cycleRepeatMode,
                  icon: Icon(icon, color: color),
                  tooltip: 'Repetir',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

PageRoute<void> buildPlayerRoute() {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, animation, secondaryAnimation) => const PlayerView(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
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
    backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Theme aware
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final isLight = Theme.of(ctx).brightness == Brightness.light;
      final textColor = isLight ? Colors.black87 : Colors.white;
      final subtitleColor = isLight ? Colors.black54 : Colors.white54;

      if (playlists.isEmpty) {
        return SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No hay playlists',
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Crear playlist'),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final p = playlists[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black12 : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.queue_music, color: textColor),
              ),
              title: Text(p.title, style: TextStyle(color: textColor)),
              subtitle: Text(
                p.description.isEmpty ? 'Sin descripción' : p.description,
                style: TextStyle(color: subtitleColor),
              ),
              onTap: () async {
                await pc.addSongToPlaylist(p.id);
                if (context.mounted) Navigator.of(context).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Añadido a ${p.title}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    },
  );
}

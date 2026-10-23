import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../models/song.dart';
import '../services/artwork_cache.dart';
import '../theme/app_theme.dart';
import '../views/player_view.dart';
import 'scrolling_text.dart';
import 'song_artwork.dart';

/// Mini reproductor fijo sobre la barra de pestañas.
///
/// Se monta una sola vez en el shell de la app (no una copia por vista), así
/// que sobrevive al cambio de pestaña y no puede desincronizarse consigo
/// mismo.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final song = controller.currentSong;
    final colors = context.colors;

    return AnimatedSize(
      duration: AppDuration.medium,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: song == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openPlayer(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProgressLine(player: controller.audioService.player),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'artwork-${song.id}',
                            flightShuttleBuilder: artworkFlightShuttle(song),
                            child: _CurrentArtwork(
                              key: ValueKey(ArtworkCache.keyOf(song)),
                              song: song,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ScrollingText(
                                  text: song.title,
                                  style: context.texts.titleSmall!,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  song.artist?.trim().isNotEmpty == true
                                      ? song.artist!
                                      : 'Artista desconocido',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodySmall?.copyWith(
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _Controls(player: controller.audioService.player),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _openPlayer(BuildContext context) async {
    final home = context.read<HomeController>();
    if (PlayerView.isOpen || home.playerViewOpen) return;
    home.playerViewOpen = true;
    final navigator = Navigator.of(context);

    // Deja la carátula decodificada antes de empezar la transición: si se
    // decodifica durante la animación, los primeros frames se pierden.
    final song = home.currentSong;
    if (song != null) {
      try {
        final bytes = await ArtworkCache.instance
            .load(song)
            .timeout(const Duration(milliseconds: 250));
        if (bytes != null && context.mounted) {
          await precacheImage(
            MemoryImage(bytes),
            context,
          ).timeout(const Duration(milliseconds: 250));
        }
      } catch (_) {
        // Si tarda, se abre igualmente: la carátula llegará después.
      }
    }

    navigator.push(buildPlayerRoute()).then((_) {
      home.playerViewOpen = false;
    });
  }
}

/// Carátula de la pista en curso.
///
/// Usa los mismos bytes en caché que el reproductor a pantalla completa: así
/// el Hero vuela entre dos imágenes idénticas y, al cambiar de pista, la
/// carátula se actualiza (el `QueryArtworkWidget` con `keepOldArtwork` se
/// quedaba con la de la canción anterior o con el marcador vacío).
class _CurrentArtwork extends StatelessWidget {
  const _CurrentArtwork({super.key, required this.song});

  final Song song;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final cache = ArtworkCache.instance;
    // Ya resuelta (lo normal: HomeController la precarga al cambiar de
    // pista): se pinta sin pasar por un FutureBuilder.
    if (cache.contains(song)) return _image(cache.peek(song));
    return FutureBuilder<Uint8List?>(
      future: cache.load(song),
      builder: (context, snapshot) => _image(snapshot.data),
    );
  }

  Widget _image(Uint8List? bytes) {
    if (bytes == null) return SongArtwork(song: song, size: _size);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.memory(
        bytes,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

/// Línea de progreso de 2 px pegada al borde superior del mini reproductor.
/// Da la posición de la pista sin robar altura a la fila.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final total = player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final value = total.inMilliseconds <= 0
            ? 0.0
            : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

        return SizedBox(
          height: 2,
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: colors.border,
            color: colors.primary,
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final waiting =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 26,
              tooltip: 'Anterior',
              color: colors.textSecondary,
              onPressed: () => context.read<HomeController>().previous(),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: waiting
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : IconButton.filled(
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      iconSize: 24,
                      tooltip: playing ? 'Pausar' : 'Reproducir',
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                      onPressed: () =>
                          context.read<HomeController>().togglePlayPause(),
                    ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 26,
              tooltip: 'Siguiente',
              color: colors.textSecondary,
              onPressed: () => context.read<HomeController>().next(),
            ),
          ],
        );
      },
    );
  }
}

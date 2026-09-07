import 'dart:typed_data';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';
import '../theme/app_theme.dart';

/// Reproductor a pantalla completa.
class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  /// Bandera global para evitar apilar dos instancias de esta pantalla.
  static bool isOpen = false;

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  String? _artworkSongId;
  Uint8List? _artworkBytes;

  bool _isDragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    PlayerView.isOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeController>().playerViewOpen = true;
    });
  }

  @override
  void dispose() {
    PlayerView.isOpen = false;
    super.dispose();
  }

  /// Carga la carátula incrustada a alta resolución para el fondo difuminado.
  /// Se cachea por id de canción para no releer el archivo en cada rebuild.
  Future<void> _loadArtwork(String songId) async {
    final id = int.tryParse(songId);
    if (id == null) return;
    try {
      final bytes = await _audioQuery.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1024,
      );
      if (!mounted) return;
      setState(() {
        _artworkSongId = songId;
        _artworkBytes = (bytes != null && bytes.isNotEmpty) ? bytes : null;
      });
    } catch (e) {
      debugPrint('No se pudo leer la carátula de $songId: $e');
      if (!mounted) return;
      setState(() {
        _artworkSongId = songId;
        _artworkBytes = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final colors = context.colors;
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
        body: const Center(child: Text('No hay ninguna canción sonando')),
      );
    }

    if (_artworkSongId != song.id) {
      // Fuera del build síncrono: sólo se dispara al cambiar de pista.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadArtwork(song.id));
    }

    final player = controller.audioService.player;
    final isFavorite = controller.isFavorite(song.id);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          controller.currentMixedPlaylistTitle ?? 'Reproduciendo',
          style: context.texts.labelSmall?.copyWith(color: colors.textTertiary),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Añadir a una lista',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => showAddToPlaylistSheet(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BlurredBackdrop(bytes: _artworkBytes),
          SafeArea(
            // El reproductor ocupa su propia ruta: no hay barra de navegación
            // debajo, pero sí gestos del sistema, así que reservamos el borde
            // inferior y dejamos que el contenido se adapte al alto real.
            child: LayoutBuilder(
              builder: (context, constraints) {
                // La carátula se limita por el lado más restrictivo: si la
                // pantalla es baja manda el alto, no el ancho.
                final maxByWidth = constraints.maxWidth - (AppSpacing.xl * 2);
                final usableHeight =
                    constraints.maxHeight - (AppSpacing.lg + AppSpacing.xl);
                final maxByHeight = usableHeight * 0.46;
                final artworkSide =
                    maxByWidth < maxByHeight ? maxByWidth : maxByHeight;

                // Columna de altura acotada: los Spacer reparten el hueco
                // sobrante. Nada de scroll aquí — el desbordamiento se evita
                // acotando la carátula, no dejando desplazar la pantalla.
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      _Artwork(
                        bytes: _artworkBytes,
                        songId: song.id,
                        side: artworkSide,
                      ),
                      const Spacer(flex: 2),
                      _TrackInfo(
                        title: song.title,
                        artist: song.artist,
                        album: song.album,
                        isFavorite: isFavorite,
                        onToggleFavorite: () =>
                            controller.toggleFavoriteById(song.id),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _Seekbar(
                        player: player,
                        isDragging: _isDragging,
                        dragValue: _dragValue,
                        onDragStart: (v) => setState(() {
                          _isDragging = true;
                          _dragValue = v;
                        }),
                        onDragUpdate: (v) => setState(() => _dragValue = v),
                        onDragEnd: (v) async {
                          await controller.audioService
                              .seek(Duration(milliseconds: v.round()));
                          if (!mounted) return;
                          setState(() => _isDragging = false);
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _TransportControls(controller: controller),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo: la carátula ampliada y difuminada, atenuada sobre el fondo del tema.
/// Da profundidad sin comprometer el contraste del texto.
class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (bytes == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.16),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes!, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: 0.78),
                  Theme.of(context).scaffoldBackgroundColor,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.bytes,
    required this.songId,
    required this.side,
  });

  final Uint8List? bytes;
  final String songId;

  /// Lado del cuadrado, ya acotado por el espacio disponible.
  final double side;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Hero(
      tag: 'artwork-$songId',
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : ColoredBox(
                color: colors.surface2,
                child: Icon(
                  Icons.music_note_rounded,
                  size: side * 0.28,
                  color: colors.textTertiary,
                ),
              ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({
    required this.title,
    required this.artist,
    required this.album,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final String title;
  final String? artist;
  final String? album;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final subtitle = [
      if (artist?.trim().isNotEmpty == true) artist!.trim(),
      if (album?.trim().isNotEmpty == true) album!.trim(),
    ].join(' · ');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle.isEmpty ? 'Artista desconocido' : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodyMedium
                    ?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          tooltip: isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
          iconSize: 28,
          color: isFavorite ? colors.primary : colors.textSecondary,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
          onPressed: onToggleFavorite,
        ),
      ],
    );
  }
}

class _Seekbar extends StatelessWidget {
  const _Seekbar({
    required this.player,
    required this.isDragging,
    required this.dragValue,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final AudioPlayer player;
  final bool isDragging;
  final double dragValue;
  final ValueChanged<double> onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        // Un máximo de 1 ms evita que el Slider reciba max == 0 mientras la
        // pista todavía no ha reportado duración.
        final maxMs = duration.inMilliseconds > 0
            ? duration.inMilliseconds.toDouble()
            : 1.0;

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final value = isDragging
                ? dragValue.clamp(0.0, maxMs)
                : position.inMilliseconds.toDouble().clamp(0.0, maxMs);

            final labelStyle = context.texts.bodySmall?.copyWith(
              color: colors.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            );

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 18),
                  ),
                  child: Slider(
                    value: value.toDouble(),
                    max: maxMs,
                    onChangeStart: onDragStart,
                    onChanged: onDragUpdate,
                    onChangeEnd: onDragEnd,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _format(Duration(milliseconds: value.round())),
                        style: labelStyle,
                      ),
                      Text(_format(duration), style: labelStyle),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = controller.audioService.player;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        StreamBuilder<bool>(
          stream: player.shuffleModeEnabledStream,
          initialData: player.shuffleModeEnabled,
          builder: (context, snapshot) {
            final on = snapshot.data ?? false;
            return IconButton(
              tooltip: on ? 'Aleatorio activado' : 'Aleatorio',
              icon: const Icon(Icons.shuffle_rounded),
              color: on ? colors.primary : colors.textTertiary,
              onPressed: controller.toggleShuffle,
            );
          },
        ),
        IconButton(
          tooltip: 'Anterior',
          iconSize: 40,
          color: colors.textPrimary,
          icon: const Icon(Icons.skip_previous_rounded),
          onPressed: controller.previous,
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final playing = state?.playing ?? false;
            final waiting =
                state?.processingState == ProcessingState.loading ||
                    state?.processingState == ProcessingState.buffering;

            return Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: colors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: waiting
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : IconButton(
                      tooltip: playing ? 'Pausar' : 'Reproducir',
                      iconSize: 40,
                      color: Theme.of(context).colorScheme.onPrimary,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      onPressed: controller.togglePlayPause,
                    ),
            );
          },
        ),
        IconButton(
          tooltip: 'Siguiente',
          iconSize: 40,
          color: colors.textPrimary,
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: controller.next,
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          initialData: player.loopMode,
          builder: (context, snapshot) {
            final mode = snapshot.data ?? LoopMode.off;
            final (icon, tooltip) = switch (mode) {
              LoopMode.off => (Icons.repeat_rounded, 'Repetir'),
              LoopMode.all => (Icons.repeat_rounded, 'Repetir todo'),
              LoopMode.one => (Icons.repeat_one_rounded, 'Repetir una'),
            };
            return IconButton(
              tooltip: tooltip,
              icon: Icon(icon),
              color:
                  mode == LoopMode.off ? colors.textTertiary : colors.primary,
              onPressed: controller.cycleRepeatMode,
            );
          },
        ),
      ],
    );
  }
}

/// Transición de entrada del reproductor: sube desde abajo.
PageRoute<void> buildPlayerRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const PlayerView(),
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
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

/// Hoja para añadir la canción en curso a una lista de reproducción.
void showAddToPlaylistSheet(BuildContext context) {
  final playlistController = context.read<PlaylistController>();
  final playlists = playlistController.playlists;

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      if (playlists.isEmpty) {
        return const SizedBox(
          height: 220,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                'Todavía no has creado ninguna lista.\n'
                'Créala desde la pestaña Listas.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: sheetContext.colors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.queue_music_rounded, size: 20),
              ),
              title: Text(playlist.title),
              subtitle: Text(
                playlist.description.isEmpty
                    ? 'Sin descripción'
                    : playlist.description,
              ),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(sheetContext).pop();
                await playlistController.addSongToPlaylist(playlist.id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Añadido a ${playlist.title}')),
                );
              },
            );
          },
        ),
      );
    },
  );
}

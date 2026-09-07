import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';

/// Carátula de una canción, con la misma cascada de respaldo en toda la app:
/// imagen remota → carátula incrustada en el archivo → marcador de posición.
///
/// El marcador usa colores del tema, así que no se ve un bloque gris fuera de
/// sitio en las paletas claras.
class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.song,
    this.size = 52,
    this.radius = AppRadius.sm,
  });

  final Song song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final embeddedId = int.tryParse(song.id) ?? 0;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: size,
        height: size,
        child: song.artworkUrl != null
            ? Image.network(
                song.artworkUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _embedded(embeddedId),
              )
            : _embedded(embeddedId),
      ),
    );
  }

  Widget _embedded(int id) {
    return QueryArtworkWidget(
      id: id,
      type: ArtworkType.AUDIO,
      artworkBorder: BorderRadius.zero,
      artworkWidth: size,
      artworkHeight: size,
      artworkFit: BoxFit.cover,
      keepOldArtwork: true,
      size: size.round().clamp(48, 512),
      nullArtworkWidget: _ArtworkPlaceholder(size: size),
      errorBuilder: (_, __, ___) => _ArtworkPlaceholder(size: size),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.artworkPlaceholder,
        border: Border.all(color: colors.border),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.42,
        color: colors.textTertiary,
      ),
    );
  }
}

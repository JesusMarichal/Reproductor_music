import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/playlist_controller.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';
import 'song_artwork.dart';

/// Portada de una lista de reproducción.
///
/// Cascada de respaldo, de más a menos específico: la imagen elegida por la
/// persona, un mosaico con las carátulas de sus primeras canciones, o un
/// degradado de marca. Así una lista nunca se ve como un hueco vacío.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.playlist,
    required this.size,
    this.radius = AppRadius.sm,
  });

  final Playlist playlist;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlaylistController>();
    final songs = controller.aggregatedSongs(playlist);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: _build(context, songs),
      ),
    );
  }

  Widget _build(BuildContext context, List<Song> songs) {
    final imagePath = playlist.imagePath;
    if (imagePath != null) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _Fallback(playlist: playlist, size: size),
        );
      }
    }

    // Con cuatro o más canciones, mosaico 2×2 como hacen las apps de música
    // cuando la lista no tiene portada propia.
    if (songs.length >= 4) {
      return GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final song in songs.take(4))
            SongArtwork(song: song, size: size / 2, radius: 0),
        ],
      );
    }

    if (songs.isNotEmpty) {
      return SongArtwork(song: songs.first, size: size, radius: 0);
    }

    return _Fallback(playlist: playlist, size: size);
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.playlist, required this.size});

  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.55),
            colors.accent.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          playlist.isMixed
              ? Icons.auto_awesome_motion_rounded
              : Icons.queue_music_rounded,
          size: size * 0.38,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

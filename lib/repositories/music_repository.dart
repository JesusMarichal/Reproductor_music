import 'package:on_audio_query/on_audio_query.dart';
import '../models/song.dart';

class MusicRepository {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Comprueba y solicita permisos necesarios para acceder al almacen de audio.
  /// Devuelve verdadero si el permiso está concedido.
  Future<bool> ensurePermissions() async {
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      permissionStatus = await _audioQuery.permissionsRequest();
    }
    return permissionStatus;
  }

  /// Solicita permisos si es necesario y devuelve la lista de canciones locales
  Future<List<Song>> fetchAll() async {
    // Request permissions (Android 13+ uses READ_MEDIA_AUDIO; OnAudioQuery handles it)
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      permissionStatus = await _audioQuery.permissionsRequest();
    }
    if (!permissionStatus) return [];

    // Query songs ordered by title (ALPHABETIC)
    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    // Filter out non-music and WhatsApp audio files (paths containing 'whatsapp')
    final filtered = songs.where((s) {
      // Prefer the isMusic flag when available. Plugins/devices may return int (1) or bool (true).
      final dynamic isMusicValue = s.isMusic;
      final bool isMusicFlag = () {
        if (isMusicValue == null) return true;
        if (isMusicValue is int) return isMusicValue == 1;
        if (isMusicValue is bool) return isMusicValue;
        return false;
      }();
      // s.data is provided by the plugin as the file path; normalize to lowercase
      final dataLower = s.data.toLowerCase();
      final uriLower = s.uri?.toLowerCase() ?? '';
      final combined = '$dataLower|$uriLower';
      final isWhatsapp = combined.contains('whatsapp');
      return isMusicFlag && !isWhatsapp;
    }).toList();

    return filtered
        .map(
          (s) => Song(
            id: s.id.toString(),
            title: s.title,
            uri: s.uri,
            artist: s.artist,
            duration: s.duration,
            album: s.album ?? '',
            albumId: s.albumId,
          ),
        )
        .toList();
  }
}

import 'package:on_audio_query/on_audio_query.dart';
import '../models/song.dart';

class MusicRepository {
  final OnAudioQuery _audioQuery = OnAudioQuery();

  /// Solicita permisos si es necesario y devuelve la lista de canciones locales
  Future<List<Song>> fetchAll() async {
    // Request permissions (Android 13+ uses READ_MEDIA_AUDIO; OnAudioQuery handles it)
    bool permissionStatus = await _audioQuery.permissionsStatus();
    if (!permissionStatus) {
      permissionStatus = await _audioQuery.permissionsRequest();
    }
    if (!permissionStatus) return [];

    final songs = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    return songs
        .map(
          (s) => Song(
            id: s.id.toString(),
            title: s.title,
            uri: s.uri,
            artist: s.artist,
            duration: s.duration,
          ),
        )
        .toList();
  }
}

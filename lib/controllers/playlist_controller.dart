import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../repositories/playlist_repository.dart';
import 'home_controller.dart';
import '../models/song.dart';

class PlaylistController extends ChangeNotifier {
  final PlaylistRepository _repo = PlaylistRepository();
  final HomeController homeController;

  List<Playlist> playlists = [];
  bool loading = false;
  bool creating = false;

  PlaylistController({required this.homeController});

  Future<void> init() async {
    loading = true;
    notifyListeners();
    playlists = await _repo.loadPlaylists();
    playlists = await _repo.seedIfFirstTime(playlists);
    loading = false;
    notifyListeners();
  }

  Future<void> createPlaylist(
    String title,
    String description,
    List<String> songIds, {
    String? imagePath,
  }) async {
    creating = true;
    notifyListeners();
    await _repo.createPlaylist(
      title,
      description,
      songIds,
      imagePath: imagePath,
    );
    playlists = await _repo.loadPlaylists();
    creating = false;
    notifyListeners();
  }

  Future<void> createMixedPlaylist(
    String title,
    String description,
    List<String> childPlaylistIds, {
    String? imagePath,
  }) async {
    creating = true;
    notifyListeners();
    await _repo.createMixedPlaylist(
      title,
      description,
      childPlaylistIds,
      imagePath: imagePath,
    );
    playlists = await _repo.loadPlaylists();
    creating = false;
    notifyListeners();
  }

  Future<void> addSongToPlaylist(String playlistId) async {
    final song = homeController.currentSong;
    if (song == null) return;
    await _repo.addSongToPlaylist(playlistId, song.id);
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }

  Future<void> addSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    await _repo.addSongsToPlaylist(playlistId, songIds);
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }

  Future<void> updatePlaylist({
    required String id,
    String? title,
    String? description,
    List<String>? songIds,
    PlaylistType? type,
    List<String>? childPlaylistIds,
    List<String>? excludedSongIds,
    String? imagePath,
  }) async {
    await _repo.updatePlaylist(
      id: id,
      title: title,
      description: description,
      songIds: songIds,
      type: type,
      childPlaylistIds: childPlaylistIds,
      excludedSongIds: excludedSongIds,
      imagePath: imagePath,
    );
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    await _repo.deletePlaylist(id);
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _repo.removeSongFromPlaylist(playlistId, songId);
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }

  /// Retorna las canciones agregadas de una playlist. Para mixtas, agrega
  /// las canciones de sus playlists hijas (sin duplicados) preservando el
  /// orden por lista y luego por canción.
  List<Song> aggregatedSongs(Playlist p) {
    final allSongs = homeController.songs;
    if (!p.isMixed) {
      final ids = p.songIds;
      return allSongs.where((s) => ids.contains(s.id)).toList();
    }

    final resultIds = <String>[];
    final seen = <String>{};
    for (final childId in p.childPlaylistIds) {
      final child = playlists.firstWhere(
        (e) => e.id == childId,
        orElse: () =>
            const Playlist(id: '', title: '', description: '', songIds: []),
      );
      if (child.id.isEmpty) continue;
      final ids = child.songIds;
      for (final id in ids) {
        if (seen.add(id)) resultIds.add(id);
      }
    }
    // Mapear a Song respetando el orden de resultIds
    final map = {for (final s in allSongs) s.id: s};
    final excluded = p.excludedSongIds.toSet();
    return resultIds
        .where((id) => !excluded.contains(id))
        .map((id) => map[id])
        .whereType<Song>()
        .toList();
  }

  Future<void> excludeSongFromMixed(String playlistId, String songId) async {
    await _repo.excludeSongFromMixedPlaylist(playlistId, songId);
    playlists = await _repo.loadPlaylists();
    notifyListeners();
  }
}

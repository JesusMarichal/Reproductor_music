import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../repositories/playlist_repository.dart';
import 'home_controller.dart';

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
    List<String> songIds,
  ) async {
    creating = true;
    notifyListeners();
    await _repo.createPlaylist(title, description, songIds);
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
  }) async {
    await _repo.updatePlaylist(
      id: id,
      title: title,
      description: description,
      songIds: songIds,
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
}

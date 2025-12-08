import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class PlaylistRepository {
  static const _playlistsKey = 'playlists_data_v1';
  static const _seedKey = 'playlists_seed_done_v1';

  Future<List<Playlist>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_playlistsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_playlistsKey, encoded);
  }

  Future<List<Playlist>> seedIfFirstTime(List<Playlist> current) async {
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(_seedKey) ?? false;
    if (seeded) return current;
    // Crear playlists iniciales vacías (pop, rock, jazz, chill).
    final initial = <Playlist>[
      Playlist(
        id: 'pop',
        title: 'Pop',
        description: 'Tus canciones pop',
        songIds: const [],
        type: PlaylistType.normal,
        childPlaylistIds: const [],
        excludedSongIds: const [],
      ),
      Playlist(
        id: 'rock',
        title: 'Rock',
        description: 'Rock y energía',
        songIds: const [],
        type: PlaylistType.normal,
        childPlaylistIds: const [],
        excludedSongIds: const [],
      ),
      Playlist(
        id: 'jazz',
        title: 'Jazz',
        description: 'Suaves ritmos de jazz',
        songIds: const [],
        type: PlaylistType.normal,
        childPlaylistIds: const [],
        excludedSongIds: const [],
      ),
      Playlist(
        id: 'chill',
        title: 'Chill',
        description: 'Relajación y calma',
        songIds: const [],
        type: PlaylistType.normal,
        childPlaylistIds: const [],
        excludedSongIds: const [],
      ),
    ];
    final merged = [...current, ...initial];
    await savePlaylists(merged);
    await prefs.setBool(_seedKey, true);
    return merged;
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final all = await loadPlaylists();
    final index = all.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = all[index];
    if (!playlist.songIds.contains(songId)) {
      final updated = playlist.copyWith(songIds: [...playlist.songIds, songId]);
      all[index] = updated;
      await savePlaylists(all);
    }
  }

  Future<void> addSongsToPlaylist(
    String playlistId,
    List<String> songIds,
  ) async {
    if (songIds.isEmpty) return;
    final all = await loadPlaylists();
    final index = all.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = all[index];
    final existing = playlist.songIds.toSet();
    final toAdd = songIds.where((id) => !existing.contains(id)).toList();
    if (toAdd.isEmpty) return;
    final updated = playlist.copyWith(songIds: [...playlist.songIds, ...toAdd]);
    all[index] = updated;
    await savePlaylists(all);
  }

  Future<void> createPlaylist(
    String title,
    String description,
    List<String> songIds, {
    String? imagePath,
  }) async {
    final all = await loadPlaylists();
    final id = _generateId(title, all);
    final newPlaylist = Playlist(
      id: id,
      title: title,
      description: description,
      songIds: songIds,
      type: PlaylistType.normal,
      childPlaylistIds: const [],
      excludedSongIds: const [],
      imagePath: imagePath,
    );
    all.add(newPlaylist);
    await savePlaylists(all);
  }

  Future<void> createMixedPlaylist(
    String title,
    String description,
    List<String> childPlaylistIds, {
    String? imagePath,
  }) async {
    final all = await loadPlaylists();
    final id = _generateId(title, all);
    final newPlaylist = Playlist(
      id: id,
      title: title,
      description: description,
      songIds: const [],
      type: PlaylistType.mixed,
      childPlaylistIds: childPlaylistIds,
      excludedSongIds: const [],
      imagePath: imagePath,
    );
    all.add(newPlaylist);
    await savePlaylists(all);
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
    final all = await loadPlaylists();
    final index = all.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final updated = all[index].copyWith(
      title: title,
      description: description,
      songIds: songIds,
      type: type,
      childPlaylistIds: childPlaylistIds,
      excludedSongIds: excludedSongIds,
      imagePath: imagePath,
    );
    all[index] = updated;
    await savePlaylists(all);
  }

  /// Excluye una canción de una lista mixta sin afectar las playlists hijas
  Future<void> excludeSongFromMixedPlaylist(
    String playlistId,
    String songId,
  ) async {
    final all = await loadPlaylists();
    final index = all.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = all[index];
    if (playlist.type != PlaylistType.mixed) return;
    if (playlist.excludedSongIds.contains(songId)) return;
    final updated = playlist.copyWith(
      excludedSongIds: [...playlist.excludedSongIds, songId],
    );
    all[index] = updated;
    await savePlaylists(all);
  }

  Future<void> deletePlaylist(String id) async {
    final all = await loadPlaylists();
    all.removeWhere((p) => p.id == id);
    await savePlaylists(all);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final all = await loadPlaylists();
    final index = all.indexWhere((p) => p.id == playlistId);
    if (index == -1) return;
    final playlist = all[index];
    if (!playlist.songIds.contains(songId)) return;
    final updated = playlist.copyWith(
      songIds: playlist.songIds.where((id) => id != songId).toList(),
    );
    all[index] = updated;
    await savePlaylists(all);
  }

  String _generateId(String base, List<Playlist> existing) {
    var normalized = base.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    if (normalized.isEmpty) normalized = 'playlist';
    var candidate = normalized;
    var i = 1;
    while (existing.any((p) => p.id == candidate)) {
      candidate = '$normalized-$i';
      i++;
    }
    return candidate;
  }
}

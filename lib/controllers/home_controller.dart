import 'dart:async';

import '../models/song.dart';
import 'base_controller.dart';
import '../repositories/music_repository.dart';
import '../services/audio_service.dart';

class HomeController extends BaseController {
  List<Song> songs = [];
  Song? currentSong;
  int currentIndex = -1;
  bool isLoading = false;
  bool permissionGranted = true;

  /// Carga inicial de canciones. Notifica a los listeners para que la UI
  /// pueda actualizarse sin reconstruir widgets enteros innecesariamente.
  final MusicRepository _repo = MusicRepository();
  final AudioService audioService = AudioService();
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription? _playerStateSub;

  HomeController() {
    // Bind to the player's streams so the controller stays in sync when the
    // user uses next/previous or the player advances automatically.
    _bindPlayer();
  }

  void _bindPlayer() {
    final player = audioService.player;
    _currentIndexSub = player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < songs.length) {
        currentIndex = index;
        currentSong = songs[index];
        notifyListeners();
      }
    });

    // Keep UI updated for play/pause state changes.
    _playerStateSub = player.playerStateStream.listen((_) {
      notifyListeners();
    });
  }

  Future<void> loadSongs() async {
    isLoading = true;
    notifyListeners();
    // First try to obtain permission status; we will request if needed but
    // keep the UI responsive while the permission dialog is shown.
    final granted = await _repo.ensurePermissions();
    permissionGranted = granted;

    // Fetch songs (the repository may request permissions internally if needed).
    songs = await _repo.fetchAll();

    // If we got songs, prepare the audio queue so playback is immediate and
    // seamless (avoids blocking later when starting playback).
    if (songs.isNotEmpty) {
      await audioService.setQueueFromSongs(songs);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= songs.length) return;
    final song = songs[index];
    if (song.uri == null) return;
    currentIndex = index;
    currentSong = song;
    notifyListeners();
    // If the queue was set, play by index for seamless navigation.
    try {
      await audioService.playIndex(index);
    } catch (_) {
      // Fallback: play the uri directly
      await audioService.playUri(song.uri!);
    }
  }

  Future<void> togglePlayPause() async {
    if (audioService.player.playing) {
      await audioService.pause();
    } else {
      await audioService.play();
    }
    notifyListeners();
  }

  Future<void> next() async {
    await audioService.next();
  }

  Future<void> previous() async {
    await audioService.previous();
  }

  @override
  void dispose() {
    _currentIndexSub?.cancel();
    _playerStateSub?.cancel();
    audioService.dispose();
    super.dispose();
  }
}

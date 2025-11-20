import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'base_controller.dart';
import '../repositories/music_repository.dart';
import '../repositories/favorites_repository.dart';
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
  final FavoritesRepository _favRepo = FavoritesRepository();
  Set<String> favorites = {};
  final AudioService audioService = AudioService();
  StreamSubscription<int?>? _currentIndexSub;
  StreamSubscription? _playerStateSub;

  HomeController() {
    // Bind to the player's streams so the controller stays in sync when the
    // user uses next/previous or the player advances automatically.
    _bindPlayer();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    favorites = await _favRepo.loadFavorites();
    notifyListeners();
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

  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavoriteById(String id) async {
    if (id.isEmpty) return;
    if (favorites.contains(id)) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    await _favRepo.saveFavorites(favorites);
    notifyListeners();
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

  /// Alterna el modo aleatorio (shuffle). Cuando se activa, también mezcla
  /// la lista para evitar patrones predecibles.
  Future<void> toggleShuffle() async {
    final player = audioService.player;
    try {
      final enabled = player.shuffleModeEnabled;
      if (!enabled) {
        await player.setShuffleModeEnabled(true);
        await player.shuffle();
      } else {
        await player.setShuffleModeEnabled(false);
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Cicla el modo de repetición: off -> all -> one -> off
  Future<void> cycleRepeatMode() async {
    final player = audioService.player;
    try {
      final current = player.loopMode;
      LoopMode next;
      if (current == LoopMode.off) {
        next = LoopMode.all;
      } else if (current == LoopMode.all) {
        next = LoopMode.one;
      } else {
        next = LoopMode.off;
      }
      await player.setLoopMode(next);
      notifyListeners();
    } catch (_) {}
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
    // No debemos disponer el servicio de audio aquí: `AudioService` es una
    // fachada/singleton usada por toda la app y su ciclo de vida debe
    // gestionarse a nivel de la aplicación. Disponerlo al destruir el
    // `HomeController` puede cerrar el `AudioPlayer` inesperadamente cuando
    // la UI navega entre vistas (por ejemplo abrir/cerrar `PlayerView`).
    //audioService.dispose();
    super.dispose();
  }
}

import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as a;

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
  // Identificador de playlist mixta actualmente en reproducción (si aplica)
  String? currentMixedPlaylistId;
  String? currentMixedPlaylistTitle;
  // Flag para evitar abrir múltiples instancias de PlayerView
  bool playerViewOpen = false;

  /// Carga inicial de canciones. Notifica a los listeners para que la UI
  /// pueda actualizarse sin reconstruir widgets enteros innecesariamente.
  final MusicRepository _repo = MusicRepository();
  final FavoritesRepository _favRepo = FavoritesRepository();
  Set<String> favorites = {};
  final AudioService audioService = AudioService();
  StreamSubscription<SequenceState?>? _currentIndexSub;
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
    // Mapear canción actual basándonos en la etiqueta MediaItem (id = uri),
    // para que funcione aunque la cola activa sea un subconjunto (favoritos).
    _currentIndexSub = player.sequenceStateStream.listen((seqState) {
      try {
        final tag = seqState.currentSource?.tag;
        if (tag is a.MediaItem) {
          final uri = tag.id;
          final idx = songs.indexWhere((s) => s.uri == uri);
          currentIndex =
              idx; // puede ser -1 si la cola no pertenece a "songs" completa
          currentSong = idx != -1 ? songs[idx] : null;
          notifyListeners();
        }
      } catch (_) {
        // Fallback: mantener estado actual
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
    // Si se reproduce directamente desde la vista general, limpiar indicador mixto
    currentMixedPlaylistId = null;
    currentMixedPlaylistTitle = null;
    // Pausar video si está activo para liberar foco y evitar conflicto de audio.
    try {
      final vc = VideoControllerAccess.instanceOrNull();
      if (vc?.pauseIfPlaying != null) vc!.pauseIfPlaying!();
    } catch (_) {}
    // Configurar cola completa de canciones y reproducir desde índice dado.
    try {
      await audioService.setQueueFromSongs(songs);
      await audioService.playIndex(index);
    } catch (_) {
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

  /// Configura la cola a partir de un subconjunto de canciones (playlist normal o mixta)
  /// y reproduce desde el índice dado. Permite marcar si la fuente es una playlist mixta.
  Future<void> playSubset(
    List<Song> subset,
    int startIndex, {
    bool mixed = false,
    String? mixedId,
    String? mixedTitle,
  }) async {
    if (subset.isEmpty || startIndex < 0 || startIndex >= subset.length) return;
    try {
      final vc = VideoControllerAccess.instanceOrNull();
      if (vc?.pauseIfPlaying != null) vc!.pauseIfPlaying!();
    } catch (_) {}
    try {
      await audioService.setQueueFromSongs(subset);
      await audioService.playIndex(startIndex);
    } catch (_) {
      final song = subset[startIndex];
      if (song.uri != null) {
        await audioService.playUri(song.uri!);
      }
    }
    currentMixedPlaylistId = mixed ? mixedId : null;
    currentMixedPlaylistTitle = mixed ? mixedTitle : null;
    notifyListeners();
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

/// Acceso estático al VideoController sin acoplar provider directamente aquí.
/// Permite pausar video desde controladores que no tienen BuildContext.
class VideoControllerAccess {
  static VideoControllerAccess? _instance;
  final void Function()? pauseIfPlaying;
  VideoControllerAccess({this.pauseIfPlaying});
  static void register(VideoControllerAccess access) {
    _instance = access;
  }

  static VideoControllerAccess? instanceOrNull() => _instance;
}

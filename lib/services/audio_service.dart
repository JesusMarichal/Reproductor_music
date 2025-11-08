// Nuevo servicio basado en audio_service para notificación y controles del sistema.
// Conservamos la interfaz anterior (métodos play/pause/etc) para minimizar cambios
// en controladores y vistas existentes.

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as a;
import '../models/song.dart';

/// Handler que integra JustAudio con audio_service para exponer estado a
/// notificaciones del sistema (Android) y controles externos.
class _MyAudioHandler extends a.BaseAudioHandler
    with a.QueueHandler, a.SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  _MyAudioHandler() {
    _notifyPlaybackEvents();
    _listenForDurationChanges();
    _listenForCurrentSongChanges();
    // Transiciones: si tu versión de just_audio soporta crossfade, usa:
    // _player.setClip(...); (No disponible aquí) Mantendremos configuración simple.
  }

  // Mapea eventos del reproductor a PlaybackState para que audio_service
  // construya una notificación con controles dinámicos.
  void _notifyPlaybackEvents() {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      final processingState = () {
        switch (_player.processingState) {
          case ProcessingState.idle:
            return a.AudioProcessingState.idle;
          case ProcessingState.loading:
            return a.AudioProcessingState.loading;
          case ProcessingState.buffering:
            return a.AudioProcessingState.buffering;
          case ProcessingState.ready:
            return a.AudioProcessingState.ready;
          case ProcessingState.completed:
            return a.AudioProcessingState.completed;
        }
      }();

      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            if (queue.value.isNotEmpty) a.MediaControl.skipToPrevious,
            if (playing) a.MediaControl.pause else a.MediaControl.play,
            if (queue.value.isNotEmpty) a.MediaControl.skipToNext,
            a.MediaControl.stop,
          ],
          androidCompactActionIndices: const [0, 1, 2],
          processingState: processingState,
          playing: playing,
          speed: _player.speed,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
    });
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      if (index == null || index < 0 || index >= queue.value.length) return;
      final oldItem = queue.value[index];
      final newItem = oldItem.copyWith(duration: duration);
      final newQueue = [...queue.value];
      newQueue[index] = newItem;
      queue.add(newQueue);
      mediaItem.add(newItem);
    });
  }

  void _listenForCurrentSongChanges() {
    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= queue.value.length) return;
      mediaItem.add(queue.value[index]);
    });
  }

  // ---- Métodos de control ----
  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async => _player.seekToPrevious();

  // ---- Manejo de la cola ----
  Future<void> setQueueFromUris(List<String> uris) async {
    try {
      final items = <a.MediaItem>[
        for (final uri in uris)
          a.MediaItem(
            id: uri,
            title: _fileNameFallback(uri),
            artist: 'Desconocido',
          ),
      ];
      queue.add(items);

      final children = [
        for (final i in items) AudioSource.uri(Uri.parse(i.id)),
      ];
      final playlist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: children,
      );

      final currentIndex = _player.currentIndex;
      final currentPosition = _player.position;
      if (currentIndex != null &&
          currentIndex >= 0 &&
          currentIndex < children.length) {
        await _player.setAudioSource(
          playlist,
          initialIndex: currentIndex,
          initialPosition: currentPosition,
        );
      } else {
        await _player.setAudioSource(playlist);
      }
    } catch (e) {
      debugPrint('AudioHandler.setQueueFromUris error: $e');
    }
  }

  /// Construye la cola con metadatos ricos desde Song para notificación.
  Future<void> setQueueFromSongs(List<Song> songs) async {
    final playable = songs.where((s) => s.uri != null).toList();
    final items = <a.MediaItem>[
      for (final s in playable)
        a.MediaItem(
          id: s.uri!,
          title: s.title,
          artist: s.artist ?? 'Desconocido',
          album: s.album,
          artUri: (s.albumId != null)
              ? Uri.parse(
                  'content://media/external/audio/albumart/${s.albumId}',
                )
              : null,
          duration: s.duration != null
              ? Duration(milliseconds: s.duration!)
              : null,
        ),
    ];
    queue.add(items);

    final children = [for (final i in items) AudioSource.uri(Uri.parse(i.id))];
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: children,
    );
    await _player.setAudioSource(playlist);
  }

  Future<void> playIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('AudioHandler.playIndex error: $e');
    }
  }

  Future<void> playUri(String uri) async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      await _player.play();
    } catch (e) {
      debugPrint('AudioHandler.playUri error: $e');
    }
  }

  String _fileNameFallback(String uri) {
    try {
      final parts = Uri.parse(uri).pathSegments;
      if (parts.isNotEmpty) return parts.last;
    } catch (_) {}
    return 'Pista';
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Fachada para mantener compatibilidad con el controlador existente.
/// Internamente usa audio_service para mostrar la notificación.
class AudioService {
  static a.AudioHandler? _handler; // Singleton una vez inicializado.
  final _MyAudioHandler _internalHandler;

  AudioService._(this._internalHandler);

  factory AudioService() {
    if (_handler is _MyAudioHandler) {
      return AudioService._(_handler as _MyAudioHandler);
    }
    // Si aún no se inicializó desde main, creamos uno "local" sin notificación.
    final temp = _MyAudioHandler();
    _handler = temp;
    return AudioService._(temp);
  }

  static Future<void> initForNotifications() async {
    if (_handler != null) return; // Ya inicializado.
    _handler = await AudioServiceInit.init(builder: () => _MyAudioHandler());
  }

  AudioPlayer get player => (_internalHandler)._player;

  Future<void> setQueue(List<String> uris) =>
      _internalHandler.setQueueFromUris(uris);
  Future<void> setQueueFromSongs(List<Song> songs) =>
      _internalHandler.setQueueFromSongs(songs);
  Future<void> playIndex(int index) => _internalHandler.playIndex(index);
  Future<void> playUri(String uri) => _internalHandler.playUri(uri);
  Future<void> pause() => _internalHandler.pause();
  Future<void> play() => _internalHandler.play();
  Future<void> seek(Duration position) => _internalHandler.seek(position);
  Future<void> next() => _internalHandler.skipToNext();
  Future<void> previous() => _internalHandler.skipToPrevious();
  Future<void> stop() => _internalHandler.stop();
  Future<void> dispose() => _internalHandler.dispose();
}

/// Wrapper para inicialización con configuración de notificación.
class AudioServiceInit {
  static Future<a.AudioHandler> init({
    required a.AudioHandler Function() builder,
  }) {
    return a.AudioService.init(
      builder: builder,
      config: const a.AudioServiceConfig(
        androidNotificationChannelId: 'com.primek.music.playback',
        androidNotificationChannelName: 'Reproducción de música',
        androidNotificationOngoing: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  }
}

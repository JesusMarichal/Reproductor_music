// Nuevo servicio basado en audio_service para notificación y controles del sistema.
// Conservamos la interfaz anterior (métodos play/pause/etc) para minimizar cambios
// en controladores y vistas existentes.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as a;
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/song.dart';

/// Handler que integra JustAudio con audio_service para exponer estado a
/// notificaciones del sistema (Android) y controles externos.
class _MyAudioHandler extends a.BaseAudioHandler
    with a.QueueHandler, a.SeekHandler {
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Buffer mínimo (12s) para gestión balanceada
        minBufferDuration: const Duration(seconds: 12),
        maxBufferDuration: const Duration(seconds: 40),
        // INICIO RÁPIDO: Solo 500ms para empezar a sonar
        bufferForPlaybackDuration: const Duration(milliseconds: 500),
        // RECUPERACIÓN RÁPIDA: Solo 1s para volver a sonar si se traba
        bufferForPlaybackAfterRebufferDuration: const Duration(
          milliseconds: 1000,
        ),
        prioritizeTimeOverSizeThresholds: true,
        backBufferDuration: const Duration(seconds: 20),
      ),
      darwinLoadControl: const DarwinLoadControl(
        preferredForwardBufferDuration: Duration(seconds: 10),
      ),
    ),
  );
  String? _lastQueueSignature; // Para evitar reconstituir la cola idéntica.
  bool _playingBeforeInterruption = false;

  // Callbacks y estado para favoritos
  Future<void> Function(String)? onFavoriteToggled;
  Set<String> _favorites = {};

  static const _favoriteAction = a.MediaControl(
    androidIcon: 'drawable/ic_action_favorite_border',
    label: 'Favorito',
    action: a.MediaAction.custom,
    customAction: a.CustomMediaAction(name: 'favorite'),
  );

  static const _unfavoriteAction = a.MediaControl(
    androidIcon: 'drawable/ic_action_favorite',
    label: 'Quitar favorito',
    action: a.MediaAction.custom,
    customAction: a.CustomMediaAction(name: 'unfavorite'),
  );

  _MyAudioHandler() {
    _notifyPlaybackEvents();
    _listenForDurationChanges();
    _listenForCurrentSongChanges();
    _initSession();
    // logs y monitor debug opcional desactivado para release.
  }

  void updateFavorites(Set<String> favs) {
    _favorites = favs;
    _broadcastState();
  }

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      // Configuración afinada para reproducción de música (convenience preset).
      await session.configure(const AudioSessionConfiguration.music());

      // Asegurar atributos directos para Android (latencia estable / routing adecuado).
      await _player.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
      );

      // Pausar cuando se desconectan auriculares / salida cambia.
      session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) {
          pause();
        }
      });

      // Manejo básico de interrupciones (llamadas, alarmas, etc.).
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_player.playing) {
                _playingBeforeInterruption = true;
                pause();
              }
              break;
            default:
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_playingBeforeInterruption) {
                play();
                _playingBeforeInterruption = false;
              }
              break;
            default:
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('AudioSession init error: $e');
    }
  }

  // Mapea eventos del reproductor a PlaybackState para que audio_service
  // construya una notificación con controles dinámicos.
  void _notifyPlaybackEvents() {
    _player.playbackEventStream.listen(
      (event) => _broadcastState(),
      onError: (Object e, StackTrace st) {
        debugPrint('JustAudio playbackEventStream error: $e');
        debugPrint('$st');
      },
    );

    // Log ligero de estados (útil para depurar bloqueos de buffer/ready)
    _player.playerStateStream.listen(
      (state) {
        debugPrint(
          'PlayerState -> playing=${state.playing} processing=${state.processingState}',
        );
        if (state.playing &&
            state.processingState != ProcessingState.completed &&
            state.processingState != ProcessingState.idle) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
        // Force update UI for play/pause state changes if not covered by playbackEventStream
        _broadcastState();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('playerStateStream error: $e');
      },
    );
  }

  void _broadcastState() {
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

    // Determinar ícono de favorito
    final index = _player.currentIndex;
    final currentId = (index != null && index < queue.value.length)
        ? queue.value[index].id
        : null;
    final isFav = currentId != null && _favorites.contains(currentId);

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          // Layout: [Prev] [Play/Pause] [Next] [Favorite]
          a.MediaControl.skipToPrevious,
          if (playing) a.MediaControl.pause else a.MediaControl.play,
          a.MediaControl.skipToNext,
          if (currentId != null) (isFav ? _unfavoriteAction : _favoriteAction),
        ],
        // Indices para la vista compacta (notificación colapsada)
        // Mostramos: Prev, Play/Pause, Next
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: {
          a.MediaAction.seek, // Habilita la barra de búsqueda (seeking)
          a.MediaAction.seekForward,
          a.MediaAction.seekBackward,
        },
        processingState: processingState,
        playing: playing,
        speed: _player.speed,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ),
    );
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    debugPrint('AudioService customAction: $name');
    if (name == 'favorite' || name == 'unfavorite') {
      final index = _player.currentIndex;
      if (index != null && index < queue.value.length) {
        final id = queue.value[index].id;
        if (onFavoriteToggled != null) {
          await onFavoriteToggled!(id);
        }
      }
    }
    super.customAction(name, extras);
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
      _broadcastState(); // Update favorites state when song changes
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
        for (final i in items)
          AudioSource.uri(
            Uri.parse(i.id),
            tag:
                i, // Tag MediaItem para poder identificar pista actual fuera de índice fijo.
          ),
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
          preload: true,
        );
        // Prepara el primer frame para inicio instantáneo
        await _player.load();
      } else {
        await _player.setAudioSource(playlist, preload: true);
        await _player.load();
      }
    } catch (e) {
      debugPrint('AudioHandler.setQueueFromUris error: $e');
    }
  }

  /// Construye la cola con metadatos ricos desde Song para notificación.
  Future<void> setQueueFromSongs(List<Song> songs) async {
    final playable = songs.where((s) => s.uri != null).toList();
    final signature = playable.map((s) => s.uri!).join('|');
    // Evitar reconstruir la cola si es idéntica (reduce cortes / buffering al volver a vistas).
    if (_lastQueueSignature == signature &&
        queue.value.length == playable.length) {
      return;
    }
    final items = <a.MediaItem>[
      for (final s in playable)
        a.MediaItem(
          id: s.uri!,
          title: s.title,
          artist: s.artist ?? 'Desconocido',
          album: s.album,
          // Se habilita artUri para mostrar la carátula del álbum en la notificación,
          // lo que le da el aspecto "bello" y completo (estilo Spotify/YouTube).
          // Android automáticamente usa esto como fondo/icono grande.
          artUri: s.albumId != null
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

    final children = [
      for (final i in items)
        AudioSource.uri(
          Uri.parse(i.id),
          tag:
              i, // Tag MediaItem para mapear favoritos incluso si la cola es subset.
        ),
    ];
    final playlist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: children,
    );
    try {
      await _player.setAudioSource(playlist, preload: true);
      // Preparar en background para que el primer play sea inmediato.
      await _player.load();
      _lastQueueSignature = signature;
    } catch (e) {
      debugPrint(
        'AudioHandler.setQueueFromSongs: failed to set audio source: $e',
      );
      // Limpia la cola para evitar estado inconsistente y propaga el error
      // para que los controladores superiores decidan qué hacer.
      queue.add([]);
      _lastQueueSignature = null;
      // Re-throw para que los callers que esperan un error lo reciban.
      rethrow;
    }
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
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(uri)),
        preload: true,
      );
      await _player.load();
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
    // _stallTimer no existe en release.
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

  void updateFavorites(Set<String> favs) =>
      _internalHandler.updateFavorites(favs);
  void setFavoriteCallback(Future<void> Function(String) callback) {
    _internalHandler.onFavoriteToggled = callback;
  }
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
        // Permitir que la notificación sea cerrable desde la UI del sistema.
        // Antes estaba en `true` (notificación "ongoing"), lo que impedía
        // que el usuario la descartara manualmente. Al ponerlo en `false`,
        // la notificación se podrá cerrar y la acción Stop descargará
        // correctamente el servicio cuando se invoque.
        androidNotificationOngoing: false,
        // Usar un icono de notificación dedicado (blanco y fondo transparente)
        // para evitar que el launcher adaptive icon muestre un recuadro/forma
        // alrededor del icono en la notificación.
        androidNotificationIcon: 'drawable/ic_stat_music',
      ),
    );
  }
}

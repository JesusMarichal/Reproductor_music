// Nuevo servicio basado en audio_service para notificación y controles del sistema.
// Conservamos la interfaz anterior (métodos play/pause/etc) para minimizar cambios
// en controladores y vistas existentes.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as a;
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';

/// Handler que integra JustAudio con audio_service para exponer estado a
/// notificaciones del sistema (Android) y controles externos.
class _MyAudioHandler extends a.BaseAudioHandler
    with a.QueueHandler, a.SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  String? _lastQueueSignature; // Para evitar reconstituir la cola idéntica.

  _MyAudioHandler() {
    _notifyPlaybackEvents();
    _listenForDurationChanges();
    _listenForCurrentSongChanges();
    _initSession();
    _attachDiagnostics(); // Logs avanzados y monitor de 'stall'.
    // Transiciones: si tu versión de just_audio soporta crossfade, usa:
    // _player.setClip(...); (No disponible aquí) Mantendremos configuración simple.
  }

  // --- Diagnósticos avanzados opcionales ---
  Timer? _stallTimer;
  Duration _lastPosition = Duration.zero;
  int _stallTicks = 0;
  static const int _stallThresholdSeconds =
      6; // Si posición no avanza por 6s -> posible bloqueo.

  void _attachDiagnostics() {
    // Solo en modo debug para evitar ruido en producción.
    if (!kDebugMode) return;

    // Log de secuencia/cola para detectar inconsistencias.
    _player.sequenceStateStream.listen(
      (seqState) {
        final current = seqState.currentSource;
        final sequenceLength = seqState.sequence.length;
        final index = seqState.currentIndex;
        debugPrint(
          '[AudioDiag] sequenceState: len=$sequenceLength index=$index source=${current?.tag}',
        );
      },
      onError: (e, st) {
        debugPrint('[AudioDiag] sequenceStateStream error: $e');
      },
    );

    // Monitor de avance de posición para detectar stalls (buffer lock / crash silencioso).
    _stallTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        final pos = _player.position;
        if (_player.playing) {
          if (pos == _lastPosition) {
            _stallTicks++;
          } else {
            _stallTicks = 0;
          }
          if (_stallTicks >= _stallThresholdSeconds) {
            debugPrint(
              '[AudioDiag] Posición no avanza hace ${_stallTicks}s (pos=$pos, buffered=${_player.bufferedPosition}, processing=${_player.processingState})',
            );
            _stallTicks = 0; // Evitar spam continuo.
          }
        } else {
          _stallTicks = 0; // Reset si no está reproduciendo.
        }
        _lastPosition = pos;
      } catch (e) {
        debugPrint('[AudioDiag] Stall monitor error: $e');
      }
    });

    // Log de errores en position/distraction potenciales.
    _player.playbackEventStream.listen((event) {
      if (!kDebugMode) return; // Doble guard por si se cambia en runtime.
      if (event.processingState == ProcessingState.buffering) {
        debugPrint(
          '[AudioDiag] buffering… pos=${_player.position} buffered=${_player.bufferedPosition}',
        );
      }
    });
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
          if (event.type == AudioInterruptionType.pause ||
              event.type == AudioInterruptionType.duck) {
            if (_player.playing) {
              pause();
            }
          }
        } else {
          // Reanudar sólo si se desea (aquí lo dejamos manual para evitar sorpresas).
          // Podríamos auto-reanudar si event.type == AudioInterruptionType.pause
          // y event.shouldResume es true.
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
      (event) {
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
      },
      onError: (Object e, StackTrace st) {
        // Log detallado para diagnosticar "crasheos" o fallos intermitentes.
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
      },
      onError: (Object e, StackTrace st) {
        debugPrint('playerStateStream error: $e');
      },
    );
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
          // Evitamos proporcionar `artUri` aquí para que Android no muestre
          // un "large icon" cuadrado en la notificación que puede verse
          // visualmente extraño en algunos launchers/versión de Android.
          // Si se desea mostrar artwork, podemos gestionar un recurso
          // distinto o una versión circular/recortada, pero por simplicidad
          // dejamos `artUri` en null para que la notificación use solo el
          // icono de notificación pequeño (`ic_stat_music`).
          artUri: null,
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
    _stallTimer?.cancel();
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

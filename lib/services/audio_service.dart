import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  /// Configura una cola de reproducción a partir de URIs.
  Future<void> setQueue(List<String> uris) async {
    try {
      final sources = uris.map((u) => AudioSource.uri(Uri.parse(u))).toList();

      // Intentar preservar índice y posición actuales para evitar saltos
      final currentIndex = _player.currentIndex;
      final currentPosition = _player.position;

      if (currentIndex != null &&
          currentIndex >= 0 &&
          currentIndex < sources.length) {
        await _player.setAudioSources(
          sources,
          initialIndex: currentIndex,
          initialPosition: currentPosition,
        );
      } else {
        await _player.setAudioSources(sources);
      }
    } catch (e) {
      debugPrint('AudioService.setQueue error: $e');
    }
  }

  Future<void> playIndex(int index) async {
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } catch (e) {
      debugPrint('AudioService.playIndex error: $e');
    }
  }

  Future<void> playUri(String uri) async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      await _player.play();
    } catch (e) {
      debugPrint('AudioService.playUri error: $e');
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> play() => _player.play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      debugPrint('AudioService.next error: $e');
    }
  }

  Future<void> previous() async {
    try {
      await _player.seekToPrevious();
    } catch (e) {
      debugPrint('AudioService.previous error: $e');
    }
  }

  Future<void> stop() async => await _player.stop();

  Future<void> dispose() async {
    await _player.dispose();
  }
}

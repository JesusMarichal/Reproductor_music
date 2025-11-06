import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Future<void> playUri(String uri) async {
    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      await _player.play();
    } catch (e) {
      // manejo mínimo de errores
      debugPrint('AudioService.playUri error: $e');
    }
  }

  Future<void> stop() async => await _player.stop();

  Future<void> dispose() async {
    await _player.dispose();
  }
}

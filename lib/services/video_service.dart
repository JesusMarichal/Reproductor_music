import 'package:flutter/foundation.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

/// VideoService: wrapper ligero alrededor de VlcPlayerController.
/// - init(url): crea y prepara el controlador
/// - play/pause/stop/dispose
class VideoService {
  VlcPlayerController? _controller;

  VlcPlayerController? get controller => _controller;

  /// Inicializa el controlador para la URL proporcionada.
  /// Llama a [initialize] internamente si la API lo requiere.
  Future<void> init(String url, {bool hwAcc = true}) async {
    // Liberar cualquier controlador previo
    await dispose();

    _controller = VlcPlayerController.network(url);

    // Algunos bindings requieren inicializar; si la API expone initialize, úsalo.
    try {
      await _controller!.initialize();
    } catch (_) {
      // En algunos entornos la inicialización es opcional o sin await.
      if (kDebugMode) {
        print('VideoService: initialize() no disponible o falló, continuar');
      }
    }
  }

  void play() => _controller?.play();
  void pause() => _controller?.pause();
  void stop() => _controller?.stop();

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}

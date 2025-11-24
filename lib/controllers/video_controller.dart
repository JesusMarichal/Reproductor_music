import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as ytx;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'home_controller.dart';
import '../services/audio_service.dart';
import 'video_settings_controller.dart';

class VideoItem {
  final String id;
  final String title;
  final String? channel;
  final Duration? duration;
  String get thumbUrl => 'https://img.youtube.com/vi/$id/hqdefault.jpg';

  const VideoItem({
    required this.id,
    required this.title,
    this.channel,
    this.duration,
  });
}

class VideoController extends ChangeNotifier {
  // Featured iniciales sin API
  static const List<VideoItem> featured = [
    VideoItem(
      id: 'dQw4w9WgXcQ',
      title: 'Rick Astley - Never Gonna Give You Up',
    ),
    VideoItem(id: '9bZkp7q19f0', title: 'PSY - GANGNAM STYLE'),
    VideoItem(
      id: 'kJQP7kiw5Fk',
      title: 'Luis Fonsi - Despacito ft. Daddy Yankee',
    ),
    VideoItem(id: '3JZ_D3ELwOQ', title: 'Coldplay - Adventure Of A Lifetime'),
    VideoItem(id: 'CevxZvSJLk8', title: 'Katy Perry - Roar'),
    VideoItem(id: 'hT_nvWreIhg', title: 'OneRepublic - Counting Stars'),
  ];

  final ytx.YoutubeExplode _yt = ytx.YoutubeExplode();
  late YoutubePlayerController ytController;

  bool _isReady = false;
  bool get isReady => _isReady;
  bool get isPlaying => ytController.value.isPlaying;
  String? _currentId;
  String? _currentTitle;
  String? get currentId => _currentId;
  String? get currentTitle => _currentTitle;

  // Últimos resultados de búsqueda
  List<VideoItem> searchResults = const [];

  // Cache por categoría y control de paginación simple (por tamaño solicitado)
  final Map<String, List<VideoItem>> _categoryCache = {};
  final Map<String, int> _categoryTake = {};
  final Set<String> _loadingCategories = {};
  static const int _initialPageSize = 30;
  static const int _pageStep = 20;
  bool _lastCaptionsEnabled = true;
  final Set<String> _loadingMore = {};
  final Map<String, DateTime> _lastLoadMore = {};
  int _controllerVersion = 0;
  int get controllerVersion => _controllerVersion;

  bool isLoadingMore(String name) => _loadingMore.contains(name);

  VideoController() {
    // No usar un video por defecto para evitar reproducir un "featured" no seleccionado.
    // Inicializamos con un id vacío y solo cargamos cuando el usuario selecciona un video.
    ytController = YoutubePlayerController(
      initialVideoId: '',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    )..addListener(_onPlayerChanged);
    // No inicializamos currentId/currentTitle hasta que el usuario cargue un video.
  }

  void _onPlayerChanged() {
    final value = ytController.value;
    if (value.isReady && !_isReady) {
      _isReady = true;
      notifyListeners();
    }
    // No llamar notifyListeners para cada tick si no cambia algo relevante
  }

  Future<void> load(String id, {String? title, bool autoPlay = true}) async {
    try {
      // Debug: registrar id solicitada y título para ayudar a diagnosticar fallos de carga
      try {
        // Use debugPrint para no interferir con producción si está deshabilitado
        debugPrint(
          'VideoController.load -> id: $id, title: ${title ?? ''}, autoPlay: $autoPlay',
        );
      } catch (_) {}
      // Verificar restricciones de red antes de cargar
      try {
        final settingsAccess = _SettingsAccess.instance;
        if (settingsAccess != null) {
          final allow = await settingsAccess.canStream();
          if (!allow) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('Bloqueado por WiFi-only');
            }
            settingsAccess.onBlocked?.call();
            return; // Abortamos carga
          }
          // Re-evaluar subtítulos
          final captions = settingsAccess.captionsEnabled?.call() ?? true;
          if (captions != _lastCaptionsEnabled) {
            _recreateController(captionsEnabled: captions);
          }
        }
      } catch (_) {}
      _currentId = id;
      _currentTitle = title;
      // Si hay audio en reproducción, pausarlo para evitar mezcla de audio/video
      try {
        final audio = AudioService();
        if (audio.player.playing) {
          await audio.pause();
        }
      } catch (_) {}
      // Registrar acceso global la primera vez o actualizar referencia
      VideoControllerAccess.register(
        VideoControllerAccess(
          pauseIfPlaying: () {
            if (ytController.value.isPlaying) {
              ytController.pause();
            }
          },
        ),
      );
      ytController.load(id);
      try {
        debugPrint('VideoController: ytController.load called for $id');
      } catch (_) {}
      if (autoPlay) {
        // give a microtask so load commits
        scheduleMicrotask(() {
          try {
            debugPrint('VideoController: scheduling play for $id');
          } catch (_) {}
          try {
            ytController.play();
            debugPrint('VideoController: play() invoked for $id');
          } catch (e) {
            debugPrint('VideoController: play() error for $id -> $e');
          }
        });
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('VideoController.load error: $e');
      }
    }
  }

  /// Limpia el estado cuando se quiere ocultar el mini bar sin reproducir.
  void clear() {
    _currentId = null;
    _currentTitle = null;
    notifyListeners();
  }

  Future<void> play() async {
    ytController.play();
    notifyListeners();
  }

  Future<void> pause() async {
    ytController.pause();
    notifyListeners();
  }

  Future<List<VideoItem>> search(String query, {int take = 20}) async {
    final list = await _yt.search.getVideos(query);
    final results = list.take(take).toList();
    final mapped = results
        .map(
          (v) => VideoItem(
            id: v.id.value,
            title: v.title,
            channel: v.author,
            duration: v.duration,
          ),
        )
        .toList(growable: false);
    searchResults = mapped;
    notifyListeners();
    return mapped;
  }

  // Categorías lógicas implementadas vía consultas
  static const categories = <String, String>{
    'Destacados': 'Top Music Hits 2024',
    'Música': 'Music Hits 2024',
    'Gaming': 'Gaming highlights 2024',
    'Noticias': 'Breaking news 2024',
    'Deportes': 'Sports highlights 2024',
    'Tecnología': 'Tech reviews 2024',
    'Aprendizaje': 'Programming tutorials beginner',
    'En vivo': 'Live music',
  };

  List<VideoItem> categoryItems(String name) =>
      _categoryCache[name] ?? const <VideoItem>[];

  bool isLoadingCategory(String name) => _loadingCategories.contains(name);

  Future<void> ensureCategoryLoaded(String name) async {
    if (_categoryCache.containsKey(name)) return;
    // marcar que la categoría está cargando para la UI
    _loadingCategories.add(name);
    notifyListeners();
    if (name == 'Destacados') {
      _categoryCache[name] = featured;
      _categoryTake[name] = featured.length;
      _loadingCategories.remove(name);
      notifyListeners();
      return;
    }
    final q = categories[name] ?? 'Trending videos';
    final take = _initialPageSize;
    final items = await search(q, take: take);
    _categoryCache[name] = items;
    _categoryTake[name] = take;
    _loadingCategories.remove(name);
    notifyListeners();
  }

  Future<void> loadMoreCategory(String name) async {
    // No paginar en destacados fijos
    if (name == 'Destacados') return;
    if (_loadingMore.contains(name)) return; // ya hay una petición
    final last = _lastLoadMore[name];
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 900)) {
      return; // debounce adicional de seguridad
    }
    _loadingMore.add(name);
    notifyListeners();
    final current = _categoryCache[name] ?? const <VideoItem>[];
    final q = categories[name] ?? 'Trending videos';
    final nextTake = (_categoryTake[name] ?? _initialPageSize) + _pageStep;
    final items = await search(q, take: nextTake);
    // De-duplicar por id por si el proveedor repite
    final ids = <String>{}..addAll(current.map((e) => e.id));
    final merged = [...current];
    for (final v in items) {
      if (ids.add(v.id)) merged.add(v);
    }
    _categoryCache[name] = merged;
    _categoryTake[name] = nextTake;
    _lastLoadMore[name] = DateTime.now();
    _loadingMore.remove(name);
    notifyListeners();
  }

  @override
  void dispose() {
    ytController.removeListener(_onPlayerChanged);
    ytController.dispose();
    _yt.close();
    super.dispose();
  }

  void _recreateController({required bool captionsEnabled}) {
    final wasPlaying = ytController.value.isPlaying;
    // No usar featured.first.id como fallback. Si no hay _currentId no recargamos.
    final currentVideoId = _currentId;
    final old = ytController;
    // Crear nuevo controller primero
    final newController = YoutubePlayerController(
      initialVideoId: currentVideoId ?? '',
      flags: YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: captionsEnabled,
      ),
    )..addListener(_onPlayerChanged);
    // Reasignar y notificar con una versión nueva para forzar rebuild seguro
    ytController = newController;
    _lastCaptionsEnabled = captionsEnabled;
    _controllerVersion++;
    notifyListeners();
    // Disponer el antiguo al finalizar el microtask para evitar usar un
    // controller ya dispuesto en el mismo frame por el widget actual.
    scheduleMicrotask(() {
      try {
        old.removeListener(_onPlayerChanged);
        old.dispose();
      } catch (_) {}
    });
    // Si hay un id actual válido, recargarlo. No recargamos un id por defecto.
    if (_currentId != null && _currentId!.isNotEmpty) {
      ytController.load(_currentId!);
      if (wasPlaying) {
        scheduleMicrotask(() => ytController.play());
      }
    }
  }

  void updateCaptions(bool enabled) {
    if (enabled == _lastCaptionsEnabled) return;
    _recreateController(captionsEnabled: enabled);
  }
}

/// Acceso sencillo a settings sin acoplar provider aquí.
class _SettingsAccess {
  static _SettingsAccess? instance;
  final Future<bool> Function() canStream;
  final VoidCallback? onBlocked;
  final bool Function()? captionsEnabled;
  _SettingsAccess({
    required this.canStream,
    this.onBlocked,
    this.captionsEnabled,
  });
}

class VideoSettingsAccess {
  static void register(
    VideoSettingsController ctrl, {
    VoidCallback? onBlocked,
  }) {
    _SettingsAccess.instance = _SettingsAccess(
      canStream: () => ctrl.canStream(),
      onBlocked: onBlocked,
      captionsEnabled: () => ctrl.captionsEnabled,
    );
  }
}

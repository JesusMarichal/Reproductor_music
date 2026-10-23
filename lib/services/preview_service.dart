import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../models/youtube_track.dart';
import '../utils/text_fold.dart';
import 'audio_service.dart';

/// Estado de la vista previa de un resultado de YouTube.
enum PreviewStatus { idle, loading, playing, unavailable }

/// Vistas previas de 30 s, sólo audio, de los resultados de YouTube.
///
/// YouTube no permite reproducir sólo el audio de sus vídeos, así que cada
/// resultado se empareja con la misma canción en la API de iTunes, que sí
/// ofrece una vista previa oficial de 30 s. Si iTunes no la tiene (covers,
/// karaokes, versiones sólo de YouTube) el resultado queda sin vista previa.
///
/// Usa un reproductor propio, aparte del de la app: no toca la cola ni la
/// notificación. Al empezar pausa la música local y se detiene si ésta
/// vuelve a sonar.
class PreviewService extends ChangeNotifier {
  PreviewService._() {
    _mainPlayingSub = AudioService().player.playingStream.listen((playing) {
      if (playing && _currentId != null) stop();
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) stop();
    });
  }

  static final PreviewService instance = PreviewService._();

  static const Duration length = Duration(seconds: 30);

  /// Tiendas de iTunes con catálogos grandes y variados.
  static const List<String> _fallbackStores = [
    'ES',
    'MX',
    'FR',
    'GB',
    'BR',
    'DE',
  ];

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<bool> _mainPlayingSub;

  /// URL de la vista previa por vídeo; null = iTunes no la tiene.
  final Map<String, String?> _matches = {};

  String? _currentId;
  bool _loading = false;

  /// Avance de la vista previa en curso, de 0 a 1.
  Stream<double> get progress => _player.positionStream.map(
    (p) => (p.inMilliseconds / length.inMilliseconds).clamp(0.0, 1.0),
  );

  PreviewStatus statusOf(String videoId) {
    if (_matches.containsKey(videoId) && _matches[videoId] == null) {
      return PreviewStatus.unavailable;
    }
    if (_currentId != videoId) return PreviewStatus.idle;
    return _loading ? PreviewStatus.loading : PreviewStatus.playing;
  }

  /// Reproduce la vista previa de [track], o la detiene si ya sonaba.
  /// Devuelve false si no hay vista previa para esa canción.
  Future<bool> toggle(YouTubeTrack track) async {
    if (_currentId == track.videoId) {
      await stop();
      return true;
    }
    await _player.stop();
    _currentId = track.videoId;
    _loading = true;
    notifyListeners();

    final main = AudioService().player;
    if (main.playing) await AudioService().pause();

    final url = await _previewUrl(track);
    // Mientras se buscaba, se pudo tocar otra fila o detener.
    if (_currentId != track.videoId) return url != null;
    if (url == null) {
      _currentId = null;
      _loading = false;
      notifyListeners();
      return false;
    }

    try {
      await _player.setAudioSource(
        ClippingAudioSource(
          child: AudioSource.uri(Uri.parse(url)),
          end: length,
        ),
      );
      if (_currentId != track.videoId) return true;
      _loading = false;
      notifyListeners();
      await _player.play();
    } catch (e) {
      debugPrint('PreviewService: no se pudo reproducir $url: $e');
      _matches[track.videoId] = null;
      if (_currentId == track.videoId) {
        _currentId = null;
        _loading = false;
        notifyListeners();
      }
      return false;
    }
    return true;
  }

  Future<void> stop() async {
    if (_currentId == null && !_player.playing) return;
    _currentId = null;
    _loading = false;
    notifyListeners();
    await _player.stop();
  }

  Future<String?> _previewUrl(YouTubeTrack track) async {
    if (_matches.containsKey(track.videoId)) return _matches[track.videoId];
    final query = _PreviewQuery.fromYouTube(track);
    String? url;
    if (query != null) {
      // El catálogo cambia por país (Angèle no está en la tienda de EE. UU.,
      // sí en la de Francia o España): se consultan varias a la vez y gana
      // la primera de la lista que tenga la canción.
      final device = PlatformDispatcher.instance.locale.countryCode;
      final stores = <String>{
        'US',
        if (device != null) device.toUpperCase(),
        ..._fallbackStores,
      }.toList();
      final found = await Future.wait([
        for (final store in stores) _searchItunes(query, store),
      ]);
      url = found.firstWhere((u) => u != null, orElse: () => null);
    }
    _matches[track.videoId] = url;
    return url;
  }

  Future<String?> _searchItunes(_PreviewQuery query, String country) async {
    try {
      final res = await http
          .get(
            Uri.https('itunes.apple.com', '/search', {
              'term': query.term,
              'entity': 'song',
              'limit': '10',
              'country': country,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final results =
          (json.decode(res.body)['results'] as List<dynamic>? ?? const []);

      String? best;
      var bestScore = 0.0;
      for (final r in results) {
        final preview = r['previewUrl'] as String?;
        if (preview == null) continue;
        final score = query.score(
          r['trackName'] as String? ?? '',
          r['artistName'] as String? ?? '',
        );
        if (score > bestScore) {
          bestScore = score;
          best = preview;
        }
      }
      return best;
    } catch (e) {
      debugPrint('PreviewService: búsqueda en iTunes fallida: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _mainPlayingSub.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// Canción y artista deducidos del título de un vídeo de YouTube.
class _PreviewQuery {
  _PreviewQuery(this.song, this.artist);

  final String song;
  final String artist;

  /// Sin vista previa para versiones que no son la original: iTunes
  /// devolvería la canción original y sonaría algo distinto de lo elegido.
  static final RegExp _notOriginal = RegExp(
    r'karaoke|instrumental|cover|8d audio|slowed|sped up|nightcore',
    caseSensitive: false,
  );

  /// Coletillas de YouTube entre paréntesis o corchetes.
  static final RegExp _noise = RegExp(
    r'[\(\[][^\)\]]*(official|oficial|video|vídeo|clip|audio|lyric|lyrics|'
    r'letra|paroles|visualizer|hd|4k|remaster)[^\)\]]*[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _featuring = RegExp(
    r'\s+(feat\.?|ft\.?|featuring)\s+.*$',
    caseSensitive: false,
  );

  static _PreviewQuery? fromYouTube(YouTubeTrack track) {
    if (_notOriginal.hasMatch(track.title)) return null;
    final title = track.title.replaceAll(_noise, ' ').trim();

    // "Artista - Canción" es el formato habitual; si no, el artista es el
    // canal (que ya viene sin "VEVO" ni " - Topic").
    final parts = title.split(RegExp(r'\s+[-–—|]\s+'));
    final String song;
    final String artist;
    if (parts.length >= 2) {
      artist = parts.first;
      song = parts[1];
    } else {
      artist = track.channel;
      song = title;
    }
    final cleanSong = song.replaceAll(_featuring, '').trim();
    if (cleanSong.isEmpty) return null;
    return _PreviewQuery(cleanSong, artist.trim());
  }

  String get term => '$artist $song'.trim();

  /// Parecido de un resultado de iTunes, de 0 a 1. Exige que el título se
  /// parezca y, si se conoce el artista, también éste.
  double score(String trackName, String artistName) {
    final titleSim = _overlap(
      foldedWords(song),
      foldedWords(trackName.replaceAll(_featuring, '')),
    );
    if (titleSim < 0.6) return 0;
    if (artist.isEmpty) return titleSim;
    final artistSim = _overlap(foldedWords(artist), foldedWords(artistName));
    if (artistSim < 0.5) return 0;
    return titleSim * 0.6 + artistSim * 0.4;
  }

  /// Fracción de las palabras buscadas que aparecen en el candidato,
  /// penalizando candidatos con muchas palabras de más.
  static double _overlap(List<String> wanted, List<String> candidate) {
    if (wanted.isEmpty || candidate.isEmpty) return 0;
    final set = candidate.toSet();
    final hits = wanted.where(set.contains).length;
    final recall = hits / wanted.length;
    final precision = hits / set.length;
    return recall * 0.75 + precision * 0.25;
  }
}

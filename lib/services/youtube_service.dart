import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/youtube_track.dart';

/// Por qué falló una búsqueda en YouTube, con un mensaje para mostrar.
class YouTubeException implements Exception {
  const YouTubeException(this.message, {this.needsKey = false});

  final String message;

  /// Si se arregla configurando (otra) API key.
  final bool needsKey;

  @override
  String toString() => message;
}

/// Búsqueda de música con la API oficial de YouTube (Data API v3).
///
/// YouTube Music no tiene API pública: se buscan vídeos de la categoría
/// "Música" de YouTube, que son los mismos que reproduce YouTube Music. La
/// reproducción se hace con el reproductor oficial embebido, como exigen las
/// condiciones de la API.
///
/// La API key se toma de `--dart-define=YOUTUBE_API_KEY=...` al compilar o,
/// si no, de la que se guarde desde la app.
class YouTubeService {
  YouTubeService._();

  static final YouTubeService instance = YouTubeService._();

  static const String _prefsKey = 'youtube_api_key';
  static const String _buildKey = String.fromEnvironment('YOUTUBE_API_KEY');

  /// Cada búsqueda cuesta 100 de las 10.000 unidades diarias gratuitas: se
  /// guardan los resultados para no repetir la misma.
  final Map<String, List<YouTubeTrack>> _cache = {};

  Future<String?> apiKey() async {
    if (_buildKey.isNotEmpty) return _buildKey;
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefsKey)?.trim();
    return (key == null || key.isEmpty) ? null : key;
  }

  /// Si la key viene fijada al compilar, no se puede cambiar desde la app.
  bool get keyFromBuild => _buildKey.isNotEmpty;

  Future<void> setApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = key?.trim() ?? '';
    if (value.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, value);
    }
    _cache.clear();
  }

  List<YouTubeTrack>? cached(String query) => _cache[_normalize(query)];

  Future<List<YouTubeTrack>> search(String query) async {
    final normalized = _normalize(query);
    final hit = _cache[normalized];
    if (hit != null) return hit;

    final key = await apiKey();
    if (key == null) {
      throw const YouTubeException(
        'Añade una API key de YouTube para buscar.',
        needsKey: true,
      );
    }

    final searchJson = await _get('search', {
      'part': 'snippet',
      'type': 'video',
      'videoCategoryId': '10', // Música.
      'maxResults': '15',
      'q': query.trim(),
      'key': key,
    });

    final tracks = <YouTubeTrack>[];
    for (final item in (searchJson['items'] as List<dynamic>? ?? [])) {
      final id = item['id']?['videoId'] as String?;
      final snippet = item['snippet'] as Map<String, dynamic>?;
      if (id == null || snippet == null) continue;
      final thumbs = snippet['thumbnails'] as Map<String, dynamic>? ?? {};
      final thumb =
          (thumbs['medium'] ?? thumbs['high'] ?? thumbs['default'])?['url'];
      tracks.add(
        YouTubeTrack(
          videoId: id,
          title: _unescape(snippet['title'] as String? ?? ''),
          channel: _cleanChannel(
            _unescape(snippet['channelTitle'] as String? ?? ''),
          ),
          thumbnailUrl: thumb as String? ?? '',
        ),
      );
    }

    // La búsqueda no trae la duración; pedirla cuesta 1 unidad más y deja
    // las filas iguales que las de la biblioteca.
    if (tracks.isNotEmpty) {
      try {
        final videosJson = await _get('videos', {
          'part': 'contentDetails',
          'id': tracks.map((t) => t.videoId).join(','),
          'key': key,
        });
        final durations = <String, Duration?>{
          for (final v in (videosJson['items'] as List<dynamic>? ?? []))
            v['id'] as String: _parseDuration(
              v['contentDetails']?['duration'] as String?,
            ),
        };
        for (var i = 0; i < tracks.length; i++) {
          tracks[i] = tracks[i].withDuration(durations[tracks[i].videoId]);
        }
      } catch (e) {
        debugPrint('YouTubeService: sin duraciones: $e');
      }
    }

    _cache[normalized] = tracks;
    return tracks;
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final http.Response res;
    try {
      res = await http
          .get(Uri.https('www.googleapis.com', '/youtube/v3/$path', params))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const YouTubeException(
        'No se pudo conectar con YouTube. Revisa tu conexión.',
      );
    }

    final body = _decode(res.body);
    if (res.statusCode == 200) return body;

    final error = body['error'] as Map<String, dynamic>?;
    final reason = (error?['errors'] as List<dynamic>?)?.firstOrNull?['reason'];
    debugPrint(
      'YouTubeService: ${res.statusCode} $reason ${error?['message']}',
    );
    throw switch (reason) {
      'quotaExceeded' || 'dailyLimitExceeded' => const YouTubeException(
        'Se agotó la cuota diaria de búsquedas en YouTube. '
        'Vuelve a intentarlo mañana.',
      ),
      'keyInvalid' ||
      'badRequest' when res.statusCode == 400 => const YouTubeException(
        'La API key de YouTube no es válida.',
        needsKey: true,
      ),
      'accessNotConfigured' => const YouTubeException(
        'Activa «YouTube Data API v3» en el proyecto de Google Cloud de '
        'tu API key.',
        needsKey: true,
      ),
      'forbidden' || 'ipRefererBlocked' => const YouTubeException(
        'La API key de YouTube tiene restricciones que impiden usarla '
        'desde esta app.',
        needsKey: true,
      ),
      _ => YouTubeException(
        'YouTube respondió con un error (${res.statusCode}).',
      ),
    };
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final value = json.decode(body);
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  static String _normalize(String query) => query.trim().toLowerCase();

  /// La API devuelve los títulos con entidades HTML (`&amp;`, `&#39;`...).
  static String _unescape(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  /// "AngeleVEVO" → "Angele", "Angèle - Topic" → "Angèle".
  static String _cleanChannel(String channel) => channel
      .replaceFirst(RegExp(r'\s*-\s*Topic$'), '')
      .replaceFirst(RegExp(r'VEVO$'), '')
      .trim();

  /// Duración ISO 8601 de la API: "PT3M17S", "PT1H2M3S".
  static Duration? _parseDuration(String? iso) {
    if (iso == null) return null;
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
    ).firstMatch(iso);
    if (match == null) return null;
    int part(int i) => int.tryParse(match.group(i) ?? '') ?? 0;
    return Duration(hours: part(1), minutes: part(2), seconds: part(3));
  }
}

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';

/// Caché en memoria de las carátulas a alta resolución.
///
/// El reproductor a pantalla completa necesita los bytes de la carátula en el
/// mismo frame en que se abre: si llegan a mitad de la transición, la imagen
/// aparece de golpe, se decodifica mientras se anima y la animación se
/// entrecorta. Por eso la carátula de la pista en curso se precarga al cambiar
/// de canción y el reproductor la lee de aquí de forma síncrona con [peek].
///
/// Orden de resolución: URL remota (iTunes) → carátula incrustada en el
/// archivo.
class ArtworkCache {
  ArtworkCache._();

  static final ArtworkCache instance = ArtworkCache._();

  /// Pocas entradas: sólo interesan la pista actual y las recientes.
  static const int _maxEntries = 12;

  final OnAudioQuery _query = OnAudioQuery();

  /// LRU por [keyOf]. Un valor null significa "no tiene carátula", que
  /// también se cachea para no volver a consultarlo.
  final LinkedHashMap<String, Uint8List?> _entries = LinkedHashMap();
  final Map<String, Future<Uint8List?>> _pending = {};

  /// Bytes ya cargados de [song], o null si todavía no se han resuelto o la
  /// canción no tiene carátula.
  Uint8List? peek(Song song) => _entries[keyOf(song)];

  bool contains(Song song) => _entries.containsKey(keyOf(song));

  /// La clave incluye la URL remota: cuando el enriquecimiento de metadatos
  /// encuentra la carátula de iTunes después, se vuelve a resolver en lugar
  /// de quedarse con la incrustada (o con "sin carátula").
  static String keyOf(Song song) => '${song.id}|${song.artworkUrl ?? ''}';

  /// Carga (o devuelve de la caché) la carátula de [song].
  Future<Uint8List?> load(Song song) {
    final key = keyOf(song);
    if (_entries.containsKey(key)) {
      final bytes = _entries.remove(key);
      _entries[key] = bytes; // Marca como usada recientemente.
      return SynchronousFuture(bytes);
    }
    return _pending[key] ??= _resolve(song).then((bytes) {
      _pending.remove(key);
      _entries[key] = bytes;
      while (_entries.length > _maxEntries) {
        _entries.remove(_entries.keys.first);
      }
      return bytes;
    });
  }

  Future<Uint8List?> _resolve(Song song) async {
    final art = song.artworkUrl;
    if (art != null && art.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(art))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (e) {
        debugPrint('ArtworkCache: no se pudo leer $art: $e');
      }
    }

    final id = int.tryParse(song.id);
    if (id == null) return null;
    try {
      final bytes = await _query.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 1024,
      );
      return (bytes != null && bytes.isNotEmpty) ? bytes : null;
    } catch (e) {
      debugPrint('ArtworkCache: no se pudo leer la carátula de ${song.id}: $e');
      return null;
    }
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

/// Resuelve la imagen que muestra la notificación de reproducción.
///
/// `audio_service` necesita una URI que Android pueda abrir. La URI de
/// MediaStore `content://media/external/audio/albumart/<albumId>` sólo existe
/// si el archivo trae carátula incrustada; cuando no, falla con
/// `FileNotFoundException` y la notificación queda sin imagen.
///
/// Esta clase la resuelve a un fichero real, en este orden:
///   1. La carátula de alta resolución descargada de iTunes, si la hay.
///   2. La carátula incrustada en el propio archivo, volcada a caché.
///   3. El logo de la app, para que la notificación nunca quede vacía.
///
/// Sólo se resuelve la pista en curso, así que el coste es una consulta por
/// cambio de canción, no una por cada tema de la biblioteca.
class NotificationArtwork {
  NotificationArtwork._();

  static final NotificationArtwork instance = NotificationArtwork._();

  final OnAudioQuery _query = OnAudioQuery();

  /// Resultados ya resueltos, por id de canción.
  final Map<String, Uri?> _cache = {};

  Uri? _appLogoUri;
  Directory? _cacheDir;

  Future<Directory> _dir() async {
    return _cacheDir ??= await getApplicationCacheDirectory();
  }

  /// Copia el logo del bundle a un fichero la primera vez: Android no puede
  /// abrir una URI de asset de Flutter directamente.
  Future<Uri?> _logo() async {
    if (_appLogoUri != null) return _appLogoUri;
    try {
      final dir = await _dir();
      final file = File('${dir.path}/notification_logo.png');
      if (!file.existsSync()) {
        final bytes = await rootBundle.load('assets/logo_music_app.png');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      return _appLogoUri = file.uri;
    } catch (e) {
      debugPrint('No se pudo preparar el logo para la notificación: $e');
      return null;
    }
  }

  /// URI de imagen para la canción [songId].
  ///
  /// [remoteArtworkUrl] es la carátula de iTunes si el enriquecimiento de
  /// metadatos ya la encontró.
  Future<Uri?> resolve(String songId, {String? remoteArtworkUrl}) async {
    if (remoteArtworkUrl != null && remoteArtworkUrl.isNotEmpty) {
      return Uri.parse(remoteArtworkUrl);
    }

    if (_cache.containsKey(songId)) return _cache[songId];

    Uri? resolved;
    try {
      final id = int.tryParse(songId);
      if (id != null) {
        final bytes = await _query.queryArtwork(
          id,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 512,
        );
        if (bytes != null && bytes.isNotEmpty) {
          final dir = await _dir();
          final file = File('${dir.path}/art_$songId.jpg');
          if (!file.existsSync()) {
            await file.writeAsBytes(bytes, flush: true);
          }
          resolved = file.uri;
        }
      }
    } catch (e) {
      debugPrint('No se pudo leer la carátula de $songId: $e');
    }

    resolved ??= await _logo();
    _cache[songId] = resolved;
    return resolved;
  }
}

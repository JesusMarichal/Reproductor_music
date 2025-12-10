import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MetadataResult {
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;

  MetadataResult({this.title, this.artist, this.album, this.artworkUrl});
}

class MetadataService {
  static final MetadataService _instance = MetadataService._internal();
  factory MetadataService() => _instance;
  MetadataService._internal();

  Future<MetadataResult?> fetchMetadata(String query) async {
    try {
      debugPrint('Metadata: Buscando metadatos para: "$query"...');

      // 1. Intentar búsqueda directa en iTunes
      var result = await _searchItunes(query);

      // Si no se encuentra, simplemente devolvemos null (sin re-intento por IA)

      if (result != null) {
        debugPrint('Metadata: ¡Encontrado! ${result.artist} - ${result.title}');
      } else {
        debugPrint('Metadata: No se encontraron resultados para "$query".');
      }

      return result;
    } catch (e) {
      debugPrint('Metadata: Error buscando metadatos: $e');
      return null;
    }
  }

  Future<MetadataResult?> _searchItunes(String term) async {
    try {
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(term)}&entity=song&limit=1',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['resultCount'] > 0) {
          final item = data['results'][0];
          // Obtener la imagen de mayor calidad cambiando la dimensión en la URL
          String? art = item['artworkUrl100'];
          if (art != null) {
            art = art.replaceAll('100x100bb', '500x500bb');
          }

          return MetadataResult(
            title: item['trackName'],
            artist: item['artistName'],
            album: item['collectionName'],
            artworkUrl: art,
          );
        }
      }
    } catch (e) {
      debugPrint('iTunes API Error: $e');
    }
    return null;
  }
}

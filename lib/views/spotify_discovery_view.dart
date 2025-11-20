import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SpotifyDiscoveryView extends StatefulWidget {
  const SpotifyDiscoveryView({super.key});

  @override
  State<SpotifyDiscoveryView> createState() => _SpotifyDiscoveryViewState();
}

class _SpotifyDiscoveryViewState extends State<SpotifyDiscoveryView> {
  final TextEditingController _tokenCtrl = TextEditingController();
  final TextEditingController _queryCtrl = TextEditingController();
  List<Map<String, String>> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final token = _tokenCtrl.text.trim();
    final q = _queryCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (token.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Introduce un token de acceso de Spotify (Bearer)'),
        ),
      );
      return;
    }
    if (q.isEmpty) return;
    setState(() => _loading = true);
    try {
      final url = Uri.https('api.spotify.com', '/v1/search', {
        'q': q,
        'type': 'track',
        'limit': '12',
      });
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final tracks = (data['tracks']?['items'] as List<dynamic>?) ?? [];
        _results = tracks.map<Map<String, String>>((t) {
          final artists = (t['artists'] as List<dynamic>)
              .map((a) => a['name'])
              .join(', ');
          final external = (t['external_urls']?['spotify'] ?? '');
          return {
            'id': t['id'] ?? '',
            'name': t['name'] ?? '',
            'artists': artists,
            'album': t['album']?['name'] ?? '',
            'url': external,
          };
        }).toList();
      } else {
        _results = [];
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error ${res.statusCode}: ${res.reasonPhrase}'),
          ),
        );
      }
    } catch (e) {
      _results = [];
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _openInSpotify(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Spotify')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encontrar Nuevos Temas')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text('Conecta con la API de Spotify para buscar temas.'),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Token de acceso (Bearer)',
                hintText: 'Pega aquí tu access token temporal',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Artista, canción o álbum',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No hay resultados.'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(r['name'] ?? ''),
                            subtitle: Text(
                              '${r['artists'] ?? ''} • ${r['album'] ?? ''}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => _openInSpotify(r['url'] ?? ''),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nota: Para pruebas puedes obtener un token temporal desde la consola de desarrolladores de Spotify o usar OAuth en un flujo separado.',
            ),
          ],
        ),
      ),
    );
  }
}

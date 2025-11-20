import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../controllers/home_controller.dart';
import '../controllers/playlist_controller.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _queryCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selected = {}; // para selección múltiple

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final pc = context.read<PlaylistController>();

    if (home.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buscar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final songs = home.songs;
    final filtered = _query.isEmpty
        ? songs
        : songs.where((s) {
            final q = _query.toLowerCase();
            return (s.title.toLowerCase().contains(q) ||
                (s.artist ?? '').toLowerCase().contains(q) ||
                (s.album ?? '').toLowerCase().contains(q));
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar música'),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: 'Agregar a lista',
              icon: const Icon(Icons.playlist_add),
              onPressed: () =>
                  _showAddToPlaylist(context, pc, _selected.toList()),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por título, artista o álbum',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                final originalIndex = songs.indexWhere((x) => x.id == s.id);
                final isSelected = _selected.contains(s.id);
                return ListTile(
                  leading: QueryArtworkWidget(
                    id: int.tryParse(s.id) ?? 0,
                    type: ArtworkType.AUDIO,
                    artworkBorder: BorderRadius.circular(6),
                    nullArtworkWidget: Builder(
                      builder: (ctx) {
                        final base = Theme.of(ctx).colorScheme.primary;
                        // Evita el uso de withOpacity() (deprecado) y usa withAlpha
                        final bg = base.withAlpha((0.12 * 255).round());
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                    size: 48,
                  ),
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${s.artist ?? 'Desconocido'} • ${s.album ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Reproducir',
                        onPressed: () async {
                          if (originalIndex != -1) {
                            // Capturamos el Navigator antes del await para no usar
                            // BuildContext a través de la brecha async.
                            final nav = Navigator.of(context);
                            await home.playAt(originalIndex);
                            if (!mounted) return;
                            nav.pop(); // volver al home o lo que sea
                          } else {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo reproducir esta pista',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.playlist_add),
                        tooltip: 'Agregar a una lista',
                        onPressed: () =>
                            _showAddToPlaylist(context, pc, [s.id]),
                      ),
                      IconButton(
                        icon: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                        ),
                        tooltip: 'Seleccionar',
                        onPressed: () {
                          setState(() {
                            if (isSelected)
                              _selected.remove(s.id);
                            else
                              _selected.add(s.id);
                          });
                        },
                      ),
                    ],
                  ),
                  onLongPress: () {
                    setState(() {
                      if (isSelected)
                        _selected.remove(s.id);
                      else
                        _selected.add(s.id);
                    });
                  },
                  onTap: () async {
                    // Abrir detalles o reproducir
                    if (originalIndex != -1) {
                      final nav = Navigator.of(context);
                      await home.playAt(originalIndex);
                      if (!mounted) return;
                      nav.pop();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddToPlaylist(
    BuildContext context,
    PlaylistController pc,
    List<String> songIds,
  ) async {
    // Ensure playlists are loaded
    await pc.init();
    if (!mounted) return;

    final localCtx =
        context; // capturado después de await y comprobación de mounted
    showModalBottomSheet(
      context: localCtx,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Agregar a lista',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (pc.playlists.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No hay listas. Crea una nueva.'),
                  ),
                ...pc.playlists.map((pl) {
                  return ListTile(
                    title: Text(pl.title),
                    subtitle: Text('${pl.songIds.length} canciones'),
                    onTap: () async {
                      // Capturamos el ScaffoldMessenger antes de la llamada async
                      final messenger = ScaffoldMessenger.of(localCtx);
                      Navigator.of(ctx).pop();
                      await pc.addSongsToPlaylist(pl.id, songIds);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Agregado a "${pl.title}"')),
                      );
                    },
                  );
                }),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.create_new_folder),
                  title: const Text('Crear nueva lista'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _showCreatePlaylistDialog(localCtx, pc, songIds);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePlaylistDialog(
    BuildContext context,
    PlaylistController pc,
    List<String> songIds,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear lista'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nombre requerido' : null,
              ),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final title = nameCtrl.text.trim();
              final desc = descCtrl.text.trim();
              Navigator.of(ctx).pop();
              // Usar el contexto del diálogo (ctx) en lugar del contexto externo
              // para evitar usar un BuildContext capturado a través de awaits.
              final messenger = ScaffoldMessenger.of(ctx);
              await pc.createPlaylist(title, desc, songIds);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text('Lista "$title" creada')),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
  }
}

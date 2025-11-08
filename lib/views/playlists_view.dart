import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/home_controller.dart';
import '../models/playlist.dart';

class PlaylistsView extends StatefulWidget {
  const PlaylistsView({super.key});

  @override
  State<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends State<PlaylistsView> {
  @override
  void initState() {
    super.initState();
    // Inicializar cuando la vista se monta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pc = context.read<PlaylistController>();
      pc.init();
    });
  }

  void _openCreatePlaylistDialog(BuildContext context) {
    final home = context.read<HomeController>();
    final pc = context.read<PlaylistController>();
    final songs = home.songs;
    final selected = <String>{};
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nueva playlist'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Canciones:'),
                    ),
                    const SizedBox(height: 4),
                    ...songs.map((s) {
                      final checked = selected.contains(s.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(s.id);
                            } else {
                              selected.remove(s.id);
                            }
                          });
                        },
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          s.artist ?? 'Desconocido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;
                  await pc.createPlaylist(
                    title,
                    descCtrl.text.trim(),
                    selected.toList(),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistController>(
      builder: (context, pc, _) {
        if (pc.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (pc.playlists.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.library_music,
                  size: 72,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 12),
                const Text('Sin playlists'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _openCreatePlaylistDialog(context),
                  child: const Text('Crear playlist'),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: pc.playlists.length,
                itemBuilder: (context, index) {
                  final p = pc.playlists[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text(p.title),
                      subtitle: Text(
                        p.description.isEmpty
                            ? 'Sin descripción'
                            : p.description,
                      ),
                      trailing: Text('${p.songIds.length} canciones'),
                      onTap: () {
                        _showPlaylistSongs(context, p);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: () => _openCreatePlaylistDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Nueva playlist'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistSongs(BuildContext context, Playlist p) {
    final home = context.read<HomeController>();
    final songs = home.songs.where((s) => p.songIds.contains(s.id)).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollCtrl) {
          return Column(
            children: [
              ListTile(
                title: Text(
                  p.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(p.description),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _openEditPlaylistDialog(context, p);
                        break;
                      case 'add_songs':
                        _openAddSongsDialog(context, p);
                        break;
                      case 'delete':
                        _confirmDeletePlaylist(context, p);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'add_songs',
                      child: Text('Agregar músicas'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar playlist'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final s = songs[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note),
                      title: Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(s.artist ?? 'Desconocido', maxLines: 1),
                      onTap: () async {
                        final idx = home.songs.indexWhere((x) => x.id == s.id);
                        if (idx != -1) {
                          await home.playAt(idx);
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Quitar de playlist',
                        onPressed: () async {
                          final pc = context.read<PlaylistController>();
                          await pc.removeSongFromPlaylist(p.id, s.id);
                          if (mounted) Navigator.of(context).pop();
                          // Reabrir para refrescar listado actualizado
                          if (mounted)
                            _showPlaylistSongs(
                              context,
                              pc.playlists.firstWhere((pl) => pl.id == p.id),
                            );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddSongsDialog(BuildContext context, Playlist playlist) {
    final home = context.read<HomeController>();
    final pc = context.read<PlaylistController>();
    final allSongs = home.songs;
    final selected = playlist.songIds.toSet();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Agregar músicas a "${playlist.title}"'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...allSongs.map((s) {
                      final checked = selected.contains(s.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(s.id);
                            } else {
                              selected.remove(s.id);
                            }
                          });
                        },
                        title: Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(s.artist ?? 'Desconocido', maxLines: 1),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await pc.updatePlaylist(
                    id: playlist.id,
                    songIds: selected.toList(),
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openEditPlaylistDialog(BuildContext context, Playlist playlist) {
    final pc = context.read<PlaylistController>();
    final titleCtrl = TextEditingController(text: playlist.title);
    final descCtrl = TextEditingController(text: playlist.description);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar playlist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;
              await pc.updatePlaylist(
                id: playlist.id,
                title: t,
                description: descCtrl.text.trim(),
              );
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePlaylist(BuildContext context, Playlist playlist) {
    final pc = context.read<PlaylistController>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar playlist'),
        content: Text('¿Seguro que deseas eliminar "${playlist.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await pc.deletePlaylist(playlist.id);
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

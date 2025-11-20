import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/player_bar.dart';
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
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          String q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? songs
              : songs.where((s) {
                  return s.title.toLowerCase().contains(q) ||
                      (s.artist ?? '').toLowerCase().contains(q);
                }).toList();
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Canciones:'),
                    ),
                    const SizedBox(height: 4),
                    ...filtered.map((s) {
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

  Future<void> _openCreateMixedPlaylistFlow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed =
        prefs.getBool('mixed_playlist_info_dismissed_v1') ?? false;
    if (!dismissed && mounted) {
      bool noMostrar = false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('¿Qué es una lista mixta?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• Una lista mixta combina otras playlists.'),
                  const SizedBox(height: 8),
                  const Text(
                    '• No duplica canciones; si un tema está en varias, se muestra una vez.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Puedes reproducir en orden o aleatorio todo el contenido combinado.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: noMostrar,
                        onChanged: (v) =>
                            setState(() => noMostrar = v ?? false),
                      ),
                      const Expanded(child: Text('No volver a mostrar')),
                    ],
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Entendido'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      if (proceed == true && noMostrar) {
        await prefs.setBool('mixed_playlist_info_dismissed_v1', true);
      }
      if (proceed != true) return;
    }
    if (!mounted) return;
    _openCreateMixedPlaylistDialogInner(context);
  }

  void _openCreateMixedPlaylistDialogInner(BuildContext context) {
    final pc = context.read<PlaylistController>();
    final playlists = pc.playlists.where((p) => !p.isMixed).toList();
    final selected = <String>{};
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    // Mostrar info (sin preferencia persistida aún; se puede añadir después)
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          String q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? playlists
              : playlists
                    .where((pl) => pl.title.toLowerCase().contains(q))
                    .toList();
          return AlertDialog(
            title: const Text('Nueva lista mixta'),
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar playlists',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Selecciona playlists a mezclar:'),
                    ),
                    const SizedBox(height: 4),
                    ...filtered.map((pl) {
                      final checked = selected.contains(pl.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              selected.add(pl.id);
                            } else {
                              selected.remove(pl.id);
                            }
                          });
                        },
                        title: Text(pl.title),
                        subtitle: Text('${pl.songIds.length} canciones'),
                      );
                    }),
                    if (selected.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Playlists seleccionadas: ${selected.length}',
                          ),
                        ),
                      ),
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
                  if (title.isEmpty || selected.isEmpty) return;
                  await pc.createMixedPlaylist(
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
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _openCreateMixedPlaylistFlow(context),
                  child: const Text('Crear lista mixta'),
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
                      title: Row(
                        children: [
                          if (p.isMixed)
                            const Padding(
                              padding: EdgeInsets.only(right: 4.0),
                              child: Icon(
                                Icons.all_inclusive,
                                size: 18,
                                color: Colors.deepPurple,
                              ),
                            ),
                          Expanded(child: Text(p.title)),
                        ],
                      ),
                      subtitle: Text(
                        p.isMixed
                            ? (p.description.isEmpty
                                  ? 'Lista mixta'
                                  : p.description)
                            : (p.description.isEmpty
                                  ? 'Sin descripción'
                                  : p.description),
                      ),
                      trailing: Consumer<PlaylistController>(
                        builder: (context, ctrl, _) {
                          if (p.isMixed) {
                            final songs = ctrl.aggregatedSongs(p);
                            return Text('${songs.length} canciones');
                          }
                          return Text('${p.songIds.length} canciones');
                        },
                      ),
                      onTap: () {
                        _showPlaylistSongs(context, p);
                      },
                      onLongPress: () {
                        _showPlaylistContextMenu(context, p);
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openCreatePlaylistDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva playlist'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateMixedPlaylistFlow(context),
                    icon: const Icon(Icons.all_inclusive),
                    label: const Text('Nueva lista mixta'),
                  ),
                ],
              ),
            ),
            if (context.watch<HomeController>().currentIndex != -1) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const PlayerBar(),
            ],
          ],
        );
      },
    );
  }

  void _showPlaylistSongs(BuildContext context, Playlist p) {
    final home = context.read<HomeController>();
    final pc = context.read<PlaylistController>();
    final songs = p.isMixed
        ? pc.aggregatedSongs(p)
        : home.songs.where((s) => p.songIds.contains(s.id)).toList();
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
              // Header estilizado
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.85),
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      if (p.isMixed)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(
                            Icons.all_inclusive,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          p.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    p.description.isEmpty
                        ? (p.isMixed ? 'Lista mixta' : 'Sin descripción')
                        : p.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Reproducir',
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        onPressed: () async {
                          final home = context.read<HomeController>();
                          final subset = songs;
                          await home.playSubset(
                            subset,
                            0,
                            mixed: p.isMixed,
                            mixedId: p.isMixed ? p.id : null,
                            mixedTitle: p.isMixed ? p.title : null,
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        color: Theme.of(context).colorScheme.surface,
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
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          if (!p.isMixed)
                            const PopupMenuItem(
                              value: 'add_songs',
                              child: Text('Agregar músicas'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar playlist'),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (songs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await home.playSubset(
                              songs,
                              0,
                              mixed: p.isMixed,
                              mixedId: p.isMixed ? p.id : null,
                              mixedTitle: p.isMixed ? p.title : null,
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Reproducir en orden'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final shuffled = [...songs]..shuffle();
                            await home.playSubset(
                              shuffled,
                              0,
                              mixed: p.isMixed,
                              mixedId: p.isMixed ? p.id : null,
                              mixedTitle: p.isMixed ? p.title : null,
                            );
                          },
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Reproducir aleatorio'),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        await home.playSubset(
                          songs,
                          index,
                          mixed: p.isMixed,
                          mixedId: p.isMixed ? p.id : null,
                          mixedTitle: p.isMixed ? p.title : null,
                        );
                      },
                      trailing: IconButton(
                        icon: Icon(
                          p.isMixed
                              ? Icons.remove_circle_outline
                              : Icons.delete_outline,
                        ),
                        tooltip: p.isMixed
                            ? 'Quitar solo de esta lista mixta'
                            : 'Quitar de playlist',
                        onPressed: () async {
                          final pc2 = context.read<PlaylistController>();
                          if (p.isMixed) {
                            await pc2.excludeSongFromMixed(p.id, s.id);
                          } else {
                            await pc2.removeSongFromPlaylist(p.id, s.id);
                          }
                          if (mounted) Navigator.of(context).pop();
                          if (mounted)
                            _showPlaylistSongs(
                              context,
                              pc2.playlists.firstWhere((pl) => pl.id == p.id),
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

  void _showPlaylistContextMenu(BuildContext context, Playlist p) {
    final pc = context.read<PlaylistController>();
    final home = context.read<HomeController>();
    final songs = p.isMixed
        ? pc.aggregatedSongs(p)
        : home.songs.where((s) => p.songIds.contains(s.id)).toList();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Reproducir en orden'),
              onTap: () async {
                await home.playSubset(
                  songs,
                  0,
                  mixed: p.isMixed,
                  mixedId: p.isMixed ? p.id : null,
                  mixedTitle: p.isMixed ? p.title : null,
                );
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Reproducir aleatorio'),
              onTap: () async {
                final shuffled = [...songs]..shuffle();
                await home.playSubset(
                  shuffled,
                  0,
                  mixed: p.isMixed,
                  mixedId: p.isMixed ? p.id : null,
                  mixedTitle: p.isMixed ? p.title : null,
                );
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar playlist'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openEditPlaylistDialog(context, p);
              },
            ),
            if (!p.isMixed)
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Agregar músicas'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openAddSongsDialog(context, p);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeletePlaylist(context, p);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAddSongsDialog(BuildContext context, Playlist playlist) {
    final home = context.read<HomeController>();
    final pc = context.read<PlaylistController>();
    final allSongs = home.songs;
    final selected = playlist.songIds.toSet();
    final searchCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? allSongs
              : allSongs.where((s) {
                  return s.title.toLowerCase().contains(q) ||
                      (s.artist ?? '').toLowerCase().contains(q);
                }).toList();
          return AlertDialog(
            title: Text('Agregar músicas a "${playlist.title}"'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Buscar',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    ...filtered.map((s) {
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

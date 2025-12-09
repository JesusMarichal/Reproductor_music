import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/player_bar.dart';
import '../controllers/playlist_controller.dart';
import '../controllers/home_controller.dart';
import '../models/playlist.dart';
import '../widgets/now_playing_indicator.dart';

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
    final pc = context.read<PlaylistController>();
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate height to push content up when keyboard opens
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final hintColor = isDark ? Colors.grey[600] : Colors.grey[500];

          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Ponle nombre a tu playlist',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // Title Input - Large and Center
                TextField(
                  controller: titleCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Mi Playlist',
                    hintStyle: TextStyle(
                      color: hintColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[500]!,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                // Description Input (Optional)
                TextField(
                  controller: descCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Descripción (Opcional)',
                    hintStyle: TextStyle(color: hintColor),
                    border: InputBorder.none,
                  ),
                ),

                const SizedBox(height: 48),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: textColor ?? Colors.grey,
                      ),
                      child: const Text('CANCELAR'),
                    ),
                    const SizedBox(width: 32),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) return;
                        await pc.createPlaylist(
                          title,
                          descCtrl.text.trim(),
                          [],
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Playlist "$title" creada')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'CREAR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Text(
                        'Nueva Lista Mixta',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),

                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          const SizedBox(height: 16),
                          // Form fields
                          TextField(
                            controller: titleCtrl,
                            decoration: InputDecoration(
                              labelText: 'Título',
                              prefixIcon: const Icon(Icons.title),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: descCtrl,
                            decoration: InputDecoration(
                              labelText: 'Descripción (Opcional)',
                              prefixIcon: const Icon(Icons.description),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.surfaceVariant.withOpacity(0.3),
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 8),

                          Text(
                            'Selecciona las playlists a combinar:',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (playlists.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No tienes otras playlists para mezclar.',
                                ),
                              ),
                            )
                          else
                            ...playlists.map((pl) {
                              final isSelected = selected.contains(pl.id);
                              return Card(
                                elevation: 0,
                                color: isSelected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.4)
                                    : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: CheckboxListTile(
                                  value: isSelected,
                                  activeColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true)
                                        selected.add(pl.id);
                                      else
                                        selected.remove(pl.id);
                                    });
                                  },
                                  title: Text(
                                    pl.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${pl.songIds.length} canciones',
                                  ),
                                  secondary: const Icon(Icons.queue_music),
                                ),
                              );
                            }),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),

                    // Bottom Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingresa un título'),
                                ),
                              );
                              return;
                            }
                            if (selected.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selecciona al menos una playlist',
                                  ),
                                ),
                              );
                              return;
                            }
                            await pc.createMixedPlaylist(
                              title,
                              descCtrl.text.trim(),
                              selected.toList(),
                            );
                            if (!mounted) return;
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Crear Lista Mixta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ).then((_) {
      // Logic to actually create if not handled inside (but Button is better inside)
      // Actually I'll put a FloatButton or BottomBar inside the Stack if I could, but here
      // I'll just use a button at the bottom of the column or a FAB overlaid.
      // Since `showModalBottomSheet` blocks, I can't overlay easily outside the builder unless I put it in the builder.
    });

    // Quick fix: Add the button INSIDE the builder. I'll re-do the builder content stack.
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistController>(
      builder: (context, pc, _) {
        if (pc.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            if (pc.playlists.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.library_music,
                      size: 72,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text('Sin playlists'),
                  ],
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
                itemCount: pc.playlists.length,
                itemBuilder: (context, index) {
                  final p = pc.playlists[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          image: p.imagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(p.imagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: p.imagePath == null
                            ? Icon(
                                p.isMixed
                                    ? Icons.all_inclusive
                                    : Icons.queue_music,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      title: Text(
                        p.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        p.isMixed
                            ? (p.description.isEmpty
                                  ? 'Lista mixta'
                                  : p.description)
                            : (p.description.isEmpty
                                  ? 'Sin descripción'
                                  : p.description),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${p.isMixed ? pc.aggregatedSongs(p).length : p.songIds.length} canciones',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      onTap: () => _showPlaylistSongs(context, p),
                      onLongPress: () => _showPlaylistContextMenu(context, p),
                    ),
                  );
                },
              ),
            Positioned(
              bottom: (context.watch<HomeController>().currentIndex != -1)
                  ? 90
                  : 24,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.playlist_add),
                            title: const Text('Nueva Playlist'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _openCreatePlaylistDialog(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.merge_type),
                            title: const Text('Nueva Lista Mixta'),
                            onTap: () {
                              Navigator.pop(ctx);
                              _openCreateMixedPlaylistFlow(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear'),
                elevation: 4,
              ),
            ),
            if (context.watch<HomeController>().currentIndex != -1)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: PlayerBar(),
              ),
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
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: EdgeInsets.zero,
                    children: [
                      // Header Section
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => SafeArea(
                                child: Wrap(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.photo_library),
                                      title: const Text('Cambiar foto'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final picker = ImagePicker();
                                        final picked = await picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        if (picked != null) {
                                          await pc.updatePlaylist(
                                            id: p.id,
                                            imagePath: picked.path,
                                          );
                                          // Force refresh or rebuild?
                                          if (context.mounted)
                                            Navigator.pop(
                                              context,
                                            ); // Close details to refresh easily or setState if possible
                                          // Actually re-opening might be jarring.
                                          // The view might not auto-refresh unless p is watched.
                                          // p is passed by value/reference but if the list in controller updates, this widget might not rebuild because it's in a modal builder using 'p' from closure.
                                          // Better to close details and let user re-open or implement a better reactive stream.
                                          // For simplicity, we just close the modal details to "refresh" or use stateful builder inside showModalBottomSheet.
                                          // But showModalBottomSheet uses `builder` which runs once.
                                          // Wait, DraggableScrollableSheet builder runs on scroll.
                                          // We should close the detail view to reflect changes safely or reload p.
                                          if (context.mounted) {
                                            _showPlaylistSongs(
                                              context,
                                              pc.playlists.firstWhere(
                                                (pl) => pl.id == p.id,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    if (p.imagePath != null)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        title: const Text(
                                          'Quitar foto',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          await pc.updatePlaylist(
                                            id: p.id,
                                            imagePath: null,
                                          ); // Remove image
                                          // Same refresh logic
                                          if (context.mounted)
                                            Navigator.pop(context);
                                          if (context.mounted) {
                                            _showPlaylistSongs(
                                              context,
                                              pc.playlists.firstWhere(
                                                (pl) => pl.id == p.id,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              image: p.imagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(p.imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: p.imagePath == null
                                ? Icon(
                                    p.isMixed
                                        ? Icons.all_inclusive
                                        : Icons.queue_music,
                                    size: 80,
                                    color: Theme.of(context).primaryColor,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        p.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (p.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 8,
                          ),
                          child: Text(
                            p.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Action Buttons Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Play Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final home = context.read<HomeController>();
                                  home.playSubset(
                                    songs,
                                    0,
                                    mixed: p.isMixed,
                                    mixedId: p.isMixed ? p.id : null,
                                    mixedTitle: p.isMixed ? p.title : null,
                                  );
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                ),
                                label: const Text('Reproducir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Shuffle Button
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final home = context.read<HomeController>();
                                  home.playSubset(
                                    songs,
                                    0, // Will be shuffled anyway usually or just start first then shuffle
                                    // Better logic might be needed for true shuffle start, but playSubset handles standard playback.
                                    // We can just play and toggle shuffle, or if playSubset supports it.
                                    // For now, let's just play.
                                    mixed: p.isMixed,
                                    mixedId: p.isMixed ? p.id : null,
                                    mixedTitle: p.isMixed ? p.title : null,
                                  );
                                  home.toggleShuffle(); // Toggle shuffle on
                                },
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('Aleatorio'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Meta info row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${songs.length} Canciones',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            // Edit/Menu Button
                            IconButton(
                              icon: const Icon(Icons.more_horiz),
                              onPressed: () {
                                // Re-using context menu logic, but maybe in a bottom sheet or simple menu
                                _showPlaylistContextMenu(context, p);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Songs List
                      if (songs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.music_off_rounded,
                                  size: 48,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Lista vacía',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...songs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final s = entry.value;
                          return ListTile(
                            leading: QueryArtworkWidget(
                              id: int.tryParse(s.id) ?? 0,
                              type: ArtworkType.AUDIO,
                              nullArtworkWidget: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.music_note,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            title: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              s.artist ?? 'Desconocido',
                              maxLines: 1,
                            ),
                            trailing: Consumer<HomeController>(
                              builder: (context, home, _) {
                                final isCurrent = home.currentSong?.id == s.id;
                                if (isCurrent) {
                                  return StreamBuilder<bool>(
                                    stream:
                                        home.audioService.player.playingStream,
                                    initialData:
                                        home.audioService.player.playing,
                                    builder: (context, snapshot) {
                                      final isPlaying = snapshot.data ?? false;
                                      return NowPlayingIndicator(
                                        isPlaying: isPlaying,
                                      );
                                    },
                                  );
                                }
                                return IconButton(
                                  icon: const Icon(Icons.play_circle_outline),
                                  onPressed: () {
                                    final home = context.read<HomeController>();
                                    home.playSubset(
                                      songs,
                                      idx,
                                      mixed: p.isMixed,
                                      mixedId: p.isMixed ? p.id : null,
                                      mixedTitle: p.isMixed ? p.title : null,
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        }),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
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
    // Copiamos la lista para no afectar la original mientras filtramos
    final allSongs = home.songs;
    // Set de IDs seleccionados (inicia con los que ya tiene la playlist)
    final selected = playlist.songIds.toSet();
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final q = searchCtrl.text.trim().toLowerCase();
          final filtered = q.isEmpty
              ? allSongs
              : allSongs.where((s) {
                  return s.title.toLowerCase().contains(q) ||
                      (s.artist ?? '').toLowerCase().contains(q);
                }).toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header con título y botón guardar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Agregar canciones',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${selected.length} seleccionadas',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await pc.updatePlaylist(
                                id: playlist.id,
                                songIds: selected.toList(),
                              );
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Playlist "${playlist.title}" actualizada',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              // Refresh viewed playlist if needed
                              // _showPlaylistSongs(context, ... ) logic handled by parent refresh usually
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Guardar'),
                          ),
                        ],
                      ),
                    ),

                    // Buscador
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar canciones...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    const Divider(),

                    // Lista de canciones
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No se encontraron canciones',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              padding: const EdgeInsets.only(bottom: 24),
                              itemBuilder: (context, index) {
                                final s = filtered[index];
                                final isSelected = selected.contains(s.id);
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: QueryArtworkWidget(
                                          id: int.tryParse(s.id) ?? 0,
                                          type: ArtworkType.AUDIO,
                                          size: 50,
                                          nullArtworkWidget: Container(
                                            width: 50,
                                            height: 50,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceVariant,
                                            child: const Icon(
                                              Icons.music_note,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Text(
                                    s.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    s.artist ?? 'Desconocido',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    activeColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          selected.add(s.id);
                                        } else {
                                          selected.remove(s.id);
                                        }
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selected.remove(s.id);
                                      } else {
                                        selected.add(s.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
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

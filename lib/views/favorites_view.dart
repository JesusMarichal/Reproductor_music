import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final favs = controller.favorites;
    final favoriteSongs = controller.songs
        .where((s) => s.id.isNotEmpty && favs.contains(s.id))
        .toList();

    if (favoriteSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_border, size: 72, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay favoritos', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: favoriteSongs.length,
      itemBuilder: (context, index) {
        final song = favoriteSongs[index];
        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artist ?? 'Desconocido', maxLines: 1),
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            onPressed: () async {
              await controller.toggleFavoriteById(song.id);
            },
          ),
          onTap: () async {
            // Reproducir esta canción desde la lista principal
            final idx = controller.songs.indexWhere((s) => s.id == song.id);
            if (idx != -1) {
              await controller.playAt(idx);
            }
          },
        );
      },
    );
  }
}

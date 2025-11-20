import 'package:flutter/material.dart';
import 'package:reproductor_music/controllers/video_controller.dart';

class VideoSearchDelegate extends SearchDelegate<VideoItem?> {
  final VideoController controller;
  VideoSearchDelegate(this.controller);

  @override
  String? get searchFieldLabel => 'Buscar en YouTube';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      // Sugerir destacados
      return ListView.builder(
        itemCount: VideoController.featured.length,
        itemBuilder: (_, i) {
          final v = VideoController.featured[i];
          return ListTile(
            leading: Image.network(v.thumbUrl, width: 72, fit: BoxFit.cover),
            title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => close(context, v),
          );
        },
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return FutureBuilder(
      future: controller.search(query, take: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? const <VideoItem>[];
        if (list.isEmpty) {
          return const Center(child: Text('Sin resultados'));
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final v = list[i];
            return ListTile(
              leading: Image.network(v.thumbUrl, width: 72, fit: BoxFit.cover),
              title: Text(
                v.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: v.channel != null ? Text(v.channel!) : null,
              onTap: () => close(context, v),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class PlaylistsView extends StatelessWidget {
  const PlaylistsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.library_music, size: 72, color: Colors.blueAccent),
          SizedBox(height: 12),
          Text('Listas', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

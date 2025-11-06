import 'package:flutter/material.dart';

class FavoritesView extends StatelessWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.favorite, size: 72, color: Colors.redAccent),
          SizedBox(height: 12),
          Text('Favoritos', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

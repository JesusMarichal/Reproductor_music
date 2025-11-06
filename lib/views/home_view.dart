import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../widgets/player_bar.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Cargar canciones la primera vez usando el HomeController proporcionado por Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<HomeController>();
      controller.loadSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: controller.songs.length,
            itemBuilder: (context, index) {
              final song = controller.songs[index];
              return ListTile(
                title: Text(song.title),
                subtitle: Text(song.artist ?? song.id),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await controller.playSong(song);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Reproduciendo: ${song.title}')),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const PlayerBar(),
      ],
    );
  }
}

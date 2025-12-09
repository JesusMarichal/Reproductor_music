import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/home_controller.dart';
import '../views/player_view.dart';
import 'scrolling_text.dart';

class PlayerBar extends StatefulWidget {
  const PlayerBar({super.key});

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  late AudioPlayer _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<HomeController>();
    _player = controller.audioService.player;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeController>();
    final song = controller.currentSong;
    if (song == null) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                final home = context.read<HomeController>();
                // Usar la bandera estática del PlayerView como guardia más fiable
                if (PlayerView.isOpen || home.playerViewOpen)
                  return; // ya abierto
                home.playerViewOpen = true;
                Navigator.of(context).push(buildPlayerRoute()).then((_) {
                  home.playerViewOpen = false;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScrollingText(
                    text: song.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(song.artist ?? '', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: () {
                      final ctrl = context.read<HomeController>();
                      ctrl.previous();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                    ),
                    iconSize: 36,
                    onPressed: () {
                      final ctrl = context.read<HomeController>();
                      ctrl.togglePlayPause();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: () {
                      final ctrl = context.read<HomeController>();
                      ctrl.next();
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

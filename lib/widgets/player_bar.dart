import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/home_controller.dart';

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

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(song.artist ?? '', style: const TextStyle(fontSize: 12)),
                // Progress
                StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, snapshotDuration) {
                    final duration = snapshotDuration.data ?? Duration.zero;
                    return StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, snapshotPosition) {
                        final position = snapshotPosition.data ?? Duration.zero;
                        final max = duration > Duration.zero
                            ? duration.inMilliseconds.toDouble()
                            : 1.0;
                        final value = position.inMilliseconds.toDouble().clamp(
                          0.0,
                          max,
                        );
                        return Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: value,
                                max: max,
                                onChanged: (v) {
                                  _player.seek(
                                    Duration(milliseconds: v.toInt()),
                                  );
                                },
                              ),
                            ),
                            Text(
                              '${_formatDuration(position)}/${_formatDuration(duration)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
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
                      // placeholder: no prev handling yet
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                    ),
                    iconSize: 36,
                    onPressed: () {
                      if (playing) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: () => _player.stop(),
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

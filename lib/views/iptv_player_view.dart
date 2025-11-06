import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../services/video_service.dart';

class IptvPlayerView extends StatefulWidget {
  final String url;
  const IptvPlayerView({super.key, required this.url});

  @override
  State<IptvPlayerView> createState() => _IptvPlayerViewState();
}

class _IptvPlayerViewState extends State<IptvPlayerView> {
  final VideoService _videoService = VideoService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _videoService.init(widget.url);
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _videoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoService.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Reproduciendo canal')),
      body: Center(
        child: _initialized && controller != null
            ? Column(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: VlcPlayer(
                      controller: controller,
                      aspectRatio: 16 / 9,
                      placeholder: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => controller.play(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.pause),
                        onPressed: () => controller.pause(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.stop),
                        onPressed: () => controller.stop(),
                      ),
                    ],
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

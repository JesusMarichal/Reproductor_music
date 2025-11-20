import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/video_controller.dart';

class MiniVideoBar extends StatelessWidget {
  final VoidCallback onOpenVideos;
  final VoidCallback? onClose;
  const MiniVideoBar({super.key, required this.onOpenVideos, this.onClose});

  @override
  Widget build(BuildContext context) {
    final vc = context.watch<VideoController>();
    // Mostrar sólo si hay video en reproducción
    final active = vc.currentId != null && vc.isPlaying;
    // Si no hay video activo, no renderizar nada para evitar franjas/espacio.
    if (!active) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            // Usamos un contenedor de superficie neutro para evitar tonos fuertes.
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://img.youtube.com/vi/${vc.currentId}/default.jpg',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.black12,
                    child: const Icon(Icons.ondemand_video),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onOpenVideos,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vc.currentTitle ?? 'Reproduciendo…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'YouTube',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  vc.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                ),
                iconSize: 34,
                onPressed: () {
                  if (vc.isPlaying) {
                    vc.pause();
                  } else {
                    vc.play();
                  }
                },
              ),
              if (onClose != null)
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

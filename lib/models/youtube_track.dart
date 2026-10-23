/// Un vídeo musical encontrado en YouTube.
class YouTubeTrack {
  const YouTubeTrack({
    required this.videoId,
    required this.title,
    required this.channel,
    required this.thumbnailUrl,
    this.duration,
  });

  final String videoId;
  final String title;

  /// Canal ya limpio de sufijos como "VEVO" o " - Topic".
  final String channel;

  /// Miniatura 16:9 sin franjas negras (la "medium" de la API).
  final String thumbnailUrl;
  final Duration? duration;

  YouTubeTrack withDuration(Duration? value) => YouTubeTrack(
    videoId: videoId,
    title: title,
    channel: channel,
    thumbnailUrl: thumbnailUrl,
    duration: value,
  );
}

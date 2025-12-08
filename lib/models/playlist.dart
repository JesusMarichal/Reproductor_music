enum PlaylistType { normal, mixed }

class Playlist {
  final String id;
  final String title;
  final String description;
  final List<String> songIds;
  final PlaylistType type;
  final List<String> childPlaylistIds;

  /// Canciones excluidas solo para listas mixtas. Permite "quitar" una canción
  /// de la vista combinada sin eliminarla de sus listas originales.
  final List<String> excludedSongIds;
  final String? imagePath;

  const Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.songIds,
    this.type = PlaylistType.normal,
    this.childPlaylistIds = const [],
    this.excludedSongIds = const [],
    this.imagePath,
  });

  bool get isMixed => type == PlaylistType.mixed;

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? songIds,
    PlaylistType? type,
    List<String>? childPlaylistIds,
    List<String>? excludedSongIds,
    String? imagePath,
  }) => Playlist(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    songIds: songIds ?? this.songIds,
    type: type ?? this.type,
    childPlaylistIds: childPlaylistIds ?? this.childPlaylistIds,
    excludedSongIds: excludedSongIds ?? this.excludedSongIds,
    imagePath: imagePath ?? this.imagePath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'songIds': songIds,
    'type': type.name,
    'childPlaylistIds': childPlaylistIds,
    'excludedSongIds': excludedSongIds,
    'imagePath': imagePath,
  };

  static Playlist fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'normal';
    final parsedType = typeStr == 'mixed'
        ? PlaylistType.mixed
        : PlaylistType.normal;
    return Playlist(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      songIds: (json['songIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      type: parsedType,
      childPlaylistIds: (json['childPlaylistIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      excludedSongIds: (json['excludedSongIds'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      imagePath: json['imagePath'] as String?,
    );
  }
}

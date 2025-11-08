class Playlist {
  final String id;
  final String title;
  final String description;
  final List<String> songIds;

  Playlist({
    required this.id,
    required this.title,
    required this.description,
    required this.songIds,
  });

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? songIds,
  }) => Playlist(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    songIds: songIds ?? this.songIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'songIds': songIds,
  };

  static Playlist fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    songIds: (json['songIds'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}

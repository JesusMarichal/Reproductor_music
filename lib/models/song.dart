import 'base_model.dart';

class Song extends BaseModel {
  final String id;
  final String title;
  final String? uri;
  final String? artist;
  final int? duration;
  final String? album;
  final int? albumId;
  final String? artworkUrl;

  Song({
    required this.id,
    required this.title,
    this.uri,
    this.artist,
    this.duration,
    this.album,
    this.albumId,
    this.artworkUrl,
  });

  Song copyWith({
    String? id,
    String? title,
    String? uri,
    String? artist,
    int? duration,
    String? album,
    int? albumId,
    String? artworkUrl,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      uri: uri ?? this.uri,
      artist: artist ?? this.artist,
      duration: duration ?? this.duration,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }

  @override
  String toString() =>
      'Song(id: $id, title: $title, uri: $uri, art: $artworkUrl)';
}

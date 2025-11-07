import 'base_model.dart';

class Song extends BaseModel {
  final String id;
  final String title;
  final String? uri;
  final String? artist;
  final int? duration;
  final String? album;
  final int? albumId;

  Song({
    required this.id,
    required this.title,
    this.uri,
    this.artist,
    this.duration,
    this.album,
    this.albumId,
  });

  @override
  String toString() => 'Song(id: $id, title: $title, uri: $uri)';
}

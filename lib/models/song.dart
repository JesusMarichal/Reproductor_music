import 'base_model.dart';

class Song extends BaseModel {
  final String id;
  final String title;
  final String? uri;
  final String? artist;
  final int? duration;

  Song({
    required this.id,
    required this.title,
    this.uri,
    this.artist,
    this.duration,
  });

  @override
  String toString() => 'Song(id: $id, title: $title, uri: $uri)';
}

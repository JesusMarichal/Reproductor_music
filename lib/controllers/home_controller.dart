import '../models/song.dart';
import 'base_controller.dart';
import '../repositories/music_repository.dart';
import '../services/audio_service.dart';

class HomeController extends BaseController {
  List<Song> songs = [];
  Song? currentSong;

  /// Carga inicial de canciones. Notifica a los listeners para que la UI
  /// pueda actualizarse sin reconstruir widgets enteros innecesariamente.
  final MusicRepository _repo = MusicRepository();
  final AudioService audioService = AudioService();

  Future<void> loadSongs() async {
    songs = await _repo.fetchAll();
    notifyListeners();
  }

  Future<void> playSong(Song song) async {
    if (song.uri == null) return;
    currentSong = song;
    notifyListeners();
    await audioService.playUri(song.uri!);
  }

  @override
  void dispose() {
    audioService.dispose();
    super.dispose();
  }
}

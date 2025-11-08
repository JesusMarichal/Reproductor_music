import 'package:shared_preferences/shared_preferences.dart';

class FavoritesRepository {
  static const _key = 'favorites_song_ids';

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? <String>[];
    return list.toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }

  Future<void> toggleFavorite(String id) async {
    final favs = await loadFavorites();
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    await saveFavorites(favs);
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos del perfil local: nombre y foto.
///
/// No hay cuenta ni servidor: todo vive en el dispositivo, así que basta con
/// SharedPreferences y una ruta de fichero para el avatar.
class ProfileController extends ChangeNotifier {
  static const _nameKey = 'profile_name';
  static const _avatarKey = 'profile_avatar_path';

  String _name = '';
  String? _avatarPath;
  bool _loaded = false;

  /// Nombre elegido por la persona, o vacío si aún no lo ha puesto.
  String get name => _name;

  /// Nombre a mostrar, con un valor por defecto razonable.
  String get displayName => _name.isEmpty ? 'Tu perfil' : _name;

  /// Iniciales para el avatar cuando no hay foto.
  String get initials {
    final parts = _name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '♪';
    if (parts.length == 1) return _firstLetter(parts.first);
    return _firstLetter(parts.first) + _firstLetter(parts.last);
  }

  /// Primer carácter completo de una palabra. Usa runas para no partir por la
  /// mitad un carácter fuera del plano básico (emoji, por ejemplo).
  static String _firstLetter(String word) =>
      String.fromCharCode(word.runes.first).toUpperCase();

  /// Fichero del avatar, o `null` si no hay foto o se ha borrado del disco.
  File? get avatarFile {
    final path = _avatarPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_nameKey) ?? '';
    _avatarPath = prefs.getString(_avatarKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    if (trimmed == _name) return;
    _name = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, trimmed);
  }

  Future<void> setAvatarPath(String? path) async {
    if (path == _avatarPath) return;
    _avatarPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_avatarKey);
    } else {
      await prefs.setString(_avatarKey, path);
    }
  }
}

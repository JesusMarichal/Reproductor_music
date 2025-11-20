import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Controlador para preferencias de video: calidad y restricciones de red.
class VideoSettingsController extends ChangeNotifier {
  static const _kQualityKey = 'video_quality_pref';
  static const _kWifiOnlyKey = 'video_wifi_only_pref';
  static const _kCaptionsKey = 'video_captions_enabled_pref';

  /// Calidades soportadas (representación textual para UI), YouTube adapta bitrate.
  /// NOTA: youtube_player_flutter no expone API directa para forzar calidad;
  /// se deja para futura extensión usando IFrame JS o web view.
  static const supportedQualities = <String>[
    'Auto',
    '360p',
    '480p',
    '720p',
    '1080p',
  ];

  String _preferredQuality = 'Auto';
  bool _wifiOnly = false;
  bool _captionsEnabled = true;

  String get preferredQuality => _preferredQuality;
  bool get wifiOnly => _wifiOnly;
  bool get captionsEnabled => _captionsEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _preferredQuality = prefs.getString(_kQualityKey) ?? 'Auto';
    _wifiOnly = prefs.getBool(_kWifiOnlyKey) ?? false;
    if (!supportedQualities.contains(_preferredQuality)) {
      _preferredQuality = 'Auto';
    }
    _captionsEnabled = prefs.getBool(_kCaptionsKey) ?? true;
    notifyListeners();
  }

  Future<void> setPreferredQuality(String q) async {
    if (!supportedQualities.contains(q)) return;
    _preferredQuality = q;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQualityKey, q);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool v) async {
    _wifiOnly = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWifiOnlyKey, v);
    notifyListeners();
  }

  Future<void> setCaptionsEnabled(bool v) async {
    _captionsEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kCaptionsKey, v);
    notifyListeners();
  }

  /// Verifica si se puede reproducir considerando la restricción wifi-only.
  Future<bool> canStream() async {
    if (!_wifiOnly) return true; // No hay restricción
    final result = await Connectivity().checkConnectivity();
    // Si hay al menos wifi (o ethernet) permitimos. Datos móviles se bloquean.
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }
}

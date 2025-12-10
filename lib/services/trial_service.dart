import 'package:shared_preferences/shared_preferences.dart';

class TrialService {
  static const _installTsKey = 'trial_install_ts_v1';
  static const _expiredKey = 'trial_expired_v1';
  static const _unlimitedKey = 'trial_unlimited_v1';
  static const _activatedKey = 'trial_activated_v1';
  // Duración de la fase de prueba en producción: 2 días.
  static const Duration trialDuration = Duration(days: 7);

  Future<DateTime> _now() async => DateTime.now();

  Future<DateTime?> getInstallTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_installTsKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> isUnlimited() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_unlimitedKey) ?? false;
  }

  Future<DateTime?> getExpiryTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_unlimitedKey) == true) return null;
    final install = await getInstallTimestamp();
    if (install == null) return null;
    return install.add(trialDuration);
  }

  Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    // Activado si hay flag de activación o si es ilimitado.
    if (prefs.getBool(_unlimitedKey) == true) return true;
    return prefs.getBool(_activatedKey) == true;
  }

  Future<bool> isExpired() async {
    final prefs = await SharedPreferences.getInstance();
    // Si es ilimitado, nunca expira.
    if (prefs.getBool(_unlimitedKey) == true) return false;
    if (prefs.getBool(_expiredKey) == true) return true;
    final install = await getInstallTimestamp();
    if (install == null) return false; // No activado limitado correctamente.
    final now = await _now();
    final expired = now.isAfter(install.add(trialDuration));
    if (expired) {
      await prefs.setBool(_expiredKey, true);
    }
    return expired;
  }

  Future<void> activateLimitedNow() async {
    final prefs = await SharedPreferences.getInstance();
    final now = await _now();
    await prefs.setInt(_installTsKey, now.millisecondsSinceEpoch);
    await prefs.setBool(_expiredKey, false);
    await prefs.setBool(_unlimitedKey, false);
    await prefs.setBool(_activatedKey, true);
  }

  Future<void> activateUnlimited() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unlimitedKey, true);
    await prefs.setBool(_expiredKey, false);
    await prefs.setBool(_activatedKey, true);
  }

  Future<void> forceExpire() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expiredKey, true);
  }

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
  }
}

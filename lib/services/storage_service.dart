import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] for StudentHold persistence.
class StorageService {
  static const _keyOnboarded = 'isOnboarded';
  static const _keyUserName = 'userName';
  static const _keyUserEmail = 'userEmail';
  static const _keyVaultPin = 'vaultPin';

  // ── Onboarding & Profile ──────────────────────────────────────────────────

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboarded) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboarded, value);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> getVaultPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVaultPin);
  }

  Future<void> saveProfile({
    required String name,
    required String email,
    required String pin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyVaultPin, pin);
    await prefs.setBool(_keyOnboarded, true);
  }

  // ── Generic List Storage ──────────────────────────────────────────────────

  Future<List<String>?> getStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  Future<void> setStringList(String key, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, list);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

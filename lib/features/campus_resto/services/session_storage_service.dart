import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_cookies.dart';

/// Secure persistence wrapper for university portal session cookies.
///
/// Uses [FlutterSecureStorage] by default on mobile platforms (Keychain/Keystore),
/// with seamless automatic fallback to [SharedPreferences] when secure storage
/// is unavailable (e.g. unit tests, emulators, or desktop platforms).
class SessionStorageService {
  static const String keyRestoCookie = 'resto_cookie';
  static const String keyPhpSessId = 'resto_u_phpsessid';
  static const String keyCookieSession1 = 'resto_u_cookiesession1';
  static const String keyRawCookieHeader = 'resto_u_raw_cookie_header';
  static const String keyLastChecked = 'resto_u_session_last_checked';

  final FlutterSecureStorage? _secureStorage;
  final SharedPreferences? _prefs;

  bool _useFallback = false;

  SessionStorageService({
    FlutterSecureStorage? secureStorage,
    SharedPreferences? prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  // ── Internal Storage Abstraction with Fallback ────────────────────────────

  Future<void> _write(String key, String value) async {
    if (_secureStorage != null && !_useFallback) {
      try {
        await _secureStorage.write(key: key, value: value);
        return;
      } on MissingPluginException {
        _useFallback = true;
      } on PlatformException {
        _useFallback = true;
      } catch (_) {
        _useFallback = true;
      }
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _read(String key) async {
    if (_secureStorage != null && !_useFallback) {
      try {
        final val = await _secureStorage.read(key: key);
        if (val != null) return val;
      } on MissingPluginException {
        _useFallback = true;
      } on PlatformException {
        _useFallback = true;
      } catch (_) {
        _useFallback = true;
      }
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _delete(String key) async {
    if (_secureStorage != null) {
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}
    }
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Securely saves session cookies.
  /// Throws [ArgumentError] if [phpSessId] is empty or whitespace.
  Future<void> saveSession({
    required String phpSessId,
    String? cookieSession1,
    String? rawCookieHeader,
  }) async {
    final cleanPhp = phpSessId.trim();
    if (cleanPhp.isEmpty) {
      throw ArgumentError('PHPSESSID cannot be empty');
    }

    await _write(keyPhpSessId, cleanPhp);

    if (cookieSession1 != null && cookieSession1.trim().isNotEmpty) {
      await _write(keyCookieSession1, cookieSession1.trim());
    } else {
      await _delete(keyCookieSession1);
    }

    if (rawCookieHeader != null && rawCookieHeader.trim().isNotEmpty) {
      await _write(keyRawCookieHeader, rawCookieHeader.trim());
      await _write(keyRestoCookie, rawCookieHeader.trim());
    } else {
      final constructed =
          'PHPSESSID=$cleanPhp${cookieSession1 != null ? '; cookiesession1=${cookieSession1.trim()}' : ''}';
      await _write(keyRawCookieHeader, constructed);
      await _write(keyRestoCookie, constructed);
    }

    await _write(keyLastChecked, DateTime.now().toIso8601String());
  }

  /// Securely saves the serialized HTTP Cookie header under key 'resto_cookie'.
  Future<void> saveRestoCookie(String rawCookieHeader) async {
    final clean = rawCookieHeader.trim();
    if (clean.isEmpty) return;

    await _write(keyRestoCookie, clean);
    await _write(keyRawCookieHeader, clean);

    final phpSessId = _extractCookie(clean, 'PHPSESSID');
    if (phpSessId != null && phpSessId.isNotEmpty) {
      await _write(keyPhpSessId, phpSessId);
    }

    final cookieSession1 = _extractCookie(clean, 'cookiesession1');
    if (cookieSession1 != null && cookieSession1.isNotEmpty) {
      await _write(keyCookieSession1, cookieSession1);
    }

    await _write(keyLastChecked, DateTime.now().toIso8601String());
  }

  /// Parses and saves session cookies directly from a raw cookie header string.
  Future<void> saveFromCookieHeader(String rawCookieHeader) async {
    final phpSessId = _extractCookie(rawCookieHeader, 'PHPSESSID');
    if (phpSessId == null || phpSessId.isEmpty) {
      throw ArgumentError('No valid PHPSESSID found in cookie string');
    }
    final cookieSession1 = _extractCookie(rawCookieHeader, 'cookiesession1');
    await saveSession(
      phpSessId: phpSessId,
      cookieSession1: cookieSession1,
      rawCookieHeader: rawCookieHeader,
    );
  }

  /// Loads the persisted session cookies. Returns `null` if no valid session exists.
  Future<SessionCookies?> getSession() async {
    final phpSessId = await _read(keyPhpSessId);
    final rawHeader =
        await _read(keyRestoCookie) ?? await _read(keyRawCookieHeader);

    if ((phpSessId == null || phpSessId.trim().isEmpty) &&
        (rawHeader == null || rawHeader.trim().isEmpty)) {
      return null;
    }

    final effectivePhp = (phpSessId != null && phpSessId.trim().isNotEmpty)
        ? phpSessId.trim()
        : (_extractCookie(rawHeader ?? '', 'PHPSESSID') ?? 'session_active');

    final cookieSession1 = await _read(keyCookieSession1) ??
        (rawHeader != null
            ? _extractCookie(rawHeader, 'cookiesession1')
            : null);
    final lastCheckedRaw = await _read(keyLastChecked);

    DateTime? lastChecked;
    if (lastCheckedRaw != null) {
      lastChecked = DateTime.tryParse(lastCheckedRaw);
    }

    return SessionCookies(
      phpSessId: effectivePhp,
      cookieSession1: cookieSession1?.trim(),
      rawCookieHeader: rawHeader,
      lastChecked: lastChecked,
    );
  }

  /// Loads the persisted 'resto_cookie' string from secure storage.
  Future<String?> getRestoCookie() async {
    final cookie = await _read(keyRestoCookie);
    if (cookie != null && cookie.trim().isNotEmpty) {
      return cookie.trim();
    }
    return await getCookieHeader();
  }

  /// Convenience getter returning the formatted HTTP `Cookie` header string,
  /// or `null` if no active session is stored.
  Future<String?> getCookieHeader() async {
    final session = await getSession();
    if (session != null && session.isValid) {
      return session.toCookieHeader();
    }
    final restoCookie = await _read(keyRestoCookie);
    if (restoCookie != null && restoCookie.trim().isNotEmpty) {
      return restoCookie.trim();
    }
    return null;
  }

  /// Checks if a session is currently stored.
  Future<bool> hasSession() async {
    final restoCookie = await _read(keyRestoCookie);
    if (restoCookie != null && restoCookie.trim().isNotEmpty) {
      return true;
    }
    final phpSessId = await _read(keyPhpSessId);
    return phpSessId != null && phpSessId.trim().isNotEmpty;
  }

  /// Updates the timestamp of the last successful session check.
  Future<void> updateLastChecked(DateTime timestamp) async {
    await _write(keyLastChecked, timestamp.toIso8601String());
  }

  /// Retrieves the timestamp of the last successful session check.
  Future<DateTime?> getLastChecked() async {
    final raw = await _read(keyLastChecked);
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  /// Completely purges all stored session cookies and metadata from both
  /// secure storage and SharedPreferences fallback.
  Future<void> clearSession() async {
    await _delete(keyRestoCookie);
    await _delete(keyPhpSessId);
    await _delete(keyCookieSession1);
    await _delete(keyRawCookieHeader);
    await _delete(keyLastChecked);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _extractCookie(String raw, String name) {
    final pattern = RegExp('(?:^|;\\s*)${RegExp.escape(name)}=([^;]*)');
    final match = pattern.firstMatch(raw);
    return match?.group(1)?.trim();
  }
}

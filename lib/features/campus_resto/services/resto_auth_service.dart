import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/session_cookies.dart';
import 'session_storage_service.dart';

/// Status classification of a session validation attempt.
enum SessionStatus {
  valid,
  expired,
  networkError,
  serverError,
}

/// Structured outcome of a session heartbeat check against `/admin/api/check-session.php`.
class SessionCheckResult {
  final SessionStatus status;
  final String? message;
  final DateTime timestamp;

  const SessionCheckResult({
    required this.status,
    this.message,
    required this.timestamp,
  });

  bool get isValid => status == SessionStatus.valid;
  bool get isExpired => status == SessionStatus.expired;
  bool get isNetworkError => status == SessionStatus.networkError;
  bool get isServerError => status == SessionStatus.serverError;

  factory SessionCheckResult.valid() => SessionCheckResult(
        status: SessionStatus.valid,
        message: 'Session is active and valid',
        timestamp: DateTime.now(),
      );

  factory SessionCheckResult.expired([String? message]) => SessionCheckResult(
        status: SessionStatus.expired,
        message: message ?? 'Session expired',
        timestamp: DateTime.now(),
      );

  factory SessionCheckResult.networkError(String message) => SessionCheckResult(
        status: SessionStatus.networkError,
        message: message,
        timestamp: DateTime.now(),
      );

  factory SessionCheckResult.serverError(String message) => SessionCheckResult(
        status: SessionStatus.serverError,
        message: message,
        timestamp: DateTime.now(),
      );
}

/// Handles authentication lifecycle, session heartbeats, and logout operations
/// against the university portal (https://cukl.ooun.rnu.tn/).
class RestoAuthService {
  static const String defaultBaseUrl = 'https://cukl.ooun.rnu.tn';
  static const String checkSessionPath = '/admin/api/check-session.php';
  static const String disconnectPath = '/?p=users.disconnect';
  static const String loginPath = '/?p=users.login';
  static const String dashboardPath = '/?p=etd.posts.index';

  final http.Client _client;
  final SessionStorageService _sessionStorage;
  final String _baseUrl;
  final Duration _timeout;

  RestoAuthService({
    http.Client? client,
    required SessionStorageService sessionStorage,
    String baseUrl = defaultBaseUrl,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _sessionStorage = sessionStorage,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout;

  // ── Session Heartbeat Check ───────────────────────────────────────────────

  /// Probes `GET /admin/api/check-session.php` to verify session liveness.
  ///
  /// - Returns [SessionStatus.valid] if server responds with `{"session":"valid"}`.
  /// - Returns [SessionStatus.expired] if server responds with `{"session":"expired"}` or 302 redirect.
  /// - Returns [SessionStatus.networkError] on timeout or connection loss (DOES NOT clear session).
  /// - Returns [SessionStatus.serverError] on HTTP 5xx responses.
  Future<SessionCheckResult> checkSession(
      {String? cookieHeaderOverride}) async {
    final cookieHeader =
        cookieHeaderOverride ?? await _sessionStorage.getCookieHeader();

    if (cookieHeader == null || !cookieHeader.contains('PHPSESSID=')) {
      return SessionCheckResult.expired('No session cookie stored');
    }

    final uri = Uri.parse('$_baseUrl$checkSessionPath');
    final headers = {
      'Cookie': cookieHeader,
      'Accept': 'application/json, text/plain, */*',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };

    try {
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);

      // Handle HTTP redirects (e.g. 302 -> /?p=users.login)
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'] ?? '';
        if (location.contains('users.login')) {
          return SessionCheckResult.expired('Redirected to login page');
        }
      }

      if (response.statusCode == 200) {
        try {
          final dynamic data = jsonDecode(response.body);
          if (data is Map && data['session'] == 'valid') {
            await _sessionStorage.updateLastChecked(DateTime.now());
            return SessionCheckResult.valid();
          } else if (data is Map && data['session'] == 'expired') {
            return SessionCheckResult.expired(
                'Server returned expired session');
          }
        } catch (_) {
          // If body is HTML containing login indicators
          if (response.body.contains('users.login') ||
              response.body.contains('expired')) {
            return SessionCheckResult.expired(
                'Session expired (HTML response)');
          }
        }
        return SessionCheckResult.serverError(
            'Unexpected response body: ${response.body}');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        return SessionCheckResult.expired(
            'HTTP ${response.statusCode} Unauthorized');
      }

      if (response.statusCode >= 500) {
        return SessionCheckResult.serverError(
            'HTTP ${response.statusCode} Server Error');
      }

      return SessionCheckResult.serverError(
          'Unexpected HTTP status ${response.statusCode}');
    } on TimeoutException {
      return SessionCheckResult.networkError('Session check timed out');
    } on SocketException catch (e) {
      return SessionCheckResult.networkError(
          'Network unavailable: ${e.message}');
    } on http.ClientException catch (e) {
      return SessionCheckResult.networkError('Client error: ${e.message}');
    } catch (e) {
      return SessionCheckResult.networkError('Session check failed: $e');
    }
  }

  // ── Logout & Server Disconnect ────────────────────────────────────────────

  /// Logs out the student: sends `POST /?p=users.disconnect` to the server
  /// and unconditionally wipes local storage via [SessionStorageService.clearSession].
  Future<bool> disconnect({String? cookieHeaderOverride}) async {
    final cookieHeader =
        cookieHeaderOverride ?? await _sessionStorage.getCookieHeader();

    final uri = Uri.parse('$_baseUrl$disconnectPath');
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      if (cookieHeader != null && cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
    };

    try {
      await _client
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Network failure during disconnect is gracefully tolerated;
      // client-side purge must happen regardless.
    } finally {
      await _sessionStorage.clearSession();
    }

    return true;
  }

  // ── Static Cookie Utilities ───────────────────────────────────────────────

  /// Formats cookie components into standard HTTP Cookie header string.
  static String formatCookieHeader({
    required String phpSessId,
    String? cookieSession1,
  }) {
    final parts = <String>['PHPSESSID=${phpSessId.trim()}'];
    if (cookieSession1 != null && cookieSession1.trim().isNotEmpty) {
      parts.add('cookiesession1=${cookieSession1.trim()}');
    }
    return parts.join('; ');
  }

  /// Parses cookie key-value pairs from a Cookie or raw header string.
  static Map<String, String> parseCookieHeader(String? rawHeader) {
    final map = <String, String>{};
    if (rawHeader == null || rawHeader.trim().isEmpty) return map;

    final pairs = rawHeader.split(';');
    for (final pair in pairs) {
      final trimmed = pair.trim();
      if (trimmed.isEmpty) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex > 0) {
        final key = trimmed.substring(0, eqIndex).trim();
        final value = trimmed.substring(eqIndex + 1).trim();
        map[key] = value;
      }
    }
    return map;
  }

  /// Extracts a specific named cookie from a raw header string.
  static String? extractCookie(String? rawHeader, String cookieName) {
    if (rawHeader == null) return null;
    final map = parseCookieHeader(rawHeader);
    return map[cookieName];
  }

  /// Extracts a [SessionCookies] model from raw cookie header text.
  static SessionCookies? parseCookies(String? rawHeader) {
    if (rawHeader == null) return null;
    final map = parseCookieHeader(rawHeader);
    final php = map['PHPSESSID'];
    if (php == null || php.isEmpty) return null;

    return SessionCookies(
      phpSessId: php,
      cookieSession1: map['cookiesession1'],
      rawCookieHeader: rawHeader,
    );
  }

  /// Extracts a [SessionCookies] model from a list of HTTP `Set-Cookie` response headers.
  static SessionCookies? parseSetCookieHeaders(List<String> setCookieHeaders) {
    String? php;
    String? session1;

    for (final header in setCookieHeaders) {
      final map = parseCookieHeader(header);
      if (map.containsKey('PHPSESSID')) {
        php = map['PHPSESSID'];
      }
      if (map.containsKey('cookiesession1')) {
        session1 = map['cookiesession1'];
      }
    }

    if (php == null || php.isEmpty) return null;

    return SessionCookies(
      phpSessId: php,
      cookieSession1: session1,
      rawCookieHeader: setCookieHeaders.join('; '),
    );
  }
}

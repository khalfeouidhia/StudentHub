import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'resto_auth_service.dart';

/// Dual-Engine Request Bridge for the university portal (https://cukl.ooun.rnu.tn/).
///
/// Combines:
/// 1. Primary Engine: Authenticated WebView JS Bridge (executing in the live browser
///    context where `HttpOnly` `PHPSESSID` cookies are automatically attached by the OS).
/// 2. Secondary Engine: Native [Dio] client for background requests, desktop/PC testing,
///    and headless cookie header synchronization.
class CampusRestoService {
  static final CampusRestoService instance = CampusRestoService();

  static const String defaultBaseUrl = 'https://cukl.ooun.rnu.tn';
  static const String dashboardPath = '/?p=etd.posts.index';
  static const String mealDetailsPath = '/?p=etd.posts.index';
  static const String reservationPath = '/?p=etd.posts.res';
  static const String checkSessionPath = '/admin/api/check-session.php';
  static const String disconnectPath = '/?p=users.disconnect';

  final Dio _dio;
  final String _baseUrl;
  final Duration _timeout;

  String? lastExtractedHtml;
  WebViewController? _activeWebViewController;
  final Map<String, Completer<String>> _pendingBridgeRequests = {};

  Duration get timeout => _timeout;

  CampusRestoService({
    Dio? dio,
    String baseUrl = defaultBaseUrl,
    Duration timeout = const Duration(seconds: 12),
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl.endsWith('/')
                    ? baseUrl.substring(0, baseUrl.length - 1)
                    : baseUrl,
                connectTimeout: timeout,
                receiveTimeout: timeout,
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Accept-Language': 'fr-FR,fr;q=0.9,ar;q=0.8,en;q=0.7',
                },
                followRedirects: false,
                validateStatus: (status) => status != null && status < 500,
              ),
            ) {
    if (!kIsWeb) {
      try {
        if (_dio.httpClientAdapter is IOHttpClientAdapter) {
          (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient =
              () {
            final client = HttpClient();
            client.badCertificateCallback = (cert, host, port) =>
                host.contains('ooun.rnu.tn') || host.contains('rnu.tn');
            return client;
          };
        }
      } catch (_) {}
    }
  }

  // ── Platform Safety Guards ────────────────────────────────────────────────

  /// Returns true only on platforms where webview_flutter has a native implementation (Android/iOS).
  static bool get isWebViewSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Safe check ensuring [WebViewPlatform.instance] is initialized before invoking any WebView API.
  static bool get canCreateWebView {
    if (!isWebViewSupported) return false;
    try {
      return WebViewPlatform.instance != null;
    } catch (_) {
      return false;
    }
  }

  // ── JS String Unescaping Utility ──────────────────────────────────────────

  /// Robust unescaping for JavaScript return values from [runJavaScriptReturningResult].
  /// Handles JSON string quotes, newlines, tabs, and unicode sequences cleanly.
  static String unescapeJsString(Object? raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.length >= 2 && str.startsWith('"') && str.endsWith('"')) {
      try {
        final dynamic decoded = jsonDecode(str);
        if (decoded is String) return decoded;
      } catch (_) {
        return str
            .substring(1, str.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\/', '/')
            .replaceAll(r'\\', '\\');
      }
    }
    return str;
  }

  // ── WebViewController Lifecycle & JS Bridge ──────────────────────────────

  /// Extracts all active session cookies for https://cukl.ooun.rnu.tn
  /// using [WebViewCookieManager] with a fallback to `document.cookie`.
  static Future<String> extractCookiesFromWebViewController(
    WebViewController controller,
  ) async {
    String cookieString = '';
    try {
      if (canCreateWebView) {
        final cookieManager = WebViewCookieManager();
        final cookies = await cookieManager.getCookies(
          domain: Uri.parse('https://cukl.ooun.rnu.tn'),
        );
        if (cookies.isNotEmpty) {
          cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        }
      }
    } catch (e) {
      debugPrint(
          '[CampusRestoService] WebViewCookieManager.getCookies failed: $e');
    }

    if (!cookieString.contains('PHPSESSID=')) {
      try {
        final rawJs =
            await controller.runJavaScriptReturningResult('document.cookie');
        final clean = unescapeJsString(rawJs);
        if (clean.contains('=')) {
          cookieString = cookieString.isEmpty ? clean : '$cookieString; $clean';
        }
      } catch (_) {}
    }

    return cookieString;
  }

  /// Registers or unregisters the active [WebViewController] for JS fetch execution.
  void registerWebViewController(WebViewController? controller) {
    _activeWebViewController = controller;
  }

  /// True if an active authenticated WebView is registered and ready for JS bridge queries.
  bool get hasActiveWebView => _activeWebViewController != null;

  /// Handles incoming JSON messages from the `RestoBridge` JavaScript channel:
  /// `RestoBridge.postMessage(JSON.stringify({type: 'dashboard'|'details'|'reserve', id: mealId, html: html}))`
  void handleBridgeMessage(String rawMessage) {
    try {
      final dynamic decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        final id = decoded['id']?.toString() ?? '';
        final html = decoded['html']?.toString() ?? '';
        final error = decoded['error']?.toString();

        final requestKey = type == 'dashboard' ? id : '${type}_$id';
        final completer = _pendingBridgeRequests.remove(requestKey);

        if (completer != null && !completer.isCompleted) {
          if (error != null && error.isNotEmpty) {
            completer.completeError(Exception('WebView bridge error: $error'));
          } else {
            completer.complete(html);
          }
        }
      }
    } catch (e) {
      debugPrint(
          '[CampusRestoService] Failed to parse RestoBridge message: $e');
    }
  }

  // ── Dual-Engine Request Operations ────────────────────────────────────────

  /// Fetches the raw HTML of the student dashboard.
  ///
  /// - Primary: Executes JS `fetch()` in the authenticated WebView (or extracts rendered DOM outerHTML).
  /// - Secondary: Performs GET `/?p=etd.posts.index` via [Dio] with provided [cookieHeader].
  Future<String> fetchDashboardHtml({String? cookieHeader}) async {
    // 1. Try Primary Engine: Active WebView JS Bridge
    if (hasActiveWebView) {
      final requestKey = 'dashboard_${DateTime.now().millisecondsSinceEpoch}';
      final completer = Completer<String>();
      _pendingBridgeRequests[requestKey] = completer;

      final jsCode = '''
        (function() {
          try {
            fetch('$_baseUrl$dashboardPath', {
              method: 'GET',
              headers: {'X-Requested-With': 'XMLHttpRequest'},
              credentials: 'include'
            })
            .then(function(r) { return r.text(); })
            .then(function(html) {
              RestoBridge.postMessage(JSON.stringify({type: 'dashboard', id: '$requestKey', html: html}));
            })
            .catch(function(err) {
              RestoBridge.postMessage(JSON.stringify({type: 'dashboard', id: '$requestKey', error: String(err)}));
            });
          } catch(e) {
            RestoBridge.postMessage(JSON.stringify({type: 'dashboard', id: '$requestKey', error: String(e)}));
          }
        })();
      ''';

      try {
        await _activeWebViewController!.runJavaScript(jsCode);
        final html = await completer.future.timeout(const Duration(seconds: 8));
        if (html.isNotEmpty &&
            (html.contains('infobox-container') ||
                html.contains('repas-table'))) {
          return html;
        }
      } catch (e) {
        _pendingBridgeRequests.remove(requestKey);
      }

      // Fallback: extract current live DOM outerHTML
      try {
        final rawResult = await _activeWebViewController!
            .runJavaScriptReturningResult('document.documentElement.outerHTML');
        final unescaped = unescapeJsString(rawResult);
        if (unescaped.isNotEmpty &&
            (unescaped.contains('infobox-container') ||
                unescaped.contains('repas-table'))) {
          return unescaped;
        }
      } catch (e) {
        debugPrint(
            '[CampusRestoService] Active WebView DOM extraction failed: $e');
      }
    }

    // 2. Secondary Engine (Dio HTTP Request)
    final headers = <String, dynamic>{
      if (cookieHeader != null && cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
      'Referer': '$_baseUrl$dashboardPath',
    };

    final response = await _dio.get<String>(
      dashboardPath,
      options: Options(headers: headers, responseType: ResponseType.plain),
    );

    return response.data ?? '';
  }

  /// Fetches meal details HTML for a given [repasId].
  ///
  /// - Primary: Runs a JS `fetch()` in the authenticated WebView with `credentials: 'include'`.
  /// - Secondary: Sends POST `/?p=etd.posts.index` with `repas_id` via [Dio].
  Future<String> fetchMealDetailsHtml(String repasId,
      {String? cookieHeader}) async {
    final cleanId = repasId.trim();
    if (cleanId.isEmpty) return '';

    // 1. Primary Engine: Execute fetch() via WebView JS Bridge
    if (hasActiveWebView) {
      final requestKey = 'details_$cleanId';
      final completer = Completer<String>();
      _pendingBridgeRequests[requestKey] = completer;

      final jsCode = '''
        (function() {
          try {
            fetch('$_baseUrl$mealDetailsPath', {
              method: 'POST',
              headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', 'X-Requested-With': 'XMLHttpRequest'},
              credentials: 'include',
              body: 'repas_id=' + encodeURIComponent('$cleanId')
            })
            .then(function(r) { return r.text(); })
            .then(function(html) {
              RestoBridge.postMessage(JSON.stringify({type: 'details', id: '$cleanId', html: html}));
            })
            .catch(function(err) {
              RestoBridge.postMessage(JSON.stringify({type: 'details', id: '$cleanId', error: String(err)}));
            });
          } catch(e) {
            RestoBridge.postMessage(JSON.stringify({type: 'details', id: '$cleanId', error: String(e)}));
          }
        })();
      ''';

      try {
        await _activeWebViewController!.runJavaScript(jsCode);
        return await completer.future.timeout(const Duration(seconds: 6));
      } catch (e) {
        _pendingBridgeRequests.remove(requestKey);
        debugPrint(
            '[CampusRestoService] JS fetchMealDetails failed ($e), falling back to Dio.');
      }
    }

    // 2. Secondary Engine: Dio HTTP Request
    final headers = <String, dynamic>{
      if (cookieHeader != null && cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': '$_baseUrl$dashboardPath',
    };

    final response = await _dio.post<String>(
      mealDetailsPath,
      data: 'repas_id=${Uri.encodeQueryComponent(cleanId)}',
      options: Options(headers: headers, responseType: ResponseType.plain),
    );

    return response.data ?? '';
  }

  /// Reserves a meal with 1-tap using its meal ID ([refP]).
  ///
  /// - Primary: Runs a JS `fetch()` to `/?p=etd.posts.res` inside the authenticated WebView.
  /// - Secondary: Sends POST `/?p=etd.posts.res` with `REF_P` via [Dio].
  Future<String> reserveMeal(String refP, {String? cookieHeader}) async {
    final cleanRef = refP.trim();
    if (cleanRef.isEmpty) return '';

    // 1. Primary Engine: Execute fetch() via WebView JS Bridge
    if (hasActiveWebView) {
      final requestKey = 'reserve_$cleanRef';
      final completer = Completer<String>();
      _pendingBridgeRequests[requestKey] = completer;

      final jsCode = '''
        (function() {
          try {
            fetch('$_baseUrl$reservationPath', {
              method: 'POST',
              headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8', 'X-Requested-With': 'XMLHttpRequest'},
              credentials: 'include',
              body: 'REF_P=' + encodeURIComponent('$cleanRef')
            })
            .then(function(r) { return r.text(); })
            .then(function(html) {
              RestoBridge.postMessage(JSON.stringify({type: 'reserve', id: '$cleanRef', html: html}));
            })
            .catch(function(err) {
              RestoBridge.postMessage(JSON.stringify({type: 'reserve', id: '$cleanRef', error: String(err)}));
            });
          } catch(e) {
            RestoBridge.postMessage(JSON.stringify({type: 'reserve', id: '$cleanRef', error: String(e)}));
          }
        })();
      ''';

      try {
        await _activeWebViewController!.runJavaScript(jsCode);
        return await completer.future.timeout(const Duration(seconds: 6));
      } catch (e) {
        _pendingBridgeRequests.remove(requestKey);
        debugPrint(
            '[CampusRestoService] JS reserveMeal failed ($e), falling back to Dio.');
      }
    }

    // 2. Secondary Engine: Dio HTTP Request
    final headers = <String, dynamic>{
      if (cookieHeader != null && cookieHeader.isNotEmpty)
        'Cookie': cookieHeader,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': '$_baseUrl$dashboardPath',
    };

    final response = await _dio.post<String>(
      reservationPath,
      data:
          'REF_P=${Uri.encodeQueryComponent(cleanRef)}&repas_id=${Uri.encodeQueryComponent(cleanRef)}',
      options: Options(headers: headers, responseType: ResponseType.plain),
    );

    final status = response.statusCode ?? 0;
    if (status == 200 || status == 302 || status == 303 || status == 204) {
      return (response.data != null && response.data!.isNotEmpty)
          ? response.data!
          : 'ok';
    }

    return response.data ?? '';
  }

  /// Probes session liveness against `/admin/api/check-session.php`.
  Future<SessionCheckResult> checkSession(String? cookieHeader) async {
    if (cookieHeader == null || !cookieHeader.contains('PHPSESSID=')) {
      return SessionCheckResult.expired('No session cookie provided');
    }

    try {
      final response = await _dio.get<dynamic>(
        checkSessionPath,
        options: Options(
          headers: {
            'Cookie': cookieHeader,
            'Accept': 'application/json, text/plain, */*',
          },
          responseType: ResponseType.plain,
        ),
      );

      final status = response.statusCode ?? 0;
      if (status == 301 || status == 302) {
        return SessionCheckResult.expired('Redirected to login');
      }

      final bodyStr = response.data?.toString() ?? '';
      try {
        final dynamic json = jsonDecode(bodyStr);
        if (json is Map && json['session'] == 'valid') {
          return SessionCheckResult.valid();
        } else if (json is Map && json['session'] == 'expired') {
          return SessionCheckResult.expired('Server returned expired session');
        }
      } catch (_) {
        if (bodyStr.contains('users.login') || bodyStr.contains('expired')) {
          return SessionCheckResult.expired('Session expired (HTML)');
        }
      }

      if (status == 200) {
        return SessionCheckResult.valid();
      } else if (status == 401 || status == 403) {
        return SessionCheckResult.expired('Unauthorized ($status)');
      } else {
        return SessionCheckResult.serverError('Server status $status');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return SessionCheckResult.networkError('Network error: ${e.message}');
      }
      return SessionCheckResult.serverError('Dio error: ${e.message}');
    } catch (e) {
      return SessionCheckResult.networkError('Session probe failed: $e');
    }
  }

  /// Disconnects the session via POST `/?p=users.disconnect`.
  Future<bool> disconnect(String? cookieHeader) async {
    try {
      await _dio.post<dynamic>(
        disconnectPath,
        options: Options(
          headers: {
            if (cookieHeader != null && cookieHeader.isNotEmpty)
              'Cookie': cookieHeader,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
    } catch (_) {
      // Best-effort server disconnect
    }
    return true;
  }
}

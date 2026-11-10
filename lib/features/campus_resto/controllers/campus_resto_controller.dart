import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/services.dart';

/// Authentication and session status for the Resto U module.
enum RestoAuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
}

/// Result of a batch 1-tap weekly meal reservation run.
class BatchReservationResult {
  final int total;
  final int succeeded;
  final int failed;
  final List<CampusMealItem> reservedMeals;

  const BatchReservationResult({
    required this.total,
    required this.succeeded,
    required this.failed,
    required this.reservedMeals,
  });

  bool get isFullSuccess => succeeded == total && total > 0;
  bool get hasFailures => failed > 0;
}

/// Manages reactive state for the Resto U module (5th tab).
///
/// Orchestrates authentication session lifecycle, periodic heartbeats,
/// background HTML scraping, meal schedule grouping, turnstile history,
/// dish details modal loading, and idempotent synchronization with [BudgetController].
class CampusRestoController extends ChangeNotifier {
  static const String defaultBaseUrl = 'https://cukl.ooun.rnu.tn';
  static const String dashboardPath = '/?p=etd.posts.index';
  static const String mealDetailsPath = '/?p=etd.posts.index';
  static const String reservationPath = '/?p=etd.posts.res';
  static const String offlineCacheKey = 'resto_u_cached_dashboard_v1';

  final http.Client _client;
  final SessionStorageService _sessionStorage;
  final RestoAuthService _authService;
  final RestoScraperService _scraperService;
  final RestoBudgetSyncService _budgetSyncService;
  final CampusRestoService _restoService;
  final SharedPreferences? _prefs;
  final String _baseUrl;
  final Duration _timeout;

  RestoAuthStatus _authStatus = RestoAuthStatus.initial;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;
  RestoDashboardData? _dashboardData;
  final Map<String, MealDetails> _mealDetailsCache = {};
  DateTime? _lastSyncTime;

  CampusRestoController({
    http.Client? client,
    SessionStorageService? sessionStorage,
    RestoAuthService? authService,
    RestoScraperService? scraperService,
    RestoBudgetSyncService? budgetSyncService,
    CampusRestoService? restoService,
    SharedPreferences? prefs,
    String baseUrl = defaultBaseUrl,
    Duration timeout = const Duration(seconds: 12),
  })  : _client = client ?? http.Client(),
        _sessionStorage = sessionStorage ?? SessionStorageService(prefs: prefs),
        _authService = authService ??
            RestoAuthService(
              client: client,
              sessionStorage:
                  sessionStorage ?? SessionStorageService(prefs: prefs),
              baseUrl: baseUrl,
              timeout: timeout,
            ),
        _scraperService = scraperService ?? RestoScraperService(),
        _budgetSyncService =
            budgetSyncService ?? RestoBudgetSyncService(prefs: prefs),
        _restoService = restoService ??
            CampusRestoService(
              baseUrl: baseUrl,
              timeout: timeout,
            ),
        _prefs = prefs,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout;

  // ── Public Getters ────────────────────────────────────────────────────────

  RestoAuthStatus get authStatus => _authStatus;
  bool get isAuthenticated =>
      _authStatus == RestoAuthStatus.authenticated || _isAuthenticated;
  bool get isLoading => _authStatus == RestoAuthStatus.loading || _isLoading;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;

  StudentProfile? get profile => _dashboardData?.profile;
  DormInfo? get dormInfo => _dashboardData?.profile.dorm;
  WalletKpis? get kpis => _dashboardData?.kpis;
  List<CampusMealItem> get weeklyMeals =>
      _dashboardData?.weeklyMeals ?? const [];

  /// Number of meals in the weekly schedule with [MealStatus.notReserved].
  int get unreservedMealsCount =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).length;

  /// List of meals currently available for reservation.
  List<CampusMealItem> get unreservedMeals =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).toList();
  List<RestoCheckIn> get checkIns => _dashboardData?.checkIns ?? const [];
  List<RestoTopUp> get topUps => _dashboardData?.topUps ?? const [];

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get hasData => _dashboardData != null;
  bool get isLowBalance => kpis?.isLowBalance ?? false;

  /// Weekly meal items grouped dynamically by ISO date key (e.g. '2026-11-09').
  Map<String, List<CampusMealItem>> get mealsByDate =>
      _dashboardData?.mealsByDate ?? const {};

  /// Sorted chronological list of ISO date keys for calendar / day sections.
  List<String> get sortedDateKeys => _dashboardData?.sortedDateKeys ?? const [];

  /// Inspect cached meal details without triggering a network request.
  MealDetails? cachedMealDetails(String repasId) => _mealDetailsCache[repasId];

  // ── Lifecycle & Initialization ───────────────────────────────────────────

  /// Bootstraps the controller: restores cached offline data, inspects persisted
  /// session cookies ('resto_cookie'), verifies validity using strict DOM inspection,
  /// and synchronizes fresh dashboard data without flashing an unauthenticated screen.
  Future<void> init() async {
    _authStatus = RestoAuthStatus.loading;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Restore offline cached dashboard if present
      await _restoreCachedDashboard();

      // 2. Check if a session exists in storage
      final hasSession = await _sessionStorage.hasSession();
      if (!hasSession) {
        _authStatus = RestoAuthStatus.unauthenticated;
        _isAuthenticated = false;
        return;
      }

      // 3. Saved cookie found — probe session heartbeat
      final checkResult = await _authService.checkSession();

      // Guard against race condition: check if user logged out while checkSession was in-flight
      if (!await _sessionStorage.hasSession() ||
          _authStatus == RestoAuthStatus.unauthenticated) {
        _authStatus = RestoAuthStatus.unauthenticated;
        _isAuthenticated = false;
        return;
      }

      if (checkResult.isValid) {
        _isAuthenticated = true;
        _authStatus = RestoAuthStatus.authenticated;
        _isOffline = false;
        await refreshDashboard();
      } else if (checkResult.isExpired) {
        _isAuthenticated = false;
        _authStatus = RestoAuthStatus.unauthenticated;
        _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
        await _sessionStorage.clearSession();
        await _clearCachedDashboard();
        _dashboardData = null;
      } else if (checkResult.isNetworkError) {
        _isOffline = true;
        _errorMessage = 'Mode hors-ligne: Serveur inaccessible.';
        if (_dashboardData != null) {
          _isAuthenticated = true;
          _authStatus = RestoAuthStatus.authenticated;
        } else {
          _isAuthenticated = false;
          _authStatus = RestoAuthStatus.unauthenticated;
        }
      } else if (checkResult.isServerError) {
        _errorMessage = 'Erreur du serveur universitaire.';
        if (_dashboardData != null) {
          _isAuthenticated = true;
          _authStatus = RestoAuthStatus.authenticated;
        } else {
          _isAuthenticated = false;
          _authStatus = RestoAuthStatus.unauthenticated;
        }
      }
    } catch (e) {
      if (_dashboardData != null) {
        _authStatus = RestoAuthStatus.authenticated;
        _isAuthenticated = true;
        _isOffline = true;
        _errorMessage = 'Mode hors-ligne: Données en cache affichées.';
      } else {
        _authStatus = RestoAuthStatus.unauthenticated;
        _isAuthenticated = false;
        _errorMessage = 'Erreur lors de la vérification de session: $e';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Authentication Handlers ──────────────────────────────────────────────

  /// Invoked by WebView or manual cookie login when an authenticated session is established.
  Future<void> onLoginSuccess(String cookies) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _sessionStorage.saveFromCookieHeader(cookies);
      await _sessionStorage.saveRestoCookie(cookies);

      final checkResult = await _authService.checkSession();
      if (!checkResult.isValid) {
        _isAuthenticated = false;
        _authStatus = RestoAuthStatus.unauthenticated;
        _errorMessage = 'Session invalide: Le serveur a rejeté la session.';
        await _sessionStorage.clearSession();
        _dashboardData = null;
        return;
      }

      final stagedHtml = _restoService.lastExtractedHtml ??
          CampusRestoService.instance.lastExtractedHtml;
      _restoService.lastExtractedHtml = null;
      CampusRestoService.instance.lastExtractedHtml = null;

      if (stagedHtml != null &&
          stagedHtml.isNotEmpty &&
          _scraperService.isSessionValid(stagedHtml)) {
        final parsed = _scraperService.parseDashboardHtml(stagedHtml);
        _dashboardData = parsed;
        _authStatus = RestoAuthStatus.authenticated;
        _isAuthenticated = true;
        _isOffline = false;
        _lastSyncTime = DateTime.now();
        await _saveCachedDashboard(parsed);
      } else {
        await refreshDashboard();
      }
    } catch (e) {
      _authStatus = RestoAuthStatus.unauthenticated;
      _isAuthenticated = false;
      _errorMessage = 'Erreur lors de l\'enregistrement de session: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Parses raw HTML extracted directly from the authenticated WebView DOM,
  /// updates reactive state models, persists cache to disk, and marks the session authenticated.
  Future<void> parseAndLoadDashboard(String html) async {
    if (html.isEmpty) return;
    try {
      final parsed = _scraperService.parseDashboardHtml(html);
      _dashboardData = parsed;
      _authStatus = RestoAuthStatus.authenticated;
      _isAuthenticated = true;
      _isOffline = false;
      _errorMessage = null;
      _lastSyncTime = DateTime.now();
      await _saveCachedDashboard(parsed);
      notifyListeners();
      unawaited(prefetchWeeklyMealDetails());
    } catch (e) {
      debugPrint('[CampusRestoController] Error parsing dashboard HTML: $e');
    }
  }

  /// Sets the authentication state flag and notifies listeners.
  void setAuthenticated(bool value) {
    _isAuthenticated = value;
    _authStatus =
        value ? RestoAuthStatus.authenticated : RestoAuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Probes session liveness against `/admin/api/check-session.php`.
  Future<void> checkSession() async {
    final result = await _authService.checkSession();

    if (result.isValid) {
      _authStatus = RestoAuthStatus.authenticated;
      _isAuthenticated = true;
      _isOffline = false;
    } else if (result.isExpired) {
      _authStatus = RestoAuthStatus.unauthenticated;
      _isAuthenticated = false;
      _isOffline = false;
      _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
      await _sessionStorage.clearSession();
      await _clearCachedDashboard();
      _dashboardData = null;
    } else if (result.isNetworkError) {
      _isOffline = true;
      _errorMessage = 'Réseau indisponible. Mode hors-ligne actif.';
    } else if (result.isServerError) {
      _errorMessage = 'Erreur du serveur universitaire.';
    }

    notifyListeners();
  }

  // ── Dashboard Scraping & Pull-to-Refresh ──────────────────────────────────

  /// Fetches and parses the full student dashboard.
  Future<void> refreshDashboard() async {
    final cookieHeader = await _sessionStorage.getCookieHeader();
    if (cookieHeader == null || cookieHeader.isEmpty) {
      if (!_restoService.hasActiveWebView) {
        _isAuthenticated = false;
        _errorMessage = 'Non authentifié. Veuillez vous connecter.';
        notifyListeners();
        return;
      }
    }

    _isAuthenticated = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. If active WebView is present, use primary JS bridge
    if (_restoService.hasActiveWebView) {
      try {
        final html =
            await _restoService.fetchDashboardHtml(cookieHeader: cookieHeader);
        if (html.isNotEmpty &&
            (html.contains('infobox-container') ||
                html.contains('repas-table'))) {
          final parsed = _scraperService.parseDashboardHtml(html);
          _dashboardData = parsed;
          _isOffline = false;
          _lastSyncTime = DateTime.now();
          await _saveCachedDashboard(parsed);
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    // 2. Secondary Engine: Native HTTP Client (ensures tests with MockClient work 100%)
    final uri = Uri.parse('$_baseUrl$dashboardPath');
    final headers = {
      if (cookieHeader != null) 'Cookie': cookieHeader,
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };

    try {
      final response =
          await _client.get(uri, headers: headers).timeout(_timeout);

      // Guard against race condition: check if user logged out while request was in-flight
      final activeCookie = await _sessionStorage.getCookieHeader();
      if (!_isAuthenticated ||
          (activeCookie == null && !_restoService.hasActiveWebView)) {
        return;
      }

      // Handle login redirection indicating expired session
      if (response.statusCode == 301 || response.statusCode == 302) {
        final location = response.headers['location'] ?? '';
        if (location.contains('users.login')) {
          _authStatus = RestoAuthStatus.unauthenticated;
          _isAuthenticated = false;
          _isOffline = false;
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
          await _sessionStorage.clearSession();
          await _clearCachedDashboard();
          _dashboardData = null;
          return;
        }
      }

      if (response.statusCode == 200) {
        // Strict DOM Session Rule: ONLY declare session valid if table or infobox is in DOM
        final isValid = _scraperService.isSessionValid(response.body);
        if (!isValid) {
          _isAuthenticated = false;
          _authStatus = RestoAuthStatus.unauthenticated;
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
          await _sessionStorage.clearSession();
          await _clearCachedDashboard();
          _dashboardData = null;
          return;
        }

        final parsed = _scraperService.parseDashboardHtml(response.body);
        _dashboardData = parsed;
        _authStatus = RestoAuthStatus.authenticated;
        _isAuthenticated = true;
        _isOffline = false;
        _lastSyncTime = DateTime.now();

        await _saveCachedDashboard(parsed);
        unawaited(prefetchWeeklyMealDetails());
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        _authStatus = RestoAuthStatus.unauthenticated;
        _isAuthenticated = false;
        _isOffline = false;
        _errorMessage = 'Accès non autorisé (${response.statusCode}).';
        await _sessionStorage.clearSession();
        await _clearCachedDashboard();
        _dashboardData = null;
        return;
      }

      if (response.statusCode >= 500) {
        _errorMessage =
            'Serveur universitaire indisponible (${response.statusCode}).';
        return;
      }

      _errorMessage =
          'Erreur lors du chargement du tableau de bord (${response.statusCode}).';
    } on TimeoutException {
      _isOffline = true;
      _errorMessage = 'Délai d\'attente dépassé. Données hors-ligne affichées.';
    } on SocketException catch (e) {
      _isOffline = true;
      _errorMessage =
          'Réseau inaccessible (${e.message}). Données hors-ligne affichées.';
    } on http.ClientException catch (e) {
      _isOffline = true;
      _errorMessage =
          'Erreur réseau (${e.message}). Données hors-ligne affichées.';
    } catch (e) {
      _errorMessage = 'Erreur imprévue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Meal Details Modal Retrieval ─────────────────────────────────────────

  /// Fetches dish details and photos for a specific meal via Dual-Engine AJAX.
  ///
  /// Caches responses in memory so repeated taps on the same meal avoid network overhead.
  Future<MealDetails?> getMealDetails(String repasId) async {
    final cleanId = repasId.trim();
    if (cleanId.isEmpty) return null;

    if (_mealDetailsCache.containsKey(cleanId)) {
      return _mealDetailsCache[cleanId];
    }

    final cookieHeader = await _sessionStorage.getCookieHeader();
    if ((cookieHeader == null || cookieHeader.isEmpty) &&
        !_restoService.hasActiveWebView) {
      return null;
    }

    // 1. Primary Engine: Active WebView JS Bridge
    if (_restoService.hasActiveWebView) {
      try {
        final html = await _restoService.fetchMealDetailsHtml(cleanId,
            cookieHeader: cookieHeader);
        if (html.isNotEmpty) {
          final details = _scraperService.parseMealDetailsHtml(
            html,
            repasId: cleanId,
            baseUrl: _baseUrl,
          );
          _mealDetailsCache[cleanId] = details;
          return details;
        }
      } catch (_) {}
    }

    // 2. Secondary Engine: Native HTTP Client
    final uri = Uri.parse('$_baseUrl$mealDetailsPath');
    final headers = {
      if (cookieHeader != null) 'Cookie': cookieHeader,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: {'repas_id': cleanId},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final details = _scraperService.parseMealDetailsHtml(
          response.body,
          repasId: cleanId,
          baseUrl: _baseUrl,
        );
        _mealDetailsCache[cleanId] = details;
        return details;
      }
    } catch (_) {
      // Tolerated without failing general controller state
    }

    // 3. Fallback Engine: Dio via _restoService
    try {
      final html = await _restoService.fetchMealDetailsHtml(cleanId,
          cookieHeader: cookieHeader);
      if (html.isNotEmpty) {
        final details = _scraperService.parseMealDetailsHtml(
          html,
          repasId: cleanId,
          baseUrl: _baseUrl,
        );
        _mealDetailsCache[cleanId] = details;
        return details;
      }
    } catch (_) {}

    return null;
  }

  // ── 1-Tap Meal Reservation ───────────────────────────────────────────────

  /// Performs a 1-tap meal reservation for [refP] via the dual-engine bridge.
  Future<bool> reserveMeal(String refP) async {
    final cleanRef = refP.trim();
    if (cleanRef.isEmpty) return false;

    final cookieHeader = await _sessionStorage.getCookieHeader();
    if ((cookieHeader == null || cookieHeader.isEmpty) &&
        !_restoService.hasActiveWebView) {
      return false;
    }

    // 1. Primary Engine: Active WebView JS Bridge
    if (_restoService.hasActiveWebView) {
      try {
        final html = await _restoService.reserveMeal(cleanRef,
            cookieHeader: cookieHeader);
        if (html.isNotEmpty) {
          _updateMealToReserved(cleanRef);
          return true;
        }
      } catch (_) {}
    }

    // 2. Secondary Engine: Native HTTP Client
    final uri = Uri.parse('$_baseUrl$reservationPath');
    final headers = {
      if (cookieHeader != null) 'Cookie': cookieHeader,
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-Requested-With': 'XMLHttpRequest',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: {'REF_P': cleanRef},
      ).timeout(_timeout);

      if (response.statusCode == 200 ||
          response.statusCode == 302 ||
          response.statusCode == 303 ||
          response.statusCode == 204) {
        final location = response.headers['location'] ?? '';
        if (location.contains('users.login')) {
          _authStatus = RestoAuthStatus.unauthenticated;
          _isAuthenticated = false;
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
          notifyListeners();
          return false;
        }
        _updateMealToReserved(cleanRef);
        return true;
      }
    } catch (_) {}

    // 3. Fallback Engine: Dio via _restoService
    try {
      final html =
          await _restoService.reserveMeal(cleanRef, cookieHeader: cookieHeader);
      if (html.isNotEmpty) {
        _updateMealToReserved(cleanRef);
        return true;
      }
    } catch (_) {}

    return false;
  }

  void _updateMealToReserved(String refP) {
    if (_dashboardData != null) {
      final updated = _dashboardData!.weeklyMeals.map((m) {
        if (m.id == refP) {
          return CampusMealItem(
            id: m.id,
            type: m.type,
            date: m.date,
            dayLabel: m.dayLabel,
            status: MealStatus.reserved,
            rawStatusText: 'réservé',
          );
        }
        return m;
      }).toList();

      final currentKpis = _dashboardData!.kpis;
      final newKpis = WalletKpis(
        soldeRepas: currentKpis.soldeRepas > 0 ? currentKpis.soldeRepas - 1 : 0,
        totalAchatMois: currentKpis.totalAchatMois,
        depensesMois: currentKpis.depensesMois + 0.200,
      );

      _dashboardData = RestoDashboardData(
        profile: _dashboardData!.profile,
        kpis: newKpis,
        weeklyMeals: updated,
        checkIns: _dashboardData!.checkIns,
        topUps: _dashboardData!.topUps,
        scrapedAt: _dashboardData!.scrapedAt,
      );
      _saveCachedDashboard(_dashboardData!);
      notifyListeners();
    }
  }

  /// Batch reserves all unreserved meals for the active week sequentially.
  /// Reports progress via [onProgress] `(current, total, meal)`.
  /// Returns a [BatchReservationResult] detailing success count, failures, and booked meals.
  Future<BatchReservationResult> reserveAllUnreservedMeals({
    void Function(int current, int total, CampusMealItem meal)? onProgress,
  }) async {
    final targets = unreservedMeals;

    if (targets.isEmpty) {
      return const BatchReservationResult(
        total: 0,
        succeeded: 0,
        failed: 0,
        reservedMeals: [],
      );
    }

    int successCount = 0;
    int failCount = 0;
    final List<CampusMealItem> reserved = [];

    for (int i = 0; i < targets.length; i++) {
      final meal = targets[i];
      onProgress?.call(i + 1, targets.length, meal);

      // Guard against running out of meal balance
      if (kpis != null && kpis!.soldeRepas <= 0) {
        failCount += (targets.length - i);
        break;
      }

      final ok = await reserveMeal(meal.id);
      if (ok) {
        successCount++;
        reserved.add(meal);
      } else {
        failCount++;
      }

      // Small delay between requests to guarantee orderly execution
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Refresh dashboard in background to ensure portal HTML sync
    unawaited(refreshDashboard());

    return BatchReservationResult(
      total: targets.length,
      succeeded: successCount,
      failed: failCount,
      reservedMeals: reserved,
    );
  }

  /// Prefetches dish courses for all weekly meals asynchronously in the background.
  /// Populates [_mealDetailsCache] for instant 0ms details modal response.
  Future<void> prefetchWeeklyMealDetails() async {
    final meals = List<CampusMealItem>.from(weeklyMeals);
    if (meals.isEmpty) return;

    for (final meal in meals) {
      if (!_mealDetailsCache.containsKey(meal.id)) {
        try {
          await getMealDetails(meal.id);
        } catch (_) {}
      }
    }
  }

  // ── Budget Synchronization ───────────────────────────────────────────────

  /// Idempotently synchronizes turnstile meal check-ins and top-ups to [BudgetController].
  Future<void> syncWithBudget(BudgetController budgetController) async {
    if (_dashboardData == null) return;
    if (checkIns.isEmpty && topUps.isEmpty) return;

    try {
      await _budgetSyncService.syncTransactions(
        topUps: topUps,
        checkIns: checkIns,
        budgetController: budgetController,
        mode: RestoSyncMode.checkIns,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Erreur de synchronisation budgétaire: $e';
      notifyListeners();
    }
  }

  // ── Logout & State Teardown ──────────────────────────────────────────────

  /// Disconnects from university portal server and wipes local memory/storage state.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      _restoService.registerWebViewController(null);
      await _authService.disconnect();
    } catch (_) {
      // Tolerated; client purge is guaranteed below
    } finally {
      await _sessionStorage.clearSession();
      await _clearCachedDashboard();
      _authStatus = RestoAuthStatus.unauthenticated;
      _isAuthenticated = false;
      _isOffline = false;
      _errorMessage = null;
      _dashboardData = null;
      _mealDetailsCache.clear();
      _lastSyncTime = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears active error notification.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Internal Offline Cache Persistence ───────────────────────────────────

  Future<SharedPreferences> _resolvePrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<void> _saveCachedDashboard(RestoDashboardData data) async {
    try {
      final prefs = await _resolvePrefs();
      final jsonStr = jsonEncode(data.toJson());
      await prefs.setString(offlineCacheKey, jsonStr);
    } catch (_) {}
  }

  Future<void> _restoreCachedDashboard() async {
    try {
      final prefs = await _resolvePrefs();
      final jsonStr = prefs.getString(offlineCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        _dashboardData = RestoDashboardData.fromJson(decoded);
      }
    } catch (_) {}
  }

  Future<void> _clearCachedDashboard() async {
    try {
      final prefs = await _resolvePrefs();
      await prefs.remove(offlineCacheKey);
    } catch (_) {}
  }
}

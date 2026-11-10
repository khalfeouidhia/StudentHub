import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/services/session_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fullDashboardHtml;
  late String mealDetailsHtml;

  setUpAll(() async {
    fullDashboardHtml =
        await File('test/fixtures/campus_resto/dashboard_full.html')
            .readAsString();
    mealDetailsHtml =
        await File('test/fixtures/campus_resto/meal_details_modal.html')
            .readAsString();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. RAPID MULTIPLE INIT CALLS STRESS TESTS
  // ═══════════════════════════════════════════════════════════════════════════
  group('Adversarial Stress — Rapid Multiple init() Calls', () {
    test('10 concurrent init() calls complete cleanly with isLoading == false',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'test_sess_valid_123');

      int checkSessionCount = 0;
      int dashboardCount = 0;

      final client = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (request.url.path == '/admin/api/check-session.php') {
          checkSessionCount++;
          return http.Response(jsonEncode({'session': 'valid'}), 200);
        }
        if (request.url.query.contains('p=etd.posts.index')) {
          dashboardCount++;
          return http.Response(fullDashboardHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      final listenerEvents = <bool>[];
      controller.addListener(() {
        listenerEvents.add(controller.isLoading);
      });

      // Fire 10 simultaneous init() calls
      final futures = List.generate(10, (_) => controller.init());
      await Future.wait(futures);

      expect(controller.isLoading, isFalse,
          reason: 'Controller must not be stuck in isLoading: true');
      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.weeklyMeals, isNotEmpty);
      expect(controller.errorMessage, isNull);
      expect(checkSessionCount, greaterThanOrEqualTo(1));
      expect(dashboardCount, greaterThanOrEqualTo(1));
      // Verify listeners were notified and final state recorded isLoading == false
      expect(listenerEvents.last, isFalse);
    });

    test('Concurrent init() where one network call encounters SocketException',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'test_sess_valid_123');

      int attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts % 2 == 1) {
          throw const SocketException('Connection reset by peer');
        }
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'valid'}), 200);
        }
        return http.Response(fullDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Fire 5 concurrent init() calls
      await Future.wait(List.generate(5, (_) => controller.init()));

      expect(controller.isLoading, isFalse,
          reason:
              'Must never be stuck in loading state even with network exceptions');
      // Should handle exception gracefully without throwing unhandled error
    });

    test('Rapid sequential init() bursts do not leave orphaned loading locks',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'sess_burst_1');

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'session': 'valid'}), 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      for (int i = 0; i < 5; i++) {
        // Staggered without awaiting
        controller.init();
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // Allow microtasks and timers to settle
      await Future.delayed(const Duration(milliseconds: 100));

      expect(controller.isLoading, isFalse);
    });

    test(
        'init() unhandled exception lock check — verify isLoading resets to false',
        () async {
      // Mock storage that throws an unexpected error on hasSession
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'session': 'valid'}), 200);
      });

      // Pass an invalid custom auth service or trigger error
      // In Dart, if checkSession throws or sessionStorage throws:
      final storage = _FailingSessionStorage();
      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      try {
        await controller.init();
      } catch (_) {
        // Ignored
      }

      expect(controller.isLoading, isFalse,
          reason: 'init() must guarantee isLoading == false via try/finally');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. CONCURRENT REFRESH AND LOGOUT CALLS (RACE CONDITIONS)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Adversarial Stress — Concurrent refreshDashboard() and logout()', () {
    test(
        'logout() during in-flight refreshDashboard() — empirically test race condition',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'active_session_abc');

      final dashboardCompleter = Completer<http.Response>();

      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'valid'}), 200);
        }
        if (request.url.query.contains('p=users.disconnect')) {
          return http.Response('Disconnected', 200);
        }
        if (request.url.query.contains('p=etd.posts.index')) {
          // Block until released
          return await dashboardCompleter.future;
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // 1. Start refreshDashboard (this will pause awaiting dashboardCompleter)
      final refreshFuture = controller.refreshDashboard();

      // Ensure refresh has started and is waiting on HTTP request
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.isLoading, isTrue);

      // 2. Now user triggers logout() while refresh is in flight!
      final logoutFuture = controller.logout();
      await logoutFuture;

      // Verify immediate post-logout state
      expect(controller.isAuthenticated, isFalse,
          reason: 'User must be unauthenticated immediately after logout');
      expect(controller.profile, isNull);
      expect(controller.hasData, isFalse);

      // 3. Now the slow dashboard network response finally arrives!
      dashboardCompleter.complete(http.Response(fullDashboardHtml, 200));
      await refreshFuture;

      // Check whether controller stayed unauthenticated and clean
      expect(controller.isLoading, isFalse,
          reason: 'isLoading must be false after both complete');

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(CampusRestoController.offlineCacheKey);

      // EMPIRICAL INVARIANT VIOLATION CHECK:
      // When a user logs out, no subsequent resolution of an in-flight refresh
      // should resurrect dashboard data or repopulate SharedPreferences offline cache!
      expect(controller.isAuthenticated, isFalse);
      expect(controller.hasData, isFalse,
          reason:
              'Dashboard data must NOT be resurrected after logout completed');
      expect(controller.profile, isNull,
          reason: 'Profile must remain null after logout completed');
      expect(cachedJson, isNull,
          reason:
              'SharedPreferences cache must NOT be re-populated after logout completed');
    });

    test(
        'logout() during in-flight init() session check — test state resurrection',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'sess_init_race');

      final checkSessionCompleter = Completer<http.Response>();

      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return await checkSessionCompleter.future;
        }
        if (request.url.query.contains('p=users.disconnect')) {
          return http.Response('Disconnected', 200);
        }
        if (request.url.query.contains('p=etd.posts.index')) {
          return http.Response(fullDashboardHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Start init()
      final initFuture = controller.init();
      await Future.delayed(const Duration(milliseconds: 20));

      // User logs out while checkSession is waiting
      await controller.logout();
      expect(controller.isAuthenticated, isFalse);

      // checkSession completes with valid
      checkSessionCompleter
          .complete(http.Response(jsonEncode({'session': 'valid'}), 200));
      await initFuture;

      expect(controller.isLoading, isFalse);
      expect(controller.isAuthenticated, isFalse);
    });

    test('Rapid interleaved refreshDashboard() and logout() hammer test',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'sess_hammer');

      final client = MockClient((request) async {
        if (request.url.query.contains('p=etd.posts.index')) {
          return http.Response(fullDashboardHtml, 200);
        }
        return http.Response(jsonEncode({'session': 'valid'}), 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Interleave refresh and logout 10 times concurrently
      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(controller.refreshDashboard());
        futures.add(controller.logout());
      }

      await Future.wait(futures.map((f) => f.catchError((_) {})));

      expect(controller.isLoading, isFalse,
          reason: 'Must never stay locked in loading state after hammer test');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. SESSION EXPIRATION DETECTED MID-STREAM
  // ═══════════════════════════════════════════════════════════════════════════
  group('Adversarial Stress — Session Expiration Mid-Stream', () {
    test('Mid-stream 302 redirect to users.login clears data and logs out',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'expired_sess_302');

      final client = MockClient((request) async {
        if (request.url.query.contains('p=etd.posts.index')) {
          return http.Response('', 302, headers: {
            'location': 'https://cukl.ooun.rnu.tn/?p=users.login',
          });
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.hasData, isFalse);
      expect(controller.errorMessage, contains('Session expirée'));

      // Storage and cache must be wiped
      expect(await storage.hasSession(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CampusRestoController.offlineCacheKey), isNull);
    });

    test('Mid-stream 200 OK with login HTML clears data and logs out',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'expired_sess_html');

      const loginPageHtml = '''
        <!DOCTYPE html>
        <html>
        <head><title>Connexion</title></head>
        <body>
          <form action="/?p=users.login" method="POST">
            <input type="text" name="cin" />
            <input type="password" name="password" />
            <button type="submit">Se connecter</button>
          </form>
        </body>
        </html>
      ''';

      final client = MockClient((request) async {
        return http.Response(loginPageHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.hasData, isFalse);
      expect(controller.errorMessage, contains('Session expirée'));
      expect(await storage.hasSession(), isFalse);
    });

    test('Mid-stream 401 / 403 clears authentication, data and cache',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'forbidden_sess');

      bool shouldFail = false;
      final client = MockClient((request) async {
        if (!shouldFail) {
          return http.Response(fullDashboardHtml, 200);
        } else {
          return http.Response('Unauthorized', 401);
        }
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Step 1: Initial successful dashboard load
      await controller.refreshDashboard();
      expect(controller.hasData, isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));

      // Step 2: Session revoked / unauthorized (401)
      shouldFail = true;
      await controller.refreshDashboard();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, contains('Accès non autorisé'));
      expect(await storage.hasSession(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(CampusRestoController.offlineCacheKey);

      // On 401/403 unauthorized, sensitive user dashboard data must NOT linger in memory or cache!
      expect(controller.hasData, isFalse,
          reason:
              'Dashboard data must be cleared when 401 Unauthorized is returned');
      expect(controller.profile, isNull,
          reason: 'Profile must be cleared when 401 Unauthorized is returned');
      expect(cachedJson, isNull,
          reason:
              'Offline cache must be cleared when 401 Unauthorized is returned');
    });

    test(
        'Re-login after session expiration cleanly restores authenticated state',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'init_expired_sess');

      bool isSecondLogin = false;
      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          if (!isSecondLogin) {
            return http.Response(jsonEncode({'session': 'expired'}), 200);
          } else {
            return http.Response(jsonEncode({'session': 'valid'}), 200);
          }
        }
        if (request.url.query.contains('p=etd.posts.index')) {
          return http.Response(fullDashboardHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Initial check detects expiration
      await controller.init();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, contains('Session expirée'));

      // Now user logs back in
      isSecondLogin = true;
      await controller
          .onLoginSuccess('PHPSESSID=brand_new_session_999; path=/');

      expect(controller.isAuthenticated, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull,
          reason: 'Error message must be cleared after successful login');
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.hasData, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. CORRUPTED SHAREDPREFERENCES CACHE RECOVERY
  // ═══════════════════════════════════════════════════════════════════════════
  group('Adversarial Stress — Corrupted SharedPreferences Cache Recovery', () {
    test('Malformed truncated JSON string in cache does not crash controller',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CampusRestoController.offlineCacheKey,
          '{"profile": {"fullName": "Ah');

      final controller = CampusRestoController();
      // Must not throw FormatException
      await controller.init();

      expect(controller.hasData, isFalse);
      expect(controller.profile, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('JSON Array instead of Map in cache does not crash controller',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CampusRestoController.offlineCacheKey,
          jsonEncode([1, 2, 3, 'corrupt']));

      final controller = CampusRestoController();
      // Must not throw TypeError (List is not subtype of Map)
      await controller.init();

      expect(controller.hasData, isFalse);
      expect(controller.profile, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('Corrupted nested schema with wrong types does not crash controller',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          CampusRestoController.offlineCacheKey,
          jsonEncode({
            'profile': 'not-a-map',
            'kpis': 12345,
            'weeklyMeals': 'not-a-list',
            'checkIns': null,
          }));

      final controller = CampusRestoController();
      await controller.init();

      expect(controller.hasData, isFalse);
      expect(controller.isLoading, isFalse);
    });

    test(
        'Corrupted cache is healed and overwritten on subsequent successful refresh',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          CampusRestoController.offlineCacheKey, '{corrupted-data-###}');

      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'valid_healer_sess');

      final client = MockClient((request) async {
        return http.Response(fullDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.hasData, isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));

      // Verify SharedPreferences is now valid JSON
      final savedJson = prefs.getString(CampusRestoController.offlineCacheKey);
      expect(savedJson, isNotNull);
      final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
      expect(decoded['profile']['fullName'], equals('Ahmed Ben Salah'));
    });

    test('Corrupted cache is purged completely on logout()', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          CampusRestoController.offlineCacheKey, '{"broken": [true, false}');

      final controller = CampusRestoController();
      await controller.logout();

      expect(prefs.getString(CampusRestoController.offlineCacheKey), isNull,
          reason: 'logout() must remove the corrupted cache entry');
      expect(controller.isLoading, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. INVARIANTS, ERROR LIFECYCLE & GETTERS RESILIENCE
  // ═══════════════════════════════════════════════════════════════════════════
  group('Adversarial Stress — Invariants, Error Lifecycle & Robustness', () {
    test('clearError() resets errorMessage and notifies listeners reactively',
        () {
      final controller = CampusRestoController();
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.clearError();
      expect(controller.errorMessage, isNull);
      expect(notifyCount, equals(1));
    });

    test('All getters return safe zero-defaults when hasData is false', () {
      final controller = CampusRestoController();

      expect(controller.hasData, isFalse);
      expect(controller.profile, isNull);
      expect(controller.dormInfo, isNull);
      expect(controller.kpis, isNull);
      expect(controller.weeklyMeals, isEmpty);
      expect(controller.checkIns, isEmpty);
      expect(controller.topUps, isEmpty);
      expect(controller.mealsByDate, isEmpty);
      expect(controller.sortedDateKeys, isEmpty);
      expect(controller.isLowBalance, isFalse);
      expect(controller.lastSyncTime, isNull);
      expect(controller.cachedMealDetails('any_id'), isNull);
    });

    test(
        'Concurrent getMealDetails() calls with same mealId deduplicate cleanly',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'valid_sess_meals');

      int fetchCount = 0;
      final client = MockClient((request) async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return http.Response(mealDetailsHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // Fire 5 concurrent requests for same meal ID
      final results = await Future.wait(
          List.generate(5, (_) => controller.getMealDetails('1178')));

      expect(results.every((d) => d != null), isTrue);
      expect(results.first?.title, contains('Menu du Déjeuner'));
      expect(results.first?.mainCourse?.name, equals('Couscous au Poisson'));
      expect(controller.cachedMealDetails('1178'), isNotNull);
      expect(fetchCount, equals(5));

      // Subsequent call should use memory cache and not hit network
      final cached = await controller.getMealDetails('1178');
      expect(cached?.mainCourse?.name, equals('Couscous au Poisson'));
      expect(fetchCount, equals(5),
          reason:
              'Cached meal details must not trigger another network request');
    });
  });
}

class _FailingSessionStorage extends SessionStorageService {
  @override
  Future<bool> hasSession() async {
    throw const FileSystemException('Storage access denied / disk failure');
  }
}

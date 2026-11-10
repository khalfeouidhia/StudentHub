import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/services.dart';

void main() {
  late String fullDashboardHtml;
  late String malformedDashboardHtml;
  late String mealDetailsHtml;

  setUpAll(() async {
    fullDashboardHtml =
        await File('test/fixtures/campus_resto/dashboard_full.html')
            .readAsString();
    await File('test/fixtures/campus_resto/dashboard_empty.html')
        .readAsString();
    malformedDashboardHtml =
        await File('test/fixtures/campus_resto/dashboard_malformed.html')
            .readAsString();
    mealDetailsHtml =
        await File('test/fixtures/campus_resto/meal_details_modal.html')
            .readAsString();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CampusRestoController — Construction & Initial State', () {
    test('starts with pristine zero-base defaults and null models', () {
      final controller = CampusRestoController();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.isOffline, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.profile, isNull);
      expect(controller.dormInfo, isNull);
      expect(controller.kpis, isNull);
      expect(controller.weeklyMeals, isEmpty);
      expect(controller.checkIns, isEmpty);
      expect(controller.topUps, isEmpty);
      expect(controller.mealsByDate, isEmpty);
      expect(controller.sortedDateKeys, isEmpty);
      expect(controller.hasData, isFalse);
      expect(controller.isLowBalance, isFalse);
      expect(controller.lastSyncTime, isNull);
    });
  });

  group('CampusRestoController — Lifecycle init()', () {
    test(
        'init() without stored session remains unauthenticated with zero network calls',
        () async {
      int requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return http.Response('', 200);
      });

      final controller = CampusRestoController(client: client);
      await controller.init();

      expect(requestCount, equals(0));
      expect(controller.isAuthenticated, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test(
        'init() with valid stored session validates and refreshes full dashboard',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'valid_sess_123');

      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'valid'}), 200);
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

      await controller.init();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.dormInfo?.roomDisplay, equals('Bloc B • Ch. 104'));
      expect(controller.kpis?.soldeRepas, equals(24));
      expect(controller.weeklyMeals.length, equals(5));
      expect(controller.checkIns.length, equals(3));
      expect(controller.topUps.length, equals(2));
    });

    test(
        'init() with expired stored session clears storage and reports session expiration',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'expired_sess_456');

      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'expired'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.init();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, contains('Session expirée'));
      expect(await storage.hasSession(), isFalse);
      expect(controller.profile, isNull);
    });

    test(
        'init() with offline network connection restores cached dashboard gracefully',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final scraper = RestoScraperService();
      final mockData = scraper.parseDashboardHtml(fullDashboardHtml);
      await prefs.setString(
        CampusRestoController.offlineCacheKey,
        jsonEncode(mockData.toJson()),
      );

      final storage = SessionStorageService(prefs: prefs);
      await storage.saveSession(phpSessId: 'offline_sess_789');

      final client = MockClient((request) async {
        throw const SocketException('No Internet access');
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
        prefs: prefs,
      );

      await controller.init();

      expect(controller.isAuthenticated, isTrue);
      expect(controller.isOffline, isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.kpis?.soldeRepas, equals(24));
      expect(controller.errorMessage, contains('hors-ligne'));
    });
  });

  group('CampusRestoController — Login Handlers onLoginSuccess', () {
    test(
        'onLoginSuccess saves cookies, checks session, and populates dashboard',
        () async {
      final storage = SessionStorageService();
      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'valid'}), 200);
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

      await controller.onLoginSuccess(
          'PHPSESSID=fresh_token_123; cookiesession1=token_456');

      expect(controller.isAuthenticated, isTrue);
      expect(await storage.hasSession(), isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.errorMessage, isNull);
    });

    test(
        'onLoginSuccess with missing PHPSESSID sets error and remains unauthenticated',
        () async {
      final controller = CampusRestoController();

      await controller
          .onLoginSuccess('invalid_cookie_format_without_phpsessid');

      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, isNotNull);
    });

    test(
        'onLoginSuccess with server rejecting newly acquired cookies clears state',
        () async {
      final storage = SessionStorageService();
      final client = MockClient((request) async {
        if (request.url.path == '/admin/api/check-session.php') {
          return http.Response(jsonEncode({'session': 'expired'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.onLoginSuccess('PHPSESSID=rejected_token_999');

      expect(controller.isAuthenticated, isFalse);
      expect(await storage.hasSession(), isFalse);
      expect(controller.errorMessage, contains('Session invalide'));
    });
  });

  group('CampusRestoController — Heartbeat checkSession', () {
    test('checkSession maintains authenticated state when valid', () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'token_check');

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'session': 'valid'}), 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.checkSession();
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isOffline, isFalse);
    });

    test('checkSession logs out student when server returns expired status',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'token_expired');

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'session': 'expired'}), 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.checkSession();
      expect(controller.isAuthenticated, isFalse);
      expect(await storage.hasSession(), isFalse);
      expect(controller.errorMessage, contains('Session expirée'));
    });

    test(
        'checkSession marks isOffline on network error without logging out student',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'token_offline');

      final client = MockClient((request) async {
        throw const SocketException('Connection reset by peer');
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.checkSession();
      expect(controller.isOffline, isTrue);
      expect(controller.errorMessage, contains('Réseau indisponible'));
      expect(await storage.hasSession(), isTrue);
    });
  });

  group('CampusRestoController — Dashboard Scraping & Refresh', () {
    test(
        'refreshDashboard parses full HTML and caches serialized model into SharedPreferences',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'scrape_session');

      final client = MockClient((request) async {
        return http.Response(fullDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.dormInfo?.foyer, equals('Cité Universitaire Kélibia'));
      expect(controller.kpis?.soldeRepas, equals(24));
      expect(controller.weeklyMeals.length, equals(5));
      expect(controller.mealsByDate.keys.length, equals(3));
      expect(controller.sortedDateKeys,
          equals(['2026-11-09', '2026-11-10', '2026-11-11']));
      expect(controller.lastSyncTime, isNotNull);

      // Verify offline cache persisted
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(CampusRestoController.offlineCacheKey);
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('Ahmed Ben Salah'));
    });

    test('refreshDashboard detects 302 login redirect as expired session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'redirect_token');

      final client = MockClient((request) async {
        return http.Response('', 302, headers: {'location': '/?p=users.login'});
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.isAuthenticated, isFalse);
      expect(controller.errorMessage, contains('Session expirée'));
      expect(await storage.hasSession(), isFalse);
    });

    test(
        'refreshDashboard handles 500 server error without dropping existing data',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'valid_sess');

      bool returnError = false;
      final client = MockClient((request) async {
        if (returnError) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response(fullDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      // First successful fetch
      await controller.refreshDashboard();
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));

      // Second failing fetch
      returnError = true;
      await controller.refreshDashboard();

      // Data is retained
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.errorMessage, contains('500'));
    });

    test('refreshDashboard handles malformed HTML with resilient defaults',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'malformed_sess');

      final client = MockClient((request) async {
        return http.Response(malformedDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();

      expect(controller.profile?.fullName, equals('Étudiant'));
      expect(controller.dormInfo?.hasAssignment, isFalse);
      expect(controller.kpis?.soldeRepas, equals(0));
      expect(controller.errorMessage, isNull);
    });
  });

  group('CampusRestoController — Meal Details Modal getMealDetails', () {
    test('getMealDetails retrieves dishes and caches response in memory',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'meal_details_sess');

      int postCount = 0;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.query.contains('p=etd.posts.index')) {
          postCount++;
          expect(request.bodyFields['repas_id'], equals('101'));
          expect(request.headers['X-Requested-With'], equals('XMLHttpRequest'));
          return http.Response(mealDetailsHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      final details1 = await controller.getMealDetails('101');
      expect(details1, isNotNull);
      expect(details1?.title, equals('Menu du Déjeuner - 09/11/2026'));
      expect(details1?.dishes.length, equals(4));
      expect(postCount, equals(1));

      // Second call must resolve from in-memory cache with zero additional HTTP posts
      final details2 = await controller.getMealDetails('101');
      expect(identical(details1, details2), isTrue);
      expect(postCount, equals(1));
    });

    test(
        'getMealDetails returns null on network failure without corrupting state',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'meal_details_err');

      final client = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      final details = await controller.getMealDetails('999');
      expect(details, isNull);
      expect(controller.errorMessage, isNull);
    });
  });

  group('CampusRestoController — Budget Synchronization syncWithBudget', () {
    test(
        'syncWithBudget idempotently pushes check-in meal expenses to BudgetController',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'sync_sess');

      final client = MockClient((request) async {
        return http.Response(fullDashboardHtml, 200);
      });

      final controller = CampusRestoController(
        client: client,
        sessionStorage: storage,
      );

      await controller.refreshDashboard();
      expect(controller.checkIns.length, equals(3));

      final budgetController = BudgetController();

      // First sync
      await controller.syncWithBudget(budgetController);
      final initialTxCount = budgetController.transactions.length;
      expect(initialTxCount, equals(3));
      expect(
          budgetController.transactions
              .every((tx) => tx.category == 'Campus Dining'),
          isTrue);

      // Second consecutive sync — idempotent zero addition
      await controller.syncWithBudget(budgetController);
      expect(budgetController.transactions.length, equals(initialTxCount));
    });
  });

  group('CampusRestoController — Logout & State Purge', () {
    test(
        'logout() sends server disconnect, clears stored session, and wipes memory state',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'logout_token');

      bool disconnectCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.query.contains('p=users.disconnect')) {
          disconnectCalled = true;
          return http.Response('', 302,
              headers: {'location': '/?p=users.login'});
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

      await controller.refreshDashboard();
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));

      await controller.logout();

      expect(disconnectCalled, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.profile, isNull);
      expect(controller.dormInfo, isNull);
      expect(controller.kpis, isNull);
      expect(controller.weeklyMeals, isEmpty);
      expect(controller.checkIns, isEmpty);
      expect(controller.topUps, isEmpty);
      expect(await storage.hasSession(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CampusRestoController.offlineCacheKey), isNull);
    });

    test('clearError resets errorMessage reactively', () async {
      final controller = CampusRestoController();
      await controller.onLoginSuccess('invalid');
      expect(controller.errorMessage, isNotNull);

      controller.clearError();
      expect(controller.errorMessage, isNull);
    });

    test('parseAndLoadDashboard populates models and sets authenticated state',
        () async {
      final controller = CampusRestoController();
      expect(controller.isAuthenticated, isFalse);
      expect(controller.profile, isNull);

      await controller.parseAndLoadDashboard(fullDashboardHtml);

      expect(controller.isAuthenticated, isTrue);
      expect(controller.profile?.fullName, equals('Ahmed Ben Salah'));
      expect(controller.dormInfo?.chambre, equals('104'));
      expect(controller.kpis?.soldeRepas, equals(24));
      expect(controller.weeklyMeals, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CampusRestoController.offlineCacheKey), isNotNull);
    });

    test('setAuthenticated toggles authentication flag and notifies listeners',
        () {
      final controller = CampusRestoController();
      bool notified = false;
      controller.addListener(() => notified = true);

      expect(controller.isAuthenticated, isFalse);
      controller.setAuthenticated(true);
      expect(controller.isAuthenticated, isTrue);
      expect(notified, isTrue);
    });

    test(
        'unreservedMealsCount and unreservedMeals filter unreserved meals properly',
        () async {
      final controller = CampusRestoController();
      await controller.parseAndLoadDashboard(fullDashboardHtml);

      expect(controller.unreservedMealsCount, greaterThan(0));
      expect(controller.unreservedMeals.length,
          equals(controller.unreservedMealsCount));
      for (final meal in controller.unreservedMeals) {
        expect(meal.status, MealStatus.notReserved);
      }
    });

    test(
        'reserveAllUnreservedMeals reports progress and reserves meals sequentially',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('etd.posts.res')) {
          return http.Response('success', 200);
        }
        return http.Response(fullDashboardHtml, 200);
      });

      final sessionStorage = SessionStorageService();
      await sessionStorage.saveSession(phpSessId: 'session_valid_123');

      final controller = CampusRestoController(
        client: mockClient,
        sessionStorage: sessionStorage,
      );
      await controller.parseAndLoadDashboard(fullDashboardHtml);

      final initialUnreserved = controller.unreservedMealsCount;
      expect(initialUnreserved, greaterThan(0));

      final progressSteps = <int>[];
      final result = await controller.reserveAllUnreservedMeals(
        onProgress: (current, total, meal) {
          progressSteps.add(current);
        },
      );

      expect(result.total, equals(initialUnreserved));
      expect(result.succeeded, equals(initialUnreserved));
      expect(result.failed, equals(0));
      expect(result.isFullSuccess, isTrue);
      expect(progressSteps.length, equals(initialUnreserved));
    });
  });
}

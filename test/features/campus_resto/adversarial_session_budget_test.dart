import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_auth_service.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_budget_sync_service.dart';
import 'package:studenthold_app/features/campus_resto/services/session_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BudgetController budgetController;
  late RestoBudgetSyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    budgetController = BudgetController();
    syncService = const RestoBudgetSyncService();
  });

  final testCheckIns = [
    RestoCheckIn(
      id: 'c1',
      timestamp: DateTime(2026, 11, 6, 12, 45, 12),
      quantity: 1,
      cin: '09876543',
      mealType: MealType.dejeuner,
    ),
    RestoCheckIn(
      id: 'c2',
      timestamp: DateTime(2026, 11, 5, 19, 15, 30),
      quantity: 1,
      cin: '09876543',
      mealType: MealType.diner,
    ),
    RestoCheckIn(
      id: 'c3',
      timestamp: DateTime(2026, 11, 5, 12, 30, 0),
      quantity: 2,
      cin: '09876543',
      mealType: MealType.dejeuner,
    ),
  ];

  final testTopUps = [
    RestoTopUp(
      id: 't1',
      timestamp: DateTime(2026, 11, 1, 9, 14, 22),
      mealCount: 20,
      cin: '09876543',
    ),
    RestoTopUp(
      id: 't2',
      timestamp: DateTime(2026, 10, 15, 14, 20, 0),
      mealCount: 10,
      cin: '09876543',
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 1: RestoBudgetSyncService Stress & Idempotency Testing
  // ═══════════════════════════════════════════════════════════════════════════
  group(
      'ADV-1: RestoBudgetSyncService — 10x Repetition & High Stress Idempotency',
      () {
    test(
        '10 consecutive syncs on identical data adds expenses exactly once and 0 duplicates',
        () async {
      int totalAddedAcrossRuns = 0;

      for (int i = 1; i <= 10; i++) {
        final added = await syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        );
        totalAddedAcrossRuns += added;

        if (i == 1) {
          expect(added, equals(5),
              reason:
                  'First run must add all 5 items (3 check-ins + 2 top-ups)');
        } else {
          expect(added, equals(0),
              reason: 'Run #$i must add 0 duplicate expenses');
        }
      }

      expect(totalAddedAcrossRuns, equals(5));
      expect(budgetController.transactions.length, equals(5),
          reason:
              'BudgetController must hold exactly 5 transactions after 10 sync runs');

      final syncedCount = await syncService.getSyncedHashesCount();
      expect(syncedCount, equals(5));
    });

    test(
        'Input list containing internal duplicates is deduplicated in a single sync run',
        () async {
      // Create a list with the same check-in repeated 5 times
      final duplicateList = [
        testCheckIns[0],
        testCheckIns[0],
        testCheckIns[0],
        testCheckIns[1],
        testCheckIns[1],
      ];

      final added = await syncService.syncTransactions(
        topUps: [],
        checkIns: duplicateList,
        budgetController: budgetController,
        mode: RestoSyncMode.checkIns,
      );

      expect(added, equals(2),
          reason:
              'Internal duplicates must be deduplicated via syncedHashes set');
      expect(budgetController.transactions.length, equals(2));
    });

    test(
        'Concurrent sync invocations via Future.wait do not create duplicate expenses',
        () async {
      // Launch 5 parallel sync invocations simultaneously
      final results = await Future.wait([
        syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        ),
        syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        ),
        syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        ),
        syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        ),
        syncService.syncTransactions(
          topUps: testTopUps,
          checkIns: testCheckIns,
          budgetController: budgetController,
          mode: RestoSyncMode.both,
        ),
      ]);

      final totalReportedAdded =
          results.fold<int>(0, (sum, count) => sum + count);
      expect(totalReportedAdded, equals(5),
          reason:
              'Sum of added items reported across concurrent syncs must be 5');
      // Let's verify whether BudgetController has duplicates under concurrent execution
      expect(budgetController.transactions.length, equals(5),
          reason:
              'Concurrent syncs must result in exactly 5 transactions in BudgetController');
    });

    test(
        'Handles 1,000 transaction records under single sync without timeout or memory error',
        () async {
      final largeCheckIns = List.generate(
        1000,
        (i) => RestoCheckIn(
          id: 'bulk_$i',
          timestamp: DateTime(2026, 1, 1).add(Duration(hours: i)),
          quantity: 1,
          cin: 'CIN$i',
          mealType: i % 2 == 0 ? MealType.dejeuner : MealType.diner,
        ),
      );

      final added = await syncService.syncTransactions(
        topUps: [],
        checkIns: largeCheckIns,
        budgetController: budgetController,
      );

      expect(added, equals(1000));
      expect(budgetController.transactions.length, equals(1000));
      expect(await syncService.getSyncedHashesCount(), equals(1000));
    });

    test(
        'Boundary values: check-in with 0 quantity produces 0.000 DT expense without crashing',
        () async {
      final zeroCheckIn = RestoCheckIn(
        id: 'zero',
        timestamp: DateTime(2026, 11, 6, 12, 0, 0),
        quantity: 0,
        cin: '09876543',
        mealType: MealType.dejeuner,
      );

      final added = await syncService.syncTransactions(
        topUps: [],
        checkIns: [zeroCheckIn],
        budgetController: budgetController,
      );

      expect(added, equals(1));
      expect(budgetController.transactions.first.amount, equals(0.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 2: Corrupted SharedPreferences Hash Registry
  // ═══════════════════════════════════════════════════════════════════════════
  group('ADV-2: RestoBudgetSyncService — Corrupted SharedPreferences Registry',
      () {
    test(
        'Handles SharedPreferences containing empty strings and strange characters in hash list',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(RestoBudgetSyncService.storageKey, [
        '',
        '   ',
        'corrupted_invalid_hash_string',
        'resto_checkin_09876543_2026-11-06T12:45:12.000_1_dejeuner',
      ]);

      // Now sync with testCheckIns. testCheckIns[0] has the exact hash above!
      final added = await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );

      // Only checkIns[1] and checkIns[2] should be added because checkIns[0] was already recorded
      expect(added, equals(2));
      expect(budgetController.transactions.length, equals(2));
    });

    test(
        'Probes behavior when storage key holds unexpected non-List type in SharedPreferences',
        () async {
      final prefs = await SharedPreferences.getInstance();
      // Set storageKey to a String instead of a List<String>
      await prefs.setString(
          RestoBudgetSyncService.storageKey, 'corrupted_raw_string');

      // Check whether syncTransactions crashes or handles the type mismatch
      try {
        await syncService.syncTransactions(
          topUps: [],
          checkIns: testCheckIns,
          budgetController: budgetController,
        );
      } catch (e) {
        // We capture any crash for our adversarial report
        expect(e, isA<TypeError>(),
            reason:
                'SharedPreferences getStringList throws TypeError if key stores a String');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 3: RestoAuthService Network Failures & Connection Stress
  // ═══════════════════════════════════════════════════════════════════════════
  group('ADV-3: RestoAuthService — Network Stress & Error Resilience', () {
    test(
        'Simulated SocketException ("Connection refused") returns networkError and preserves session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'valid_sess_keep_me');

      final client = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.status, equals(SessionStatus.networkError));
      expect(result.isNetworkError, isTrue);
      expect(result.message, contains('Connection refused'));
      // Critical: Session must NEVER be purged on temporary network failure
      expect(await storage.hasSession(), isTrue);
      expect((await storage.getSession())?.phpSessId,
          equals('valid_sess_keep_me'));
    });

    test(
        'Simulated HttpException ("Connection closed prematurely") returns networkError without crash',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'premature_close_token');

      final client = MockClient((request) async {
        throw const HttpException(
            'Connection closed before full header was received');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isNetworkError, isTrue);
      expect(result.message, contains('Connection closed'));
      expect(await storage.hasSession(), isTrue);
    });

    test(
        'Simulated HandshakeException (TLS/SSL certificate failure) returns networkError without crash',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'tls_fail_token');

      final client = MockClient((request) async {
        throw const HandshakeException(
            'Handshake error in client (CERTIFICATE_VERIFY_FAILED)');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isNetworkError, isTrue);
      expect(await storage.hasSession(), isTrue);
    });

    test(
        'Slow response exceeding configured timeout triggers TimeoutException and returns networkError',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'slow_portal_token');

      final client = MockClient((request) async {
        // Delay beyond service timeout
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response('{"session":"valid"}', 200);
      });

      // Use a very short timeout of 20ms to trigger timeout
      final service = RestoAuthService(
        client: client,
        sessionStorage: storage,
        timeout: const Duration(milliseconds: 20),
      );
      final result = await service.checkSession();

      expect(result.isNetworkError, isTrue);
      expect(result.message, contains('timed out'));
      expect(await storage.hasSession(), isTrue);
    });

    test(
        'HTTP 502 Bad Gateway and 504 Gateway Timeout return serverError without purging session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'gateway_error_token');

      for (final code in [502, 503, 504]) {
        final client = MockClient((request) async {
          return http.Response('Bad Gateway / Server Down', code);
        });

        final service =
            RestoAuthService(client: client, sessionStorage: storage);
        final result = await service.checkSession();

        expect(result.isServerError, isTrue);
        expect(result.message, contains('$code'));
        expect(await storage.hasSession(), isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 4: RestoAuthService Malformed JSON & Adversarial Payloads
  // ═══════════════════════════════════════════════════════════════════════════
  group(
      'ADV-4: RestoAuthService — Malformed JSON & Adversarial Server Payloads',
      () {
    test(
        'Handles malformed JSON syntax (unquoted keys, trailing commas) safely',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'malformed_json_token');

      final malformedBodies = [
        '{session: valid}', // Unquoted keys and values
        '{"session": "valid",,}', // Extra comma
        '{"session":', // Truncated JSON
        '', // Completely empty body
        '   \n\t  ', // Whitespace only
        '<!DOCTYPE html><html><body>Error 500</body></html>', // HTML error page with 200 OK
      ];

      for (final body in malformedBodies) {
        final client = MockClient((request) async {
          return http.Response(body, 200);
        });

        final service =
            RestoAuthService(client: client, sessionStorage: storage);
        final result = await service.checkSession();

        expect(result.isValid, isFalse,
            reason: 'Malformed payload must not be marked valid: $body');
        // Must not throw an unhandled FormatException
        expect(result.status,
            isIn([SessionStatus.serverError, SessionStatus.expired]));
      }
    });

    test('Detects login page HTML returned with HTTP 200 as expired session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'html_redirect_token');

      const loginHtmlBody = '''
      <!DOCTYPE html>
      <html>
        <head><title>Connexion</title></head>
        <body>
          <form action="/?p=users.login" method="post">
            <input type="text" name="cin" placeholder="Numéro CIN"/>
            <button type="submit">Se connecter</button>
          </form>
        </body>
      </html>
      ''';

      final client = MockClient((request) async {
        return http.Response(loginHtmlBody, 200);
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isExpired, isTrue,
          reason: 'HTML containing users.login must be flagged as expired');
    });

    test(
        'Handles unexpected JSON data types (numbers, arrays, booleans, nested maps)',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'unexpected_json_types');

      final unexpectedBodies = [
        '[1, 2, 3]', // Array instead of object
        '{"session": true}', // Boolean instead of string
        '{"session": 12345}', // Number instead of string
        '{"session": {"nested": "valid"}}', // Map instead of string
        '{"session": null}', // Null value
        '{"status": "ok", "user": "admin"}', // Valid JSON but missing "session" key
      ];

      for (final body in unexpectedBodies) {
        final client = MockClient((request) async {
          return http.Response(body, 200);
        });

        final service =
            RestoAuthService(client: client, sessionStorage: storage);
        final result = await service.checkSession();

        expect(result.isValid, isFalse,
            reason: 'Unexpected structure must not be valid: $body');
        expect(result.status, equals(SessionStatus.serverError));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION 5: Cookie Injection, Whitespace & Adversarial Cookie Parsing
  // ═══════════════════════════════════════════════════════════════════════════
  group('ADV-5: Cookie Utilities & Injection Resistance', () {
    test(
        'parseCookieHeader handles weird characters, extra delimiters, and URL-encoded values',
        () {
      const header =
          '  ;;  PHPSESSID=abc%20123+xyz; ; cookiesession1=waf%3Dval;  evil=; =emptyKey; foo=bar=baz; ';
      final map = RestoAuthService.parseCookieHeader(header);

      expect(map['PHPSESSID'], equals('abc%20123+xyz'));
      expect(map['cookiesession1'], equals('waf%3Dval'));
      expect(map['foo'], equals('bar=baz'));
      expect(map.containsKey(''), isFalse,
          reason: 'Empty keys must not be added to map');
    });

    test(
        'Cookie injection attempt: extra semicolons and fake credentials are isolated',
        () {
      const injection =
          'PHPSESSID=legit123; admin=true; role=superadmin; token="xyz;injection"';
      final parsed = RestoAuthService.parseCookies(injection);

      expect(parsed, isNotNull);
      expect(parsed!.phpSessId, equals('legit123'));
      // Only PHPSESSID and cookiesession1 should be emitted in toCookieHeader
      expect(parsed.toCookieHeader(), equals('PHPSESSID=legit123'));
      expect(parsed.toCookieHeader().contains('admin=true'), isFalse,
          reason:
              'Unauthorized injected attributes must not leak into generated cookie header');
    });

    test(
        'SessionStorageService rejects whitespace or empty PHPSESSID with ArgumentError',
        () async {
      final storage = SessionStorageService();

      expect(
        () async => await storage.saveSession(phpSessId: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () async => await storage.saveSession(phpSessId: '   \t\n  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'SessionStorageService saveFromCookieHeader extracts and trims PHPSESSID from messy headers without space before equals',
        () async {
      final storage = SessionStorageService();
      await storage.saveFromCookieHeader(
          '  random_key=value; PHPSESSID=  clean_token_7788  ; other=123 ');

      final session = await storage.getSession();
      expect(session, isNotNull);
      expect(session!.phpSessId, equals('clean_token_7788'));
      expect(await storage.getCookieHeader(),
          equals('PHPSESSID=clean_token_7788'));
    });

    test(
        'SessionStorageService saveFromCookieHeader fails when space precedes equals sign due to strict regex',
        () async {
      final storage = SessionStorageService();
      // Space between cookie name and equals: "PHPSESSID = token"
      expect(
        () async => await storage
            .saveFromCookieHeader('random=1; PHPSESSID = clean_token; other=2'),
        throwsA(isA<ArgumentError>()),
        reason:
            'SessionStorageService._extractCookie regex requires no whitespace immediately preceding =',
      );
    });

    test(
        'Overlapping concurrent sync subsets merge into exactly the unique union of items',
        () async {
      final subset1 = [testCheckIns[0], testCheckIns[1]];
      final subset2 = [testCheckIns[1], testCheckIns[2]];
      final subset3 = [testCheckIns[0], testCheckIns[2]];

      final results = await Future.wait([
        syncService.syncTransactions(
            topUps: [], checkIns: subset1, budgetController: budgetController),
        syncService.syncTransactions(
            topUps: [], checkIns: subset2, budgetController: budgetController),
        syncService.syncTransactions(
            topUps: [], checkIns: subset3, budgetController: budgetController),
      ]);

      final totalNew = results.fold<int>(0, (sum, count) => sum + count);
      expect(totalNew, equals(3),
          reason:
              'Total new transactions across overlapping subsets must be 3');
      expect(budgetController.transactions.length, equals(3));
      expect(await syncService.getSyncedHashesCount(), equals(3));
    });

    test(
        'Interleaved syncs: repeating previous items while introducing new items adds only the delta',
        () async {
      // Step 1: sync first 2 check-ins
      final r1 = await syncService.syncTransactions(
        topUps: [],
        checkIns: [testCheckIns[0], testCheckIns[1]],
        budgetController: budgetController,
      );
      expect(r1, equals(2));
      expect(budgetController.transactions.length, equals(2));

      // Step 2: repeat first 2 check-ins
      final r2 = await syncService.syncTransactions(
        topUps: [],
        checkIns: [testCheckIns[0], testCheckIns[1]],
        budgetController: budgetController,
      );
      expect(r2, equals(0));
      expect(budgetController.transactions.length, equals(2));

      // Step 3: sync all 3 check-ins + 1 top-up
      final r3 = await syncService.syncTransactions(
        topUps: [testTopUps[0]],
        checkIns: testCheckIns,
        budgetController: budgetController,
        mode: RestoSyncMode.both,
      );
      expect(r3, equals(2), reason: '1 new check-in + 1 new top-up');
      expect(budgetController.transactions.length, equals(4));

      // Step 4: repeat all 3 check-ins + 1 top-up
      final r4 = await syncService.syncTransactions(
        topUps: [testTopUps[0]],
        checkIns: testCheckIns,
        budgetController: budgetController,
        mode: RestoSyncMode.both,
      );
      expect(r4, equals(0));
      expect(budgetController.transactions.length, equals(4));
    });

    test(
        'Calculated expense amount in BudgetController is exact to 3 decimal places',
        () async {
      // testCheckIns: c1(qty:1) = 0.200, c2(qty:1) = 0.200, c3(qty:2) = 0.400 -> total 0.800 DT
      // testTopUps: t1(20 meals) = 4.000 DT, t2(10 meals) = 2.000 DT -> total 6.000 DT
      await syncService.syncTransactions(
        topUps: testTopUps,
        checkIns: testCheckIns,
        budgetController: budgetController,
        mode: RestoSyncMode.both,
      );

      final totalSpent = budgetController.transactions
          .fold<double>(0.0, (sum, tx) => sum + tx.amount);
      expect(totalSpent, closeTo(6.800, 0.0001));
    });
  });
}

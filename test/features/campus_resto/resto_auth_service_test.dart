import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/main.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_auth_service.dart';
import 'package:studenthold_app/features/campus_resto/services/session_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RestoAuthService — Tier 1: Core Functional Coverage', () {
    test(
        '1. checkSession returns SessionStatus.valid when server responds {"session":"valid"}',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'active_session_123');

      final client = MockClient((request) async {
        expect(request.url.path, equals('/admin/api/check-session.php'));
        expect(request.headers['Cookie'],
            contains('PHPSESSID=active_session_123'));
        return http.Response(jsonEncode({'session': 'valid'}), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isValid, isTrue);
      expect(result.status, equals(SessionStatus.valid));
      expect(await storage.getLastChecked(), isNotNull);
    });

    test(
        '2. checkSession returns SessionStatus.expired when server responds {"session":"expired"}',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'expired_session_456');

      final client = MockClient((request) async {
        return http.Response(jsonEncode({'session': 'expired'}), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isExpired, isTrue);
      expect(result.status, equals(SessionStatus.expired));
    });

    test(
        '3. checkSession formats and passes both PHPSESSID and cookiesession1 in request header',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(
        phpSessId: 'sess_part1',
        cookieSession1: 'waf_part2',
      );

      String? recordedCookie;
      final client = MockClient((request) async {
        recordedCookie = request.headers['Cookie'];
        return http.Response('{"session":"valid"}', 200);
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      await service.checkSession();

      expect(recordedCookie,
          equals('PHPSESSID=sess_part1; cookiesession1=waf_part2'));
    });

    test(
        '4. checkSession returns SessionStatus.expired when redirected to /?p=users.login',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'redirect_token');

      final client = MockClient((request) async {
        return http.Response('', 302, headers: {
          'location': '/?p=users.login',
        });
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isExpired, isTrue);
      expect(result.status, equals(SessionStatus.expired));
    });

    test(
        '5. disconnect issues POST request with Cookie and clears SessionStorageService',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'session_to_disconnect');

      bool postExecuted = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.query.contains('p=users.disconnect')) {
          postExecuted = true;
          expect(request.headers['Cookie'],
              contains('PHPSESSID=session_to_disconnect'));
          return http.Response('', 302,
              headers: {'location': '/?p=users.login'});
        }
        return http.Response('Not found', 404);
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final disconnected = await service.disconnect();

      expect(disconnected, isTrue);
      expect(postExecuted, isTrue);
      expect(await storage.hasSession(), isFalse);
    });
  });

  group('RestoAuthService — Tier 2: Boundary & Adversarial Cases', () {
    test(
        '1. checkSession returns expired immediately without network request when no cookie is stored',
        () async {
      final storage = SessionStorageService();
      bool networkHit = false;

      final client = MockClient((request) async {
        networkHit = true;
        return http.Response('{"session":"valid"}', 200);
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(networkHit, isFalse);
      expect(result.isExpired, isTrue);
    });

    test(
        '2. checkSession returns networkError on TimeoutException without clearing local session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'timeout_token');

      final client = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isNetworkError, isTrue);
      expect(result.status, equals(SessionStatus.networkError));
      // Local session MUST NOT be cleared on timeout
      expect(await storage.hasSession(), isTrue);
    });

    test(
        '3. checkSession returns networkError on SocketException without clearing local session',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'offline_token');

      final client = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isNetworkError, isTrue);
      expect(await storage.hasSession(), isTrue);
    });

    test('4. checkSession returns serverError on HTTP 500 without crashing',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'err_token');

      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final result = await service.checkSession();

      expect(result.isServerError, isTrue);
      expect(result.status, equals(SessionStatus.serverError));
    });

    test(
        '5. disconnect clears local session storage even if network request throws exception',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'throw_token');

      final client = MockClient((request) async {
        throw const SocketException('Connection lost');
      });

      final service = RestoAuthService(client: client, sessionStorage: storage);
      final disconnected = await service.disconnect();

      expect(disconnected, isTrue);
      // Local session MUST be wiped even on connection loss
      expect(await storage.hasSession(), isFalse);
    });
  });

  group('RestoAuthService — Static Cookie Utilities', () {
    test(
        'parseCookieHeader handles messy whitespace, equals signs, and trailing semicolons',
        () {
      const header =
          '  PHPSESSID = abc123xyz ;  cookiesession1=waf999;  foo=bar=baz;  ';
      final map = RestoAuthService.parseCookieHeader(header);

      expect(map['PHPSESSID'], equals('abc123xyz'));
      expect(map['cookiesession1'], equals('waf999'));
      expect(map['foo'], equals('bar=baz'));
    });

    test('parseCookies extracts SessionCookies model accurately', () {
      const header = 'PHPSESSID=session_88; cookiesession1=waf_44; path=/';
      final cookies = RestoAuthService.parseCookies(header);

      expect(cookies, isNotNull);
      expect(cookies!.phpSessId, equals('session_88'));
      expect(cookies.cookieSession1, equals('waf_44'));
      expect(cookies.toCookieHeader(),
          equals('PHPSESSID=session_88; cookiesession1=waf_44'));
    });

    test('parseSetCookieHeaders extracts cookies from response header list',
        () {
      final setCookies = [
        'PHPSESSID=sess_header_1; path=/; Max-Age=86400',
        'cookiesession1=waf_header_2; Expires=Sat, 06 Nov 2027 17:55:33 GMT; Path=/; HttpOnly',
      ];
      final cookies = RestoAuthService.parseSetCookieHeaders(setCookies);

      expect(cookies, isNotNull);
      expect(cookies!.phpSessId, equals('sess_header_1'));
      expect(cookies.cookieSession1, equals('waf_header_2'));
    });
  });

  group('CampusHttpOverrides — SSL Handshake Resilience', () {
    test(
        'CampusHttpOverrides.verifyCertificate accepts university domains and rejects foreign hosts',
        () {
      expect(
          CampusHttpOverrides.verifyCertificate(null, 'cukl.ooun.rnu.tn', 443),
          isTrue);
      expect(CampusHttpOverrides.verifyCertificate(null, 'portal.rnu.tn', 443),
          isTrue);
      expect(
          CampusHttpOverrides.verifyCertificate(null, 'evil-hacker.com', 443),
          isFalse);
    });

    test(
        'CampusHttpOverrides createHttpClient configures an HttpClient without error',
        () {
      final overrides = CampusHttpOverrides();
      final client = overrides.createHttpClient(null);
      expect(client, isA<HttpClient>());
    });
  });
}

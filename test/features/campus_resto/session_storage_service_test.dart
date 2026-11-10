import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/features/campus_resto/services/session_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SessionStorageService — Tier 1: Core Functional Coverage', () {
    test(
        '1. saveSession stores PHPSESSID and getSession retrieves it accurately',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(phpSessId: 'sess_abc123456');

      final session = await storage.getSession();
      expect(session, isNotNull);
      expect(session!.phpSessId, equals('sess_abc123456'));
      expect(session.cookieSession1, isNull);
      expect(await storage.hasSession(), isTrue);
    });

    test(
        '2. saveSession with both PHPSESSID and cookiesession1 preserves both and formats header',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(
        phpSessId: 'php_98765',
        cookieSession1: 'waf_54321',
      );

      final session = await storage.getSession();
      expect(session, isNotNull);
      expect(session!.phpSessId, equals('php_98765'));
      expect(session.cookieSession1, equals('waf_54321'));

      final header = await storage.getCookieHeader();
      expect(header, equals('PHPSESSID=php_98765; cookiesession1=waf_54321'));
    });

    test('3. saveFromCookieHeader parses and persists raw cookie string',
        () async {
      final storage = SessionStorageService();
      await storage.saveFromCookieHeader(
          'PHPSESSID=live_token_77; cookiesession1=waf_token_88; path=/');

      final session = await storage.getSession();
      expect(session, isNotNull);
      expect(session!.phpSessId, equals('live_token_77'));
      expect(session.cookieSession1, equals('waf_token_88'));
      expect(await storage.hasSession(), isTrue);
    });

    test('4. clearSession purges all keys and hasSession returns false',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(
          phpSessId: 'token_to_delete', cookieSession1: 'waf_to_delete');
      expect(await storage.hasSession(), isTrue);

      await storage.clearSession();

      expect(await storage.getSession(), isNull);
      expect(await storage.getCookieHeader(), isNull);
      expect(await storage.hasSession(), isFalse);
    });

    test(
        '5. getSession on clean zero-base storage returns null without throwing',
        () async {
      final storage = SessionStorageService();
      final session = await storage.getSession();
      expect(session, isNull);
      expect(await storage.getCookieHeader(), isNull);
      expect(await storage.hasSession(), isFalse);
    });
  });

  group('SessionStorageService — Tier 2: Boundary & Edge Cases', () {
    test('1. throws ArgumentError when saving empty or whitespace PHPSESSID',
        () async {
      final storage = SessionStorageService();
      expect(() => storage.saveSession(phpSessId: ''), throwsArgumentError);
      expect(() => storage.saveSession(phpSessId: '   '), throwsArgumentError);
    });

    test('2. throws ArgumentError when saveFromCookieHeader lacks PHPSESSID',
        () async {
      final storage = SessionStorageService();
      expect(
        () => storage.saveFromCookieHeader('some_other_cookie=12345; path=/'),
        throwsArgumentError,
      );
    });

    test(
        '3. multiple clearSession calls on empty storage succeed without error',
        () async {
      final storage = SessionStorageService();
      await storage.clearSession();
      await storage.clearSession();
      expect(await storage.hasSession(), isFalse);
    });

    test('4. updating session overwrites old cookies cleanly without remnants',
        () async {
      final storage = SessionStorageService();
      await storage.saveSession(
          phpSessId: 'old_sess', cookieSession1: 'old_waf');
      expect((await storage.getSession())!.phpSessId, equals('old_sess'));

      // Overwrite with new PHPSESSID and no cookieSession1
      await storage.saveSession(phpSessId: 'new_sess');
      final updated = await storage.getSession();
      expect(updated!.phpSessId, equals('new_sess'));
      expect(updated.cookieSession1, isNull);
    });

    test('5. updateLastChecked and getLastChecked accurately record timestamps',
        () async {
      final storage = SessionStorageService();
      final target = DateTime(2026, 11, 6, 18, 0, 0);

      await storage.updateLastChecked(target);
      final readBack = await storage.getLastChecked();

      expect(readBack, isNotNull);
      expect(readBack!.year, equals(2026));
      expect(readBack.month, equals(11));
      expect(readBack.day, equals(6));
      expect(readBack.hour, equals(18));
    });
  });
}

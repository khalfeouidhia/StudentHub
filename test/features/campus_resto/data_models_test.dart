import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';

void main() {
  group('DormInfo Model Tests', () {
    test('DormInfo.empty returns default placeholders', () {
      const dorm = DormInfo.empty();
      expect(dorm.foyer, 'Non assigné');
      expect(dorm.bloc, '-');
      expect(dorm.chambre, '-');
      expect(dorm.hasAssignment, isFalse);
      expect(dorm.roomDisplay, 'Non assigné');
    });

    test('DormInfo formatted roomDisplay with bloc and chambre', () {
      const dorm = DormInfo(foyer: 'Cité U', bloc: 'A', chambre: '204');
      expect(dorm.hasAssignment, isTrue);
      expect(dorm.roomDisplay, 'Bloc A • Ch. 204');
    });

    test('DormInfo formatted roomDisplay without bloc', () {
      const dorm = DormInfo(foyer: 'Cité U', bloc: '-', chambre: '12');
      expect(dorm.hasAssignment, isTrue);
      expect(dorm.roomDisplay, 'Ch. 12');
    });

    test('DormInfo serialization / deserialization roundtrip', () {
      const dorm = DormInfo(foyer: 'Foyer Kélibia', bloc: 'B', chambre: '101');
      final json = dorm.toJson();
      final reconstructed = DormInfo.fromJson(json);

      expect(reconstructed, equals(dorm));
      expect(reconstructed.hashCode, equals(dorm.hashCode));
    });

    test('DormInfo copyWith modifies specified fields', () {
      const dorm = DormInfo(foyer: 'Foyer', bloc: 'A', chambre: '1');
      final updated = dorm.copyWith(chambre: '2');
      expect(updated.foyer, 'Foyer');
      expect(updated.bloc, 'A');
      expect(updated.chambre, '2');
    });
  });

  group('StudentProfile Model Tests', () {
    test('StudentProfile.empty returns default values', () {
      const profile = StudentProfile.empty();
      expect(profile.fullName, 'Étudiant');
      expect(profile.firstName, 'Étudiant');
      expect(profile.initials, 'É');
      expect(profile.cin, isEmpty);
      expect(profile.dorm.hasAssignment, isFalse);
    });

    test('StudentProfile firstName and initials calculation', () {
      const profile = StudentProfile(
        fullName: 'Ahmed Ben Salah',
        cin: '09876543',
        dorm: DormInfo(foyer: 'Foyer', bloc: 'C', chambre: '15'),
      );
      expect(profile.firstName, 'Ahmed');
      expect(profile.initials, 'AS');
    });

    test('StudentProfile single name initials calculation', () {
      const profile = StudentProfile(
        fullName: 'Nader',
        dorm: DormInfo.empty(),
      );
      expect(profile.firstName, 'Nader');
      expect(profile.initials, 'N');
    });

    test('StudentProfile serialization / deserialization roundtrip', () {
      const profile = StudentProfile(
        fullName: 'Sami Mansour',
        cin: '12345678',
        dorm: DormInfo(foyer: 'Cité 1', bloc: 'D', chambre: '44'),
      );
      final json = profile.toJson();
      final fromJson = StudentProfile.fromJson(json);

      expect(fromJson, equals(profile));
      expect(fromJson.hashCode, equals(profile.hashCode));
    });

    test('StudentProfile copyWith creates modified instance', () {
      const profile = StudentProfile(fullName: 'Ali', dorm: DormInfo.empty());
      final updated = profile.copyWith(fullName: 'Ali Baba');
      expect(updated.fullName, 'Ali Baba');
      expect(updated.dorm, equals(profile.dorm));
    });
  });

  group('WalletKpis Model Tests', () {
    test('WalletKpis.empty returns zero-based defaults', () {
      const kpis = WalletKpis.empty();
      expect(kpis.soldeRepas, 0);
      expect(kpis.totalAchatMois, 0);
      expect(kpis.depensesMois, 0.0);
      expect(kpis.currency, 'DT');
      expect(kpis.hasBalance, isFalse);
      expect(kpis.isLowBalance, isTrue);
      expect(kpis.formattedDepenses, '0.000 DT');
    });

    test('WalletKpis balance threshold indicators', () {
      const kpisHigh =
          WalletKpis(soldeRepas: 10, totalAchatMois: 20, depensesMois: 4.0);
      expect(kpisHigh.hasBalance, isTrue);
      expect(kpisHigh.isLowBalance, isFalse);

      const kpisLow =
          WalletKpis(soldeRepas: 2, totalAchatMois: 20, depensesMois: 3.6);
      expect(kpisLow.hasBalance, isTrue);
      expect(kpisLow.isLowBalance, isTrue);
    });

    test('WalletKpis serialization / deserialization roundtrip', () {
      const kpis = WalletKpis(
        soldeRepas: 24,
        totalAchatMois: 40,
        depensesMois: 3.200,
        currency: 'DT',
      );
      final json = kpis.toJson();
      final fromJson = WalletKpis.fromJson(json);

      expect(fromJson, equals(kpis));
      expect(fromJson.formattedDepenses, '3.200 DT');
    });

    test('WalletKpis copyWith modifies specified metrics', () {
      const kpis = WalletKpis.empty();
      final updated = kpis.copyWith(soldeRepas: 15, depensesMois: 1.500);
      expect(updated.soldeRepas, 15);
      expect(updated.depensesMois, 1.500);
      expect(updated.totalAchatMois, 0);
    });
  });

  group('CampusMealItem & Enums Tests', () {
    test('MealType.fromString parses variations robustly', () {
      expect(MealType.fromString('Déjeuner'), MealType.dejeuner);
      expect(MealType.fromString('dejeuner'), MealType.dejeuner);
      expect(MealType.fromString('Dîner'), MealType.diner);
      expect(MealType.fromString('diner'), MealType.diner);
      expect(MealType.fromString('other'), MealType.unknown);
      expect(MealType.fromString(null), MealType.unknown);
    });

    test('MealStatus.fromString parses variations accurately', () {
      expect(MealStatus.fromString('Réservé'), MealStatus.reserved);
      expect(MealStatus.fromString('reserve'), MealStatus.reserved);
      expect(MealStatus.fromString('Non réservé'), MealStatus.notReserved);
      expect(MealStatus.fromString('non reserve'), MealStatus.notReserved);
      expect(MealStatus.fromString('Consommé'), MealStatus.consumed);
      expect(MealStatus.fromString('consomme'), MealStatus.consumed);
      expect(MealStatus.fromString('autre'), MealStatus.unknown);
      expect(MealStatus.fromString(null), MealStatus.unknown);
    });

    test('CampusMealItem computed getters and dateKey format', () {
      final item = CampusMealItem(
        id: '101',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 9),
        dayLabel: 'Lundi',
        status: MealStatus.reserved,
      );

      expect(item.isReserved, isTrue);
      expect(item.isConsumed, isFalse);
      expect(item.isAvailableToReserve, isFalse);
      expect(item.dateKey, '2026-11-09');
    });

    test('CampusMealItem serialization / deserialization roundtrip', () {
      final item = CampusMealItem(
        id: '104',
        type: MealType.diner,
        date: DateTime(2026, 11, 10, 19, 0),
        dayLabel: 'Mardi',
        status: MealStatus.consumed,
        rawStatusText: 'Consommé',
      );

      final json = item.toJson();
      final fromJson = CampusMealItem.fromJson(json);

      expect(fromJson.id, item.id);
      expect(fromJson.type, item.type);
      expect(fromJson.status, item.status);
      expect(fromJson.dayLabel, item.dayLabel);
    });
  });

  group('RestoCheckIn & RestoTopUp History Models Tests', () {
    test('RestoCheckIn roundtrip serialization', () {
      final checkIn = RestoCheckIn(
        id: 'checkin_1',
        timestamp: DateTime(2026, 11, 6, 12, 45, 12),
        quantity: 1,
        cin: '09876543',
        mealType: MealType.dejeuner,
      );

      final json = checkIn.toJson();
      final fromJson = RestoCheckIn.fromJson(json);

      expect(fromJson.id, checkIn.id);
      expect(fromJson.quantity, 1);
      expect(fromJson.cin, '09876543');
      expect(fromJson.mealType, MealType.dejeuner);
    });

    test(
        'RestoTopUp computedAmount and toExpenseItem with Campus Dining category',
        () {
      final topUp = RestoTopUp(
        id: 'topup_1',
        timestamp: DateTime(2026, 11, 1, 9, 14, 22),
        mealCount: 20,
        cin: '09876543',
      );

      expect(topUp.computedAmount, 4.000);
      expect(topUp.formattedAmount, '4.000 DT');

      final expense = topUp.toExpenseItem();
      expect(expense.id, 'resto-topup-topup_1');
      expect(expense.title, 'Recharge Resto U (20 repas)');
      expect(expense.amount, 4.000);
      expect(expense.category, 'Campus Dining');
      expect(expense.date, topUp.timestamp);
    });

    test('RestoTopUp explicitAmount overrides calculation', () {
      final topUp = RestoTopUp(
        id: 'topup_2',
        timestamp: DateTime(2026, 11, 1),
        mealCount: 10,
        cin: '09876543',
        explicitAmount: 2.500,
      );

      expect(topUp.computedAmount, 2.500);
      expect(topUp.formattedAmount, '2.500 DT');
    });
  });

  group('MealDetails & MealDishItem Tests', () {
    test('MealDishItem fullImageUrl resolves relative and absolute paths', () {
      const dishRel = MealDishItem(
        courseType: 'Entrée',
        name: 'Salade',
        imageRelativeUrl: 'images/plat/entree/CP_1.jpg',
      );
      expect(dishRel.hasImage, isTrue);
      expect(dishRel.fullImageUrl(),
          'https://cukl.ooun.rnu.tn/images/plat/entree/CP_1.jpg');

      const dishAbs = MealDishItem(
        courseType: 'Plat',
        name: 'Couscous',
        imageRelativeUrl: 'https://cdn.example.com/couscous.jpg',
      );
      expect(dishAbs.fullImageUrl(), 'https://cdn.example.com/couscous.jpg');

      const dishNoImg = MealDishItem(courseType: 'Dessert', name: 'Pomme');
      expect(dishNoImg.hasImage, isFalse);
      expect(dishNoImg.fullImageUrl(), isNull);
    });

    test('MealDetails empty constructor and mainCourse resolution', () {
      final empty = MealDetails.empty('101');
      expect(empty.repasId, '101');
      expect(empty.isEmpty, isTrue);
      expect(empty.isNotEmpty, isFalse);
      expect(empty.mainCourse, isNull);

      const withDishes = MealDetails(
        repasId: '102',
        title: 'Menu Dîner',
        dishes: [
          MealDishItem(courseType: 'Entrée', name: 'Soupe'),
          MealDishItem(courseType: 'Plat Principal', name: 'Riz au Poulet'),
          MealDishItem(courseType: 'Dessert', name: 'Yaourt'),
        ],
      );
      expect(withDishes.isEmpty, isFalse);
      expect(withDishes.mainCourse?.name, 'Riz au Poulet');
    });

    test('MealDetails serialization roundtrip', () {
      const details = MealDetails(
        repasId: '103',
        title: 'Menu Déjeuner',
        dishes: [
          MealDishItem(courseType: 'Entrée', name: 'Salade'),
        ],
      );
      final json = details.toJson();
      final fromJson = MealDetails.fromJson(json);

      expect(fromJson.repasId, '103');
      expect(fromJson.title, 'Menu Déjeuner');
      expect(fromJson.dishes.length, 1);
      expect(fromJson.dishes.first.name, 'Salade');
    });
  });

  group('RestoDashboardData Model Tests', () {
    test('RestoDashboardData mealsByDate groups meals by ISO date string', () {
      final meal1 = CampusMealItem(
        id: '1',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 9, 12, 0),
        dayLabel: 'Lundi',
        status: MealStatus.reserved,
      );
      final meal2 = CampusMealItem(
        id: '2',
        type: MealType.diner,
        date: DateTime(2026, 11, 9, 19, 0),
        dayLabel: 'Lundi',
        status: MealStatus.notReserved,
      );
      final meal3 = CampusMealItem(
        id: '3',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 10, 12, 0),
        dayLabel: 'Mardi',
        status: MealStatus.reserved,
      );

      final data = RestoDashboardData(
        profile: const StudentProfile.empty(),
        kpis: const WalletKpis.empty(),
        weeklyMeals: [meal1, meal2, meal3],
        checkIns: const [],
        topUps: const [],
        scrapedAt: DateTime.now(),
      );

      final map = data.mealsByDate;
      expect(map.keys.length, 2);
      expect(map['2026-11-09']?.length, 2);
      expect(map['2026-11-10']?.length, 1);

      final keys = data.sortedDateKeys;
      expect(keys, ['2026-11-09', '2026-11-10']);
    });

    test('RestoDashboardData serialization roundtrip', () {
      final original = RestoDashboardData.empty();
      final json = original.toJson();
      final fromJson = RestoDashboardData.fromJson(json);

      expect(fromJson.profile.fullName, original.profile.fullName);
      expect(fromJson.kpis.soldeRepas, original.kpis.soldeRepas);
      expect(fromJson.weeklyMeals, isEmpty);
    });
  });

  group('SessionCookies Model Tests', () {
    test('SessionCookies isValid and toCookieHeader formatting', () {
      const cookies = SessionCookies(
        phpSessId: 'token_abc123',
        cookieSession1: 'waf_xyz789',
      );
      expect(cookies.isValid, isTrue);
      expect(cookies.toCookieHeader(),
          'PHPSESSID=token_abc123; cookiesession1=waf_xyz789');

      const noWaf = SessionCookies(phpSessId: 'only_php');
      expect(noWaf.isValid, isTrue);
      expect(noWaf.toCookieHeader(), 'PHPSESSID=only_php');

      const emptyPhp = SessionCookies(phpSessId: '   ');
      expect(emptyPhp.isValid, isFalse);
    });

    test('SessionCookies serialization roundtrip', () {
      final cookies = SessionCookies(
        phpSessId: 'php_session_val',
        cookieSession1: 'waf_session_val',
        lastChecked: DateTime(2026, 11, 6, 18, 30),
      );

      final json = cookies.toJson();
      final fromJson = SessionCookies.fromJson(json);

      expect(fromJson.phpSessId, cookies.phpSessId);
      expect(fromJson.cookieSession1, cookies.cookieSession1);
      expect(fromJson.lastChecked, cookies.lastChecked);
      expect(fromJson, equals(cookies));
    });
  });
}

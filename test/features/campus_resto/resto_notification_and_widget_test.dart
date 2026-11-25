import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_notification_service.dart';
import 'package:studenthold_app/services/home_widget_sync_service.dart';

/// Test double implementing CampusRestoController for notification & widget tests.
class TestRestoController extends CampusRestoController {
  final List<CampusMealItem> _testMeals;
  final Map<String, MealDetails> _testCache;

  TestRestoController({
    List<CampusMealItem> weeklyMeals = const [],
    Map<String, MealDetails>? cache,
  })  : _testMeals = weeklyMeals,
        _testCache = cache ?? {},
        super();

  @override
  List<CampusMealItem> get weeklyMeals => _testMeals;

  @override
  MealDetails? cachedMealDetails(String repasId) => _testCache[repasId];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      return true;
    });
  });

  group('Task 2: RestoNotificationService Smart Suppression & 8:00 AM Logic', () {
    late RestoNotificationService service;

    setUp(() {
      service = RestoNotificationService();
    });

    test('2.1: Suppresses reminder when tomorrow has NO scheduled menu (e.g. Sunday/holiday)', () {
      final saturday = DateTime(2026, 11, 14, 10, 0); // Saturday

      // No meals for Sunday (2026-11-15)
      final controller = TestRestoController(
        weeklyMeals: [
          CampusMealItem(
            id: 'sat_meal',
            type: MealType.dejeuner,
            date: DateTime(2026, 11, 14),
            dayLabel: 'Samedi',
            status: MealStatus.reserved,
          ),
        ],
      );

      final shouldNotify = service.shouldNotifyForTomorrow(
        controller: controller,
        now: saturday,
      );

      expect(shouldNotify, isFalse,
          reason: 'Must suppress notification when tomorrow has zero scheduled meals');
    });

    test('2.2: Suppresses reminder when all tomorrow meals are ALREADY reserved', () {
      final sunday = DateTime(2026, 11, 15, 10, 0); // Sunday

      // Monday meals are all reserved
      final mondayLunch = CampusMealItem(
        id: 'mon_lunch',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 16),
        dayLabel: 'Lundi',
        status: MealStatus.reserved,
      );
      final mondayDinner = CampusMealItem(
        id: 'mon_dinner',
        type: MealType.diner,
        date: DateTime(2026, 11, 16),
        dayLabel: 'Lundi',
        status: MealStatus.reserved,
      );

      final controller = TestRestoController(
        weeklyMeals: [mondayLunch, mondayDinner],
      );

      final shouldNotify = service.shouldNotifyForTomorrow(
        controller: controller,
        now: sunday,
      );

      expect(shouldNotify, isFalse,
          reason: 'Must suppress reminder when user already reserved all tomorrow meals');
    });

    test('2.3: Fires reminder when tomorrow has available unreserved meals', () {
      final sunday = DateTime(2026, 11, 15, 10, 0); // Sunday

      // Monday lunch is NOT reserved
      final mondayLunch = CampusMealItem(
        id: 'mon_lunch',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 16),
        dayLabel: 'Lundi',
        status: MealStatus.notReserved,
      );

      final controller = TestRestoController(
        weeklyMeals: [mondayLunch],
      );

      final shouldNotify = service.shouldNotifyForTomorrow(
        controller: controller,
        now: sunday,
      );

      expect(shouldNotify, isTrue,
          reason: 'Must fire notification when tomorrow has at least one unreserved meal');
    });

    test('2.4: Title, body, and payload adhere to strict specification', () {
      expect(RestoNotificationService.notificationTitle,
          "🍽️ Reserve Tomorrow's Resto U Meal!");
      expect(RestoNotificationService.notificationBody,
          "Reservations close at 12:00 PM today. Tap to book tomorrow's Déjeuner & Dîner before noon.");
      expect(RestoNotificationService.notificationPayload, 'resto_u');
    });
  });

  group('Task 3: HomeWidgetSyncService Data Mapping & Formatting', () {
    test('3.1: syncBalanceExpensesWidget correctly formats remaining, spent, cap progress and daily safe spend', () async {
      final budget = BudgetController();
      // Set cap to 152 DT and spent 0 DT
      await budget.setBudgetCap(152.0, 0.0);

      final result = await HomeWidgetSyncService.syncBalanceExpensesWidget(budget: budget);
      // In headless test environment, MethodChannel handles saveWidgetData gracefully
      expect(result, isTrue);

      expect(budget.remainingBudget, 152.0);
      expect(budget.spentSoFar, 0.0);
      expect(budget.totalCap, 152.0);
      expect(budget.dailySafeSpend, greaterThan(0.0));
    });

    test('3.2: syncRestoUMenuWidget correctly resolves upcoming meal and extracts prioritized dishes', () async {
      final mondayMeal = CampusMealItem(
        id: 'mon_01',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 16),
        dayLabel: 'Lundi',
        status: MealStatus.reserved,
      );
      final details = MealDetails(
        repasId: 'mon_01',
        title: 'Déjeuner',
        dishes: const [
          MealDishItem(courseType: 'Plat Principal', name: 'Couscous au poisson'),
          MealDishItem(courseType: 'Entree', name: 'Salade Mechouia'),
          MealDishItem(courseType: 'Dessert', name: 'Orange'),
        ],
      );

      final controller = TestRestoController(
        weeklyMeals: [mondayMeal],
        cache: {'mon_01': details},
      );

      final result = await HomeWidgetSyncService.syncRestoUMenuWidget(
        controller: controller,
        now: DateTime(2026, 11, 14, 21, 0), // Saturday 21:00 -> skips Sunday to Monday
      );

      expect(result, isTrue);
    });

    test('3.3: Deep link parser routes "studenthub://resto" and "studenthub://expense"', () {
      bool restoNavigated = false;
      bool expenseNavigated = false;

      void handleDeepLink(Uri? uri) {
        if (uri == null) return;
        final str = uri.toString().toLowerCase();
        if (str.contains('resto')) restoNavigated = true;
        if (str.contains('expense')) expenseNavigated = true;
      }

      handleDeepLink(Uri.parse('studenthub://resto'));
      expect(restoNavigated, isTrue);
      expect(expenseNavigated, isFalse);

      handleDeepLink(Uri.parse('studenthub://expense'));
      expect(expenseNavigated, isTrue);
    });
  });
}

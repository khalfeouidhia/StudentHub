import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_u_meal_strip.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/weekly_rhythm_card.dart';

/// Test double implementing CampusRestoController for deterministic testing.
class MockRestoController extends ChangeNotifier
    implements CampusRestoController {
  @override
  RestoAuthStatus authStatus;

  @override
  bool isAuthenticated;

  @override
  bool isLoading;

  @override
  bool isOffline;

  @override
  String? errorMessage;

  @override
  StudentProfile? profile;

  @override
  DormInfo? dormInfo;

  @override
  WalletKpis? kpis;

  @override
  List<CampusMealItem> weeklyMeals;

  @override
  List<RestoCheckIn> checkIns;

  @override
  List<RestoTopUp> topUps;

  final Map<String, MealDetails> _cache;
  int refreshCallCount = 0;
  Future<MealDetails?> Function(String repasId)? onGetMealDetails;

  MockRestoController({
    this.authStatus = RestoAuthStatus.authenticated,
    this.isAuthenticated = true,
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.profile,
    this.dormInfo,
    this.kpis,
    this.weeklyMeals = const [],
    this.checkIns = const [],
    this.topUps = const [],
    Map<String, MealDetails>? cache,
    this.onGetMealDetails,
  }) : _cache = cache ?? {};

  @override
  Map<String, List<CampusMealItem>> get mealsByDate {
    final grouped = <String, List<CampusMealItem>>{};
    for (final meal in weeklyMeals) {
      grouped.putIfAbsent(meal.dateKey, () => []).add(meal);
    }
    return grouped;
  }

  @override
  List<String> get sortedDateKeys => mealsByDate.keys.toList()..sort();

  @override
  bool get hasData => weeklyMeals.isNotEmpty;

  @override
  bool get isLowBalance => false;

  @override
  DateTime? get lastSyncTime => DateTime.now();

  @override
  MealDetails? cachedMealDetails(String repasId) => _cache[repasId];

  void setCachedMealDetails(String repasId, MealDetails details) {
    _cache[repasId] = details;
  }

  @override
  Future<MealDetails?> getMealDetails(String repasId) async {
    if (onGetMealDetails != null) {
      return onGetMealDetails!(repasId);
    }
    return _cache[repasId];
  }

  @override
  Future<void> refreshDashboard() async {
    refreshCallCount++;
    notifyListeners();
  }

  @override
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> checkSession() async {}

  @override
  Future<bool> onLoginSuccess(String cookies) async => true;

  @override
  Future<bool> reserveMeal(String refP) async => false;

  @override
  int get unreservedMealsCount =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).length;

  @override
  List<CampusMealItem> get unreservedMeals =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).toList();

  @override
  Future<BatchReservationResult> reserveAllUnreservedMeals({
    void Function(int current, int total, CampusMealItem meal)? onProgress,
  }) async =>
      const BatchReservationResult(
        total: 0,
        succeeded: 0,
        failed: 0,
        reservedMeals: [],
      );

  @override
  Future<void> prefetchWeeklyMealDetails() async {}

  @override
  Future<void> parseAndLoadDashboard(String html) async {}

  @override
  void setAuthenticated(bool value) {
    isAuthenticated = value;
    notifyListeners();
  }

  @override
  Future<int> syncWithBudget(BudgetController budgetController) async => 0;

  @override
  Future<void> logout() async {
    isAuthenticated = false;
    notifyListeners();
  }
}

CampusMealItem createTestMeal({
  required String id,
  required DateTime date,
  required MealType type,
  MealStatus status = MealStatus.notReserved,
  String dayLabel = 'Lundi',
}) {
  return CampusMealItem(
    id: id,
    type: type,
    date: date,
    dayLabel: dayLabel,
    status: status,
  );
}

MealDetails createTestDetails({
  required String repasId,
  String title = 'Menu du jour',
  List<MealDishItem>? dishes,
}) {
  return MealDetails(
    repasId: repasId,
    title: title,
    dishes: dishes ??
        const [
          MealDishItem(
              courseType: 'Plat Principal', name: 'Couscous au poisson'),
          MealDishItem(courseType: 'Entree', name: 'Salade Mechouia'),
          MealDishItem(courseType: 'Dessert', name: 'Orange sanguine'),
        ],
  );
}

final RegExp _prohibitedEmojiRegex = RegExp(
  r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}]',
  unicode: true,
);

Widget _wrapHarness({
  required Widget child,
  CampusRestoController? controller,
  BudgetController? budget,
  AuthController? auth,
  TasksController? tasks,
  Size surfaceSize = const Size(400, 1800),
  double textScale = 1.0,
}) {
  return MultiProvider(
    providers: [
      if (controller != null)
        ChangeNotifierProvider<CampusRestoController>.value(value: controller),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => budget ?? BudgetController()),
      ChangeNotifierProvider<AuthController>(
          create: (_) => auth ?? AuthController()),
      ChangeNotifierProvider<TasksController>(
          create: (_) => tasks ?? TasksController()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // GROUP 1: MealTimeSlotResolver Time Boundaries & Sweep (Feature 12)
  // =========================================================================
  group('Group 1: MealTimeSlotResolver Time Boundaries & Sweep (Feature 12)', () {
    test('1.1: 00:00:00 exact lower bound -> Today Dejeuner', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 0, 0, 0));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Déjeuner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
      expect(slot.dateKey, '2026-11-14');
    });

    test('1.2: 13:59:59 exact upper bound -> Today Dejeuner', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 13, 59, 59));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Déjeuner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
      expect(slot.dateKey, '2026-11-14');
    });

    test('1.3: 13:59:59.999999 microsecond bound -> Today Dejeuner', () {
      final slot = MealTimeSlotResolver.resolve(
          DateTime(2026, 11, 14, 13, 59, 59, 999, 999));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Déjeuner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
    });

    test('1.4: 14:00:00 exact lower bound -> Today Diner', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 14, 0, 0));
      expect(slot.mealType, MealType.diner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Dîner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
      expect(slot.dateKey, '2026-11-14');
    });

    test('1.5: 20:30:00 exact upper bound -> Today Diner', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 20, 30, 0));
      expect(slot.mealType, MealType.diner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Dîner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
      expect(slot.dateKey, '2026-11-14');
    });

    test('1.6: 20:30:59 exact upper bound -> Today Diner within 20:30 minute', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 20, 30, 59));
      expect(slot.mealType, MealType.diner);
      expect(slot.isTomorrow, false);
      expect(slot.title, 'Dîner');
      expect(slot.badge, isNull);
      expect(slot.targetDate, DateTime(2026, 11, 14));
      expect(slot.dateKey, '2026-11-14');
    });

    test('1.7: 20:31:00 exact lower bound -> Tomorrow Dejeuner with Demain badge', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 20, 31, 0));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, true);
      expect(slot.title, 'Déjeuner');
      expect(slot.badge, 'Demain');
      expect(slot.targetDate, DateTime(2026, 11, 15));
      expect(slot.dateKey, '2026-11-15');
    });

    test('1.8: 23:59:59 exact late-night upper bound -> Tomorrow Dejeuner with Demain badge', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 11, 14, 23, 59, 59));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, true);
      expect(slot.title, 'Déjeuner');
      expect(slot.badge, 'Demain');
      expect(slot.targetDate, DateTime(2026, 11, 15));
      expect(slot.dateKey, '2026-11-15');
    });

    test('1.9: 23:59:59.999999 microsecond bound -> Tomorrow Dejeuner', () {
      final slot = MealTimeSlotResolver.resolve(
          DateTime(2026, 11, 14, 23, 59, 59, 999, 999));
      expect(slot.mealType, MealType.dejeuner);
      expect(slot.isTomorrow, true);
      expect(slot.badge, 'Demain');
      expect(slot.targetDate, DateTime(2026, 11, 15));
    });

    test('1.10: 1,440-minute continuous 24-hour sweep confirms exact intervals with zero gaps', () {
      int dejeunerCount = 0;
      int dinerCount = 0;
      int tomorrowDejeunerCount = 0;

      for (int hour = 0; hour < 24; hour++) {
        for (int minute = 0; minute < 60; minute++) {
          final dt = DateTime(2026, 11, 14, hour, minute);
          final slot = MealTimeSlotResolver.resolve(dt);
          final minuteOfDay = hour * 60 + minute;

          if (minuteOfDay < 14 * 60) {
            expect(slot.mealType, MealType.dejeuner);
            expect(slot.isTomorrow, false);
            expect(slot.title, 'Déjeuner');
            expect(slot.badge, isNull);
            expect(slot.dateKey, '2026-11-14');
            dejeunerCount++;
          } else if (minuteOfDay <= 20 * 60 + 30) {
            expect(slot.mealType, MealType.diner);
            expect(slot.isTomorrow, false);
            expect(slot.title, 'Dîner');
            expect(slot.badge, isNull);
            expect(slot.dateKey, '2026-11-14');
            dinerCount++;
          } else {
            expect(slot.mealType, MealType.dejeuner);
            expect(slot.isTomorrow, true);
            expect(slot.title, 'Déjeuner');
            expect(slot.badge, 'Demain');
            expect(slot.dateKey, '2026-11-15');
            tomorrowDejeunerCount++;
          }
        }
      }

      expect(dejeunerCount, 14 * 60); // 840 minutes (00:00 - 13:59)
      expect(dinerCount, 6 * 60 + 31); // 391 minutes (14:00 - 20:30)
      expect(tomorrowDejeunerCount, 3 * 60 + 29); // 209 minutes (20:31 - 23:59)
      expect(dejeunerCount + dinerCount + tomorrowDejeunerCount, 1440);
    });
  });

  // =========================================================================
  // GROUP 2: Calendar Transitions, Leap Years & Normalization (Feature 12)
  // =========================================================================
  group('Group 2: Calendar Transitions, Leap Years & Normalization (Feature 12)', () {
    test('2.1: Leap Year Feb 28 -> Feb 29 (2024-02-28 21:00)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2024, 2, 28, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2024, 2, 29));
      expect(slot.dateKey, '2024-02-29');
    });

    test('2.2: Leap Year Feb 29 -> Mar 01 (2024-02-29 21:00)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2024, 2, 29, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2024, 3, 1));
      expect(slot.dateKey, '2024-03-01');
    });

    test('2.3: Non-Leap Year Feb 28 -> Mar 01 (2025-02-28 21:00)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2025, 2, 28, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2025, 3, 1));
      expect(slot.dateKey, '2025-03-01');
    });

    test('2.4: 30-Day Month Apr 30 -> May 01 (2026-04-30 21:00)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 4, 30, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2026, 5, 1));
      expect(slot.dateKey, '2026-05-01');
    });

    test('2.5: 31-Day Month Oct 31 -> Nov 01 (2026-10-31 21:00)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 10, 31, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2026, 11, 1));
      expect(slot.dateKey, '2026-11-01');
    });

    test('2.6: Year-End Dec 31 -> Jan 01 (2026-12-31 21:00 -> 2027-01-01)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 12, 31, 21, 0));
      expect(slot.isTomorrow, true);
      expect(slot.targetDate, DateTime(2027, 1, 1));
      expect(slot.dateKey, '2027-01-01');
    });

    test('2.7: ISO dateKey format (zero-padded YYYY-MM-DD)', () {
      final slot = MealTimeSlotResolver.resolve(DateTime(2026, 3, 5, 10, 0));
      expect(slot.dateKey, '2026-03-05');
      final slot2 = MealTimeSlotResolver.resolve(DateTime(2026, 9, 9, 10, 0));
      expect(slot2.dateKey, '2026-09-09');
    });

    test('2.8: MealTimeSlot value equality and hashCode contract', () {
      final s1 = MealTimeSlot(
        targetDate: DateTime(2026, 11, 14),
        mealType: MealType.dejeuner,
        isTomorrow: false,
        title: 'Déjeuner',
        badge: null,
      );
      final s2 = MealTimeSlot(
        targetDate: DateTime(2026, 11, 14, 10, 30),
        mealType: MealType.dejeuner,
        isTomorrow: false,
        title: 'Déjeuner',
        badge: null,
      );
      final s3 = MealTimeSlot(
        targetDate: DateTime(2026, 11, 14),
        mealType: MealType.diner,
        isTomorrow: false,
        title: 'Dîner',
        badge: null,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1.toString(), contains('dateKey: 2026-11-14'));
    });
  });

  // =========================================================================
  // GROUP 3: Dynamic Meal Header & Demain Badge (Feature 13)
  // =========================================================================
  group('Group 3: Dynamic Meal Header & Demain Badge (Feature 13)', () {
    testWidgets('3.1: Icons.restaurant_rounded size 16 and color #1E3A2E rendered in header',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 11, 0),
        ),
      ));
      await tester.pumpAndSettle();

      final headerFinder = find.byKey(const Key('resto_u_meal_header'));
      expect(headerFinder, findsOneWidget);

      final iconFinder = find.descendant(
        of: headerFinder,
        matching: find.byIcon(Icons.restaurant_rounded),
      );
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.size, 16.0);
      expect(icon.color, const Color(0xFF1E3A2E));
    });

    testWidgets('3.2: Dynamic title "Déjeuner" rendered at 11:00',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 11, 0),
        ),
      ));
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(const Key('resto_u_meal_title'));
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.data, 'Déjeuner');
      expect(textWidget.style?.color, const Color(0xFF1E3A2E));
      expect(textWidget.style?.fontSize, 13.0);
      expect(textWidget.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('3.3: Dynamic title "Dîner" rendered at 17:00',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 17, 0),
        ),
      ));
      await tester.pumpAndSettle();

      final titleFinder = find.byKey(const Key('resto_u_meal_title'));
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.data, 'Dîner');
    });

    testWidgets('3.4: Demain badge is absent during today Déjeuner/Dîner (10:00, 18:00)',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 10, 0),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resto_u_demain_badge')), findsNothing);

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 18, 0),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resto_u_demain_badge')), findsNothing);
    });

    testWidgets('3.5: Demain badge is present with #E2F4EA background and #1E3A2E text at 21:00',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 21, 0),
        ),
      ));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(const Key('resto_u_demain_badge'));
      expect(badgeFinder, findsOneWidget);

      final container = tester.widget<Container>(badgeFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFE2F4EA));

      final textFinder =
          find.descendant(of: badgeFinder, matching: find.byType(Text));
      expect(textFinder, findsOneWidget);
      final text = tester.widget<Text>(textFinder);
      expect(text.data, 'Demain');
      expect(text.style?.color, const Color(0xFF1E3A2E));
      expect(text.style?.fontSize, 10.0);
      expect(text.style?.fontWeight, FontWeight.w700);
    });
  });

  // =========================================================================
  // GROUP 4: Reservation Status Pill Badge & State Synchronization (Feature 13)
  // =========================================================================
  group('Group 4: Reservation Status Pill Badge & State Synchronization (Feature 13)', () {
    testWidgets('4.1: Reserved state -> green #1E3A2E, check icon (size 12, white), Réservé text',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          isReservedOverride: true,
        ),
      ));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(const Key('resto_u_reservation_badge'));
      expect(badgeFinder, findsOneWidget);

      final containerFinder =
          find.descendant(of: badgeFinder, matching: find.byType(Container));
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFF1E3A2E));

      final checkIconFinder = find.descendant(
          of: badgeFinder, matching: find.byIcon(Icons.check_rounded));
      expect(checkIconFinder, findsOneWidget);
      final checkIcon = tester.widget<Icon>(checkIconFinder);
      expect(checkIcon.size, 12.0);
      expect(checkIcon.color, Colors.white);

      expect(
          find.descendant(of: badgeFinder, matching: find.text('Réservé')),
          findsOneWidget);
    });

    testWidgets('4.2: Not Reserved state -> warm amber/coral #F08C4F, NO check icon, Non réservé text',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          isReservedOverride: false,
        ),
      ));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(const Key('resto_u_reservation_badge'));
      expect(badgeFinder, findsOneWidget);

      final containerFinder =
          find.descendant(of: badgeFinder, matching: find.byType(Container));
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF08C4F));

      expect(find.descendant(
          of: badgeFinder, matching: find.byIcon(Icons.check_rounded)), findsNothing);
      expect(
          find.descendant(of: badgeFinder, matching: find.text('Non réservé')),
          findsOneWidget);
    });

    testWidgets('4.3: English labels mode -> Reserved vs Not Reserved vs Tomorrow',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 21, 0), // Tomorrow
          isReservedOverride: true,
          useEnglishLabels: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Reserved'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          isReservedOverride: false,
          useEnglishLabels: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Not Reserved'), findsOneWidget);
    });

    testWidgets('4.4: Custom label overrides -> custom strings rendered verbatim',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 21, 0),
          isReservedOverride: false,
          notReservedBadgeLabel: 'Available Now',
          tomorrowBadgeLabel: 'J+1',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Available Now'), findsOneWidget);
      expect(find.text('J+1'), findsOneWidget);

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          isReservedOverride: true,
          reservedBadgeLabel: 'Confirmed Seat',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed Seat'), findsOneWidget);
    });

    testWidgets('4.5: Reactive state sync -> controller updates meal status from notReserved to reserved',
        (tester) async {
      final meal = CampusMealItem(
        id: 'meal_sync_1',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 14),
        dayLabel: 'Samedi',
        status: MealStatus.notReserved,
      );

      final mockController = MockRestoController(
        weeklyMeals: [meal],
        cache: {
          'meal_sync_1': createTestDetails(repasId: 'meal_sync_1'),
        },
      );

      await tester.pumpWidget(_wrapHarness(
        controller: mockController,
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Non réservé'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      final updatedMeal = CampusMealItem(
        id: 'meal_sync_1',
        type: MealType.dejeuner,
        date: DateTime(2026, 11, 14),
        dayLabel: 'Samedi',
        status: MealStatus.reserved,
      );
      mockController.weeklyMeals = [updatedMeal];
      mockController.notifyListeners();
      await tester.pumpAndSettle();

      expect(find.text('Réservé'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 5: Tap Callbacks & Tab Navigation (Feature 13)
  // =========================================================================
  group('Group 5: Tap Callbacks & Tab Navigation (Feature 13)', () {
    testWidgets('5.1: Tap reservation badge invokes onNavigateToResto',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          onNavigateToResto: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resto_u_reservation_badge')));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('5.2: Tap empty state card invokes onNavigateToResto and controller.refreshDashboard()',
        (tester) async {
      bool tapped = false;
      final mock = MockRestoController(weeklyMeals: []);

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: RestoUMealStrip(
          controller: mock,
          currentTime: DateTime(2026, 11, 14, 12, 0),
          onNavigateToResto: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      final emptyStateFinder = find.byKey(const Key('resto_u_empty_state'));
      expect(emptyStateFinder, findsOneWidget);

      await tester.tap(emptyStateFinder);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(mock.refreshCallCount, 1);
    });

    testWidgets('5.3: Tap dish chip invokes onNavigateToResto',
        (tester) async {
      bool tapped = false;
      final details = createTestDetails(repasId: 'chip_test');

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
          onNavigateToResto: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      final chipFinder = find.byKey(const Key('resto_u_dish_chip_0'));
      expect(chipFinder, findsOneWidget);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('5.4: Fallback navigation switches to MainShell tab 4 when onNavigateToResto is null',
        (tester) async {
      final mock = MockRestoController(weeklyMeals: []);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CampusRestoController>.value(value: mock),
            ChangeNotifierProvider<BudgetController>(
                create: (_) => BudgetController()),
            ChangeNotifierProvider<AuthController>(
                create: (_) => AuthController()),
            ChangeNotifierProvider<TasksController>(
                create: (_) => TasksController()),
          ],
          child: const MaterialApp(
            home: MainShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(const Key('resto_u_reservation_badge'));
      expect(badgeFinder, findsOneWidget);

      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, 4);
    });
  });

  // =========================================================================
  // GROUP 6: Horizontal Dish Strip & Visual Styling (Feature 13)
  // =========================================================================
  group('Group 6: Horizontal Dish Strip & Visual Styling (Feature 13)', () {
    testWidgets('6.1: Horizontal ListView.separated bounded at fixed height 84px',
        (tester) async {
      final details = createTestDetails(repasId: 'h_test');

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
        ),
      ));
      await tester.pumpAndSettle();

      final listSizedBoxFinder = find.byKey(const Key('resto_u_dish_list'));
      expect(listSizedBoxFinder, findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(listSizedBoxFinder);
      expect(sizedBox.height, 84.0);

      final listViewFinder = find.descendant(
          of: listSizedBoxFinder, matching: find.byType(ListView));
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      expect(listView.scrollDirection, Axis.horizontal);
    });

    testWidgets('6.2: Dish card visual properties: width 150, #FFFFFF fill, #C7CBB8 border (0.40 opacity)',
        (tester) async {
      final details = createTestDetails(repasId: 'prop_test');

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
        ),
      ));
      await tester.pumpAndSettle();

      final chipFinder = find.byKey(const Key('resto_u_dish_chip_0'));
      expect(chipFinder, findsOneWidget);

      final containerFinder =
          find.descendant(of: chipFinder, matching: find.byType(Container));
      final container = tester.widget<Container>(containerFinder.first);
      expect(container.constraints?.maxWidth, 150.0);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect(decoration.border, isNotNull);
      expect(decoration.border!.top.color,
          const Color(0xFFC7CBB8).withOpacity(0.40));
      expect(decoration.border!.top.width, 1.0);
    });

    testWidgets('6.3: Main course dish -> star icon Icons.star_rounded (11px, #1E3A2E) & #1E3A2E category',
        (tester) async {
      const details = MealDetails(
        repasId: 'star_test',
        title: 'Déjeuner',
        dishes: [
          MealDishItem(
              courseType: 'Plat Principal', name: 'Couscous au Poisson'),
        ],
      );

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
        ),
      ));
      await tester.pumpAndSettle();

      final starIconFinder = find.byIcon(Icons.star_rounded);
      expect(starIconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(starIconFinder);
      expect(icon.size, 11.0);
      expect(icon.color, const Color(0xFF1E3A2E));

      final categoryTextFinder = find.text('الطبق الرئيسي');
      expect(categoryTextFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(categoryTextFinder);
      expect(textWidget.style?.color, const Color(0xFF1E3A2E));
      expect(textWidget.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('6.4: Secondary dish -> NO star icon, #6B7F67 category',
        (tester) async {
      const details = MealDetails(
        repasId: 'sec_test',
        title: 'Déjeuner',
        dishes: [
          MealDishItem(courseType: 'Dessert', name: 'Orange Sanguine'),
        ],
      );

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_rounded), findsNothing);

      final categoryTextFinder = find.text('DESSERT');
      expect(categoryTextFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(categoryTextFinder);
      expect(textWidget.style?.color, const Color(0xFF6B7F67));
    });

    testWidgets('6.5: Multilingual & Arabic text handling without truncation crashes',
        (tester) async {
      const details = MealDetails(
        repasId: 'ar_test',
        title: 'Déjeuner',
        dishes: [
          MealDishItem(
            courseType: 'Plat Principal',
            name: 'كسكسي تونسي بالسمك والخضار الطازجة مع صلصة حارة',
          ),
          MealDishItem(
            courseType: 'Entree',
            name: 'سلاطة مشوية تونسية بالتون والبيض وزيت الزيتون',
          ),
        ],
      );

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealDetailsOverride: details,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resto_u_dish_chip_0')), findsOneWidget);
      expect(find.byKey(const Key('resto_u_dish_chip_1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 7: Empty and Loading States (Feature 13)
  // =========================================================================
  group('Group 7: Empty and Loading States (Feature 13)', () {
    testWidgets('7.1: isLoading == true renders 3 shimmer cards with CircularProgressIndicator (#1E3A2E)',
        (tester) async {
      final mock = MockRestoController(isLoading: true);

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: RestoUMealStrip(
          controller: mock,
          currentTime: DateTime(2026, 11, 14, 12, 0),
        ),
      ));
      // Pump frame without pumpAndSettle since CircularProgressIndicator animates indefinitely
      await tester.pump(const Duration(milliseconds: 50));

      final loadingFinder = find.byKey(const Key('resto_u_loading_state'));
      expect(loadingFinder, findsOneWidget);

      final indicators = tester.widgetList<CircularProgressIndicator>(
        find.descendant(
            of: loadingFinder,
            matching: find.byType(CircularProgressIndicator)),
      );
      expect(indicators.length, 3);
      for (final indicator in indicators) {
        expect(indicator.color, const Color(0xFF1E3A2E));
        expect(indicator.strokeWidth, 2.0);
      }
    });

    testWidgets('7.2: Empty meals/details renders Menu unavailable — Tap to sync with restaurant_menu_rounded',
        (tester) async {
      final mock = MockRestoController(weeklyMeals: []);

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: RestoUMealStrip(
          controller: mock,
          currentTime: DateTime(2026, 11, 14, 12, 0),
        ),
      ));
      await tester.pumpAndSettle();

      final emptyFinder = find.byKey(const Key('resto_u_empty_state'));
      expect(emptyFinder, findsOneWidget);

      expect(
          find.descendant(
              of: emptyFinder,
              matching: find.text('Menu unavailable — Tap to sync')),
          findsOneWidget);
      expect(
          find.descendant(
              of: emptyFinder,
              matching: find.text('Toucher pour actualiser le menu Resto U')),
          findsOneWidget);
      expect(
          find.descendant(
              of: emptyFinder,
              matching: find.byIcon(Icons.restaurant_menu_rounded)),
          findsOneWidget);
      expect(
          find.descendant(
              of: emptyFinder, matching: find.byIcon(Icons.sync_rounded)),
          findsOneWidget);
    });

    testWidgets('7.3: Async getMealDetails transitions from loading skeleton to dish cards',
        (tester) async {
      final meal = createTestMeal(
        id: 'async_7_3',
        date: DateTime(2026, 11, 14),
        type: MealType.dejeuner,
      );

      final details = createTestDetails(repasId: 'async_7_3');
      final completer = Completer<MealDetails?>();

      final mock = MockRestoController(
        weeklyMeals: [meal],
        onGetMealDetails: (_) => completer.future,
      );

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: RestoUMealStrip(
          controller: mock,
          currentTime: DateTime(2026, 11, 14, 12, 0),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('resto_u_loading_state')), findsOneWidget);
      expect(find.byKey(const Key('resto_u_dish_list')), findsNothing);

      completer.complete(details);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resto_u_loading_state')), findsNothing);
      expect(find.byKey(const Key('resto_u_dish_list')), findsOneWidget);
      expect(find.text('Couscous au poisson'), findsOneWidget);
    });

    testWidgets('7.4: Async getMealDetails returning null falls back to empty state cleanly',
        (tester) async {
      final meal = createTestMeal(
        id: 'async_7_4',
        date: DateTime(2026, 11, 14),
        type: MealType.dejeuner,
      );

      final mock = MockRestoController(
        weeklyMeals: [meal],
        onGetMealDetails: (_) async => null,
      );

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: RestoUMealStrip(
          controller: mock,
          currentTime: DateTime(2026, 11, 14, 12, 0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resto_u_empty_state')), findsOneWidget);
      expect(find.text('Menu unavailable — Tap to sync'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 8: Defensive Provider Lookup & Direct Overrides (Feature 13)
  // =========================================================================
  group('Group 8: Defensive Provider Lookup & Direct Overrides (Feature 13)', () {
    testWidgets('8.1: Mounts cleanly with NO Provider in ancestor tree (safe fallback)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RestoUMealStrip(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resto_u_meal_strip')), findsOneWidget);
      expect(find.byKey(const Key('resto_u_empty_state')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8.2: Direct prop overrides bypass controller completely',
        (tester) async {
      final overrideMeal = createTestMeal(
        id: 'override_1',
        date: DateTime(2026, 11, 14),
        type: MealType.dejeuner,
        status: MealStatus.notReserved,
      );

      final overrideDetails = const MealDetails(
        repasId: 'override_1',
        title: 'Menu Exclusif',
        dishes: [
          MealDishItem(courseType: 'Plat Principal', name: 'Tajine dagneau'),
        ],
      );

      await tester.pumpWidget(_wrapHarness(
        child: RestoUMealStrip(
          currentTime: DateTime(2026, 11, 14, 12, 0),
          mealItemOverride: overrideMeal,
          mealDetailsOverride: overrideDetails,
          isReservedOverride: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tajine dagneau'), findsOneWidget);
      expect(find.text('Réservé'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 9: Quick Actions Styling & Home Screen Integration (Feature 14)
  // =========================================================================
  group('Group 9: Quick Actions Styling & Home Screen Integration (Feature 14)', () {
    testWidgets('9.1: Quick Actions buttons render flat #FFFFFF cards with 1px #C7CBB8 border and #1E3A2E icons',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(child: const HomeDashboard()));
      await tester.pumpAndSettle();

      const labels = ['Add Expense', 'Scan Receipt', 'Adjust Cap', 'Calendar'];

      for (final label in labels) {
        final labelFinder = find.text(label);
        expect(labelFinder, findsOneWidget);

        final inkFinder = find.ancestor(
          of: labelFinder,
          matching: find.byType(Ink),
        );
        expect(inkFinder, findsWidgets);
        final ink = tester.widget<Ink>(inkFinder.first);
        final decoration = ink.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        expect(decoration!.color, Colors.white);
        expect(decoration.boxShadow, isNull);
        expect(decoration.borderRadius, BorderRadius.circular(16));
        expect(decoration.border, isNotNull);
        expect(decoration.border!.top.color,
            const Color(0xFFC7CBB8).withOpacity(0.35));
        expect(decoration.border!.top.width, 1.0);
      }
    });

    testWidgets('9.2: InkWell ripple configured with #1E3A2E splash without gray container wrappers',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(child: const HomeDashboard()));
      await tester.pumpAndSettle();

      const labels = ['Add Expense', 'Scan Receipt', 'Adjust Cap', 'Calendar'];

      for (final label in labels) {
        final labelFinder = find.text(label);
        final inkWellFinder = find.ancestor(
          of: labelFinder,
          matching: find.byType(InkWell),
        );
        expect(inkWellFinder, findsWidgets);
        final inkWell = tester.widget<InkWell>(inkWellFinder.first);
        expect(inkWell.splashColor, const Color(0xFF1E3A2E).withOpacity(0.08));
        expect(
            inkWell.highlightColor, const Color(0xFF1E3A2E).withOpacity(0.04));
      }
    });

    testWidgets('9.3: Home screen vertical layout invariant: Quick Actions < RestoUMealStrip < WeeklyRhythmCard',
        (tester) async {
      await tester.pumpWidget(_wrapHarness(child: const HomeDashboard()));
      await tester.pumpAndSettle();

      final quickActionsFinder = find.text('QUICK ACTIONS');
      final restoStripFinder = find.byKey(const Key('resto_u_meal_strip'));
      final weeklyRhythmFinder = find.byType(WeeklyRhythmCard);

      expect(quickActionsFinder, findsOneWidget);
      expect(restoStripFinder, findsOneWidget);
      expect(weeklyRhythmFinder, findsOneWidget);

      final quickActionsY = tester.getTopLeft(quickActionsFinder).dy;
      final restoStripY = tester.getTopLeft(restoStripFinder).dy;
      final weeklyRhythmY = tester.getTopLeft(weeklyRhythmFinder).dy;

      expect(quickActionsY, lessThan(restoStripY),
          reason: 'Quick Actions must appear above RestoUMealStrip');
      expect(restoStripY, lessThan(weeklyRhythmY),
          reason: 'RestoUMealStrip must appear above WeeklyRhythmCard');
    });

    testWidgets('9.4: Micro-viewport (280x653) at 1.0x to 2.5x scaling renders with ZERO RenderFlex overflows',
        (tester) async {
      const scales = [1.0, 1.5, 2.0, 2.5];

      for (final scale in scales) {
        await tester.pumpWidget(_wrapHarness(
          surfaceSize: const Size(280, 653),
          textScale: scale,
          child: const HomeDashboard(),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason:
                'Micro-viewport at scale ${scale}x must not cause exceptions or overflows');
        expect(find.byKey(const Key('resto_u_meal_strip')), findsOneWidget);
      }
    });
  });

  // =========================================================================
  // GROUP 10: Zero Unicode Emoji Static & Runtime Enforcement (Feature 14)
  // =========================================================================
  group('Group 10: Zero Unicode Emoji Static & Runtime Enforcement (Feature 14)', () {
    testWidgets('10.1: Runtime scan of all Text and RichText widgets across mounted tree confirms 0 emojis',
        (tester) async {
      final meal = createTestMeal(
        id: 'emoji_test_1',
        date: DateTime(2026, 11, 14),
        type: MealType.dejeuner,
        status: MealStatus.reserved,
      );

      final mock = MockRestoController(
        weeklyMeals: [meal],
        cache: {
          'emoji_test_1': createTestDetails(repasId: 'emoji_test_1'),
        },
      );

      await tester.pumpWidget(_wrapHarness(
        controller: mock,
        child: const HomeDashboard(),
      ));
      await tester.pumpAndSettle();

      for (final textWidget in tester.widgetList<Text>(find.byType(Text))) {
        final text =
            textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(_prohibitedEmojiRegex.hasMatch(text), isFalse,
            reason: 'Runtime Text "$text" must contain zero Unicode emojis');
      }
    });

    test('10.2: Static file inspection of resto_u_meal_strip.dart and test suite confirms 0 emojis', () {
      final widgetFile = File(
          'lib/features/campus_resto/ui/widgets/resto_u_meal_strip.dart');
      expect(widgetFile.existsSync(), isTrue);
      final widgetContent = widgetFile.readAsStringSync();
      expect(_prohibitedEmojiRegex.hasMatch(widgetContent), isFalse,
          reason: 'resto_u_meal_strip.dart must contain 0 Unicode emojis');

      final testFile = File('test/widgets/resto_u_meal_strip_test.dart');
      expect(testFile.existsSync(), isTrue);
      final testContent = testFile.readAsStringSync();

      // Check test file content excluding the regex definition line itself
      final linesWithoutRegex = testContent
          .split('\n')
          .where((line) => !line.contains(r'[\u{1F300}'))
          .join('\n');
      expect(_prohibitedEmojiRegex.hasMatch(linesWithoutRegex), isFalse,
          reason: 'resto_u_meal_strip_test.dart must contain 0 Unicode emojis');
    });
  });

  // =========================================================================
  // GROUP 11: Smart Next-Available Meal Fallback & Day Scanning
  // =========================================================================
  group('Group 11: Smart Next-Available Meal Fallback & Day Scanning', () {
    test('11.1: Saturday night (21:00) with empty Sunday automatically jumps to Monday Dejeuner', () {
      final now = DateTime(2026, 11, 14, 21, 0); // Saturday 21:00

      final mondayMeal = createTestMeal(
        id: 'monday_lunch',
        date: DateTime(2026, 11, 16),
        type: MealType.dejeuner,
        dayLabel: 'Lundi',
      );

      final controller = MockRestoController(
        weeklyMeals: [mondayMeal],
      );

      final resolved = MealTimeSlotResolver.resolveNextAvailable(
        now: now,
        controller: controller,
      );

      expect(resolved.targetDate, DateTime(2026, 11, 16));
      expect(resolved.mealType, MealType.dejeuner);
      expect(resolved.daysAhead, 2);
      expect(resolved.isTomorrow, false);
      expect(resolved.title, 'Déjeuner');
      expect(resolved.badge, 'Lundi');
      expect(resolved.weekdayName, 'Lundi');
      expect(resolved.dateKey, '2026-11-16');
    });

    test('11.2: English labels mode formats weekday badge as Monday', () {
      final now = DateTime(2026, 11, 14, 21, 0); // Saturday 21:00

      final mondayMeal = createTestMeal(
        id: 'monday_lunch_en',
        date: DateTime(2026, 11, 16),
        type: MealType.dejeuner,
        dayLabel: 'Lundi',
      );

      final controller = MockRestoController(
        weeklyMeals: [mondayMeal],
      );

      final resolved = MealTimeSlotResolver.resolveNextAvailable(
        now: now,
        controller: controller,
        useEnglishLabels: true,
      );

      expect(resolved.targetDate, DateTime(2026, 11, 16));
      expect(resolved.badge, 'Monday');
      expect(resolved.weekdayName, 'Monday');
    });

    test('11.3: Mid-week closed lunch skips directly to dinner of same day', () {
      final now = DateTime(2026, 11, 18, 10, 0); // Wednesday 10:00

      // Only Wednesday dinner exists (lunch is closed/empty)
      final wednesdayDinner = createTestMeal(
        id: 'wed_dinner',
        date: DateTime(2026, 11, 18),
        type: MealType.diner,
        dayLabel: 'Mercredi',
      );

      final controller = MockRestoController(
        weeklyMeals: [wednesdayDinner],
      );

      final resolved = MealTimeSlotResolver.resolveNextAvailable(
        now: now,
        controller: controller,
      );

      expect(resolved.targetDate, DateTime(2026, 11, 18));
      expect(resolved.mealType, MealType.diner);
      expect(resolved.daysAhead, 0);
      expect(resolved.badge, isNull);
      expect(resolved.title, 'Dîner');
    });

    test('11.4: 7-day lookahead exhaust falls back to initial slot without infinite loop', () {
      final now = DateTime(2026, 11, 14, 21, 0); // Saturday 21:00

      // All meals are empty / closed
      final controller = MockRestoController(
        weeklyMeals: const [],
      );

      final resolved = MealTimeSlotResolver.resolveNextAvailable(
        now: now,
        controller: controller,
      );

      // Initial slot for 21:00 is tomorrow lunch (Sunday)
      expect(resolved.targetDate, DateTime(2026, 11, 15));
      expect(resolved.mealType, MealType.dejeuner);
      expect(resolved.isTomorrow, true);
    });

    testWidgets('11.5: UI renders Monday badge and syncs reservation status to Monday meal',
        (tester) async {
      final now = DateTime(2026, 11, 14, 21, 0); // Saturday 21:00

      // Sunday is closed. Monday lunch is reserved!
      final mondayMeal = createTestMeal(
        id: 'mon_res',
        date: DateTime(2026, 11, 16),
        type: MealType.dejeuner,
        status: MealStatus.reserved,
      );
      final mondayDetails = createTestDetails(
        repasId: 'mon_res',
        dishes: [
          const MealDishItem(courseType: 'Plat Principal', name: 'Poulet Roti'),
        ],
      );

      final controller = MockRestoController(
        weeklyMeals: [mondayMeal],
        cache: {'mon_res': mondayDetails},
      );

      await tester.pumpWidget(_wrapHarness(
        controller: controller,
        child: RestoUMealStrip(
          controller: controller,
          currentTime: now,
        ),
      ));
      await tester.pumpAndSettle();

      // Meal title is Déjeuner
      expect(find.byKey(const Key('resto_u_meal_title')), findsOneWidget);
      expect(find.text('Déjeuner'), findsOneWidget);

      // Day badge is present with text "Lundi"
      expect(find.byKey(const Key('resto_u_demain_badge')), findsOneWidget);
      expect(find.byKey(const Key('resto_u_day_badge')), findsOneWidget);
      expect(find.text('Lundi'), findsOneWidget);

      // Reservation status queries Monday: shows "Reserve" with check icon
      expect(find.text('Réservé'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Dish list shows Monday's dishes
      expect(find.text('Poulet Roti'), findsOneWidget);

      // Now switch Monday meal to notReserved
      controller.weeklyMeals = [
        mondayMeal.copyWith(status: MealStatus.notReserved),
      ];
      controller.notifyListeners();
      await tester.pumpAndSettle();

      // Reservation badge updates to "Non reserve"
      expect(find.text('Non réservé'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('11.6: Empty dish details in cache triggers skip to next non-empty scheduled meal',
        (tester) async {
      final now = DateTime(2026, 11, 14, 11, 0); // Saturday 11:00 AM

      // Saturday lunch has empty dish details
      final satLunch = createTestMeal(
        id: 'sat_lunch_empty',
        date: DateTime(2026, 11, 14),
        type: MealType.dejeuner,
      );
      final satLunchEmptyDetails = createTestDetails(
        repasId: 'sat_lunch_empty',
        dishes: const [],
      );

      // Saturday dinner has valid dishes
      final satDinner = createTestMeal(
        id: 'sat_dinner_valid',
        date: DateTime(2026, 11, 14),
        type: MealType.diner,
      );
      final satDinnerDetails = createTestDetails(
        repasId: 'sat_dinner_valid',
        dishes: [
          const MealDishItem(courseType: 'Plat', name: 'Tajine'),
        ],
      );

      final controller = MockRestoController(
        weeklyMeals: [satLunch, satDinner],
        cache: {
          'sat_lunch_empty': satLunchEmptyDetails,
          'sat_dinner_valid': satDinnerDetails,
        },
      );

      await tester.pumpWidget(_wrapHarness(
        controller: controller,
        child: RestoUMealStrip(
          controller: controller,
          currentTime: now,
        ),
      ));
      await tester.pumpAndSettle();

      // It skipped empty Saturday lunch and displays Saturday dinner
      expect(find.text('Dîner'), findsOneWidget);
      expect(find.text('Tajine'), findsOneWidget);
    });
  });
}

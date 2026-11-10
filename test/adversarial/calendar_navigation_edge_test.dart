import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';

/// Test double implementing [CampusRestoController] for adversarial edge verification.
class MockAdversarialCampusRestoController extends ChangeNotifier
    implements CampusRestoController {
  @override
  RestoAuthStatus get authStatus => RestoAuthStatus.authenticated;
  @override
  bool isAuthenticated = true;
  @override
  bool isLoading = false;
  @override
  bool isOffline = false;
  @override
  String? errorMessage;
  @override
  StudentProfile? profile;
  @override
  DormInfo? dormInfo;
  @override
  WalletKpis? kpis;
  @override
  List<CampusMealItem> weeklyMeals = [];
  @override
  List<RestoCheckIn> checkIns = const [];
  @override
  List<RestoTopUp> topUps = const [];

  Map<String, List<CampusMealItem>> customMealsByDate = {};

  @override
  Map<String, List<CampusMealItem>> get mealsByDate => customMealsByDate;

  @override
  List<String> get sortedDateKeys => customMealsByDate.keys.toList()..sort();

  @override
  bool get hasData => weeklyMeals.isNotEmpty || customMealsByDate.isNotEmpty;
  @override
  bool get isLowBalance => false;
  @override
  DateTime? get lastSyncTime => null;
  @override
  MealDetails? cachedMealDetails(String repasId) => null;
  @override
  void clearError() {}
  @override
  Future<void> init() async {}
  @override
  Future<void> refreshDashboard() async {}
  @override
  Future<void> checkSession() async {}
  @override
  Future<void> onLoginSuccess(String cookies) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<MealDetails?> getMealDetails(String repasId) async => null;
  @override
  Future<bool> reserveMeal(String refP) async => false;
  @override
  int get unreservedMealsCount => 0;
  @override
  List<CampusMealItem> get unreservedMeals => const [];
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
  void setAuthenticated(bool value) {}
  @override
  Future<void> syncWithBudget(BudgetController budgetController) async {}
}

Widget _wrapMainShellAdversarial({
  int initialIndex = 0,
  BudgetController? budget,
  MockAdversarialCampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>.value(
        value: budget ?? BudgetController(),
      ),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<CampusRestoController>.value(
        value: resto ?? MockAdversarialCampusRestoController(),
      ),
    ],
    child: MaterialApp(
      home: MainShell(initialIndex: initialIndex),
    ),
  );
}

Widget _wrapCalendarAdversarial({
  DateTime? initialDate,
  BudgetController? budget,
  MockAdversarialCampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>.value(
        value: budget ?? BudgetController(),
      ),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<CampusRestoController>.value(
        value: resto ?? MockAdversarialCampusRestoController(),
      ),
    ],
    child: MaterialApp(
      home: CalendarScreen(initialDate: initialDate),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group(
      'Group 1: Navigation Tab Transitions & Stress Pumping (MainShell & LiquidGlassBottomNavBar)',
      () {
    testWidgets(
        '1.1: 50+ chaotic back-and-forth tab taps across all 5 tabs with mid-animation interrupts',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellAdversarial(initialIndex: 0));
      await tester.pumpAndSettle();

      final navBar = find.byType(LiquidGlassBottomNavBar);
      expect(navBar, findsOneWidget);

      final homeTab = find.descendant(of: navBar, matching: find.text('Home'));
      final expTab =
          find.descendant(of: navBar, matching: find.text('Expenses'));
      final calTab =
          find.descendant(of: navBar, matching: find.text('Calendar'));
      final tasksTab =
          find.descendant(of: navBar, matching: find.text('Tasks'));
      final restoTab =
          find.descendant(of: navBar, matching: find.text('Resto U'));

      final tabs = [homeTab, expTab, calTab, tasksTab, restoTab];

      // Chaotic tab index traversal pattern (50 transitions)
      final chaoticSequence = [
        1,
        2,
        0,
        4,
        3,
        1,
        4,
        2,
        0,
        3,
        4,
        1,
        2,
        3,
        0,
        2,
        4,
        1,
        3,
        0,
        3,
        2,
        4,
        0,
        1,
        4,
        3,
        2,
        1,
        0,
        2,
        1,
        3,
        4,
        0,
        4,
        2,
        1,
        3,
        0,
        1,
        4,
        3,
        0,
        2,
        4,
        1,
        0,
        3,
        2,
      ];

      for (int i = 0; i < chaoticSequence.length; i++) {
        final targetIndex = chaoticSequence[i];
        await tester.tap(tabs[targetIndex]);

        // Interleave variable frame pumps (simulating interruptive user taps mid-animation)
        final pumpDurationMs = (i % 4) * 20 + 10; // 10ms, 30ms, 50ms, 70ms
        await tester.pump(Duration(milliseconds: pumpDurationMs));
      }

      // Settle completely
      await tester.pumpAndSettle();

      // Final tab in chaoticSequence is index 2 (Calendar)
      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(2));
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets(
        '1.2: Rapid zero-settle burst: 30 consecutive taps without waiting for settling',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellAdversarial(initialIndex: 0));
      await tester.pumpAndSettle();

      final mainShellState =
          tester.state<MainShellState>(find.byType(MainShell));

      // Burst switchTab 30 times with 0 wait
      for (int i = 0; i < 30; i++) {
        mainShellState.switchTab(i % 5);
      }

      await tester.pumpAndSettle();

      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      // Last iteration was 29 % 5 = 4 (Resto U)
      expect(indexedStack.index, equals(4));
      expect(find.byType(RestoUView), findsOneWidget);
    });

    testWidgets(
        '1.3: Mid-flight unmount & disposal during active tab transition animation',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellAdversarial(initialIndex: 0));
      await tester.pumpAndSettle();

      final navBar = find.byType(LiquidGlassBottomNavBar);
      final calTab =
          find.descendant(of: navBar, matching: find.text('Calendar'));

      // Tap tab and pump only 15ms into the 240ms AnimatedContainer animation
      await tester.tap(calTab);
      await tester.pump(const Duration(milliseconds: 15));

      // Unmount immediately while animation ticker is active
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      // Confirm clean unmount with 0 exceptions and no lingering widgets
      expect(find.byType(MainShell), findsNothing);
      expect(find.byType(LiquidGlassBottomNavBar), findsNothing);
    });

    testWidgets('1.4: Direct switchTab boundary torture (-5, -1, 0, 4, 5, 999)',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellAdversarial(initialIndex: 1));
      await tester.pumpAndSettle();

      final mainShellState =
          tester.state<MainShellState>(find.byType(MainShell));

      // Out of bounds negative
      mainShellState.switchTab(-5);
      await tester.pump();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(1));

      mainShellState.switchTab(-1);
      await tester.pump();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(1));

      // Out of bounds positive
      mainShellState.switchTab(5);
      await tester.pump();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(1));

      mainShellState.switchTab(999);
      await tester.pump();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(1));

      // Valid boundary values
      mainShellState.switchTab(0);
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(0));

      mainShellState.switchTab(4);
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(4));
    });
  });

  group(
      'Group 2: Calendar Date Boundary & Leap Year Stress Testing (CalendarScreen)',
      () {
    testWidgets(
        '2.1: Leap Year 2024 Feb 29 mounting: displays exactly 29 days and selects day 29',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 2024 is a leap year; Feb 29 exists and was a Thursday
      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 2, 29)),
      );
      await tester.pumpAndSettle();

      // Month & Year pills
      expect(find.text('February'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // Selected Day Header should show Thursday, Feb 29
      expect(find.textContaining('Thu, Feb 29'), findsOneWidget);

      // Day 29 rendered in grid
      expect(find.text('29'), findsWidgets);

      // Day 30 must NOT exist for February
      expect(find.text('30'), findsNothing);
      expect(find.text('31'), findsNothing);
    });

    testWidgets(
        '2.2: Leap Year to Non-Leap Year transition: 2024 Feb 29 clamps safely to 2025 Feb 28',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 2, 29)),
      );
      await tester.pumpAndSettle();

      // Tap Year dropdown pill
      final yearPill = find.text('2024');
      expect(yearPill, findsOneWidget);
      await tester.tap(yearPill);
      await tester.pumpAndSettle();

      // Pick year 2025 (non-leap year)
      final option2025 = find.text('2025');
      expect(option2025, findsAtLeastNWidgets(1));
      await tester.tap(option2025.last);
      await tester.pumpAndSettle();

      // Year updated to 2025
      expect(find.text('2025'), findsAtLeastNWidgets(1));

      // Day 29 was clamped to 28 because 2025 is not a leap year
      // Header must display Fri, Feb 28
      expect(find.textContaining('Fri, Feb 28'), findsOneWidget);

      // Day 29 should no longer exist in the February 2025 grid
      expect(find.text('29'), findsNothing);
      expect(find.text('28'), findsWidgets);
    });

    testWidgets(
        '2.3: Year boundary wrap-around: 2024-12-31 steps forward to 2025-01-31 and then clamps in Feb',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 12, 31)),
      );
      await tester.pumpAndSettle();

      expect(find.text('December'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.textContaining('Tue, Dec 31'), findsOneWidget);

      // Tap next month chevron (>)
      final nextMonthBtn = find.byIcon(Icons.chevron_right_rounded);
      expect(nextMonthBtn, findsOneWidget);

      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      // Wrapped to January 2025, day 31 remains valid
      expect(find.text('January'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.textContaining('Fri, Jan 31'), findsOneWidget);

      // Tap next month chevron (>) again to February 2025
      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      // February 2025 has 28 days; day 31 must clamp to 28
      expect(find.text('February'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.textContaining('Fri, Feb 28'), findsOneWidget);
    });

    testWidgets(
        '2.4: Year boundary step-back: 2025-01-15 steps backward to 2024-12-15 and rapid step-back',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2025, 1, 15)),
      );
      await tester.pumpAndSettle();

      expect(find.text('January'), findsOneWidget);
      expect(find.text('2025'), findsOneWidget);
      expect(find.textContaining('Wed, Jan 15'), findsOneWidget);

      // Tap previous month chevron (<)
      final prevMonthBtn = find.byIcon(Icons.chevron_left_rounded);
      expect(prevMonthBtn, findsOneWidget);

      await tester.tap(prevMonthBtn);
      await tester.pumpAndSettle();

      // Stepped back to December 2024
      expect(find.text('December'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.textContaining('Sun, Dec 15'), findsOneWidget);

      // Stress step-back: tap 24 times consecutively (stepping back 2 full years)
      for (int i = 0; i < 24; i++) {
        await tester.tap(prevMonthBtn);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      // December 2024 minus 24 months = December 2022
      expect(find.text('December'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
      expect(find.textContaining('Thu, Dec 15'), findsOneWidget);
    });

    testWidgets('2.5: Month day clamping on 31st: March 31 clamps to April 30',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 3, 31)),
      );
      await tester.pumpAndSettle();

      expect(find.text('March'), findsOneWidget);
      expect(find.textContaining('Sun, Mar 31'), findsOneWidget);

      // Advance to April (which only has 30 days)
      final nextMonthBtn = find.byIcon(Icons.chevron_right_rounded);
      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      expect(find.text('April'), findsOneWidget);
      // Clamped to 30
      expect(find.textContaining('Tue, Apr 30'), findsOneWidget);
      expect(find.text('31'), findsNothing);
    });
  });

  group('Group 3: Empty State Behavior & CTA Resilience', () {
    testWidgets(
        '3.1: Zero activity day displays Empty State card in Spends mode with CTA',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = BudgetController();
      final resto = MockAdversarialCampusRestoController();

      // Day with no transactions
      await tester.pumpWidget(
        _wrapCalendarAdversarial(
          initialDate: DateTime(2024, 5, 20),
          budget: budget,
          resto: resto,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Empty State Title
      expect(find.text('No activity on this date'), findsOneWidget);
      expect(
        find.text('No expenses or campus meal bookings recorded for this day.'),
        findsOneWidget,
      );

      // Verify CTA button
      expect(find.text('Log Expense'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Verify Total spend shows 0.000 DT via RouletteNumberText semantics
      expect(find.byType(RouletteNumberText), findsWidgets);
      expect(find.bySemanticsLabel('0.000 DT'), findsWidgets);
    });

    testWidgets(
        '3.2: Zero activity day displays Empty State card in Categories mode with CTA',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 5, 20)),
      );
      await tester.pumpAndSettle();

      // Switch to Categories filter mode
      final categoriesTab = find.text('Categories');
      await tester.tap(categoriesTab);
      await tester.pumpAndSettle();

      // Verify Empty State still properly rendered in Categories mode
      expect(find.text('No activity on this date'), findsOneWidget);
      expect(find.text('Log Expense'), findsOneWidget);
    });

    testWidgets('3.3: Tapping CTA button opens Spend sheet without throwing',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 5, 20)),
      );
      await tester.pumpAndSettle();

      // Tap CTA button after ensuring it is visible in the scroll viewport
      final logExpenseBtn = find.text('Log Expense');
      expect(logExpenseBtn, findsOneWidget);

      await tester.ensureVisible(logExpenseBtn);
      await tester.tap(logExpenseBtn);
      await tester.pumpAndSettle();

      // Modal bottom sheet opens cleanly
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets(
        '3.4: Day with both expenses and campus meals renders dual indicator dots',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = BudgetController();
      budget.addExpense(
        title: 'Books & Stationery',
        amount: 35.000,
        category: 'Books & Tech',
        date: DateTime(2024, 5, 10, 14, 0),
      );

      final resto = MockAdversarialCampusRestoController();
      resto.weeklyMeals = [
        CampusMealItem(
          id: 'meal_10',
          date: DateTime(2024, 5, 10),
          dayLabel: 'Vendredi',
          type: MealType.dejeuner,
          status: MealStatus.reserved,
        ),
      ];

      await tester.pumpWidget(
        _wrapCalendarAdversarial(
          initialDate: DateTime(2024, 5, 10),
          budget: budget,
          resto: resto,
        ),
      );
      await tester.pumpAndSettle();

      // Indicator dots container: both vibrantGreen (expense) and iconBlue (meal)
      final dotWidgets =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.shape == BoxShape.circle) {
          return dec.color == AppColors.vibrantGreen ||
              dec.color == AppColors.iconBlue;
        }
        return false;
      });

      expect(dotWidgets.length, greaterThanOrEqualTo(2),
          reason: 'Both expense dot and meal dot must be rendered');

      // Both items appear in activity list
      expect(find.text('Books & Stationery'), findsOneWidget);
      expect(find.text('Campus Resto - Déjeuner'), findsOneWidget);
    });
  });

  group('Group 4: Dynamic Toggle Switching (Spends vs Categories) Under Load',
      () {
    testWidgets(
        '4.1: Rapid toggle storm (30+ alternations) between Spends and Categories with active data',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = BudgetController();
      budget.addExpense(
        title: 'Monoprix Groceries',
        amount: 42.500,
        category: 'Groceries',
        date: DateTime(2024, 6, 12, 11, 0),
      );
      budget.addExpense(
        title: 'Campus Coffee',
        amount: 3.200,
        category: 'Social & Transit',
        date: DateTime(2024, 6, 12, 15, 30),
      );
      budget.addExpense(
        title: 'Python Handbook',
        amount: 28.000,
        category: 'Books & Tech',
        date: DateTime(2024, 6, 12, 17, 0),
      );

      final resto = MockAdversarialCampusRestoController();
      resto.weeklyMeals = [
        CampusMealItem(
          id: 'meal_12_dej',
          date: DateTime(2024, 6, 12),
          dayLabel: 'Mercredi',
          type: MealType.dejeuner,
          status: MealStatus.reserved,
        ),
        CampusMealItem(
          id: 'meal_12_din',
          date: DateTime(2024, 6, 12),
          dayLabel: 'Mercredi',
          type: MealType.diner,
          status: MealStatus.reserved,
        ),
      ];

      await tester.pumpWidget(
        _wrapCalendarAdversarial(
          initialDate: DateTime(2024, 6, 12),
          budget: budget,
          resto: resto,
        ),
      );
      await tester.pumpAndSettle();

      final spendsTab = find.text('Spends');
      final categoriesTab = find.text('Categories');

      // 30 rapid alternations with partial animation steps
      for (int i = 0; i < 30; i++) {
        if (i % 2 == 0) {
          await tester.tap(categoriesTab);
        } else {
          await tester.tap(spendsTab);
        }
        await tester.pump(const Duration(milliseconds: 25));
      }

      await tester.pumpAndSettle();

      // Verify in Spends mode (last was odd index -> Spends)
      expect(find.text('Monoprix Groceries'), findsOneWidget);
      expect(find.text('Campus Coffee'), findsOneWidget);
      expect(find.text('Python Handbook'), findsOneWidget);
      expect(find.text('Campus Resto - Déjeuner'), findsOneWidget);
      expect(find.text('Campus Resto - Dîner'), findsOneWidget);

      // Now switch once to Categories and verify category items
      await tester.tap(categoriesTab);
      await tester.pumpAndSettle();

      expect(find.text('Category Share'), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsWidgets);
    });

    testWidgets('4.2: Data integrity & formatting in Spends mode',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = BudgetController();
      budget.addExpense(
        title: 'Monthly Bus Pass',
        amount: 22.000,
        category: 'Social & Transit',
        date: DateTime(2024, 7, 5, 8, 45),
      );

      await tester.pumpWidget(
        _wrapCalendarAdversarial(
          initialDate: DateTime(2024, 7, 5),
          budget: budget,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Monthly Bus Pass'), findsOneWidget);
      expect(find.text('08:45'), findsOneWidget);
      expect(find.text('Social & Transit'), findsOneWidget);
      expect(find.text('•'), findsOneWidget);

      // Roulette number text present
      expect(find.byType(RouletteNumberText), findsWidgets);
    });
  });

  group('Group 5: Micro-Viewport, Disposal & Navigation Shell Integration', () {
    testWidgets(
        '5.1: Micro-viewport stress (280x600): zero RenderFlex overflows',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final budget = BudgetController();
      budget.addExpense(
        title: 'Quick Sandwich & Soda',
        amount: 6.500,
        category: 'Food & Dining',
        date: DateTime(2024, 8, 14, 12, 15),
      );

      await tester.pumpWidget(
        _wrapCalendarAdversarial(
          initialDate: DateTime(2024, 8, 14),
          budget: budget,
        ),
      );
      await tester.pumpAndSettle();

      // Cycle next month, switch toggle, tap day
      final nextMonthBtn = find.byIcon(Icons.chevron_right_rounded);
      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      final categoriesTab = find.text('Categories');
      await tester.tap(categoriesTab);
      await tester.pumpAndSettle();

      // Zero layout overflow exceptions on micro-viewports
      expect(tester.takeException(), isNull,
          reason: 'RenderFlex must not overflow on micro-viewport (280x600)');
    });

    testWidgets(
        '5.2: CalendarScreen back button integration redirects to Tab 0 (Home) in MainShell',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Launch MainShell with Calendar as initial active tab (Tab 2)
      await tester.pumpWidget(_wrapMainShellAdversarial(initialIndex: 2));
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(2));

      // Back button in Calendar header
      final backBtn = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backBtn, findsOneWidget);

      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // MainShell must have switched to Tab 0 (Home)
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
          equals(0));
      expect(find.byType(HomeView), findsOneWidget);
    });

    testWidgets(
        '5.3: Rapid mount and unmount of CalendarScreen during active month transition',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapCalendarAdversarial(initialDate: DateTime(2024, 9, 10)),
      );
      await tester.pumpAndSettle();

      // Trigger next month
      final nextMonthBtn = find.byIcon(Icons.chevron_right_rounded);
      await tester.tap(nextMonthBtn);
      await tester.pump(const Duration(milliseconds: 20));

      // Destroy widget tree mid-flight
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

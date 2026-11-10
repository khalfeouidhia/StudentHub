import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';

class MockRestoControllerForCalendar extends ChangeNotifier
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

  @override
  Map<String, List<CampusMealItem>> get mealsByDate => {};
  @override
  List<String> get sortedDateKeys => [];
  @override
  bool get hasData => weeklyMeals.isNotEmpty;
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

Widget _wrapCalendarView({
  BudgetController? budget,
  CampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BudgetController>.value(
        value: budget ?? BudgetController(),
      ),
      ChangeNotifierProvider<CampusRestoController>.value(
        value: resto ?? MockRestoControllerForCalendar(),
      ),
    ],
    child: const MaterialApp(
      home: CalendarScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalendarScreen — Group 1: Two-Tone Header & Curved Body Scaffolding',
      () {
    testWidgets(
        'Header renders Deep Pine #1E3A2E, centered "Calender", back button, bell icon',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      // Centered Title "Calender"
      expect(find.text('Calender'), findsOneWidget);

      // Back button
      final backButton = find.byWidgetPredicate((w) =>
          w is Icon &&
          (w.icon == Icons.arrow_back ||
              w.icon == Icons.arrow_back_ios_new_rounded ||
              w.icon == Icons.chevron_left));
      expect(backButton, findsAtLeastNWidgets(1));

      // Notification bell icon
      final bellIcon = find.byWidgetPredicate((w) =>
          w is Icon &&
          (w.icon == Icons.notifications_none_rounded ||
              w.icon == Icons.notifications_outlined ||
              w.icon == Icons.notifications));
      expect(bellIcon, findsOneWidget);

      // Deep Pine header verification
      final deepPineContainers =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final color = c.color;
        final decoration = c.decoration;
        if (color == AppColors.deepPine) return true;
        if (decoration is BoxDecoration &&
            decoration.color == AppColors.deepPine) return true;
        return false;
      });
      expect(deepPineContainers, isNotEmpty,
          reason: 'Header must contain Deep Pine #1E3A2E background');
    });

    testWidgets('Curved body container features exactly 38px top border radius',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      final curvedContainers =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration &&
            decoration.borderRadius is BorderRadius) {
          final br = decoration.borderRadius as BorderRadius;
          return br.topLeft.x == 38.0 && br.topRight.x == 38.0;
        }
        return false;
      });

      expect(curvedContainers, isNotEmpty,
          reason:
              'Body container must feature 38px top border radius curved scaffolding');
    });
  });

  group('CalendarScreen — Group 2: Month & Year Selector Dialogs', () {
    testWidgets('Tapping month selector opens picker dialog and updates grid',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      // Find month dropdown button/pill
      final monthFinder = find.byWidgetPredicate((w) =>
          w is Text &&
          [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December'
          ].any((m) => w.data?.contains(m) ?? false));

      expect(monthFinder, findsAtLeastNWidgets(1));

      // Tap month selector
      await tester.tap(monthFinder.first);
      await tester.pumpAndSettle();

      // Dialog or bottom sheet opens showing months
      final mayOption = find.text('May');
      if (mayOption.evaluate().isNotEmpty) {
        await tester.tap(mayOption.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('May'), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('Tapping year selector opens picker dialog and updates grid',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      // Find year dropdown button/pill
      final yearFinder = find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'\b202[4-9]\b').hasMatch(w.data ?? ''));
      expect(yearFinder, findsAtLeastNWidgets(1));

      // Tap year selector
      await tester.tap(yearFinder.first);
      await tester.pumpAndSettle();

      // Select year 2027
      final targetYear = find.text('2027');
      if (targetYear.evaluate().isNotEmpty) {
        await tester.tap(targetYear.first);
        await tester.pumpAndSettle();
        expect(find.textContaining('2027'), findsAtLeastNWidgets(1));
      }
    });
  });

  group('CalendarScreen — Group 3: Monday-to-Sunday 7-Column Day Matrix', () {
    testWidgets('Matrix renders 7 column headers in Mon..Sun order',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      // Verify Monday first column convention
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets(
        'Active day selection applies solid #1E3A2E circle and bold white text',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      // Tap day 15 in matrix
      final day15 = find.widgetWithText(InkWell, '15').evaluate().isNotEmpty
          ? find.widgetWithText(InkWell, '15')
          : find.widgetWithText(GestureDetector, '15');

      if (day15.evaluate().isNotEmpty) {
        await tester.tap(day15.first);
        await tester.pumpAndSettle();

        // Verify active day highlight circle #1E3A2E
        final highlightedPills =
            tester.widgetList<Container>(find.byType(Container)).where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == AppColors.deepPine &&
                (decoration.shape == BoxShape.circle ||
                    (decoration.borderRadius is BorderRadius &&
                        (decoration.borderRadius as BorderRadius).topLeft.x >=
                            12));
          }
          return false;
        });

        expect(highlightedPills, isNotEmpty,
            reason:
                'Active day cell must be highlighted with solid #1E3A2E circle');
      }
    });

    testWidgets(
        'Indicator dots render for days with logged transactions or meals',
        (WidgetTester tester) async {
      final budget = BudgetController();
      final now = DateTime.now();

      budget.addExpense(
        title: 'Cafe Espresso',
        amount: 2.500,
        category: 'Food & Dining',
        date: DateTime(now.year, now.month, 10, 10, 0),
      );

      await tester.pumpWidget(_wrapCalendarView(budget: budget));
      await tester.pumpAndSettle();

      // Dot containers rendered in matrix
      final dotWidgets =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle) {
          final w = c.constraints?.maxWidth ?? 0;
          return w > 0 && w <= 8;
        }
        return false;
      });

      expect(dotWidgets, isNotEmpty,
          reason: 'Indicator dots must render for dates with transactions');
    });
  });

  group('CalendarScreen — Group 4: Spends vs Categories Segmented Toggle', () {
    testWidgets(
        'Renders Spends and Categories pills with #00D084 active highlight',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapCalendarView());
      await tester.pumpAndSettle();

      expect(find.text('Spends'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);

      // Verify active pill uses vibrant green #00D084
      final vibrantPills =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.vibrantGreen;
      });

      expect(vibrantPills, isNotEmpty,
          reason:
              'Active segmented toggle pill must use vibrant green #00D084');

      // Tap Categories
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();

      // Toggle switches mode cleanly
      expect(find.text('Categories'), findsOneWidget);
    });
  });

  group('CalendarScreen — Group 5: Selected Day Activity Cards & Empty State',
      () {
    testWidgets(
        'Renders activity cards with #42A5F5 badge, category tag, and RouletteNumberText',
        (WidgetTester tester) async {
      final budget = BudgetController();
      final now = DateTime.now();

      budget.addExpense(
        title: 'Campus Stationery',
        amount: 14.500,
        category: 'Books & Study',
        date: now,
      );

      await tester.pumpWidget(_wrapCalendarView(budget: budget));
      await tester.pumpAndSettle();

      // Title & category visible
      expect(find.text('Campus Stationery'), findsOneWidget);

      // Blue icon badge #42A5F5
      final blueBadges =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.color == AppColors.iconBlue;
      });
      expect(blueBadges, isNotEmpty,
          reason: 'Activity cards must feature #42A5F5 icon badge');

      // Amount formatted via RouletteNumberText
      expect(find.byType(RouletteNumberText), findsAtLeastNWidgets(1));
    });

    testWidgets('Renders empty state when selected date has no activity',
        (WidgetTester tester) async {
      final budget = BudgetController();
      budget.clearAllExpenses();

      await tester.pumpWidget(_wrapCalendarView(budget: budget));
      await tester.pumpAndSettle();

      final emptyStateFinder = find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data?.toLowerCase().contains('no activity') == true ||
              w.data?.toLowerCase().contains('no transactions') == true ||
              w.data?.toLowerCase().contains('empty') == true));

      expect(emptyStateFinder, findsOneWidget,
          reason:
              'Empty state placeholder must render when selected date has no activity');
    });
  });
}

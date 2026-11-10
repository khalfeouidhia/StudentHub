import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';

/// Mock CampusRestoController for stress-testing CalendarScreen data integration.
class MockRestoControllerForStress extends ChangeNotifier
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
  StudentProfile? profile = const StudentProfile(
    fullName: 'Dhia Ben Test',
    cin: '12345678',
    dorm: DormInfo(foyer: 'Foyer Nord', bloc: 'B', chambre: '204'),
  );
  @override
  DormInfo? dormInfo = const DormInfo(
    foyer: 'Foyer Nord',
    bloc: 'B',
    chambre: '204',
  );
  @override
  WalletKpis? kpis = const WalletKpis(
    soldeRepas: 12,
    totalAchatMois: 45,
    depensesMois: 32.5,
  );
  @override
  List<CampusMealItem> weeklyMeals = [];
  @override
  List<RestoCheckIn> checkIns = const [];
  @override
  List<RestoTopUp> topUps = const [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Target viewports from micro-foldable to desktop
  const viewports = <String, Size>{
    '280x653 (Micro-Foldable)': Size(280, 653),
    '320x568 (iPhone SE 1st gen)': Size(320, 568),
    '360x800 (Standard Android)': Size(360, 800),
    '390x844 (iPhone 13/14)': Size(390, 844),
    '412x915 (Pixel 7)': Size(412, 915),
    '800x1280 (Tablet/Desktop)': Size(800, 1280),
  };

  // Target accessibility text scaling factors
  const textScales = <double>[1.0, 1.5, 2.0, 2.5, 3.0];

  /// Helper to wrap and pump widget with strict viewport & text scaler
  Future<List<FlutterErrorDetails>> pumpStressWidget(
    WidgetTester tester, {
    required Size size,
    required double textScale,
    required Widget child,
    BudgetController? budget,
    CampusRestoController? resto,
    AuthController? auth,
    TasksController? tasks,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final caughtErrors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtErrors.add(details);
    };

    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BudgetController>.value(
              value: budget ?? BudgetController(),
            ),
            ChangeNotifierProvider<CampusRestoController>.value(
              value: resto ?? MockRestoControllerForStress(),
            ),
            ChangeNotifierProvider<AuthController>.value(
              value: auth ?? AuthController(),
            ),
            ChangeNotifierProvider<TasksController>.value(
              value: tasks ?? TasksController(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(top: 24, bottom: 16),
              ),
              child: child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = originalOnError;
    }

    return caughtErrors;
  }

  group(
      'Adversarial Stress Group 1: CalendarScreen Viewport & Scale Matrix (Empty State)',
      () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'CalendarScreen 0 overflow on ${vpEntry.key} @ ${scale}x text scale',
          (tester) async {
            final errors = await pumpStressWidget(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: const CalendarScreen(
                initialDate: null,
              ),
            );

            expect(
              errors,
              isEmpty,
              reason:
                  'RenderFlex or FlutterError detected on ${vpEntry.key} @ ${scale}x: $errors',
            );
            expect(tester.takeException(), isNull);

            // Confirm core elements are present
            expect(find.text('Calender'), findsOneWidget);
            expect(find.text('Spends'), findsOneWidget);
            expect(find.text('Categories'), findsOneWidget);
            expect(find.text('No activity on this date'), findsOneWidget);
          },
        );
      }
    }
  });

  group(
      'Adversarial Stress Group 2: CalendarScreen Viewport & Scale Matrix (Populated State)',
      () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'CalendarScreen populated 0 overflow on ${vpEntry.key} @ ${scale}x text scale',
          (tester) async {
            final budget = BudgetController();
            final targetDate = DateTime(2026, 9, 15, 13, 30);

            // Seed multiple heavy transactions with long titles and large amounts
            budget.addExpense(
              title: 'Comprehensive Textbook & Scientific Equipment Purchase',
              amount: 1485.650,
              date: targetDate,
              category: 'Books & Supplies',
            );
            budget.addExpense(
              title: 'Monthly University Housing & Shared Utilities Rent',
              amount: 850.000,
              date: targetDate,
              category: 'Rent & Housing',
            );
            budget.addExpense(
              title: 'Resto U Meal Voucher Pack (40 Meals)',
              amount: 80.000,
              date: targetDate,
              category: 'Food & Dining',
            );

            final resto = MockRestoControllerForStress();
            resto.weeklyMeals = [
              CampusMealItem(
                id: 'meal-stress-1',
                type: MealType.dejeuner,
                date: targetDate,
                dayLabel: 'Mardi',
                status: MealStatus.reserved,
                rawStatusText: 'Réservé',
              ),
            ];

            final errors = await pumpStressWidget(
              tester,
              size: vpEntry.value,
              textScale: scale,
              budget: budget,
              resto: resto,
              child: CalendarScreen(
                initialDate: targetDate,
              ),
            );

            expect(
              errors,
              isEmpty,
              reason:
                  'RenderFlex or FlutterError detected on populated ${vpEntry.key} @ ${scale}x: $errors',
            );
            expect(tester.takeException(), isNull);

            // Verify Spends mode displays populated items
            expect(find.text('Spends'), findsOneWidget);
            expect(find.textContaining('Textbook'), findsOneWidget);

            // Toggle to Categories mode and verify 0 overflow
            await tester.tap(find.text('Categories'));
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.textContaining('Category Share'), findsOneWidget);
          },
        );
      }
    }
  });

  group(
      'Adversarial Stress Group 3: Month & Year Picker Dialogs Under Narrow 280dp Viewport',
      () {
    for (final scale in textScales) {
      testWidgets(
        'Month Picker Dialog opens and selects smoothly at 280x653 @ ${scale}x scale',
        (tester) async {
          final errors = await pumpStressWidget(
            tester,
            size: const Size(280, 653),
            textScale: scale,
            child: CalendarScreen(
              initialDate: DateTime(2026, 1, 15),
            ),
          );
          expect(errors, isEmpty);

          // Tap month dropdown pill
          final monthPillFinder = find.text('January');
          expect(monthPillFinder, findsOneWidget);
          await tester.tap(monthPillFinder);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Month dialog should be visible
          expect(find.text('Select Month'), findsOneWidget);
          expect(find.text('Sep'), findsOneWidget);

          // Select 'Sep' (September)
          await tester.tap(find.text('Sep'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Select Month'), findsNothing);
          expect(find.text('September'), findsOneWidget);
        },
      );

      testWidgets(
        'Year Picker Dialog opens and selects smoothly at 280x653 @ ${scale}x scale',
        (tester) async {
          final errors = await pumpStressWidget(
            tester,
            size: const Size(280, 653),
            textScale: scale,
            child: CalendarScreen(
              initialDate: DateTime(2026, 9, 15),
            ),
          );
          expect(errors, isEmpty);

          // Tap year dropdown pill
          final yearPillFinder = find.text('2026');
          expect(yearPillFinder, findsOneWidget);
          await tester.tap(yearPillFinder);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Select Year'), findsOneWidget);
          expect(find.text('2027'), findsOneWidget);

          // Select '2027'
          await tester.tap(find.text('2027'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Select Year'), findsNothing);
          expect(find.text('2027'), findsOneWidget);
        },
      );
    }
  });

  group(
      'Adversarial Stress Group 4: Month Stepper Buttons (<, >) Across Long Month Names on 280dp',
      () {
    for (final scale in [1.0, 1.5, 2.0, 2.5, 3.0]) {
      testWidgets(
        'Stepper buttons cycle all 12 months including "September" without overflow at 280x653 @ ${scale}x',
        (tester) async {
          final errors = await pumpStressWidget(
            tester,
            size: const Size(280, 653),
            textScale: scale,
            child: CalendarScreen(
              initialDate: DateTime(2026, 1, 1),
            ),
          );
          expect(errors, isEmpty);

          final nextButton = find.byIcon(Icons.chevron_right_rounded);
          final prevButton = find.byIcon(Icons.chevron_left_rounded);
          expect(nextButton, findsOneWidget);
          expect(prevButton, findsOneWidget);

          const expectedMonths = [
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September', // Longest month string (9 chars)
            'October',
            'November',
            'December',
          ];

          // Forward stepping through all 12 months
          for (int m = 0; m < 12; m++) {
            expect(find.text(expectedMonths[m]), findsOneWidget);
            expect(tester.takeException(), isNull);

            if (m < 11) {
              await tester.tap(nextButton);
              await tester.pumpAndSettle();
            }
          }

          // Backward stepping from December back to September
          for (int b = 11; b >= 8; b--) {
            expect(find.text(expectedMonths[b]), findsOneWidget);
            expect(tester.takeException(), isNull);

            if (b > 8) {
              await tester.tap(prevButton);
              await tester.pumpAndSettle();
            }
          }

          expect(find.text('September'), findsOneWidget);
        },
      );
    }
  });

  group(
      'Adversarial Stress Group 5: LiquidGlassBottomNavBar & MainShell Viewport & Scale Matrix',
      () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'LiquidGlassBottomNavBar 5-tab 0 overflow on ${vpEntry.key} @ ${scale}x',
          (tester) async {
            final errors = await pumpStressWidget(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: Scaffold(
                body: Stack(
                  children: [
                    const SizedBox.expand(),
                    LiquidGlassBottomNavBar(
                      currentIndex: 2,
                      onTap: (_) {},
                      items: const [
                        GlassNavItem(
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                        ),
                        GlassNavItem(
                          icon: Icons.pie_chart_outline_rounded,
                          activeIcon: Icons.pie_chart_rounded,
                          label: 'Expenses',
                        ),
                        GlassNavItem(
                          icon: Icons.calendar_month_outlined,
                          activeIcon: Icons.calendar_month_rounded,
                          label: 'Calendar',
                        ),
                        GlassNavItem(
                          icon: Icons.checklist_rtl_outlined,
                          activeIcon: Icons.checklist_rtl_rounded,
                          label: 'Tasks',
                        ),
                        GlassNavItem(
                          icon: Icons.restaurant_outlined,
                          activeIcon: Icons.restaurant_rounded,
                          label: 'Resto U',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            expect(
              errors,
              isEmpty,
              reason:
                  'RenderFlex or FlutterError on nav dock on ${vpEntry.key} @ ${scale}x: $errors',
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Calendar'), findsOneWidget);
          },
        );

        testWidgets(
          'MainShell hosting CalendarScreen 0 overflow on ${vpEntry.key} @ ${scale}x',
          (tester) async {
            final errors = await pumpStressWidget(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: const MainShell(initialIndex: 2),
            );

            expect(
              errors,
              isEmpty,
              reason:
                  'RenderFlex or FlutterError in MainShell on ${vpEntry.key} @ ${scale}x: $errors',
            );
            expect(tester.takeException(), isNull);
            expect(find.text('Calender'), findsOneWidget);
            expect(find.text('Calendar'), findsOneWidget);
          },
        );
      }
    }
  });

  group(
      'Adversarial Stress Group 6: Interactive Day Grid Selection Under Micro-Viewport & 3.0x Scale',
      () {
    testWidgets(
      'Tapping Mon-Sun grid day cells selects dates without layout drift or exception at 280x653 @ 3.0x',
      (tester) async {
        final errors = await pumpStressWidget(
          tester,
          size: const Size(280, 653),
          textScale: 3.0,
          child: CalendarScreen(
            initialDate: DateTime(2026, 9, 1),
          ),
        );
        expect(errors, isEmpty);

        // Day 1 is initially selected
        expect(find.text('Tue, Sep 1'), findsOneWidget);

        // Tap day 15
        final day15Finder = find.widgetWithText(GestureDetector, '15');
        expect(day15Finder, findsOneWidget);
        await tester.tap(day15Finder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tue, Sep 15'), findsOneWidget);

        // Tap day 30
        final day30Finder = find.widgetWithText(GestureDetector, '30');
        expect(day30Finder, findsOneWidget);
        await tester.tap(day30Finder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Wed, Sep 30'), findsOneWidget);
      },
    );
  });
}

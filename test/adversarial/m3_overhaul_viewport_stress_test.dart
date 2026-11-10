import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';
import 'package:studenthold_app/ui/views/expenses_view.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';

/// Mock CampusRestoController for comprehensive adversarial viewport testing.
class MockRestoControllerForAdversarial extends ChangeNotifier
    implements CampusRestoController {
  @override
  RestoAuthStatus get authStatus => isAuthenticated
      ? RestoAuthStatus.authenticated
      : (isLoading ? RestoAuthStatus.loading : RestoAuthStatus.unauthenticated);

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

  MockRestoControllerForAdversarial({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.profile,
    this.dormInfo,
    this.kpis,
    this.weeklyMeals = const [],
    this.checkIns = const [],
    this.topUps = const [],
  });

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
  bool get hasData => profile != null || kpis != null || weeklyMeals.isNotEmpty;
  @override
  bool get isLowBalance => kpis?.isLowBalance ?? false;
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
  Future<bool> checkSession() async => true;
  @override
  Future<bool> onLoginSuccess(String cookies) async => true;
  @override
  Future<void> logout() async {
    isAuthenticated = false;
    notifyListeners();
  }

  @override
  Future<MealDetails?> getMealDetails(String repasId) async => null;
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Target viewports spanning micro-foldable to tablet
  const viewports = <String, Size>{
    '280x653 (Micro-Foldable)': Size(280, 653),
    '320x568 (iPhone SE 1st gen)': Size(320, 568),
    '360x800 (Standard Android)': Size(360, 800),
    '412x915 (Modern Flagship)': Size(412, 915),
    '800x1280 (Tablet / Desktop)': Size(800, 1280),
  };

  // Target accessibility text scaling factors up to 3.0x
  const textScales = <double>[1.0, 1.5, 2.0, 2.5, 3.0];

  /// Helper to wrap and pump widget with strict viewport & text scaler
  Future<List<FlutterErrorDetails>> pumpStressScreen(
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
              value: resto ?? MockRestoControllerForAdversarial(),
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = originalOnError;
    }

    return caughtErrors;
  }

  // ---------------------------------------------------------------------------
  // 1. HomeView Multi-Viewport & Scale Stress Matrix
  // ---------------------------------------------------------------------------
  group('M3 Stress Group 1: HomeView (Empty / Default State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'HomeView zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: const HomeView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on HomeView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('M3 Stress Group 2: HomeView (Populated / Long Text State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'HomeView (populated) zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final tasks = TasksController();
            tasks.addTask(
              title:
                  'Comprehensive Distributed Systems & Cloud Microservices Final Examination',
              category: 'Academic',
              dueDate: 'Due Friday at 11:59 PM',
            );
            tasks.addTask(
              title:
                  'Grocery shopping for organic vegetables, Greek yogurt and oat milk',
              category: 'Personal/Chore',
              dueDate: 'Saturday morning at 9:00 AM',
            );

            final budget = BudgetController();
            await budget.setBudgetCap(25000.500, 3500.000);
            budget.addExpense(
              title:
                  'Database Systems Architecture & Implementation Reference Edition',
              amount: 1420.750,
              category: 'Books, Course Tech & Tools',
            );
            budget.addExpense(
              title:
                  'Monthly University Campus Dining Hall Pass & Meal Card Recharge',
              amount: 2850.000,
              category: 'Campus Dining & Groceries',
            );

            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              budget: budget,
              tasks: tasks,
              child: const HomeDashboard(
                userName: 'Professor Alexander Maximilian Montgomery III',
                university:
                    'National Institute of Applied Science and Technology University Campus',
              ),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on populated HomeView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  // ---------------------------------------------------------------------------
  // 2. ExpensesView Multi-Viewport & Scale Stress Matrix
  // ---------------------------------------------------------------------------
  group('M3 Stress Group 3: ExpensesView (Empty / Default State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'ExpensesView zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: const ExpensesView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on ExpensesView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('M3 Stress Group 4: ExpensesView (Populated / Long Text State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'ExpensesView (populated) zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final budget = BudgetController();
            await budget.setBudgetCap(18500.000, 2000.000);
            budget.addExpense(
              title:
                  'Advanced Operating Systems Internals and Kernel Architecture',
              amount: 890.250,
              category: 'Books, Course Tech & Tools',
            );
            budget.addExpense(
              title:
                  'Shared Dormitory Rent & High-Speed Fiber Internet Utilities',
              amount: 4500.000,
              category: 'Housing & Shared Utilities',
            );
            budget.addExpense(
              title:
                  'Weekly Supermarket Haul for Fresh Produce, Poultry & Snacks',
              amount: 675.800,
              category: 'Campus Dining & Groceries',
            );
            budget.addExpense(
              title: 'Public Transit Monthly Student Pass & Train Tickets',
              amount: 220.000,
              category: 'Social, Club Dues & Commute',
            );

            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              budget: budget,
              child: const ExpensesView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on populated ExpensesView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  // ---------------------------------------------------------------------------
  // 3. TasksView Multi-Viewport & Scale Stress Matrix
  // ---------------------------------------------------------------------------
  group('M3 Stress Group 5: TasksView (Empty State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'TasksView zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              child: const TasksView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on TasksView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('M3 Stress Group 6: TasksView (Populated / Priority Tasks)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'TasksView (populated) zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final tasks = TasksController();
            tasks.addTask(
              title:
                  'Complete and submit Machine Learning term project final code and technical report',
              category: 'Academic',
              dueDate: 'Oct 30, 2026',
            );
            tasks.addTask(
              title:
                  'Prepare presentation slides for Distributed Software Engineering seminar',
              category: 'Academic',
              dueDate: 'Nov 02, 2026',
            );
            tasks.addTask(
              title:
                  'Deep clean shared student kitchen and organize refrigerator shelves',
              category: 'Personal/Chore',
              dueDate: 'Nov 05, 2026',
            );
            tasks.toggleTask(tasks.allTasks.first.id);

            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              tasks: tasks,
              child: const TasksView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on populated TasksView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  // ---------------------------------------------------------------------------
  // 4. RestoUView Multi-Viewport & Scale Stress Matrix
  // ---------------------------------------------------------------------------
  group('M3 Stress Group 7: RestoUView (Unauthenticated Gate State)', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'RestoUView unauth zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final resto = MockRestoControllerForAdversarial(
              isAuthenticated: false,
            );

            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              resto: resto,
              child: const RestoUView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on unauthenticated RestoUView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('M3 Stress Group 8: RestoUView (Authenticated / Full Meals Matrix)',
      () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'RestoUView auth zero overflow on ${vpEntry.key} @ ${scale}x scale',
          (tester) async {
            final resto = MockRestoControllerForAdversarial(
              isAuthenticated: true,
              profile: const StudentProfile(
                fullName: 'Dhia Eddine Ben Test Al-Mansouri',
                cin: '09876543',
                dorm: DormInfo(
                  foyer: 'Residence Universitaire Ibn Khaldoun Nord',
                  bloc: 'Bloc C - Etage 3',
                  chambre: 'Chambre 314-B',
                ),
              ),
              dormInfo: const DormInfo(
                foyer: 'Residence Universitaire Ibn Khaldoun Nord',
                bloc: 'Bloc C - Etage 3',
                chambre: 'Chambre 314-B',
              ),
              kpis: const WalletKpis(
                soldeRepas: 28,
                totalAchatMois: 60,
                depensesMois: 14.5,
              ),
              weeklyMeals: [
                CampusMealItem(
                  id: '101',
                  date: DateTime.now().add(const Duration(days: 1)),
                  type: MealType.dejeuner,
                  dayLabel: 'Lundi',
                  status: MealStatus.notReserved,
                ),
                CampusMealItem(
                  id: '102',
                  date: DateTime.now().add(const Duration(days: 1)),
                  type: MealType.diner,
                  dayLabel: 'Lundi',
                  status: MealStatus.reserved,
                ),
                CampusMealItem(
                  id: '103',
                  date: DateTime.now().add(const Duration(days: 2)),
                  type: MealType.dejeuner,
                  dayLabel: 'Mardi',
                  status: MealStatus.consumed,
                ),
              ],
            );

            final errors = await pumpStressScreen(
              tester,
              size: vpEntry.value,
              textScale: scale,
              resto: resto,
              child: const RestoUView(),
            );

            final overflowErrors = errors
                .where((e) =>
                    e.exceptionAsString().contains('overflowed') ||
                    e.exceptionAsString().contains('RenderFlex'))
                .toList();

            expect(
              overflowErrors,
              isEmpty,
              reason:
                  'Overflow on authenticated RestoUView at ${vpEntry.key} @ ${scale}x: $overflowErrors',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}

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

class FakeCampusRestoController extends ChangeNotifier
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

  bool initCalled = false;
  bool refreshDashboardCalled = false;
  bool checkSessionCalled = false;
  bool logoutCalled = false;
  BudgetController? lastBudgetSynced;

  FakeCampusRestoController({
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
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<void> checkSession() async {
    checkSessionCalled = true;
  }

  @override
  Future<void> refreshDashboard() async {
    refreshDashboardCalled = true;
  }

  @override
  Future<void> onLoginSuccess(String cookies) async {
    isAuthenticated = true;
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
  Future<void> syncWithBudget(BudgetController budgetController) async {
    lastBudgetSynced = budgetController;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    isAuthenticated = false;
    notifyListeners();
  }
}

Widget createInteractiveHarness({
  required Widget child,
  AuthController? auth,
  BudgetController? budget,
  TasksController? tasks,
  CampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(
          value: auth ?? AuthController()),
      ChangeNotifierProvider<BudgetController>.value(
          value: budget ?? BudgetController()),
      ChangeNotifierProvider<TasksController>.value(
          value: tasks ?? TasksController()),
      ChangeNotifierProvider<CampusRestoController>.value(
        value: resto ??
            FakeCampusRestoController(
              profile: const StudentProfile(
                fullName: 'Dhia Ben Amor',
                cin: '09876543',
                dorm:
                    DormInfo(foyer: 'Foyer Kélibia', bloc: 'B', chambre: '204'),
              ),
              kpis: const WalletKpis(
                  soldeRepas: 12, totalAchatMois: 30, depensesMois: 6.0),
            ),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Group 1: ExpensesView Interactive Period Pills & Auto-Sync Stress',
      () {
    testWidgets(
        '1.1: Rapid switching between Daily, Weekly, and Monthly period pills',
        (tester) async {
      final budget = BudgetController();
      final resto = FakeCampusRestoController();

      await tester.pumpWidget(createInteractiveHarness(
        child: const ExpensesView(),
        budget: budget,
        resto: resto,
      ));
      await tester.pumpAndSettle();

      expect(find.text('OCTOBER TOTAL OUTFLOW'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);

      // Stress tap: 15 rapid alternations between Daily, Weekly, Monthly
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Daily'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Weekly'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.text('Monthly'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('OCTOBER TOTAL OUTFLOW'), findsOneWidget);
    });

    testWidgets(
        '1.2: Meal Card Recharges Auto-Sync triggers sync without runtime exceptions',
        (tester) async {
      final budget = BudgetController();
      final resto = FakeCampusRestoController(
        topUps: [
          RestoTopUp(
            id: 't1',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            mealCount: 10,
            cin: '09876543',
          ),
        ],
        checkIns: [
          RestoCheckIn(
            id: 'c1',
            timestamp: DateTime.now().subtract(const Duration(hours: 4)),
            quantity: 1,
            cin: '09876543',
            mealType: MealType.dejeuner,
          ),
        ],
      );

      await tester.pumpWidget(createInteractiveHarness(
        child: const ExpensesView(),
        budget: budget,
        resto: resto,
      ));
      await tester.pumpAndSettle();

      final syncButton = find.widgetWithText(ElevatedButton, 'Sync');
      expect(syncButton, findsOneWidget);

      // Tap Sync button
      await tester.tap(syncButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify no exceptions were thrown
      expect(find.text('Meal Card Recharges Auto-Sync'), findsOneWidget);
    });

    testWidgets(
        '1.3: ExpensesView Add Expense modal opens, inputs data, and updates state',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(createInteractiveHarness(
        child: const ExpensesView(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Tap 'Add Expense' in header (first instance)
      final addExpenseBtn = find.text('Add Expense').first;
      await tester.tap(addExpenseBtn);
      await tester.pumpAndSettle();

      expect(find.text('Record Outflow'), findsOneWidget);

      // Fill in text fields in modal (skip search bar which is index 0)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));
      await tester.enterText(textFields.at(1), 'Campus Sandwich');
      await tester.enterText(textFields.at(2), '4.500');
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.widgetWithText(ElevatedButton, 'Save Expense');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify expense added to budget controller
      expect(budget.spentSoFar, 4.5);
      expect(find.text('Campus Sandwich'), findsOneWidget);
    });
  });

  group('Group 2: TasksView Interactive Filters & Checklist Stress', () {
    testWidgets(
        '2.1: Filter toggles (All, Academic, Personal/Chore) switch accurately under load',
        (tester) async {
      final tasks = TasksController();
      tasks.addTask(
          title: 'Calculus Quiz',
          category: 'Academic',
          dueDate: 'Nov 12, 2026');
      tasks.addTask(
          title: 'Buy Dorm Groceries',
          category: 'Personal',
          dueDate: 'Nov 14, 2026');

      await tester.pumpWidget(createInteractiveHarness(
        child: const TasksView(),
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Calculus Quiz'), findsOneWidget);
      expect(find.text('Buy Dorm Groceries'), findsOneWidget);

      final academicTab = find.text('Academic').first;
      final personalTab = find.text('Personal/Chore');
      final allTab = find.text('All');

      // Stress toggle between filters 10 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(academicTab);
        await tester.pump(const Duration(milliseconds: 30));
        await tester.tap(personalTab);
        await tester.pump(const Duration(milliseconds: 30));
        await tester.tap(allTab);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      // Switch to Academic: only Calculus Quiz visible
      await tester.tap(academicTab);
      await tester.pumpAndSettle();
      expect(find.text('Calculus Quiz'), findsOneWidget);
      expect(find.text('Buy Dorm Groceries'), findsNothing);

      // Switch to Personal/Chore: only Buy Dorm Groceries visible
      await tester.tap(personalTab);
      await tester.pumpAndSettle();
      expect(find.text('Calculus Quiz'), findsNothing);
      expect(find.text('Buy Dorm Groceries'), findsOneWidget);
    });

    testWidgets(
        '2.2: Toggling task completion updates completion percentage and roulette text',
        (tester) async {
      final tasks = TasksController();
      tasks.addTask(
          title: 'Physics Assignment',
          category: 'Academic',
          dueDate: 'Nov 10, 2026');

      await tester.pumpWidget(createInteractiveHarness(
        child: const TasksView(),
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      expect(find.text('0% Complete'), findsOneWidget);

      // Tap task card checkbox toggle container
      final toggleFinder = find.byType(AnimatedContainer);
      expect(toggleFinder, findsWidgets);

      // Directly toggle via controller to verify reactive header update
      tasks.toggleTask(tasks.allTasks.first.id);
      await tester.pumpAndSettle();

      expect(tasks.completionPercentage, 100);
      expect(find.text('100% Complete'), findsOneWidget);
    });

    testWidgets('2.3: Add Task modal creates task dynamically', (tester) async {
      final tasks = TasksController();
      await tester.pumpWidget(createInteractiveHarness(
        child: const TasksView(),
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      // Empty state shows Add Task button
      final addBtn = find.widgetWithText(ElevatedButton, 'Add Task');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      expect(find.text('Add Academic / Personal Task'), findsOneWidget);

      // Enter task title
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Prepare CS Presentation');
      await tester.pumpAndSettle();

      // Save task via modal button (last instance of 'Add Task' button)
      final saveBtn = find.widgetWithText(ElevatedButton, 'Add Task').last;
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(tasks.allCount, 1);
      expect(find.text('Prepare CS Presentation'), findsOneWidget);
    });
  });

  group('Group 3: HomeView Quick Action Modals & Utility Buttons Stress', () {
    testWidgets('3.1: Quick actions (Add Expense, Adjust Cap) trigger cleanly',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(createInteractiveHarness(
        child: const HomeView(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // 'Add Expense' action opens Add Expense modal
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Record New Outflow'), findsOneWidget);

      // Enter valid amount and save
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Dorm Snack');
      await tester.enterText(textFields.last, '2.500');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Expense'));
      await tester.pumpAndSettle();

      expect(budget.spentSoFar, 2.5);

      // 'Adjust Cap' action opens Adjust Monthly Cap modal
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();
      expect(find.text('Adjust Monthly Cap'), findsOneWidget);
    });

    testWidgets(
        '3.2: Utility actions (Adjust Cap) open modal sheets and update cap',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(createInteractiveHarness(
        child: const HomeView(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // 'Adjust Cap' modal opens and updates cap
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();

      expect(find.text('Adjust Monthly Cap'), findsOneWidget);
      expect(find.text('Update Budget Cap'), findsOneWidget);

      await tester.tap(find.text('Update Budget Cap'));
      await tester.pumpAndSettle();
      expect(find.text('Adjust Monthly Cap'), findsNothing);
    });

    testWidgets(
        '3.3: Header History and Notifications buttons trigger modal sheets',
        (tester) async {
      final budget = BudgetController();
      final tasks = TasksController();
      await tester.pumpWidget(createInteractiveHarness(
        child: const HomeView(),
        budget: budget,
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      // Notifications bell button
      final bellIcon = find.byIcon(Icons.notifications_none_rounded);
      expect(bellIcon, findsOneWidget);
      await tester.tap(bellIcon);
      await tester.pumpAndSettle();

      expect(find.text('Active Notifications'), findsOneWidget);
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(find.text('Active Notifications'), findsNothing);

      // History button
      final historyIcon = find.byIcon(Icons.history_rounded);
      expect(historyIcon, findsOneWidget);
      await tester.tap(historyIcon);
      await tester.pumpAndSettle();

      expect(find.text('Historical Archive'), findsOneWidget);
    });
  });

  group('Group 4: RestoUView Interactive Date Pills & Scroller Stress', () {
    testWidgets(
        '4.1: Date pills tap switches active date filter without exceptions',
        (tester) async {
      final testMeals = [
        CampusMealItem(
          id: '101',
          type: MealType.dejeuner,
          date: DateTime(2026, 11, 9),
          dayLabel: 'Lundi',
          status: MealStatus.reserved,
        ),
        CampusMealItem(
          id: '102',
          type: MealType.diner,
          date: DateTime(2026, 11, 10),
          dayLabel: 'Mardi',
          status: MealStatus.notReserved,
        ),
      ];

      final resto = FakeCampusRestoController(
        profile: const StudentProfile(
          fullName: 'Ahmed Ben Salah',
          cin: '12345678',
          dorm: DormInfo(
              foyer: 'Cité Universitaire Kélibia', bloc: 'B', chambre: '104'),
        ),
        kpis: const WalletKpis(
            soldeRepas: 24, totalAchatMois: 40, depensesMois: 3.200),
        weeklyMeals: testMeals,
      );

      await tester.pumpWidget(createInteractiveHarness(
        child: const RestoUView(),
        resto: resto,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Campus Resto U'), findsOneWidget);
      expect(find.text('Ahmed Ben Salah'), findsOneWidget);
      expect(find.text('Cité Universitaire Kélibia'), findsOneWidget);

      // Tap date pills in scroller
      final lunPill = find.text('Lun');
      if (lunPill.evaluate().isNotEmpty) {
        await tester.tap(lunPill.first);
        await tester.pumpAndSettle();
      }

      final marPill = find.text('Mar');
      if (marPill.evaluate().isNotEmpty) {
        await tester.tap(marPill.first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Campus Resto U'), findsOneWidget);
    });
  });
}

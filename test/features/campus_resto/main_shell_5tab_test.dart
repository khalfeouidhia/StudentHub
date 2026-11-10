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
import 'package:studenthold_app/ui/navigation/main_shell.dart';

/// Test double simulating CampusRestoController without external HTTP dependencies.
class FakeTestCampusRestoController extends ChangeNotifier
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

  FakeTestCampusRestoController({
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
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> refreshDashboard() async {}
  @override
  Future<void> checkSession() async {}
  @override
  Future<void> onLoginSuccess(String cookies) async {
    isAuthenticated = true;
    notifyListeners();
  }

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
  Future<void> syncWithBudget(BudgetController budgetController) async {}
}

Widget _wrapWithAllProviders(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  CampusRestoController? campusResto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(
        create: (_) => auth ?? AuthController(),
      ),
      ChangeNotifierProvider<TasksController>(
        create: (_) => tasks ?? TasksController(),
      ),
      ChangeNotifierProvider<BudgetController>(
        create: (_) => budget ?? BudgetController(),
      ),
      ChangeNotifierProvider<CampusRestoController>(
        create: (_) => campusResto ?? FakeTestCampusRestoController(),
      ),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Group 1: MainShell 5-Tab Navigation Rendering & Activation', () {
    testWidgets(
        'Renders all 5 primary navigation tabs with exact labels and icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));

      expect(find.byType(LiquidGlassBottomNavBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(LiquidGlassBottomNavBar),
              matching: find.text('Calendar')),
          findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Resto U'), findsOneWidget);

      // Default active tab is Home
      expect(find.text('StudentHub'), findsOneWidget);
    });

    testWidgets(
        'MainShell respects initialIndex parameter (initialIndex: 4 boots to Resto U)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrapWithAllProviders(const MainShell(initialIndex: 4)),
      );

      expect(find.byType(RestoUView), findsOneWidget);
      expect(find.text('Campus Resto U'), findsOneWidget);
    });

    testWidgets(
        'Tapping Tab 4 (Resto U) activates index 4 and displays RestoUView',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));

      // Initial state is Home
      expect(find.text('StudentHub'), findsOneWidget);

      // Tap Tab 4 (Resto U)
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();

      expect(find.byType(RestoUView), findsOneWidget);
      expect(find.text('Campus Resto U'), findsOneWidget);
    });

    testWidgets(
        'Tapping Tab 2 (Calendar) activates index 2 and displays CalendarScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));

      // Tap Tab 2 (Calendar)
      await tester.tap(find.descendant(
          of: find.byType(LiquidGlassBottomNavBar),
          matching: find.text('Calendar')));
      await tester.pumpAndSettle();

      expect(find.text('Calender'), findsOneWidget);
    });
  });

  group('Group 2: 5-Tab Round-Trip & Arbitrary Sequential Switching', () {
    testWidgets(
        'Sequential tab switching cycles 0 -> 1 -> 2 -> 3 -> 4 -> 0 smoothly',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));

      // 0 -> 1 (Expenses)
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Expenses & Outflows'), findsOneWidget);

      // 1 -> 2 (Calendar)
      await tester.tap(find.descendant(
          of: find.byType(LiquidGlassBottomNavBar),
          matching: find.text('Calendar')));
      await tester.pumpAndSettle();
      expect(find.text('Calender'), findsOneWidget);

      // 2 -> 3 (Tasks)
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks & Deadlines'), findsOneWidget);

      // 3 -> 4 (Resto U)
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);

      // 4 -> 0 (Home)
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('StudentHub'), findsOneWidget);
    });

    testWidgets('Arbitrary non-adjacent jumps maintain IndexedStack integrity',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));

      // Jump 0 -> 4
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);

      // Jump 4 -> 2
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Tasks & Deadlines'), findsOneWidget);

      // Jump 2 -> 4
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);

      // Jump 4 -> 1
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Expenses & Outflows'), findsOneWidget);
    });

    testWidgets(
        'MainShellState programmatic switchTab API validates boundary guards',
        (WidgetTester tester) async {
      final shellKey = GlobalKey<MainShellState>();
      await tester.pumpWidget(
        _wrapWithAllProviders(MainShell(key: shellKey)),
      );

      // Programmatic switch to index 4
      shellKey.currentState!.switchTab(4);
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);

      // Out of bounds (< 0) is ignored
      shellKey.currentState!.switchTab(-1);
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);

      // Out of bounds (>= 5) is ignored
      shellKey.currentState!.switchTab(99);
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);
    });
  });

  group(
      'Group 3: LiquidGlassNavBar Responsive Layout & Micro-Viewport Zero Overflow',
      () {
    final viewports = [
      const Size(280, 653), // Galaxy Fold narrow outer cover display
      const Size(320, 568), // iPhone SE
      const Size(375, 667), // iPhone 8
      const Size(412, 915), // Pixel 7
      const Size(800, 1280), // Tablet
    ];

    for (final size in viewports) {
      testWidgets(
          'MainShell 5-tab has zero overflow on ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(_wrapWithAllProviders(const MainShell()));
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });
    }

    for (final scale in [1.5, 2.0]) {
      testWidgets(
          'MainShell 5-tab has zero overflow with ${scale}x font scale on 320x568',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(scale),
            ),
            child: _wrapWithAllProviders(const MainShell()),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });

      testWidgets(
          'LiquidGlassNavBar 5-tab has zero overflow with ${scale}x font scale on micro 280x653',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(280, 653);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(280, 653),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: Scaffold(
                extendBody: true,
                body: Stack(
                  children: [
                    LiquidGlassBottomNavBar(
                      currentIndex: 0,
                      onTap: (_) {},
                      items: const [
                        GlassNavItem(
                          icon: Icons.grid_view_outlined,
                          activeIcon: Icons.grid_view_rounded,
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
            ),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });
    }
  });

  group(
      'Group 4: Backward Compatibility: 4-Item vs 5-Item Dock Layout Invariants',
      () {
    testWidgets(
        'LiquidGlassNavBar with 4 items renders 4 items and center floating orb',
        (WidgetTester tester) async {
      int selected = 0;
      bool centerActionPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                LiquidGlassBottomNavBar(
                  currentIndex: selected,
                  onTap: (idx) => selected = idx,
                  onCenterActionPressed: () => centerActionPressed = true,
                  items: const [
                    GlassNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
                      label: 'Home',
                    ),
                    GlassNavItem(
                      icon: Icons.pie_chart_outline_rounded,
                      activeIcon: Icons.pie_chart_rounded,
                      label: 'Expenses',
                    ),
                    GlassNavItem(
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today_rounded,
                      label: 'Tasks',
                    ),
                    GlassNavItem(
                      icon: Icons.calendar_month_outlined,
                      activeIcon: Icons.calendar_month_rounded,
                      label: 'Calendar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);

      // Verify floating center orb exists in 4-item mode
      final centerOrbFinder = find.byIcon(Icons.qr_code_scanner_rounded);
      expect(centerOrbFinder, findsOneWidget);

      // Tapping center orb invokes callback
      await tester.tap(centerOrbFinder);
      await tester.pumpAndSettle();
      expect(centerActionPressed, isTrue);

      // Tapping items switches index
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(selected, equals(2));
    });

    testWidgets(
        'LiquidGlassNavBar with 5 items evenly distributes items and omits center orb',
        (WidgetTester tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                LiquidGlassBottomNavBar(
                  currentIndex: selected,
                  onTap: (idx) => selected = idx,
                  items: const [
                    GlassNavItem(
                      icon: Icons.grid_view_outlined,
                      activeIcon: Icons.grid_view_rounded,
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
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Resto U'), findsOneWidget);

      // In 5-item mode, center orb is omitted to avoid blocking Tab 2 (Tasks)
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);

      // Tapping Tab 3 is unobstructed
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(selected, equals(3));

      // Tapping Tab 4 works
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();
      expect(selected, equals(4));
    });

    testWidgets('LiquidGlassNavBar defaults gracefully when items is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                LiquidGlassBottomNavBar(
                  currentIndex: 0,
                  onTap: (_) {},
                  items: null,
                ),
              ],
            ),
          ),
        ),
      );

      // Verifies fallback items render without crash
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);
    });
  });

  group('Group 5: Provider Resilience & View State Invariants', () {
    testWidgets(
        'MainShell mounts cleanly without throwing when CampusRestoController is absent',
        (WidgetTester tester) async {
      // Pumping without CampusRestoController (legacy harness simulation)
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(
                create: (_) => AuthController()),
            ChangeNotifierProvider<TasksController>(
                create: (_) => TasksController()),
            ChangeNotifierProvider<BudgetController>(
                create: (_) => BudgetController()),
          ],
          child: const MaterialApp(
            home: MainShell(),
          ),
        ),
      );

      expect(find.byType(LiquidGlassBottomNavBar), findsOneWidget);
      expect(find.text('Resto U'), findsOneWidget);

      // Switching to Resto U displays unauthenticated login gate safely
      await tester.tap(find.text('Resto U'));
      await tester.pumpAndSettle();

      expect(find.byType(RestoUView), findsOneWidget);
      expect(find.text('Campus Resto U'), findsOneWidget);
    });

    testWidgets(
        'Authenticated state displays student profile and KPIs in Resto U tab',
        (WidgetTester tester) async {
      final fakeController = FakeTestCampusRestoController(
        isAuthenticated: true,
        profile: const StudentProfile(
          fullName: 'Nour Cherif',
          cin: '12345678',
          dorm: DormInfo(foyer: 'Foyer Jasmin', bloc: 'B', chambre: '204'),
        ),
        kpis: const WalletKpis(
          soldeRepas: 18,
          totalAchatMois: 45,
          depensesMois: 32.5,
        ),
      );

      await tester.pumpWidget(
        _wrapWithAllProviders(
          const MainShell(initialIndex: 4),
          campusResto: fakeController,
        ),
      );

      expect(find.text('Nour Cherif'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('Solde Repas'), findsOneWidget);
      expect(find.text('Bloc B • Ch. 204'), findsOneWidget);
    });
  });
}

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
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_login_sheet.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';

/// Test double simulating CampusRestoController for empirical challenge
class ChallengerRestoController extends ChangeNotifier
    implements CampusRestoController {
  @override
  RestoAuthStatus get authStatus => isAuthenticated
      ? RestoAuthStatus.authenticated
      : (isLoading ? RestoAuthStatus.loading : RestoAuthStatus.unauthenticated);
  @override
  bool isAuthenticated = false;
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
  List<CampusMealItem> weeklyMeals = const [];
  @override
  List<RestoCheckIn> checkIns = const [];
  @override
  List<RestoTopUp> topUps = const [];

  @override
  Map<String, List<CampusMealItem>> get mealsByDate => {};
  @override
  List<String> get sortedDateKeys => [];
  @override
  bool get hasData => false;
  @override
  bool get isLowBalance => false;
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

Widget _wrapChallengerApp(Widget child,
    {CampusRestoController? restoController}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<CampusRestoController>(
        create: (_) => restoController ?? ChallengerRestoController(),
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

  final viewports = <String, Size>{
    'Galaxy Fold Narrow (280x653)': const Size(280, 653),
    'iPhone SE (320x568)': const Size(320, 568),
    'iPhone 8 (375x667)': const Size(375, 667),
    'Pixel 7 (412x915)': const Size(412, 915),
    'Tablet (800x1280)': const Size(800, 1280),
  };

  group('Challenger Suite 1: Hit Testing & Overlay Absence for Tab 2 & Tab 4',
      () {
    for (final vp in viewports.entries) {
      testWidgets('Tab 2 (Tasks) hit-test is never intercepted on ${vp.key}',
          (WidgetTester tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapChallengerApp(const MainShell()));
        await tester.pumpAndSettle();

        // 1. Verify floating orb does NOT exist anywhere in widget tree
        expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);

        // 2. Locate Tab 2 (Tasks) label and icon
        final tasksLabelFinder = find.text('Tasks');
        expect(tasksLabelFinder, findsOneWidget);

        final tasksCenter = tester.getCenter(tasksLabelFinder);

        // 3. Perform empirical hit test at exact center of Tab 2 label
        final hitResult = tester.hitTestOnBinding(tasksCenter);
        final hitTargets = hitResult.path
            .map((entry) => entry.target.runtimeType.toString())
            .toList();

        // Must hit RenderBox / RenderParagraph / RenderPadding / RenderDecoratedBox / RenderPointerListener
        // Must NOT hit any floating orb, modal barrier, or unexpected overlay
        expect(
          hitTargets.any(
              (t) => t.contains('ModalBarrier') || t.contains('Transform')),
          isFalse,
          reason: 'Tab 2 hit test was intercepted by an overlay: $hitTargets',
        );

        // 4. Tap Tab 2 and assert view switches to TasksView
        await tester.tapAt(tasksCenter);
        await tester.pumpAndSettle();

        expect(find.byType(TasksView), findsOneWidget);
        expect(find.text('Tasks & Deadlines'), findsOneWidget);
      });

      testWidgets('Tab 4 (Resto U) hit-test is never intercepted on ${vp.key}',
          (WidgetTester tester) async {
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_wrapChallengerApp(const MainShell()));
        await tester.pumpAndSettle();

        // Locate Tab 4 (Resto U) label
        final restoLabelFinder = find.text('Resto U');
        expect(restoLabelFinder, findsOneWidget);

        final restoCenter = tester.getCenter(restoLabelFinder);

        // Perform empirical hit test at exact center of Tab 4 label
        final hitResult = tester.hitTestOnBinding(restoCenter);
        final hitTargets = hitResult.path
            .map((entry) => entry.target.runtimeType.toString())
            .toList();

        expect(
          hitTargets.any(
              (t) => t.contains('ModalBarrier') || t.contains('Transform')),
          isFalse,
          reason: 'Tab 4 hit test was intercepted by an overlay: $hitTargets',
        );

        // Tap Tab 4 and assert view switches to RestoUView
        await tester.tapAt(restoCenter);
        await tester.pumpAndSettle();

        expect(find.byType(RestoUView), findsOneWidget);
        expect(find.text('Campus Resto U'), findsOneWidget);
      });
    }
  });

  group('Challenger Suite 2: Rapid Alternating Tab Switching Stress', () {
    testWidgets(
        'Rapid alternating taps between Tab 2 and Tab 4 maintain flawless state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrapChallengerApp(const MainShell()));
      await tester.pumpAndSettle();

      final tasksFinder = find.text('Tasks');
      final restoFinder = find.text('Resto U');

      // 40 rapid back-and-forth taps without full pumpAndSettle between taps
      for (int i = 0; i < 20; i++) {
        await tester.tap(tasksFinder);
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(restoFinder);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Final tap on Tab 2
      await tester.tap(tasksFinder);
      await tester.pumpAndSettle();
      expect(find.text('Tasks & Deadlines'), findsOneWidget);

      // Final tap on Tab 4
      await tester.tap(restoFinder);
      await tester.pumpAndSettle();
      expect(find.text('Campus Resto U'), findsOneWidget);
    });
  });

  group(
      'Challenger Suite 3: Subview Interactive Hit-Testing Through MainShell Stack',
      () {
    testWidgets(
        'Inside RestoUView (Tab 4), login CTA is cleanly clickable without nav obstruction',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester
          .pumpWidget(_wrapChallengerApp(const MainShell(initialIndex: 4)));
      await tester.pumpAndSettle();

      expect(find.text('Campus Resto U'), findsOneWidget);

      // Verify Login CTA button is visible and findable
      final loginBtnFinder = find.byKey(const ValueKey('resto_login_button'));
      expect(loginBtnFinder, findsOneWidget);

      // Ensure button is scrolled into view in SingleChildScrollView
      await tester.ensureVisible(loginBtnFinder);
      await tester.pumpAndSettle();

      // Tap the login CTA
      await tester.tap(loginBtnFinder);
      await tester.pumpAndSettle();

      // Bottom sheet should open cleanly
      expect(find.byType(RestoLoginSheet), findsOneWidget);
    });

    testWidgets(
        'Inside TasksView (Tab 3), main content is responsive and unobstructed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester
          .pumpWidget(_wrapChallengerApp(const MainShell(initialIndex: 3)));
      await tester.pumpAndSettle();

      expect(find.text('Tasks & Deadlines'), findsOneWidget);
      expect(find.byType(TasksView), findsOneWidget);

      // Bottom nav is active and present
      expect(find.byType(LiquidGlassBottomNavBar), findsOneWidget);
    });
  });

  group(
      'Challenger Suite 4: Extreme Font Scaling (2.0x) on Micro-Viewport (280x653) Hit Bounds',
      () {
    testWidgets(
        'Tab 2 and Tab 4 touch targets remain hit-testable at 2.0x font scale on 280dp width',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 653),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              extendBody: true,
              body: Stack(
                children: [
                  LiquidGlassBottomNavBar(
                    currentIndex: selectedTab,
                    onTap: (idx) => selectedTab = idx,
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
                        icon: Icons.task_alt_outlined,
                        activeIcon: Icons.task_alt_rounded,
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

      // Verify Tab 2 hit test succeeds
      final calendarFinder = find.text('Calendar');
      expect(calendarFinder, findsOneWidget);
      await tester.tap(calendarFinder);
      await tester.pumpAndSettle();
      expect(selectedTab, equals(2));

      // Verify Tab 4 hit test succeeds
      final restoFinder = find.text('Resto U');
      expect(restoFinder, findsOneWidget);
      await tester.tap(restoFinder);
      await tester.pumpAndSettle();
      expect(selectedTab, equals(4));
    });
  });
}

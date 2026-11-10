import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';
import 'package:studenthold_app/ui/views/expenses_view.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';

class MockRestoControllerForNav extends ChangeNotifier
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

Widget _wrapMainShellOverhaul({int initialIndex = 0}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<CampusRestoController>(
        create: (_) => MockRestoControllerForNav(),
      ),
    ],
    child: MaterialApp(
      home: MainShell(initialIndex: initialIndex),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group(
      'MainShell 5-Tab Overhaul — Group 1: 5-Tab Ordering & Screen Attachment',
      () {
    testWidgets(
        'MainShell IndexedStack mounts exactly 5 children in specified order',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellOverhaul());
      await tester.pumpAndSettle();

      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.children.length, equals(5));

      // Tab 0: Home, Tab 1: Expenses, Tab 2: Calendar, Tab 3: Tasks, Tab 4: Resto U
      expect(indexedStack.children[0], isA<HomeView>());
      expect(indexedStack.children[1], isA<ExpensesView>());
      expect(indexedStack.children[2], isA<CalendarScreen>());
      expect(indexedStack.children[3], isA<TasksView>());
      expect(indexedStack.children[4], isA<RestoUView>());
    });

    testWidgets('Bottom nav bar renders all 5 tabs with exact labels',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellOverhaul());
      await tester.pumpAndSettle();

      final navBar = find.byType(LiquidGlassBottomNavBar);
      expect(navBar, findsOneWidget);

      expect(find.descendant(of: navBar, matching: find.text('Home')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Expenses')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Calendar')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Tasks')),
          findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Resto U')),
          findsOneWidget);
    });
  });

  group('MainShell 5-Tab Overhaul — Group 2: Seamless Tab Switching', () {
    testWidgets('Tapping each tab switches to target screen without error',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellOverhaul());
      await tester.pumpAndSettle();

      final navBar = find.byType(LiquidGlassBottomNavBar);

      // 0 -> 1 (Expenses)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Expenses')));
      await tester.pumpAndSettle();
      expect(find.byType(ExpensesView), findsOneWidget);

      // 1 -> 2 (Calendar)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget);

      // 2 -> 3 (Tasks)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Tasks')));
      await tester.pumpAndSettle();
      expect(find.byType(TasksView), findsOneWidget);

      // 3 -> 4 (Resto U)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Resto U')));
      await tester.pumpAndSettle();
      expect(find.byType(RestoUView), findsOneWidget);

      // 4 -> 0 (Home)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeView), findsOneWidget);
    });
  });

  group('MainShell 5-Tab Overhaul — Group 3: Light Floating Dock Styling', () {
    testWidgets(
        'Floating dock surface uses light tint and circular active highlight',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShellOverhaul());
      await tester.pumpAndSettle();

      // Active pill indicator
      final activePills =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          final color = decoration.color;
          return color != null &&
              color != Colors.transparent &&
              (color == AppColors.deepPine ||
                  color == AppColors.vibrantGreen ||
                  color.value == 0xFFDCFCE7 ||
                  color == AppColors.sandCream ||
                  color == AppColors.surfaceWhite);
        }
        return false;
      });

      expect(activePills, isNotEmpty,
          reason:
              'Active tab must feature a distinct circular or pill highlight');
    });
  });

  group('MainShell 5-Tab Overhaul — Group 4: Haptic Feedback Verification', () {
    testWidgets('HapticFeedback.lightImpact() triggers on tab change',
        (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final hapticCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(methodCall.arguments as String? ?? 'vibrate');
          }
          return null;
        },
      );

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(_wrapMainShellOverhaul());
      await tester.pumpAndSettle();

      final navBar = find.byType(LiquidGlassBottomNavBar);

      // Tap Tab 1 (Expenses)
      await tester
          .tap(find.descendant(of: navBar, matching: find.text('Expenses')));
      await tester.pumpAndSettle();

      expect(hapticCalls, isNotEmpty,
          reason: 'Tapping a tab must invoke HapticFeedback.lightImpact()');
      expect(hapticCalls.last, equals('HapticFeedbackType.lightImpact'));
    });
  });
}

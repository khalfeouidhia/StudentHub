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
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';
import 'package:studenthold_app/ui/views/expenses_view.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/onboarding_view.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';
import 'package:studenthold_app/ui/views/welcome_vault_view.dart';

/// Test double for CampusRestoController with mock data for adversarial tab testing
class MockAdversarialRestoController extends ChangeNotifier
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
  bool get hasData => true;
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
  Future<void> refreshAll() async {}
  Future<bool> cancelReservation(String refP) async => false;
  @override
  void setAuthenticated(bool value) {
    isAuthenticated = value;
    notifyListeners();
  }

  @override
  Future<void> syncWithBudget(BudgetController budgetController) async {}
}

Widget _wrapMainShell({
  int initialIndex = 0,
  AuthController? auth,
  BudgetController? budget,
  TasksController? tasks,
  CampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(
        value: auth ?? AuthController(),
      ),
      ChangeNotifierProvider<BudgetController>.value(
        value: budget ?? BudgetController(),
      ),
      ChangeNotifierProvider<TasksController>.value(
        value: tasks ?? TasksController(),
      ),
      ChangeNotifierProvider<CampusRestoController>.value(
        value: resto ?? MockAdversarialRestoController(),
      ),
    ],
    child: MaterialApp(
      home: MainShell(initialIndex: initialIndex),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1 Adversarial Challenge: Vault Deletion Rigorous Audit', () {
    test(
        'Empirical filesystem verification: VaultController & VaultView are absent',
        () {
      final controllerFile = File('lib/controllers/vault_controller.dart');
      final viewFile = File('lib/ui/views/vault_view.dart');

      expect(controllerFile.existsSync(), isFalse,
          reason: 'lib/controllers/vault_controller.dart must not exist');
      expect(viewFile.existsSync(), isFalse,
          reason: 'lib/ui/views/vault_view.dart must not exist');
    });

    test('Zero lingering vault controller / view imports across all lib/ files',
        () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final bannedImportRegexes = [
        RegExp(r'''import\s+['"][^'"]*vault_controller\.dart['"]'''),
        RegExp(r'''import\s+['"][^'"]*(?<!welcome_)vault_view\.dart['"]'''),
      ];

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        for (final regex in bannedImportRegexes) {
          expect(regex.hasMatch(text), isFalse,
              reason:
                  'File ${file.path} contains banned import matching ${regex.pattern}');
        }
      }
    });

    test('Zero lingering VaultController class references in lib/', () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final bannedClassRegex = RegExp(r'\bVaultController\b');

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(bannedClassRegex.hasMatch(text), isFalse,
            reason:
                'File ${file.path} references banned VaultController symbol');
      }
    });

    test(
        'Zero standalone VaultView references in lib/ (allowing WelcomeVaultView)',
        () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final standaloneVaultViewRegex = RegExp(r'(?<!Welcome)\bVaultView\b');

      for (final file in dartFiles) {
        final text = file.readAsStringSync();
        expect(standaloneVaultViewRegex.hasMatch(text), isFalse,
            reason: 'File ${file.path} references banned VaultView symbol');
      }
    });

    test('lib/main.dart has zero VaultController provider or vault calls', () {
      final mainFile = File('lib/main.dart');
      final content = mainFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse);
      expect(content.contains('lockVault()'), isFalse);
    });

    test('lib/ui/sheets/payly_sheets.dart is completely cleansed of Vault', () {
      final sheetsFile = File('lib/ui/sheets/payly_sheets.dart');
      final content = sheetsFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse);
      expect(content.contains('VaultCredential'), isFalse);
      expect(content.contains('openCredentialSheet'), isFalse);
      expect(content.contains('_PinUnlockModalSheet'), isFalse);
    });

    test('lib/ui/views/home_view.dart has no vault interactions', () {
      final homeFile = File('lib/ui/views/home_view.dart');
      final content = homeFile.readAsStringSync();
      expect(content.contains('VaultController'), isFalse);
      expect(content.contains("'Vault Lock'"), isFalse);
    });
  });

  group('Milestone 1 Adversarial Challenge: Onboarding Flow Independence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
        'WelcomeVaultView mounts and renders OnboardingView with zero Vault dependencies',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final auth = AuthController();
      final budget = BudgetController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<BudgetController>.value(value: budget),
          ],
          child: const MaterialApp(
            home: WelcomeVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeVaultView), findsOneWidget);
      expect(find.byType(OnboardingView), findsOneWidget);
      expect(find.text('Personalization & Setup'), findsOneWidget);
    });

    testWidgets(
        'Onboarding submission succeeds without VaultController and navigates to MainShell',
        (tester) async {
      final auth = AuthController();
      final budget = BudgetController();
      final tasks = TasksController();
      final resto = MockAdversarialRestoController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<BudgetController>.value(value: budget),
            ChangeNotifierProvider<TasksController>.value(value: tasks),
            ChangeNotifierProvider<CampusRestoController>.value(value: resto),
          ],
          child: const MaterialApp(
            home: WelcomeVaultView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in onboarding inputs
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Dhia Test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Institution and degree'),
        'RNU Campus - Computer Science',
      );
      await tester.pumpAndSettle();

      // Enter 4 digit PIN
      await tester.ensureVisible(find.text('1'));
      await tester.tap(find.text('1'));
      await tester.pump();

      await tester.ensureVisible(find.text('2'));
      await tester.tap(find.text('2'));
      await tester.pump();

      await tester.ensureVisible(find.text('3'));
      await tester.tap(find.text('3'));
      await tester.pump();

      await tester.ensureVisible(find.text('4'));
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Tap complete setup button
      await tester.ensureVisible(find.text('Complete Setup & Enter Nest'));
      await tester.tap(find.text('Complete Setup & Enter Nest'));
      await tester.pumpAndSettle();

      expect(auth.isOnboarded, isTrue,
          reason: 'auth.isOnboarded should be true');
      expect(auth.userName, equals('Dhia Test'));
      expect(find.byType(MainShell), findsOneWidget);
    });
  });

  group('Milestone 1 Adversarial Challenge: 5-Tab Navigation Stress Test', () {
    testWidgets('MainShell mounts with exactly 5 tabs in specified order',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));
      expect(state, isNotNull);

      // Verify IndexedStack children structure
      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.children.length, equals(5));
      expect(indexedStack.children[0], isA<HomeView>());
      expect(indexedStack.children[1], isA<ExpensesView>());
      expect(indexedStack.children[2], isA<CalendarScreen>());
      expect(indexedStack.children[3], isA<TasksView>());
      expect(indexedStack.children[4], isA<RestoUView>());

      // Verify Tab 0 initially active
      expect(indexedStack.index, equals(0));
    });

    testWidgets(
        'Tab switching cycles through 0->1->2->3->4->0 sequentially without crashes',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));

      final tabExpectations = [
        (1, 'Expenses', find.byType(ExpensesView)),
        (2, 'Calendar', find.byType(CalendarScreen)),
        (3, 'Tasks', find.byType(TasksView)),
        (4, 'Resto U', find.byType(RestoUView)),
        (0, 'Home', find.byType(HomeView)),
      ];

      for (final (targetIndex, label, viewFinder) in tabExpectations) {
        state.switchTab(targetIndex);
        await tester.pumpAndSettle();

        final indexedStack =
            tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(indexedStack.index, equals(targetIndex),
            reason: 'IndexedStack index should be $targetIndex for $label');
        expect(viewFinder, findsOneWidget);
      }
    });

    testWidgets(
        'Adversarial rapid switching across chaotic permutations and reverse sequences',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));

      // Chaotic sequence testing rapid out-of-order jumps
      final chaoticSequence = [
        4,
        0,
        3,
        1,
        2,
        4,
        2,
        0,
        1,
        3,
        0,
        4,
        1,
        4,
        3,
        2,
        1,
        0,
        4,
        3,
        2,
        1,
        2,
        3,
        4,
        0,
        2,
        4,
        1,
        3,
      ];

      for (final nextIndex in chaoticSequence) {
        state.switchTab(nextIndex);
        await tester.pump(const Duration(milliseconds: 20));

        final indexedStack =
            tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(indexedStack.index, equals(nextIndex));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Boundary protection: switchTab ignores negative, out-of-bounds, or NaN-like indices',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell(initialIndex: 2));
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));
      final indexedStackBefore =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStackBefore.index, equals(2));

      // Attempt invalid index switches
      state.switchTab(-1);
      state.switchTab(-999);
      state.switchTab(5);
      state.switchTab(6);
      state.switchTab(100);
      await tester.pumpAndSettle();

      // Verify index remains safely at 2
      final indexedStackAfter =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStackAfter.index, equals(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Bottom nav bar hit testing: all 5 tabs can be tapped directly via UI interaction',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      final navBarFinder = find.byType(LiquidGlassBottomNavBar);
      expect(navBarFinder, findsOneWidget);

      final tabsToTap = [
        ('Expenses', 1),
        ('Calendar', 2),
        ('Tasks', 3),
        ('Resto U', 4),
        ('Home', 0),
      ];

      for (final (label, expectedIndex) in tabsToTap) {
        final tabItem = find.descendant(
          of: navBarFinder,
          matching: find.text(label),
        );
        expect(tabItem, findsOneWidget,
            reason: 'Tab $label must be found in bottom nav');

        await tester.tap(tabItem);
        await tester.pumpAndSettle();

        final indexedStack =
            tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(indexedStack.index, equals(expectedIndex),
            reason:
                'Tapping tab $label should switch active index to $expectedIndex');
      }
    });

    testWidgets(
        'Idempotent tab switching: redundant calls to active tab produce zero state disruptions',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));

      // Call switchTab to current tab 0 multiple times
      for (int i = 0; i < 5; i++) {
        state.switchTab(0);
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, equals(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'State preservation: IndexedStack preserves widget subtree state across switches',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tasks = TasksController();
      tasks.addTask(
        title: 'Adversarial Task 101',
        category: 'Academic',
        dueDate: 'Due today',
      );

      await tester.pumpWidget(_wrapMainShell(tasks: tasks));
      await tester.pumpAndSettle();

      final state = tester.state<MainShellState>(find.byType(MainShell));

      // Initially on Tab 0 (Home)
      expect(find.byType(HomeView), findsOneWidget);

      // Switch to Tab 3 (Tasks)
      state.switchTab(3);
      await tester.pumpAndSettle();
      expect(find.text('Adversarial Task 101'), findsOneWidget);

      // Switch away to Tab 4 (Resto U), Tab 2 (Calendar), Tab 1 (Expenses)
      state.switchTab(4);
      await tester.pumpAndSettle();
      state.switchTab(2);
      await tester.pumpAndSettle();
      state.switchTab(1);
      await tester.pumpAndSettle();

      // Switch back to Tab 3 (Tasks)
      state.switchTab(3);
      await tester.pumpAndSettle();

      // State is fully preserved
      expect(find.text('Adversarial Task 101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Zero RenderFlex overflows across 5-tab bar on narrow screen (320dp)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapMainShell());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final navBar = find.byType(LiquidGlassBottomNavBar);
      expect(navBar, findsOneWidget);
    });
  });
}

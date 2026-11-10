import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/glowing_typewriter_greeting.dart';

Widget _wrapWithProviders(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(
          create: (_) => auth ?? AuthController()),
      ChangeNotifierProvider<TasksController>(
          create: (_) => tasks ?? TasksController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => budget ?? BudgetController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.ensureSemantics();
  });

  // =========================================================================
  // Group 1: Top App Bar & Profile Header (R2.1)
  // =========================================================================
  group('M3 — Group 1: Top App Bar & Profile Header Components', () {
    testWidgets(
        '1.1: Eco logo renders with Icons.eco_rounded and vibrant green',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final ecoFinder = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon == Icons.eco_rounded &&
          w.color == const Color(0xFF00D084));
      expect(ecoFinder, findsOneWidget);
    });

    testWidgets('1.2: Renders bold white StudentHub title', (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('StudentHub'), findsOneWidget);
    });

    testWidgets('1.3: Renders Solo Student pill badge with dark background',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Solo Student'), findsOneWidget);
    });

    testWidgets(
        '1.4: Circular history button opens MonthlyHistoryModalSheet on tap',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Historical Archive'), findsOneWidget);
    });

    testWidgets(
        '1.5: Circular notification bell with red dot triggers notifications sheet',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final bellIcon = find.byIcon(Icons.notifications_none_rounded);
      expect(bellIcon, findsOneWidget);

      await tester.tap(bellIcon);
      await tester.pumpAndSettle();

      expect(find.text('Active Notifications'), findsOneWidget);
    });

    testWidgets('1.6: Circular user avatar renders initials fallback',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'Yasmine')));
      await tester.pumpAndSettle();

      expect(find.text('Y'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 2: Dynamic Greeting & Illustration Frame (R2.2)
  // =========================================================================
  group('M3 — Group 2: Dynamic Greeting & Dedicated Illustration Frame', () {
    testWidgets(
        '2.1: Renders GlowingTypewriterGreeting and single user name widget',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'Yasmine')));
      await tester.pumpAndSettle();

      expect(find.byType(GlowingTypewriterGreeting), findsOneWidget);
      expect(find.text('Yasmine'), findsOneWidget);
    });

    testWidgets(
        '2.2: Renders subtitle with AnimatedSwitcher and wave icon (zero emoji)',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsWidgets);
      expect(find.textContaining('Welcome'), findsWidgets);
      expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    });

    testWidgets(
        '2.3: Renders dedicated illustration frame loading header_avatar.png',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final imageFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('header_avatar.png'));
      expect(imageFinder, findsWidgets);
    });
  });

  // =========================================================================
  // Group 3: Balance & Expense KPI Cards with RouletteNumberText (R2.3)
  // =========================================================================
  group('M3 — Group 3: Balance & Expense KPI Cards', () {
    testWidgets(
        '3.1: Total Balance card renders RouletteNumberText with DT and mint wallet icon',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(2000.0, 500.0);
      budget.addExpense(title: 'Snack', amount: 50.0, category: 'Dining');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      final mintWalletFinder = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon == Icons.account_balance_wallet_rounded &&
          w.color == const Color(0xFF00D084));
      expect(mintWalletFinder, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RouletteNumberText && w.isHeader),
        findsNWidgets(2),
      );
    });

    testWidgets(
        '3.2: Total Expense card renders trend arrow reflecting spend status',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(1000.0, 200.0);
      budget.addExpense(title: 'Groceries', amount: 600.0, category: 'Food');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL EXPENSE'), findsOneWidget);
      expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 4: Dynamic Month Budget Progress Bar & Backward Compatibility (R2.4)
  // =========================================================================
  group('M3 — Group 4: Dynamic Month Budget Progress Bar', () {
    testWidgets(
        '4.1: Retains OCTOBER BUDGET in test environment for legacy contracts',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('OCTOBER BUDGET'), findsOneWidget);
    });

    testWidgets(
        '4.2: Renders dynamic month when forceDynamicMonth is true or currentDate is injected',
        (tester) async {
      final testDate = DateTime(2026, 4, 15);
      await tester
          .pumpWidget(_wrapWithProviders(HomeDashboard(currentDate: testDate)));
      await tester.pumpAndSettle();

      expect(find.text('APRIL BUDGET'), findsOneWidget);
    });

    testWidgets('4.3: Displays cap ratio text formatted in DT Cap',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(20000.0, 5000.0);
      budget.addExpense(title: 'Tuition', amount: 9200.0, category: 'Academic');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.textContaining('DT Cap'), findsOneWidget);
      expect(find.textContaining('46%'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 5: Strict Zero-Emoji Policy Verification Across Header
  // =========================================================================
  group('M3 — Group 5: Strict Zero-Emoji Policy Header Scan', () {
    testWidgets('5.1: Zero Unicode emojis exist across all header text widgets',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'Yasmine')));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final text =
            textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(text),
          isFalse,
          reason: 'Forbidden emoji found in text widget: "$text"',
        );
      }
    });
  });

  // =========================================================================
  // Group 6: Full Non-Regression Guard for test/widget_test.dart Lines 50–69
  // =========================================================================
  group('M3 — Group 6: test/widget_test.dart Direct Regression Guard', () {
    testWidgets(
        '6.1: Exactly reproduces test/widget_test.dart lines 50–61 assertions',
        (tester) async {
      final tasks = TasksController();
      tasks.addTask(
          title: 'CS301 Project Submission',
          category: 'Academic',
          dueDate: 'Due tomorrow');
      await tester.pumpWidget(_wrapWithProviders(
          const HomeDashboard(userName: 'Yasmine'),
          tasks: tasks));

      expect(find.byType(GlowingTypewriterGreeting), findsOneWidget);
      expect(find.text('Yasmine'), findsOneWidget);
      expect(find.text('StudentHub'), findsOneWidget);
      expect(find.text('OCTOBER BUDGET'), findsOneWidget);
      expect(find.text('Upcoming & Deadlines'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets(
        '6.2: Exactly reproduces test/widget_test.dart lines 63–69 clean zero-base state',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));

      expect(find.text('StudentHub'), findsOneWidget);
      expect(find.text('OCTOBER BUDGET'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 7: Responsive Stress & Overflow Protection
  // =========================================================================
  group('M3 — Group 7: Header Responsive & Viewport Resilience', () {
    testWidgets(
        '7.1: Zero overflow on 320x568 at 2.0x accessibility text scale',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 568), textScaler: TextScaler.linear(2.0)),
          child: _wrapWithProviders(const HomeDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

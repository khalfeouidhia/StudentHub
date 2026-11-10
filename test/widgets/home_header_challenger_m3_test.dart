import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapWithProviders(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  Size? surfaceSize,
  TextScaler? textScaler,
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
        body: MediaQuery(
          data: MediaQueryData(
            size: surfaceSize ?? const Size(360, 690),
            textScaler: textScaler ?? TextScaler.noScaling,
          ),
          child: child,
        ),
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
  // Group 1: Extreme Numerical Budget & Balance Stress
  // =========================================================================
  group(
      'Empirical Challenger — Group 1: Extreme Numerical Budget & Balance Stress',
      () {
    testWidgets('1.1: Balance = 0.000 DT when spent equals or exceeds cap',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 1000.0, spentSoFar: 1000.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      // Verify RouletteNumberText for balance displays 0.000 DT
      final balanceReel = find.byWidgetPredicate(
        (w) => w is RouletteNumberText && w.isHeader && w.value == 0.0,
      );
      expect(balanceReel, findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.2: Balance = 10,000,000.000 DT formatted with thousand separators and scaled down',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 10000000.0, spentSoFar: 0.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      final highBalanceReel = find.byWidgetPredicate(
        (w) =>
            w is RouletteNumberText &&
            w.isHeader &&
            w.value == 10000000.0 &&
            w.thousandsSeparator,
      );
      expect(highBalanceReel, findsOneWidget);
      expect(find.textContaining('10,000,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.3: Spent = 999,999.999 DT with thousand separators and 3 decimal places',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 1000000.0, spentSoFar: 999999.999),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL EXPENSE'), findsOneWidget);
      final highExpenseReel = find.byWidgetPredicate(
        (w) =>
            w is RouletteNumberText &&
            w.isHeader &&
            w.value == 999999.999 &&
            w.thousandsSeparator,
      );
      expect(highExpenseReel, findsOneWidget);
      expect(find.textContaining('99% / 1,000,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.4: Monthly cap = 0.0 DT safely falls back to default 20,000.0 DT without division by zero',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 0.0, spentSoFar: 0.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('20,000 DT Cap'), findsOneWidget);
      expect(find.textContaining('0% / 20,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.5: Monthly cap negative (-500.0 DT) safely falls back to 20,000.0 DT without crash',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: -500.0, spentSoFar: 50.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('20,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.6: Monthly cap astronomical (100,000,000.0 DT) renders cleanly within FittedBox',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 100000000.0, spentSoFar: 25000000.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('100,000,000 DT Cap'), findsOneWidget);
      expect(find.textContaining('25% / 100,000,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.7: Direct negative value support in RouletteNumberText (-500.000 DT)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouletteNumberText(
              value: -500.0,
              suffix: ' DT',
              decimalDigits: 3,
              thousandsSeparator: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-'), findsOneWidget);
      expect(find.text('500'), findsNothing); // split into reels
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '1.8: Negative spentSoFar (-500.0 DT) clamps progress fraction to 0.0 safely',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 2000.0, spentSoFar: -500.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0% / 2,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 2: Cap Ratio & Division-by-Zero Invariance
  // =========================================================================
  group(
      'Empirical Challenger — Group 2: Cap Ratio & FractionallySizedBox Safety',
      () {
    testWidgets(
        '2.1: FractionallySizedBox widthFactor is clamped between 0.0 and 1.0 even when overspent 500%',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 1000.0, spentSoFar: 5000.0),
        ),
      );
      await tester.pumpAndSettle();

      final fractionallySizedBoxFinder = find.byWidgetPredicate(
        (w) => w is FractionallySizedBox && w.widthFactor != null,
      );
      expect(fractionallySizedBoxFinder, findsOneWidget);

      final box =
          tester.widget<FractionallySizedBox>(fractionallySizedBoxFinder);
      expect(box.widthFactor, equals(1.0));
      expect(find.textContaining('100% / 1,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '2.2: FractionallySizedBox widthFactor is 0.0 when spent is 0.0',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 2000.0, spentSoFar: 0.0),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.widget<FractionallySizedBox>(
        find.byWidgetPredicate(
            (w) => w is FractionallySizedBox && w.widthFactor != null),
      );
      expect(box.widthFactor, equals(0.0));
      expect(find.textContaining('0% / 2,000 DT Cap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 3: Automated Trend Arrow & Color Transitions
  // =========================================================================
  group('Empirical Challenger — Group 3: Trend Arrow Transitions', () {
    testWidgets(
        '3.1: Controller: Accelerated spend (todaySpent > dailySafeSpend) -> green arrow (#00D084)',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(1000.0, 200.0);
      budget.addExpense(title: 'Spike Spend', amount: 350.0, category: 'Food');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      final greenArrowFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.north_east_rounded &&
            w.color == const Color(0xFF00D084),
      );
      expect(greenArrowFinder, findsOneWidget);
      expect(find.byIcon(Icons.south_east_rounded), findsNothing);
    });

    testWidgets(
        '3.2: Controller: Under-budget spend (todaySpent < dailySafeSpend) -> red arrow (#E57373)',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(3000.0, 500.0);
      budget.addExpense(title: 'Small Coffee', amount: 2.5, category: 'Food');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      final redArrowFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.south_west_rounded ||
                w.icon == Icons.south_east_rounded) &&
            (w.color == const Color(0xFFFF6B6B) ||
                w.color == const Color(0xFFE57373)),
      );
      expect(redArrowFinder, findsOneWidget);
      expect(find.byIcon(Icons.north_east_rounded), findsNothing);
    });

    testWidgets('3.3: Controller: Zero spend today -> red arrow (#E57373)',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(2000.0, 500.0);

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      final redArrowFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.south_west_rounded ||
                w.icon == Icons.south_east_rounded) &&
            (w.color == const Color(0xFFFF6B6B) ||
                w.color == const Color(0xFFE57373)),
      );
      expect(redArrowFinder, findsOneWidget);
      expect(find.byIcon(Icons.north_east_rounded), findsNothing);
    });

    testWidgets(
        '3.4: Fallback mode: spent > 50% effectiveCap -> green arrow (#00D084)',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 2000.0, spentSoFar: 1500.0),
        ),
      );
      await tester.pumpAndSettle();

      final greenArrowFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.north_east_rounded &&
            w.color == const Color(0xFF00D084),
      );
      expect(greenArrowFinder, findsOneWidget);
    });

    testWidgets(
        '3.5: Fallback mode: spent <= 50% effectiveCap -> red arrow (#E57373)',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 2000.0, spentSoFar: 500.0),
        ),
      );
      await tester.pumpAndSettle();

      final redArrowFinder = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.south_west_rounded ||
                w.icon == Icons.south_east_rounded) &&
            (w.color == const Color(0xFFFF6B6B) ||
                w.color == const Color(0xFFE57373)),
      );
      expect(redArrowFinder, findsOneWidget);
    });
  });

  // =========================================================================
  // Group 4: Layout & Micro-Viewport Resilience Under Extreme Numbers
  // =========================================================================
  group(
      'Empirical Challenger — Group 4: Layout Stress & Micro-Viewport Resilience',
      () {
    testWidgets(
        '4.1: Viewport 280px with 100,000,000 DT balance and 99,999,999 DT expense at 2.5x font scale',
        (tester) async {
      tester.view.physicalSize = const Size(280 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 100000000.0, spentSoFar: 99999999.0),
          surfaceSize: const Size(280, 700),
          textScaler: const TextScaler.linear(2.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Must not trigger RenderFlex overflow on micro viewport');
    });

    testWidgets('4.2: Viewport 320px with 0 DT balance and 0 DT expense',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 0.0, spentSoFar: 0.0),
          surfaceSize: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('4.3: Viewport 800px landscape tablet with extreme numbers',
        (tester) async {
      tester.view.physicalSize = const Size(800 * 1.5, 600 * 1.5);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(totalCap: 50000000.0, spentSoFar: 12500000.0),
          surfaceSize: const Size(800, 600),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 5: Zero Unicode Emojis Across Extreme States
  // =========================================================================
  group('Empirical Challenger — Group 5: Zero Unicode Emojis Across States',
      () {
    testWidgets(
        '5.1: Zero emojis present in all text widgets across normal and extreme states',
        (tester) async {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}]',
        unicode: true,
      );

      final testCases = [
        const HomeDashboard(totalCap: 0.0, spentSoFar: 0.0),
        const HomeDashboard(totalCap: 10000000.0, spentSoFar: 500000.0),
        const HomeDashboard(totalCap: -500.0, spentSoFar: -100.0),
      ];

      for (final testCase in testCases) {
        await tester.pumpWidget(_wrapWithProviders(testCase));
        await tester.pumpAndSettle();

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
      }
    });
  });
}

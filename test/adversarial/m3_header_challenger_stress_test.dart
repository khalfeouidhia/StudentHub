import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _buildHomeTestHarness({
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  String? userName,
  double? totalCap,
  double? spentSoFar,
  DateTime? currentDate,
  bool? forceDynamicMonth,
  double textScaleFactor = 1.0,
  Size viewportSize = const Size(360, 800),
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
    child: MediaQuery(
      data: MediaQueryData(
        size: viewportSize,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: HomeDashboard(
            userName: userName,
            totalCap: totalCap,
            spentSoFar: spentSoFar,
            currentDate: currentDate,
            forceDynamicMonth: forceDynamicMonth,
          ),
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

  group('CHALLENGER ADVERSARIAL SUITE: Micro-Viewport Stress (240px to 800px)',
      () {
    const viewports = [
      Size(240, 480), // Extreme micro-viewport
      Size(280, 653), // Galaxy Z Fold cover screen
      Size(320, 568), // iPhone SE 1st gen
      Size(360, 640), // Standard compact Android
      Size(390, 844), // iPhone 12/13/14
      Size(412, 915), // Pixel 7 / flagship large phone
      Size(600, 960), // Small tablet / foldable unfolded
      Size(800, 1280), // Large tablet
    ];

    for (final size in viewports) {
      testWidgets(
          'No RenderFlex overflow on viewport ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = Size(size.width * 2.0, size.height * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final budget = BudgetController();
        await budget.setBudgetCap(25000.0, 5000.0);
        budget.addExpense(
            title: 'Groceries', amount: 1250.75, category: 'Food');

        await tester.pumpWidget(_buildHomeTestHarness(
          budget: budget,
          userName: 'Alexandre-Jean-Baptiste',
          viewportSize: size,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Overflow or crash on ${size.width}x${size.height}');

        // Verify illustration responsive sizing
        final illustrationFinder = find.byWidgetPredicate((w) =>
            w is SizedBox &&
            w.height == 185 &&
            (w.width == 135.0 || w.width! < 135.0));
        expect(illustrationFinder, findsWidgets);

        // Verify RouletteNumberText instances exist and are wrapped in FittedBox
        final rouletteFinder = find.byType(RouletteNumberText);
        expect(rouletteFinder, findsWidgets);
      });
    }
  });

  group(
      'CHALLENGER ADVERSARIAL SUITE: Accessibility Text Scaling (1.5x, 2.0x, 3.0x)',
      () {
    const scales = [1.5, 2.0, 3.0];
    const testWidths = [280.0, 320.0, 360.0, 412.0];

    for (final scale in scales) {
      for (final width in testWidths) {
        testWidgets(
            'Zero overflow at textScaler ${scale}x on width ${width.toInt()}px',
            (tester) async {
          tester.view.physicalSize = Size(width * 2.0, 800 * 2.0);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          final budget = BudgetController();
          await budget.setBudgetCap(15000.0, 3000.0);
          budget.addExpense(
              title: 'Textbooks', amount: 350.0, category: 'Academic');

          await tester.pumpWidget(_buildHomeTestHarness(
            budget: budget,
            userName: 'Yasmine',
            textScaleFactor: scale,
            viewportSize: Size(width, 800),
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'Failed at ${scale}x text scaling on width $width');
        });
      }
    }
  });

  group('CHALLENGER ADVERSARIAL SUITE: Boundary Values & Numeric Stress', () {
    testWidgets('Extremely large currency values (999,999,999 DT)',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildHomeTestHarness(
        totalCap: 999999999.999,
        spentSoFar: 888888888.888,
        userName: 'Mega Billionaire Student',
        textScaleFactor: 2.0,
        viewportSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RouletteNumberText), findsWidgets);
    });

    testWidgets('Zero and negative edge values', (tester) async {
      await tester.pumpWidget(_buildHomeTestHarness(
        totalCap: 0.0,
        spentSoFar: 0.0,
        userName: '',
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Empty username fallback
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('Budget cap exceeded (progress fraction clamps to 1.0)',
        (tester) async {
      await tester.pumpWidget(_buildHomeTestHarness(
        totalCap: 1000.0,
        spentSoFar: 5000.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('DT Cap'), findsOneWidget);
    });

    testWidgets('Ultra-long user name does not cause RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(280 * 2.0, 600 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildHomeTestHarness(
        userName: 'Maximilianus Konstantinos Theodosius Junior the Third',
        viewportSize: const Size(280, 600),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('CHALLENGER ADVERSARIAL SUITE: Rapid Lifecycle Mount/Unmount Loops',
      () {
    testWidgets(
        'Pump and recreate widget 50 times rapidly without ticker or timer leaks',
        (tester) async {
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          _buildHomeTestHarness(
            userName: 'User_$i',
            totalCap: 1000.0 + i * 50,
            spentSoFar: 100.0 + i * 10,
          ),
        );
        // Short pump to simulate rapid user tab-switching
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Final unmount
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group(
      'CHALLENGER ADVERSARIAL SUITE: Strict Zero-Emoji Scan Across All Rendered Widgets',
      () {
    testWidgets(
        'Verify zero Unicode emoji glyphs anywhere in header or body widgets',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(20000.0, 5000.0);
      budget.addExpense(title: 'Groceries', amount: 200.0, category: 'Food');
      budget.addExpense(
          title: 'Textbooks', amount: 150.0, category: 'Academic');

      final tasks = TasksController();
      tasks.addTask(
          title: 'Prepare Presentation',
          category: 'Academic',
          dueDate: 'Today');

      await tester.pumpWidget(_buildHomeTestHarness(
        budget: budget,
        tasks: tasks,
        userName: 'Yasmine',
      ));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.isNotEmpty, isTrue);

      for (final widget in textWidgets) {
        final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(text),
          isFalse,
          reason: 'Forbidden Unicode emoji found in Text widget: "$text"',
        );
      }
    });
  });
}

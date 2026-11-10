// test/adversarial/m4_sequence_stress_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapForM4Stress({
  required Widget child,
  required Size size,
  double textScale = 1.0,
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  CampusRestoController? resto,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(
          create: (_) => auth ?? AuthController()),
      ChangeNotifierProvider<TasksController>(
          create: (_) => tasks ?? TasksController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => budget ?? BudgetController()),
      ChangeNotifierProvider<CampusRestoController>(
          create: (_) => resto ?? CampusRestoController()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: MediaQuery(
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
}

Future<List<FlutterErrorDetails>> _pumpAndCatchErrors(
  WidgetTester tester, {
  required Widget child,
  required Size size,
  double textScale = 1.0,
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
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
      _wrapForM4Stress(
        child: child,
        size: size,
        textScale: textScale,
        auth: auth,
        tasks: tasks,
        budget: budget,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('M4 Sequence & Offsets Invariant Tests', () {
    testWidgets(
        'Empty State: Add Expense dy < Weekly Rhythm dy < Recent Transactions dy < Upcoming & Deadlines dy',
        (tester) async {
      final errors = await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 2200),
      );
      expect(errors, isEmpty);

      final addExpenseFinder = find.text('Add Expense');
      final weeklyRhythmFinder = find.text('Weekly Rhythm');
      final recentTxFinder = find.text('Recent Transactions');
      final upcomingFinder = find.text('Upcoming & Deadlines');

      expect(addExpenseFinder, findsOneWidget);
      expect(weeklyRhythmFinder, findsOneWidget);
      expect(recentTxFinder, findsOneWidget);
      expect(upcomingFinder, findsOneWidget);

      final addExpenseDy = tester.getTopLeft(addExpenseFinder).dy;
      final weeklyRhythmDy = tester.getTopLeft(weeklyRhythmFinder).dy;
      final recentTxDy = tester.getTopLeft(recentTxFinder).dy;
      final upcomingDy = tester.getTopLeft(upcomingFinder).dy;

      expect(addExpenseDy, lessThan(weeklyRhythmDy),
          reason:
              'Quick Action Add Expense ($addExpenseDy) must be strictly above Weekly Rhythm ($weeklyRhythmDy)');
      expect(weeklyRhythmDy, lessThan(recentTxDy),
          reason:
              'Weekly Rhythm ($weeklyRhythmDy) must be strictly above Recent Transactions ($recentTxDy)');
      expect(recentTxDy, lessThan(upcomingDy),
          reason:
              'Recent Transactions ($recentTxDy) must be strictly above Upcoming & Deadlines ($upcomingDy)');
    });

    testWidgets(
        'Populated State: Strict vertical sequence dy order holds with active expenses and tasks',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(1200.0, 350.0);
      budget.addExpense(
          title: 'Engineering Textbook', amount: 85.500, category: 'Academic');
      budget.addExpense(
          title: 'University Cafeteria Lunch',
          amount: 12.000,
          category: 'Dining');

      final tasks = TasksController();
      tasks.addTask(
          title: 'Control Systems Lab Assignment',
          category: 'Academic',
          dueDate: 'Tomorrow');
      tasks.addTask(
          title: 'Tuition Installment Payment',
          category: 'Finance',
          dueDate: 'Friday');

      final errors = await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(userName: 'Sarra'),
        size: const Size(450, 2600),
        budget: budget,
        tasks: tasks,
      );
      expect(errors, isEmpty);

      final addExpenseDy = tester.getTopLeft(find.text('Add Expense')).dy;
      final weeklyRhythmDy = tester.getTopLeft(find.text('Weekly Rhythm')).dy;
      final recentTxDy = tester.getTopLeft(find.text('Recent Transactions')).dy;
      final upcomingDy =
          tester.getTopLeft(find.text('Upcoming & Deadlines')).dy;

      expect(addExpenseDy, lessThan(weeklyRhythmDy));
      expect(weeklyRhythmDy, lessThan(recentTxDy));
      expect(recentTxDy, lessThan(upcomingDy));
    });

    testWidgets(
        'Adversarial Heavy Content: Strict dy order holds with long text and extreme values',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(99999.999, 50000.000);
      for (int i = 0; i < 5; i++) {
        budget.addExpense(
          title:
              'Very Long Item Name For Expense Entry Number $i With Additional Technical Details',
          amount: 1234.567 + (i * 100),
          category: 'Miscellaneous Super Long Category Name $i',
        );
      }

      final tasks = TasksController();
      for (int i = 0; i < 5; i++) {
        tasks.addTask(
          title:
              'Advanced Machine Learning Semester Project Phase $i Comprehensive Report',
          category: 'Academic Milestone',
          dueDate: 'Next Month',
        );
      }

      final errors = await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(
            userName: 'Alexander Maximilian Montgomery III'),
        size: const Size(500, 3500),
        budget: budget,
        tasks: tasks,
      );
      expect(errors, isEmpty);

      final addExpenseDy = tester.getTopLeft(find.text('Add Expense')).dy;
      final weeklyRhythmDy = tester.getTopLeft(find.text('Weekly Rhythm')).dy;
      final recentTxDy = tester.getTopLeft(find.text('Recent Transactions')).dy;
      final upcomingDy =
          tester.getTopLeft(find.text('Upcoming & Deadlines')).dy;

      expect(addExpenseDy, lessThan(weeklyRhythmDy));
      expect(weeklyRhythmDy, lessThan(recentTxDy));
      expect(recentTxDy, lessThan(upcomingDy));
    });
  });

  group('M4 Micro-Viewports & Text Scaler Stress Matrix', () {
    const microViewports = <String, Size>{
      '280x600': Size(280, 600),
      '320x500': Size(320, 500),
      '360x700': Size(360, 700),
    };

    const textScaleFactors = [1.0, 1.5, 2.0];

    for (final entry in microViewports.entries) {
      for (final scale in textScaleFactors) {
        testWidgets(
            'Zero RenderFlex overflow on ${entry.key} @ textScale ${scale}x [Default State]',
            (tester) async {
          final errors = await _pumpAndCatchErrors(
            tester,
            child: const HomeDashboard(),
            size: entry.value,
            textScale: scale,
          );

          final overflowErrors = errors.where((e) {
            final msg = e.exceptionAsString();
            return msg.contains('RenderFlex') || msg.contains('overflowed');
          }).toList();

          expect(
            overflowErrors,
            isEmpty,
            reason:
                'RenderFlex overflow detected on viewport ${entry.key} at scale ${scale}x: $overflowErrors',
          );
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'Zero RenderFlex overflow on ${entry.key} @ textScale ${scale}x [Populated State]',
            (tester) async {
          final budget = BudgetController();
          await budget.setBudgetCap(15000.0, 2500.0);
          budget.addExpense(
            title: 'Campus Bookstore Purchase',
            amount: 450.750,
            category: 'Academic Books',
          );
          budget.addExpense(
            title: 'Dining Card Refill',
            amount: 120.000,
            category: 'Campus Dining',
          );

          final tasks = TasksController();
          tasks.addTask(
            title: 'Operating Systems Kernel Assignment Final Delivery',
            category: 'Academic Projects',
            dueDate: 'Due Tonight',
          );

          final errors = await _pumpAndCatchErrors(
            tester,
            child: const HomeDashboard(userName: 'Alexander Montgomery'),
            size: entry.value,
            textScale: scale,
            budget: budget,
            tasks: tasks,
          );

          final overflowErrors = errors.where((e) {
            final msg = e.exceptionAsString();
            return msg.contains('RenderFlex') || msg.contains('overflowed');
          }).toList();

          expect(
            overflowErrors,
            isEmpty,
            reason:
                'RenderFlex overflow detected in populated state on viewport ${entry.key} at scale ${scale}x: $overflowErrors',
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('M4 Quick Actions Exclusivity & Legacy Button Elimination', () {
    testWidgets(
        'Quick actions contains exactly the designated 4 cards and designated icons',
        (tester) async {
      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 1000),
      );

      // Verify the 4 labels exist
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);

      // Verify the icons exist
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);
    });

    testWidgets(
        'Legacy action buttons (Send, Receive, Pay, Top-Up) are completely absent from widget tree',
        (tester) async {
      final budget = BudgetController();
      final tasks = TasksController();
      tasks.addTask(title: 'Math Quiz', category: 'Academic', dueDate: 'Today');

      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 1800),
        budget: budget,
        tasks: tasks,
      );

      expect(find.text('Send'), findsNothing);
      expect(find.text('Receive'), findsNothing);
      expect(find.text('Pay'), findsNothing);
      expect(find.text('Top-Up'), findsNothing);
      expect(find.text('Send Money'), findsNothing);
      expect(find.text('Receive Money'), findsNothing);
      expect(find.text('Top Up'), findsNothing);
    });
  });

  group('M4 Visual Geometry & Zero Unicode Emoji Verification', () {
    testWidgets('Curved body container has 38px radius and #F4F6F0 background',
        (tester) async {
      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 1200),
      );

      final curvedBodyFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final br = dec.borderRadius;
          if (br is BorderRadius) {
            return (br.topLeft == const Radius.circular(38) ||
                    br.topLeft == const Radius.circular(28) ||
                    br.topLeft == const Radius.circular(26)) &&
                (br.topRight == const Radius.circular(38) ||
                    br.topRight == const Radius.circular(28) ||
                    br.topRight == const Radius.circular(26)) &&
                br.bottomLeft == Radius.zero &&
                br.bottomRight == Radius.zero &&
                (dec.color == const Color(0xFFF4F6F0) ||
                    dec.color == const Color(0xFFF4F7F5));
          }
        }
        return false;
      });

      expect(curvedBodyFinder, findsOneWidget);
    });

    testWidgets(
        'Recent Transactions card items render blue square badge (#42A5F5) and vertical separator',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Textbook Purchase', amount: 55.250, category: 'Education');

      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 1600),
        budget: budget,
      );

      // Blue square badge with borderRadius 10 and #42A5F5
      final blueSquareBadge = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return (dec.color == const Color(0xFF42A5F5) ||
                  dec.color == AppColors.iconBlue) &&
              dec.shape == BoxShape.rectangle &&
              dec.borderRadius == BorderRadius.circular(10);
        }
        return false;
      });
      expect(blueSquareBadge, findsWidgets);

      // Category with vertical separator
      final now = DateTime.now();
      final expectedTime = DateFormat('h:mm a').format(now);
      expect(find.text('Education | $expectedTime'), findsOneWidget);

      // RouletteNumberText used for transaction amount
      expect(find.byType(RouletteNumberText), findsWidgets);
    });

    testWidgets('Strict Zero Unicode Emojis in all rendered text widgets',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Laboratory Equipment',
          amount: 150.0,
          category: 'Course Materials');
      final tasks = TasksController();
      tasks.addTask(
          title: 'Thesis Defense Prep',
          category: 'Academic',
          dueDate: 'Tomorrow');

      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(userName: 'Yasmine'),
        size: const Size(400, 1800),
        budget: budget,
        tasks: tasks,
      );

      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final content =
            textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(content),
          isFalse,
          reason: 'Prohibited emoji detected in Text: "$content"',
        );
      }
    });

    testWidgets(
        'Rapid sequential interaction on all 4 action cards without exceptions',
        (tester) async {
      final budget = BudgetController();
      await _pumpAndCatchErrors(
        tester,
        child: const HomeDashboard(),
        size: const Size(400, 1200),
        budget: budget,
      );

      // Tap Add Expense & dismiss modal
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();
      final addExpenseCtx = tester.element(find.text('Add Expense').first);
      Navigator.of(addExpenseCtx, rootNavigator: true).maybePop();
      await tester.pumpAndSettle();

      // Tap Scan Receipt & dismiss modal
      await tester.tap(find.text('Scan Receipt'));
      await tester.pumpAndSettle();
      final scanCtx = tester.element(find.text('Scan Receipt'));
      Navigator.of(scanCtx, rootNavigator: true).maybePop();
      await tester.pumpAndSettle();

      // Tap Adjust Cap & dismiss modal
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();
      final adjustCtx = tester.element(find.text('Adjust Cap'));
      Navigator.of(adjustCtx, rootNavigator: true).maybePop();
      await tester.pumpAndSettle();

      // Tap Calendar
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

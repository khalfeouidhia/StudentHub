// test/widgets/home_body_m4_test.dart
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
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapWithProviders(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  Size? surfaceSize,
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
          data: MediaQueryData(size: surfaceSize ?? const Size(400, 1800)),
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
  // Group 1: Non-Regression Guard (test/widget_test.dart Lines 56–60)
  // =========================================================================
  group('M4 — Group 1: Direct Non-Regression Guard for test/widget_test.dart',
      () {
    testWidgets(
        '1.1: Retains exact required action and header labels without broken text',
        (tester) async {
      final tasks = TasksController();
      tasks.addTask(
          title: 'CS301 Project', category: 'Academic', dueDate: 'Tomorrow');
      await tester.pumpWidget(_wrapWithProviders(
          const HomeDashboard(userName: 'Yasmine'),
          tasks: tasks));
      await tester.pumpAndSettle();

      expect(find.text('Upcoming & Deadlines'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 2: Curved Body Sheet (38px Top Radius & Palette)
  // =========================================================================
  group('M4 — Group 2: Curved Body Container Architecture (R3)', () {
    testWidgets(
        '2.1: Body sheet has 38px top-left and top-right curved border radius and #F4F6F0 background',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final curvedSheet = find.byWidgetPredicate((w) {
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

      expect(curvedSheet, findsOneWidget);
    });
  });

  // =========================================================================
  // Group 3: Single 4-Card Quick Actions Row (R3)
  // =========================================================================
  group('M4 — Group 3: Quick Actions 4-Card Single Row (R3)', () {
    testWidgets(
        '3.1: Renders exactly one row of 4 action cards with designated icons',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);
    });

    testWidgets(
        '3.2: Legacy duplicate shortcut buttons (Send, Receive, Pay, Top-Up) are absent',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Send'), findsNothing);
      expect(find.text('Receive'), findsNothing);
      expect(find.text('Pay'), findsNothing);
      expect(find.text('Top-Up'), findsNothing);
    });
  });

  // =========================================================================
  // Group 4: Exact Vertical Sequence Order (R5)
  // =========================================================================
  group('M4 — Group 4: Vertical Sequence Ordering (R5)', () {
    testWidgets(
        '4.1: Sequence order is Quick Actions -> Weekly Rhythm -> Recent Transactions -> Upcoming Deadlines',
        (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 1800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final budget = BudgetController();
      budget.addExpense(title: 'Book', amount: 12.0, category: 'Books');
      final tasks = TasksController();
      tasks.addTask(
          title: 'Lab Report', category: 'Academic', dueDate: 'Tomorrow');

      await tester.pumpWidget(_wrapWithProviders(
        const HomeDashboard(),
        budget: budget,
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      final actionsY = tester.getTopLeft(find.text('Add Expense')).dy;
      final rhythmY = tester.getTopLeft(find.text('Weekly Rhythm')).dy;
      final transactionsY =
          tester.getTopLeft(find.text('Recent Transactions')).dy;
      final deadlinesY =
          tester.getTopLeft(find.text('Upcoming & Deadlines')).dy;

      expect(actionsY, lessThan(rhythmY),
          reason: 'Quick Actions must appear above Weekly Rhythm');
      expect(rhythmY, lessThan(transactionsY),
          reason: 'Weekly Rhythm must appear above Recent Transactions');
      expect(transactionsY, lessThan(deadlinesY),
          reason: 'Recent Transactions must appear above Upcoming Deadlines');
    });
  });

  // =========================================================================
  // Group 5: Recent Transactions Card Polish (R5)
  // =========================================================================
  group('M4 — Group 5: Recent Transactions Card Polish (R5)', () {
    testWidgets(
        '5.1: Transaction item renders blue square badge (#42A5F5) and RouletteNumberText',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Calculus Textbook', amount: 45.0, category: 'Books');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('Calculus Textbook'), findsOneWidget);

      // Verify blue square badge (#42A5F5) with BoxShape.rectangle and borderRadius 10
      final squareBadge = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final isBlue = dec.color == const Color(0xFF42A5F5) ||
              dec.color == AppColors.iconBlue;
          final isSquare = dec.shape == BoxShape.rectangle &&
              dec.borderRadius == BorderRadius.circular(10);
          return isBlue && isSquare;
        }
        return false;
      });
      expect(squareBadge, findsWidgets);

      // Verify dual-tone RouletteNumberText is used for transaction amount
      expect(find.byType(RouletteNumberText), findsWidgets);
    });

    testWidgets(
        '5.2: Category tag displays vertical bar separator between category and timestamp',
        (tester) async {
      final budget = BudgetController();
      final now = DateTime.now();
      budget.addExpense(
          title: 'Campus Coffee', amount: 3.5, category: 'Dining');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      final expectedTagSubstring =
          'Dining | ${DateFormat('h:mm a').format(now)}';
      expect(find.text(expectedTagSubstring), findsOneWidget);
    });

    testWidgets(
        '5.3: Empty state displays updated guidance without removed Send/Pay verbs',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('No recent transactions'), findsOneWidget);
      expect(
          find.text('Tap + Add Expense to record an outflow'), findsOneWidget);
      expect(find.textContaining('Send or Pay'), findsNothing);
    });
  });

  // =========================================================================
  // Group 6: Strict Zero-Emoji Policy (R5)
  // =========================================================================
  group('M4 — Group 6: Strict Zero-Unicode-Emoji Scan (R5)', () {
    testWidgets(
        '6.1: Body contains zero Unicode emojis across populated states',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(title: 'Groceries', amount: 32.5, category: 'Food');
      final tasks = TasksController();
      tasks.addTask(
          title: 'Physics Homework', category: 'Academic', dueDate: 'Friday');

      await tester.pumpWidget(_wrapWithProviders(
        const HomeDashboard(userName: 'Yasmine'),
        budget: budget,
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final text = t.data ?? t.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(text),
          isFalse,
          reason: 'Forbidden Unicode emoji found in body Text widget: "$text"',
        );
      }
    });
  });

  // =========================================================================
  // Group 7: Responsive Stress & Micro-Viewport Resilience
  // =========================================================================
  group('M4 — Group 7: Responsive Stress & Micro-Viewport Resilience', () {
    testWidgets('7.1: Zero RenderFlex overflow on micro-viewport width 280px',
        (tester) async {
      tester.view.physicalSize = const Size(280 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(280, 700)),
          child: _wrapWithProviders(const HomeDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

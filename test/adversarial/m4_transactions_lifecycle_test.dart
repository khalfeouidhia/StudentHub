// test/adversarial/m4_transactions_lifecycle_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/calendar_view.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';

Widget _wrapWithHarness(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  CampusRestoController? resto,
  Size surfaceSize = const Size(400, 1800),
  double textScale = 1.0,
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
            size: surfaceSize,
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
          ),
          child: child,
        ),
      ),
    ),
  );
}

final RegExp _unicodeEmojiRegex = RegExp(
  r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}]',
  unicode: true,
);

void _assertZeroEmojisInTree(WidgetTester tester,
    {String contextDescription = ''}) {
  final textWidgets = tester.widgetList<Text>(find.byType(Text));
  for (final t in textWidgets) {
    final text = t.data ?? t.textSpan?.toPlainText() ?? '';
    expect(
      _unicodeEmojiRegex.hasMatch(text),
      isFalse,
      reason:
          'Forbidden Unicode emoji in Text widget ($contextDescription): "$text"',
    );
  }

  final richTextWidgets = tester.widgetList<RichText>(find.byType(RichText));
  for (final rt in richTextWidgets) {
    final text = rt.text.toPlainText();
    expect(
      _unicodeEmojiRegex.hasMatch(text),
      isFalse,
      reason:
          'Forbidden Unicode emoji in RichText widget ($contextDescription): "$text"',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // =========================================================================
  // GROUP 1: Dynamic Transaction State Transitions (0, 1, 5, 20 items)
  // =========================================================================
  group(
      'M4 Adversarial Group 1: Dynamic Transaction State Transitions (0, 1, 5, 20 Items)',
      () {
    testWidgets(
        '1.1: 0 items (Empty state) renders empty placeholder, guidance, and 0 transaction rows',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Empty state assertions
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.text('No recent transactions'), findsOneWidget);
      expect(
          find.text('Tap + Add Expense to record an outflow'), findsOneWidget);

      // Transaction items should be 0
      final itemCards = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.color == Colors.white &&
              dec.borderRadius == BorderRadius.circular(16) &&
              w.margin == const EdgeInsets.only(bottom: 8);
        }
        return false;
      });
      expect(itemCards, findsNothing);
    });

    testWidgets(
        '1.2: 1 item renders transaction card, title, blue badge, category separator, and hides empty state',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
        title: 'Campus Coffee & Croissant',
        amount: 3.500,
        category: 'Campus Dining',
      );

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Empty state must be gone
      expect(find.text('No recent transactions'), findsNothing);
      expect(find.text('Tap + Add Expense to record an outflow'), findsNothing);

      // 1 transaction item present
      expect(find.text('Campus Coffee & Croissant'), findsOneWidget);
      expect(find.textContaining('Campus Dining | '), findsOneWidget);

      // Verify blue square badge #42A5F5
      final blueSquareBadge = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return (dec.color == const Color(0xFF42A5F5) ||
                  dec.color == AppColors.iconBlue) &&
              dec.borderRadius == BorderRadius.circular(10) &&
              w.constraints?.maxWidth == 40 &&
              w.constraints?.maxHeight == 40;
        }
        return false;
      });
      expect(blueSquareBadge, findsOneWidget);

      // Verify RouletteNumberText formatting for amount
      final rouletteFinder = find.byWidgetPredicate((w) {
        return w is RouletteNumberText &&
            w.value == 3.500 &&
            w.prefix == '- ' &&
            w.suffix == ' DT' &&
            w.thousandsSeparator == true &&
            w.decimalDigits == 3;
      });
      expect(rouletteFinder, findsOneWidget);
    });

    testWidgets('1.3: 5 items caps rendered preview to exactly 4 items',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(title: 'Tx 1 Coffee', amount: 3.0, category: 'Dining');
      budget.addExpense(title: 'Tx 2 Notebook', amount: 8.5, category: 'Books');
      budget.addExpense(
          title: 'Tx 3 Bus Pass', amount: 12.0, category: 'Commute');
      budget.addExpense(
          title: 'Tx 4 Lunch Meal', amount: 6.25, category: 'Dining');
      budget.addExpense(
          title: 'Tx 5 Lab Manual', amount: 25.0, category: 'Books');

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      expect(budget.transactions.length, 5);

      // Exactly 4 items rendered in recent transactions preview (take(4))
      expect(
          find.text('Tx 5 Lab Manual'), findsOneWidget); // inserted at index 0
      expect(find.text('Tx 4 Lunch Meal'), findsOneWidget);
      expect(find.text('Tx 3 Bus Pass'), findsOneWidget);
      expect(find.text('Tx 2 Notebook'), findsOneWidget);
      // 5th oldest item should NOT be in the preview list
      expect(find.text('Tx 1 Coffee'), findsNothing);

      // Blue badges count should be exactly 4
      final blueSquareBadges = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return (dec.color == const Color(0xFF42A5F5) ||
                  dec.color == AppColors.iconBlue) &&
              dec.borderRadius == BorderRadius.circular(10) &&
              w.constraints?.maxWidth == 40;
        }
        return false;
      });
      expect(blueSquareBadges, findsNWidgets(4));
    });

    testWidgets(
        '1.4: 20 items stress volume renders cleanly with 0 overflow and capped 4 preview items',
        (tester) async {
      final budget = BudgetController();
      for (int i = 1; i <= 20; i++) {
        budget.addExpense(
          title:
              'Transaction Item #$i — Descriptive Label for Student Outflow Stress Testing',
          amount: (i * 15.750),
          category: (i % 2 == 0)
              ? 'Campus Dining & Groceries'
              : 'Books, Course Tech & Tools',
        );
      }

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(budget.transactions.length, 20);

      // Exactly 4 items in preview
      final previewCards = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return dec.color == Colors.white &&
              dec.borderRadius == BorderRadius.circular(16) &&
              w.margin == const EdgeInsets.only(bottom: 8);
        }
        return false;
      });
      expect(previewCards, findsNWidgets(4));

      // Most recent item (#20) is visible
      expect(find.textContaining('Transaction Item #20'), findsOneWidget);
      // Item #1 is not visible in 4-item preview
      expect(find.textContaining('Transaction Item #1 —'), findsNothing);
    });

    testWidgets(
        '1.5: Dynamic state lifecycle mutation (0 -> 1 -> 5 -> 20 -> delete to 0) runs smoothly',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // State 0: empty
      expect(find.text('No recent transactions'), findsOneWidget);

      // Transition to 1
      budget.addExpense(title: 'Single Item', amount: 4.5, category: 'Dining');
      await tester.pumpAndSettle();
      expect(find.text('No recent transactions'), findsNothing);
      expect(find.text('Single Item'), findsOneWidget);

      // Transition to 5
      for (int i = 2; i <= 5; i++) {
        budget.addExpense(title: 'Item $i', amount: i * 5.0, category: 'Misc');
      }
      await tester.pumpAndSettle();
      expect(find.text('Item 5'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Single Item'), findsNothing); // capped

      // Transition to 20
      for (int i = 6; i <= 20; i++) {
        budget.addExpense(title: 'Item $i', amount: i * 2.0, category: 'Study');
      }
      await tester.pumpAndSettle();
      expect(find.text('Item 20'), findsOneWidget);
      expect(budget.transactions.length, 20);

      // Delete all back to 0
      final allIds = budget.transactions.map((t) => t.id).toList();
      for (final id in allIds) {
        budget.deleteExpense(id);
      }
      await tester.pumpAndSettle();
      expect(find.text('No recent transactions'), findsOneWidget);
      expect(
          find.text('Tap + Add Expense to record an outflow'), findsOneWidget);
      expect(budget.transactions.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // GROUP 2: Formatting & Component Structure Invariants
  // =========================================================================
  group(
      'M4 Adversarial Group 2: Badge Geometry, Separators, and RouletteNumberText Formatting',
      () {
    testWidgets(
        '2.1: Blue square badge #42A5F5 matches exact geometry, size 40x40, radius 10, white icon',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Campus Gym Pass', amount: 20.0, category: 'Health');

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      final badgeContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final isBlue = dec.color == const Color(0xFF42A5F5) ||
              dec.color == AppColors.iconBlue;
          final isRadius10 = dec.borderRadius == BorderRadius.circular(10);
          final is40x40 =
              w.constraints?.maxWidth == 40 && w.constraints?.maxHeight == 40;
          return isBlue && isRadius10 && is40x40;
        }
        return false;
      });

      expect(badgeContainerFinder, findsOneWidget);

      // Inside badge: white receipt icon size 20
      final iconInsideBadge = find.descendant(
        of: badgeContainerFinder,
        matching: find.byWidgetPredicate((w) {
          return w is Icon &&
              w.icon == Icons.receipt_long_rounded &&
              w.color == Colors.white &&
              w.size == 20;
        }),
      );
      expect(iconInsideBadge, findsOneWidget);
    });

    testWidgets(
        '2.2: Category tag contains exact vertical bar separator " | " with styled pill decoration',
        (tester) async {
      final budget = BudgetController();
      final fixedDate = DateTime(2026, 10, 15, 14, 30); // 2:30 PM
      budget.addExpense(
        title: 'Sandwich',
        amount: 5.5,
        category: 'Food & Dining',
        date: fixedDate,
      );

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      final expectedTagText = 'Food & Dining | 2:30 PM';
      expect(find.text(expectedTagText), findsOneWidget);

      // Verify category tag container decoration
      final tagContainerFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final isRadius4 = dec.borderRadius == BorderRadius.circular(4);
          final isSandCreamTint =
              dec.color == AppColors.sandCream.withOpacity(0.35);
          return isRadius4 && isSandCreamTint;
        }
        return false;
      });
      expect(tagContainerFinder, findsOneWidget);
    });

    testWidgets(
        '2.3: RouletteNumberText formats amounts with thousands separator, 3 decimals, and dual-tone styles',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
        title: 'Tuition Installment',
        amount: 1450.500,
        category: 'Education',
      );

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      final rouletteFinder = find.byWidgetPredicate((w) {
        if (w is RouletteNumberText) {
          return w.value == 1450.500 &&
              w.prefix == '- ' &&
              w.suffix == ' DT' &&
              w.decimalDigits == 3 &&
              w.thousandsSeparator == true &&
              w.wholeStyle?.fontWeight == FontWeight.w800 &&
              w.wholeStyle?.color == AppColors.darkForest &&
              w.decimalStyle?.fontWeight == FontWeight.w600 &&
              w.decimalStyle?.color == AppColors.softSage;
        }
        return false;
      });

      expect(rouletteFinder, findsOneWidget);

      // Let Roulette odometer animation settle
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      // Formatted whole text contains thousands comma separator widget Text(',')
      expect(find.text(','), findsWidgets);
      // Semantic accessibility label formats exact dual-tone string
      expect(find.bySemanticsLabel('- 1,450.500 DT'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: Quick Action Cards Interactive Lifecycle
  // =========================================================================
  group('M4 Adversarial Group 3: Quick Action Cards Interactive Lifecycle Taps',
      () {
    testWidgets(
        '3.1: Tap "Add Expense" opens modal, allows input, saves expense, and updates recent transactions',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Tap 'Add Expense' card
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();

      // Modal sheet appears
      expect(find.text('Record New Outflow'), findsOneWidget);
      expect(find.text('Expense Description'), findsOneWidget);
      expect(find.text('Amount (DT)'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);

      // Enter details
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.first, 'Lab Physics Goggles');
      await tester.enterText(textFields.last, '18.750');
      await tester.pumpAndSettle();

      // Tap 'Save Expense' button
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      // Modal dismisses
      expect(find.text('Record New Outflow'), findsNothing);

      // New expense is recorded in budget controller and displayed in Home recent transactions
      expect(budget.transactions.length, 1);
      expect(budget.transactions.first.title, 'Lab Physics Goggles');
      expect(budget.transactions.first.amount, 18.750);
      expect(find.text('Lab Physics Goggles'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3.2: Tap "Scan Receipt" triggers receipt camera flow safely without unhandled errors',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Tap 'Scan Receipt' card
      await tester.tap(find.text('Scan Receipt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Must not throw any unhandled exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3.3: Tap "Adjust Cap" opens adjust modal, modifies cap, and updates budget controller cleanly',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(1200.0, 180.0);

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Tap 'Adjust Cap' card
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();

      // Modal sheet appears
      expect(find.text('Adjust Monthly Cap'), findsOneWidget);
      expect(find.text('MONTHLY ALLOWANCE TARGET'), findsOneWidget);
      expect(find.text('Update Budget Cap'), findsOneWidget);

      // Modify cap textfield
      final capField = find.byType(TextField);
      expect(capField, findsOneWidget);
      await tester.enterText(capField, '1800');
      await tester.pumpAndSettle();

      // Submit update
      await tester.tap(find.text('Update Budget Cap'));
      await tester.pumpAndSettle();

      // Modal dismisses and budget controller updated
      expect(find.text('Adjust Monthly Cap'), findsNothing);
      expect(budget.totalCap, 1800.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '3.4: Tap "Calendar" in standalone mode is null-safe and throws zero exceptions',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Tap 'Calendar' card when MainShell is NOT an ancestor
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      // Completes smoothly without crashing
      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets(
        '3.5: Tap "Calendar" inside MainShell switches active tab to Tab 2 (CalendarScreen)',
        (tester) async {
      final budget = BudgetController();
      final tasks = TasksController();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>(
                create: (_) => AuthController()),
            ChangeNotifierProvider<TasksController>(create: (_) => tasks),
            ChangeNotifierProvider<BudgetController>(create: (_) => budget),
            ChangeNotifierProvider<CampusRestoController>(
                create: (_) => CampusRestoController()),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: MainShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on HomeView (Tab 0)
      expect(find.text('StudentHub'), findsOneWidget);
      expect(find.text('Calendar'),
          findsWidgets); // Tab item and Quick Action card

      // Tap the Quick Action card for 'Calendar' inside HomeDashboard
      final quickActionCalendarFinder = find.descendant(
        of: find.byType(HomeDashboard),
        matching: find.widgetWithText(GestureDetector, 'Calendar'),
      );
      expect(quickActionCalendarFinder, findsOneWidget);
      await tester.tap(quickActionCalendarFinder);
      await tester.pumpAndSettle();

      // Tab should now be switched to Tab 2 (CalendarScreen)
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // GROUP 4: Runtime Zero-Emoji Policy Across Dynamic States
  // =========================================================================
  group('M4 Adversarial Group 4: Strict Runtime Zero-Emoji Assertions', () {
    testWidgets(
        '4.1: Empty state (0 items) has 0 Unicode emojis across all Text and RichText widgets',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      _assertZeroEmojisInTree(tester,
          contextDescription: 'Empty State (0 items)');
    });

    testWidgets(
        '4.2: Populated states (1, 5, 20 items) have 0 Unicode emojis in all Text & RichText widgets',
        (tester) async {
      final budget = BudgetController();
      for (int i = 1; i <= 20; i++) {
        budget.addExpense(
          title: 'Campus Transaction #$i Expense Item',
          amount: i * 3.5,
          category: 'Dining & Groceries',
        );
      }

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      _assertZeroEmojisInTree(tester,
          contextDescription: 'Populated State (20 items)');
    });

    testWidgets(
        '4.3: Action modal sheets ("Record New Outflow" & "Adjust Monthly Cap") have 0 Unicode emojis',
        (tester) async {
      final budget = BudgetController();

      await tester.pumpWidget(_wrapWithHarness(
        const HomeDashboard(),
        budget: budget,
      ));
      await tester.pumpAndSettle();

      // Open 'Record New Outflow' modal
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();
      _assertZeroEmojisInTree(tester,
          contextDescription: 'Record New Outflow Modal');

      // Dismiss modal
      Navigator.of(tester.element(find.text('Record New Outflow'))).pop();
      await tester.pumpAndSettle();

      // Open 'Adjust Monthly Cap' modal
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();
      _assertZeroEmojisInTree(tester,
          contextDescription: 'Adjust Monthly Cap Modal');
    });
  });
}

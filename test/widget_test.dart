import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/welcome_vault_view.dart';
import 'package:studenthold_app/ui/views/budget_view.dart';
import 'package:studenthold_app/ui/views/expenses_view.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';
import 'package:studenthold_app/ui/views/monthly_history_view.dart';
import 'package:studenthold_app/ui/views/splash_screen.dart';
import 'package:studenthold_app/ui/views/glowing_typewriter_greeting.dart';
import 'package:studenthold_app/ui/views/receipt_entry_sheet.dart';
import 'package:studenthold_app/ui/views/receipt_viewer_dialog.dart';

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
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets(
      'HomeDashboard renders solo student sections without layout crashes',
      (WidgetTester tester) async {
    final tasks = TasksController();
    tasks.addTask(
      title: 'CS301 Project Submission',
      category: 'Academic',
      dueDate: 'Due tomorrow',
    );
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
      'HomeDashboard renders clean zero-base state for brand-new student',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));

    expect(find.text('StudentHub'), findsOneWidget);
    expect(find.text('OCTOBER BUDGET'), findsOneWidget);
  });

  testWidgets('WelcomeVaultView renders onboarding profile fields and PIN pad',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithProviders(const WelcomeVaultView()));

    expect(find.text('Personalization & Setup'), findsOneWidget);
    expect(find.text('Campus Profile'), findsOneWidget);
    expect(find.text('Monthly Spending Target'), findsOneWidget);
    expect(find.text('Confidential Vault PIN'), findsOneWidget);
    expect(find.text('Complete Setup & Enter Nest'), findsOneWidget);
  });

  testWidgets(
      'MainShell renders 5 primary solo student navigation tabs with LiquidGlassBottomNavBar',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithProviders(const MainShell()));

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

    // Switch to Expenses tab
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Expenses & Outflows'), findsOneWidget);

    // Switch to Calendar tab
    await tester.tap(find.descendant(
        of: find.byType(LiquidGlassBottomNavBar),
        matching: find.text('Calendar')));
    await tester.pumpAndSettle();
    expect(find.text('Calender'), findsOneWidget);

    // Switch to Tasks tab
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks & Deadlines'), findsOneWidget);
  });

  testWidgets(
      'LiquidGlassBottomNavBar renders frosted backdrop blur and gliding indicator pill',
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

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    // Tap on Tasks
    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(selected, equals(2));
  });

  testWidgets('BudgetView renders allowance and handles empty state cleanly',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await tester
        .pumpWidget(_wrapWithProviders(const BudgetView(), budget: budget));

    expect(find.text('Expenses & Outflows'), findsOneWidget);
    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('OCTOBER TOTAL OUTFLOW'), findsOneWidget);
  });

  testWidgets('TasksView renders segmented tabs and handles clean empty state',
      (WidgetTester tester) async {
    final tasks = TasksController();
    await tester
        .pumpWidget(_wrapWithProviders(const TasksView(), tasks: tasks));

    expect(find.text('Tasks & Deadlines'), findsOneWidget);
    expect(find.text('Add Task'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Academic'), findsWidgets);
    expect(find.text('Personal/Chore'), findsOneWidget);

    // Verify zero-base state
    expect(find.text('0% Complete'), findsOneWidget);
    expect(
        find.text(
            "No tasks or deadlines logged. Tap 'Add Task' to organize your study schedule."),
        findsOneWidget);
  });

  testWidgets('TasksView modal adds new task item dynamically',
      (WidgetTester tester) async {
    final tasks = TasksController();
    await tester
        .pumpWidget(_wrapWithProviders(const TasksView(), tasks: tasks));

    // Tap Add Task button
    await tester.tap(find.text('Add Task').first);
    await tester.pumpAndSettle();

    // Verify modal is visible
    expect(find.text('Add Academic / Personal Task'), findsOneWidget);

    // Enter title
    await tester.enterText(
        find.widgetWithText(
            TextField, 'Task Title (e.g. Study Math, CS301 Project)'),
        'Prepare Physics Lab Report');
    await tester.pumpAndSettle();

    // Tap 'Add Task' modal submit button
    await tester.tap(find.text('Add Task').last);
    await tester.pumpAndSettle();

    // Verify task is added to list
    expect(find.text('Prepare Physics Lab Report'), findsOneWidget);
  });

  testWidgets('TasksView allows inline editing and deleting tasks',
      (WidgetTester tester) async {
    final tasks = TasksController();
    tasks.addTask(
        title: 'Calculus Assignment 1',
        category: 'Academic',
        dueDate: 'Oct 15, 2026');
    await tester
        .pumpWidget(_wrapWithProviders(const TasksView(), tasks: tasks));

    expect(find.text('Calculus Assignment 1'), findsOneWidget);

    // Tap Edit button
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Task'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(
            TextField, 'Task Title (e.g. Study Math, CS301 Project)'),
        'Calculus Assignment 1 - Revised');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Verify updated task
    expect(find.text('Calculus Assignment 1 - Revised'), findsOneWidget);

    // Tap Delete button
    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Delete Task'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify task deleted
    expect(find.text('Calculus Assignment 1 - Revised'), findsNothing);
  });

  testWidgets('BudgetView modal adds new expense dynamically',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await tester
        .pumpWidget(_wrapWithProviders(const BudgetView(), budget: budget));

    // Tap Add Expense
    await tester.tap(find.text('Add Expense').first);
    await tester.pumpAndSettle();

    // Verify modal is visible
    expect(find.text('Record Outflow'), findsOneWidget);

    // Enter details
    await tester.enterText(
        find.widgetWithText(TextField, 'Expense Description'),
        'Calculus Textbook');
    await tester.enterText(
        find.widgetWithText(TextField, 'Amount (DT)'), '35.00');
    await tester.pumpAndSettle();

    // Tap 'Save Expense'
    await tester.tap(find.text('Save Expense'));
    await tester.pumpAndSettle();

    // Verify added transaction is listed
    expect(find.text('Calculus Textbook'), findsOneWidget);
  });

  testWidgets(
      'WelcomeVaultView completes onboarding and updates AuthController and BudgetController',
      (WidgetTester tester) async {
    final auth = AuthController();
    final budget = BudgetController();

    await tester.pumpWidget(_wrapWithProviders(const WelcomeVaultView(),
        auth: auth, budget: budget));

    // Fill in name
    await tester.enterText(
      find.widgetWithText(TextField, 'Your name'),
      'Nour Cherif',
    );
    // Fill in university
    await tester.enterText(
      find.widgetWithText(TextField, 'Institution and degree'),
      'Polytechnique Tunisie',
    );
    await tester.pumpAndSettle();

    // Enter 4-digit PIN: 1, 2, 3, 4
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

    // Tap submit button
    await tester.ensureVisible(find.text('Complete Setup & Enter Nest'));
    await tester.tap(find.text('Complete Setup & Enter Nest'));
    await tester.pumpAndSettle();

    expect(auth.isOnboarded, isTrue);
    expect(auth.userName, equals('Nour Cherif'));
    expect(auth.university, equals('Polytechnique Tunisie'));
    expect(auth.monthlyBudgetCap, equals(1500.0));
  });

  testWidgets(
      'WelcomeVaultView displays STEP 1 OF 1, budget slider markers, and 4 categories',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithProviders(const WelcomeVaultView()));

    // Verify single-step badge
    expect(find.text('STEP 1 OF 1'), findsOneWidget);

    // Verify initial target and slider markers
    expect(find.text('1500 DT'), findsOneWidget);
    expect(find.text('/ month'), findsOneWidget);
    expect(find.text('0 DT'), findsOneWidget);
    expect(find.text('1,500 DT'), findsOneWidget);
    expect(find.text('+3,000 DT'), findsOneWidget);

    // Scroll to 4 category allocations
    await tester.ensureVisible(find.text('Housing & Dining'));
    expect(find.text('Housing & Dining'), findsOneWidget);
    expect(find.text('Textbooks & Tech'), findsOneWidget);
    expect(find.text('Social & Coffee'), findsOneWidget);
    expect(find.text('Emergency Buffer'), findsOneWidget);
  });

  testWidgets(
      'HomeDashboard renders dynamic Weekly Rhythm tooltip pill badge with DT format',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await budget.setBudgetCap(1500.0, 300.0);
    budget.addExpense(
      title: 'Course Textbook',
      amount: 45.000,
      category: 'Books & Study',
    );

    await tester
        .pumpWidget(_wrapWithProviders(const HomeDashboard(), budget: budget));
    await tester.pumpAndSettle();

    // Verify Weekly Rhythm section and subtitle with DT
    expect(find.text('Weekly Rhythm'), findsOneWidget);
    expect(find.textContaining('vs. Daily Safe Spend'), findsOneWidget);
    expect(find.textContaining('DT'), findsWidgets);

    // Verify tooltip badge pill format '${dailyTotal.toInt()} DT'
    expect(find.text('45 DT'), findsOneWidget);
  });

  testWidgets(
      'HomeDashboard top header history icon opens MonthlyHistoryModalSheet',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await tester
        .pumpWidget(_wrapWithProviders(const HomeDashboard(), budget: budget));
    await tester.pumpAndSettle();

    // Verify history icon exists in header
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);

    // Tap history button
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();

    // Verify modal sheet opens with title and subtitle
    expect(find.text('Historical Archive'), findsOneWidget);
    expect(find.text('Review past spending cycles & receipts'), findsOneWidget);
  });

  testWidgets(
      'MonthlyHistoryModalSheet displays retrospective summary, category chips, and locked receipts',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await budget.addArchivedMonth(
      monthKey: '2026-09',
      cap: 1000.0,
      transactions: [
        TransactionRecord(
          id: 'tx1',
          title: 'Calculus 3 Textbook',
          amount: 85.0,
          category: 'Books & Study',
          date: DateTime(2026, 9, 15),
        ),
        TransactionRecord(
          id: 'tx2',
          title: 'Campus Cafeteria Pass',
          amount: 45.0,
          category: 'Food & Dining',
          date: DateTime(2026, 9, 20),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthlyHistoryModalSheet(budget: budget),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and month chip
    expect(find.text('Historical Archive'), findsOneWidget);
    expect(find.text('Sep 2026'), findsOneWidget);

    // Verify retrospective statement card & status pill
    expect(find.text('Sep 2026 Statement'), findsOneWidget);
    expect(find.text('Saved 870.000 DT'), findsOneWidget);
    expect(find.text('Dining: 45.000 DT'), findsOneWidget);
    expect(find.text('Books: 85.000 DT'), findsOneWidget);

    // Verify locked historical banner
    expect(
      find.text(
          'Viewing archived statement. Records from this month are locked.'),
      findsOneWidget,
    );

    // Verify receipt items
    expect(find.text('Calculus 3 Textbook'), findsOneWidget);
    expect(find.text('-85.000 DT'), findsOneWidget);
    expect(find.text('Campus Cafeteria Pass'), findsOneWidget);
    expect(find.text('-45.000 DT'), findsOneWidget);
  });

  testWidgets(
      'BudgetController performs month rollover, archives data, and resets trackers cleanly',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await budget.setBudgetCap(1500.0, 300.0);
    budget.addExpense(
      title: 'Monthly Rent',
      amount: 450.0,
      category: 'Housing',
    );
    expect(budget.spentSoFar, equals(450.0));
    expect(budget.isEmpty, isFalse);

    // Perform month rollover
    await budget.performMonthRollover('2026-11', 1600.0);

    // Active trackers must be reset strictly to clean zero
    expect(budget.spentSoFar, equals(0.0));
    expect(budget.totalCap, equals(1600.0));
    expect(budget.isEmpty, isTrue);

    // Previous month must be archived
    expect(budget.availableArchivedMonths, isNotEmpty);
    final pastKey = budget.availableArchivedMonths.first;
    expect(budget.getArchivedTotal(pastKey), equals(450.0));
    expect(budget.getArchivedCap(pastKey), equals(1500.0));
  });

  testWidgets(
      'StudentHubSplashScreen renders Vector Wallet, typography, and flat spinner',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrapWithProviders(
        const StudentHubSplashScreen(autoBootstrap: false),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('YOUR MONEY. YOUR FUTURE.'), findsOneWidget);
    expect(find.byType(RichText), findsWidgets);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets(
      'StudentHubSplashScreen completes bootstrap to WelcomeVaultView for new student',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'isOnboarded': false});
    final auth = AuthController();
    await auth.init();

    await tester.pumpWidget(
      _wrapWithProviders(
        const StudentHubSplashScreen(
          minimumDisplayDuration: Duration(milliseconds: 300),
          autoBootstrap: true,
        ),
        auth: auth,
      ),
    );

    // Initial frame
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('YOUR MONEY. YOUR FUTURE.'), findsOneWidget);

    // Complete bootstrap, pause, and silk transition
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    // Should have transitioned to WelcomeVaultView
    expect(find.byKey(const ValueKey('welcome_vault')), findsOneWidget);
  });

  testWidgets(
      'StudentHubSplashScreen boots into MainShell for onboarded student',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'isOnboarded': true,
      'userName': 'Sarra',
    });
    final auth = AuthController();
    await auth.init();

    await tester.pumpWidget(
      _wrapWithProviders(
        const StudentHubSplashScreen(
          minimumDisplayDuration: Duration(milliseconds: 300),
          autoBootstrap: true,
        ),
        auth: auth,
      ),
    );

    // Step through bootstrap and silk transition
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    // Should have transitioned to MainShell
    expect(find.byKey(const ValueKey('main_shell')), findsOneWidget);
  });

  testWidgets(
      'ReceiptEntrySheet starts empty with zero fake suggestions and saves real expense',
      (WidgetTester tester) async {
    final budget = BudgetController();
    await tester.pumpWidget(
      _wrapWithProviders(
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => ReceiptEntrySheet.show(
                context,
                budget,
                imagePath: '/mock/receipts/physics_textbook.jpg',
              ),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
        budget: budget,
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify header and zero fake suggestions
    expect(find.text('Attached Receipt Record'), findsOneWidget);
    expect(find.text('Photo Attached'), findsOneWidget);
    expect(find.text('Campus Bookstore'), findsNothing);
    expect(find.text('42.500'), findsNothing);

    // Enter real user data
    await tester.enterText(find.widgetWithText(TextField, 'What did you buy?'),
        'Engineering Calculator');
    await tester.enterText(
        find.widgetWithText(TextField, '0.000 DT'), '68.500');
    await tester.pumpAndSettle();

    // Ensure save button is visible and tap Save
    await tester.ensureVisible(find.text('Save Receipt & Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Receipt & Expense'));
    await tester.pumpAndSettle();

    // Verify added expense has real data and attached receipt
    expect(budget.transactions.length, 1);
    expect(budget.transactions.first.title, 'Engineering Calculator');
    expect(budget.transactions.first.amount, 68.500);
    expect(budget.transactions.first.hasReceipt, true);
    expect(budget.transactions.first.imagePath,
        '/mock/receipts/physics_textbook.jpg');
  });

  testWidgets(
      'ExpensesView displays receipt indicator badge for attached receipts and opens viewer',
      (WidgetTester tester) async {
    final budget = BudgetController();
    budget.addExpense(
      title: 'Lab Notebook & Pen',
      amount: 14.200,
      category: 'Books & Tools',
      imagePath: '/mock/receipts/lab_notebook.jpg',
    );

    await tester.pumpWidget(
      _wrapWithProviders(const ExpensesView(), budget: budget),
    );
    await tester.pumpAndSettle();

    // Verify expense and receipt badge exist
    expect(find.text('Lab Notebook & Pen'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_rounded), findsWidgets);

    // Ensure visible and tap receipt badge to open ReceiptViewerDialog
    await tester.ensureVisible(find.text('Receipt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receipt'));
    await tester.pumpAndSettle();

    expect(find.byType(ReceiptViewerDialog), findsOneWidget);
    expect(find.text('Original student camera photo verified'), findsOneWidget);

    // Dismiss receipt viewer
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Tap transaction row to open Edit Transaction bottom sheet
    await tester.tap(find.text('Lab Notebook & Pen'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaction'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Delete Transaction'), findsOneWidget);
  });
}

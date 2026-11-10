import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/budget_view.dart';
import 'package:studenthold_app/ui/views/tasks_view.dart';

Widget _wrapWithData(
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

  group('Populated data overflow tests on 320x568 with 1.5x and 2.0x scale',
      () {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
          'HomeView with full data has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        final tasks = TasksController();
        tasks.addTask(
          title: 'Advanced Computer Networks Lab Report Submission',
          category: 'Academic',
          dueDate: 'Due Friday at 11:59 PM',
        );
        tasks.addTask(
          title: 'Apartment grocery run for fresh vegetables and milk',
          category: 'Personal/Chore',
          dueDate: 'Saturday morning',
        );

        final budget = BudgetController();
        await budget.setBudgetCap(750.000, 150.000);
        budget.addExpense(
          title: 'Algorithms and Data Structures Textbook 4th Edition',
          amount: 85.500,
          category: 'Books & Study',
        );
        budget.addExpense(
          title: 'Monthly University Campus Cafeteria Pass',
          amount: 145.000,
          category: 'Food & Dining',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrapWithData(
              const HomeDashboard(
                userName: 'Mohamed Khalil Trabelsi',
                university:
                    'National Institute of Applied Science and Technology',
              ),
              tasks: tasks,
              budget: budget,
            ),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });

      testWidgets(
          'BudgetView with full data has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        final budget = BudgetController();
        await budget.setBudgetCap(850.000, 120.000);
        budget.addExpense(
          title: 'Campus Bookstore Course Material & Notebooks Pack',
          amount: 125.750,
          category: 'Books & Study',
        );
        budget.addExpense(
          title: 'Weekly Organic Grocery Market Shopping Trip',
          amount: 88.250,
          category: 'Food & Dining',
        );
        budget.addExpense(
          title: 'Monthly Studio Electricity & Heating Utility',
          amount: 65.000,
          category: 'Housing',
        );
        budget.addExpense(
          title: 'Espresso & Study Group Snacks at University Library Cafe',
          amount: 18.500,
          category: 'Leisure & Coffee',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrapWithData(const BudgetView(), budget: budget),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });

      testWidgets(
          'TasksView with full data has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        final tasks = TasksController();
        tasks.addTask(
          title: 'Distributed Systems Final Project Implementation Phase 2',
          category: 'Academic',
          dueDate: 'Due in 2 days at midnight',
        );
        tasks.addTask(
          title: 'Weekly room cleaning, laundry and grocery store trip',
          category: 'Personal/Chore',
          dueDate: 'Sunday evening',
        );

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrapWithData(const TasksView(), tasks: tasks),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });
    }
  });
}

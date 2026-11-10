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

Widget _wrap(
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

  group('Modal overflow tests on 320x568 at 1.5x and 2.0x font scaling', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets(
          'BudgetView Add Expense modal has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrap(const BudgetView()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add Expense').first);
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });

      testWidgets(
          'TasksView Add Task modal has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrap(const TasksView()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add Task').first);
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });

      testWidgets(
          'HomeView Add Expense modal has zero overflow at ${scale}x scale',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale)),
            child: _wrap(const HomeView()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Add Expense').first);
        await tester.tap(find.text('Add Expense').first);
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull, reason: errorDetails?.toString());
      });
    }
  });
}

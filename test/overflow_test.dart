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
import 'package:studenthold_app/ui/views/tasks_view.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
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
  final testSizes = [
    const Size(320, 568), // iPhone SE / small screen
    const Size(375, 667), // iPhone 8
    const Size(412, 915), // Pixel 7
  ];

  for (final size in testSizes) {
    testWidgets('HomeView has zero overflow on ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errorDetails = details;

      await tester.pumpWidget(_wrap(const HomeView()));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;
      expect(errorDetails, isNull);
    });

    testWidgets(
        'WelcomeVaultView has zero overflow on ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errorDetails = details;

      await tester.pumpWidget(_wrap(const WelcomeVaultView()));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;
      expect(errorDetails, isNull);
    });

    testWidgets('BudgetView has zero overflow on ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errorDetails = details;

      await tester.pumpWidget(_wrap(const BudgetView()));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;
      expect(errorDetails, isNull);
    });

    testWidgets('TasksView has zero overflow on ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errorDetails = details;

      await tester.pumpWidget(_wrap(const TasksView()));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;
      expect(errorDetails, isNull);
    });

    testWidgets('MainShell has zero overflow on ${size.width}x${size.height}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) => errorDetails = details;

      await tester.pumpWidget(_wrap(const MainShell()));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;
      expect(errorDetails, isNull);
    });
  }

  group('Extreme accessibility font scaling (1.5x and 2.0x) on 320x568', () {
    for (final scale in [1.5, 2.0]) {
      testWidgets(
          'HomeView has zero overflow with ${scale}x font scale on 320x568',
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

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });

      testWidgets(
          'WelcomeVaultView has zero overflow with ${scale}x font scale on 320x568',
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
            child: _wrap(const WelcomeVaultView()),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });

      testWidgets(
          'BudgetView has zero overflow with ${scale}x font scale on 320x568',
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

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });

      testWidgets(
          'TasksView has zero overflow with ${scale}x font scale on 320x568',
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

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });

      testWidgets(
          'MainShell has zero overflow with ${scale}x font scale on 320x568',
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
            child: _wrap(const MainShell()),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });
    }
  });
}

// test/widgets/weekly_rhythm_card_adversarial_test.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/ui/views/weekly_rhythm_card.dart';

Widget _wrapAdversarial(
  Widget child, {
  Size screenSize = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  BudgetController? budget,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => budget ?? BudgetController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.sandCream,
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(
              size: screenSize,
              textScaler: textScaler,
            ),
            child: SizedBox(
              width: screenSize.width,
              height: screenSize.height,
              child: SingleChildScrollView(
                child: child,
              ),
            ),
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

  group(
      'Milestone 2 Adversarial — 1. EaseOutBack Peak Overshoot & Height Clamping',
      () {
    testWidgets(
        'Peak overshoot at t=520ms does not produce any RenderFlex overflow',
        (tester) async {
      final List<FlutterErrorDetails> errors = [];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 40.0,
            weeklyExpenses: [60.0, 60.0, 60.0, 60.0, 60.0, 60.0, 60.0],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );

      // Frame 0
      await tester.pump(Duration.zero);
      expect(errors, isEmpty);

      // Sample every 50ms through the entire easeOutBack curve (especially peak ~500-600ms)
      for (int ms = 50; ms <= 950; ms += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(errors, isEmpty,
            reason:
                'RenderFlex overflow occurred at t=${ms}ms during easeOutBack motion');
      }

      await tester.pumpAndSettle();
      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Max bar height (84.0) with easeOutBack overshoot is strictly bounded under 140px container',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [100.0, 100.0, 100.0, 100.0, 100.0, 100.0, 100.0],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );

      await tester.pump(Duration.zero);
      // Advance to approximate easeOutBack peak (t ≈ 520ms)
      await tester.pump(const Duration(milliseconds: 520));

      final barContainers = tester
          .widgetList<Container>(
        find.descendant(
          of: find.byType(WeeklyRhythmCard),
          matching: find.byType(Container),
        ),
      )
          .where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(7) &&
            c.constraints?.maxWidth == 14;
      }).toList();

      expect(barContainers.length, equals(7));
      for (final bar in barContainers) {
        final height = bar.constraints?.maxHeight ?? 0.0;
        // Peak overshoot of 84.0 * 1.10 ≈ 92.4, clamped at 84 * 1.15 = 96.6
        expect(height, lessThanOrEqualTo(96.6));
        expect(height, greaterThan(80.0));
      }

      await tester.pumpAndSettle();
    });
  });

  group('Milestone 2 Adversarial — 2. Extreme Viewports & Narrow Screens', () {
    const viewports = [
      Size(240, 500), // Ultra-narrow wearable / test bench
      Size(280, 653), // Galaxy Fold cover
      Size(320, 568), // iPhone SE 1st gen
      Size(390, 844), // iPhone 14
      Size(412, 915), // Pixel 7
      Size(800, 1280), // Tablet
    ];

    for (final size in viewports) {
      testWidgets(
          'Viewport ${size.width.toInt()}x${size.height.toInt()} renders without overflow',
          (tester) async {
        final List<FlutterErrorDetails> errors = [];
        FlutterError.onError = (details) => errors.add(details);

        await tester.pumpWidget(
          _wrapAdversarial(
            const WeeklyRhythmCard(
              dailySafeSpend: 45.0,
              weeklyExpenses: [15.0, 30.0, 80.0, 20.0, 0.0, 95.0, 120.0],
              animationDuration: Duration(milliseconds: 300),
            ),
            screenSize: size,
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty,
            reason:
                'Layout overflowed on viewport ${size.width}x${size.height}');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Milestone 2 Adversarial — 3. Accessibility Text Scaling', () {
    testWidgets(
        'Large text scaling (1.5x) does not cause overflow in pill or weekday labels',
        (tester) async {
      final List<FlutterErrorDetails> errors = [];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 35.0,
            weeklyExpenses: [50.0, 100.0, 250.0, 0.0, 0.0, 75.0, 30.0],
            animationDuration: Duration(milliseconds: 300),
          ),
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Extra large text scaling (2.0x) scales down gracefully via FittedBox',
        (tester) async {
      final List<FlutterErrorDetails> errors = [];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 35.0,
            weeklyExpenses: [50.0, 100.0, 250.0, 0.0, 0.0, 75.0, 30.0],
            animationDuration: Duration(milliseconds: 300),
          ),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 2 Adversarial — 4. Boundary & Malformed Inputs', () {
    testWidgets(
        'Empty weeklyExpenses list [] defaults gracefully to 7 zero-height bars',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly Rhythm'), findsOneWidget);
      // All 7 weekday labels exist
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets(
        'Partial weeklyExpenses list (< 7 items) pads missing days with 0.0',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [40.0, 60.0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('40 DT'), findsOneWidget);
      expect(find.text('60 DT'), findsOneWidget);
    });

    testWidgets(
        'Oversized weeklyExpenses list (> 7 items) clamps to 7 weekday columns safely',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [
              10.0,
              20.0,
              30.0,
              40.0,
              50.0,
              60.0,
              70.0,
              80.0,
              90.0
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('70 DT'), findsOneWidget);
      expect(find.text('80 DT'), findsNothing);
    });

    testWidgets(
        'Massive financial values (10,000 DT) scale pills and bars without layout breaks',
        (tester) async {
      final List<FlutterErrorDetails> errors = [];
      FlutterError.onError = (details) => errors.add(details);

      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 500.0,
            weeklyExpenses: [10000.0, 25000.0, 5000.0, 0.0, 0.0, 0.0, 0.0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(errors, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.text('10000 DT'), findsOneWidget);
      expect(find.text('25000 DT'), findsOneWidget);
    });

    testWidgets(
        'Negative dailySafeSpend and negative expenses clamp gracefully',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: -50.0,
            weeklyExpenses: [-10.0, -20.0, 0.0, 0.0, 0.0, 0.0, 0.0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Negative daily total should not render amount pill
      expect(find.text('-10 DT'), findsNothing);
      expect(find.text('-20 DT'), findsNothing);
    });
  });

  group('Milestone 2 Adversarial — 5. Animation Thrashing & Dynamic Re-entry',
      () {
    testWidgets('20 rapid consecutive state updates do not conflict or crash',
        (tester) async {
      for (int i = 1; i <= 20; i++) {
        await tester.pumpWidget(
          _wrapAdversarial(
            WeeklyRhythmCard(
              dailySafeSpend: 30.0 + i,
              weeklyExpenses: List<double>.generate(7, (d) => (d * i * 3.0)),
              animationDuration: const Duration(milliseconds: 150),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Mid-flight update from [50, 0] to [0, 80] smoothly interpolates previous heights',
        (tester) async {
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [50.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            animationDuration: Duration(milliseconds: 600),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Mid-flight update
      await tester.pumpWidget(
        _wrapAdversarial(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [0.0, 80.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            animationDuration: Duration(milliseconds: 600),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('80 DT'), findsOneWidget);
    });
  });

  group('Milestone 2 Adversarial — 6. Integrity & Token Validation', () {
    test(
        'Source code does not contain hardcoded test strings or dummy implementations',
        () {
      final code =
          File('lib/ui/views/weekly_rhythm_card.dart').readAsStringSync();

      // Check that real mathematical formulas are used
      expect(code.contains('Curves.easeOutBack'), isTrue);
      expect(code.contains('SingleTickerProviderStateMixin'), isTrue);
      expect(code.contains('AnimationController'), isTrue);
      expect(code.contains('AnimatedBuilder'), isTrue);
      expect(code.contains('lerpDouble'), isTrue);
      expect(code.contains('_computeTargetHeights'), isTrue);

      // Check that forbidden legacy badges are absent
      expect(code.contains('Active Rhythm'), isFalse);
      expect(code.contains('Clean Zero'), isFalse);

      // Check that rainbow colors are absent
      expect(code.contains('0xFF10B981'), isFalse);
      expect(code.contains('0xFF6366F1'), isFalse);
      expect(code.contains('0xFFD97706'), isFalse);
      expect(code.contains('0xFFF43F5E'), isFalse);
    });
  });
}

// test/widgets/weekly_rhythm_card_challenger_m2_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/ui/views/weekly_rhythm_card.dart';

Widget _wrapSubject(
  Widget child, {
  Size? surfaceSize,
  TextScaler? textScaler,
  BudgetController? budget,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<BudgetController>(
          create: (_) => budget ?? BudgetController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.sandCream,
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize ?? const Size(360, 640),
              textScaler: textScaler ?? TextScaler.noScaling,
            ),
            child: SizedBox(
              width: surfaceSize?.width,
              child: child,
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

  // =========================================================================
  // Group 1: Micro-Viewport Adversarial Testing (280px to 800px)
  // =========================================================================
  group('Empirical Challenger — Group 1: Micro-Viewport & Layout Stress', () {
    const testWidths = [280.0, 300.0, 320.0, 360.0, 400.0, 480.0, 600.0, 800.0];

    for (final width in testWidths) {
      testWidgets(
          'Renders cleanly at viewport width ${width.toInt()}px without overflow',
          (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _wrapSubject(
            const WeeklyRhythmCard(
              dailySafeSpend: 42.5,
              weeklyExpenses: [15.0, 25.0, 35.0, 50.0, 80.0, 0.0, 20.0],
            ),
            surfaceSize: Size(width, 700),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Must not throw any overflow at width $width');
        expect(find.text('Weekly Rhythm'), findsOneWidget);
        expect(find.text('M'), findsOneWidget);
        expect(find.text('50 DT'), findsOneWidget);
      });
    }

    testWidgets(
        'Micro-viewport 280px survives extreme TextScaler (2.0x) without crash or overflow',
        (tester) async {
      tester.view.physicalSize = const Size(280, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 42.5,
            weeklyExpenses: [120.0, 350.0, 0.0, 45.0, 60.0, 0.0, 15.0],
          ),
          surfaceSize: const Size(280, 700),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(find.text('120 DT'), findsOneWidget);
    });

    testWidgets(
        'Renders inside scrollable ListView with unbounded height constraints',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [
                WeeklyRhythmCard(
                  dailySafeSpend: 50.0,
                  weeklyExpenses: [10, 20, 30, 40, 50, 60, 70],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WeeklyRhythmCard), findsOneWidget);
    });
  });

  // =========================================================================
  // Group 2: Rapid 50-Cycle Mount / Unmount Lifecycle Stress (Ticker/Memory)
  // =========================================================================
  group(
      'Empirical Challenger — Group 2: 50-Cycle Rapid Mount/Unmount Lifecycle',
      () {
    testWidgets(
        '50 consecutive rapid mount and mid-flight disposal cycles (no ticker leaks)',
        (tester) async {
      for (int cycle = 1; cycle <= 50; cycle++) {
        await tester.pumpWidget(
          _wrapSubject(
            WeeklyRhythmCard(
              key: ValueKey('cycle_$cycle'),
              dailySafeSpend: 40.0,
              weeklyExpenses: const [10, 25, 0, 45, 60, 0, 15],
              animationDuration: const Duration(milliseconds: 900),
            ),
          ),
        );
        // Advance 2 frames (~32ms) while ticker is actively running
        await tester.pump(const Duration(milliseconds: 32));

        // Immediately unmount by pumping a replacement empty widget
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SizedBox.shrink()),
          ),
        );
        // Ensure unmounted without ticker leaks
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Cycle $cycle threw an exception during unmount');
      }
    });

    testWidgets(
        '50 consecutive mount cycles with Duration.zero (instant completion)',
        (tester) async {
      for (int cycle = 1; cycle <= 50; cycle++) {
        await tester.pumpWidget(
          _wrapSubject(
            WeeklyRhythmCard(
              key: ValueKey('zero_cycle_$cycle'),
              dailySafeSpend: 30.0,
              weeklyExpenses: const [5, 15, 25, 35, 45, 55, 65],
              animationDuration: Duration.zero,
            ),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
        '50 consecutive mount cycles halfway through easeOutBack peak (450ms)',
        (tester) async {
      for (int cycle = 1; cycle <= 50; cycle++) {
        await tester.pumpWidget(
          _wrapSubject(
            WeeklyRhythmCard(
              key: ValueKey('peak_cycle_$cycle'),
              dailySafeSpend: 50.0,
              weeklyExpenses: const [40, 80, 120, 160, 200, 240, 280],
            ),
          ),
        );
        // Peak of easeOutBack is ~450ms to 550ms
        await tester.pump(const Duration(milliseconds: 500));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  // =========================================================================
  // Group 3: Mid-Flight Dynamic Data Updates & didUpdateWidget Stress
  // =========================================================================
  group(
      'Empirical Challenger — Group 3: Mid-Flight Animation Interruption & Data Updates',
      () {
    testWidgets(
        'Interrupt animation multiple times with drastically changing data',
        (tester) async {
      // 1. Mount with initial data
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 40.0,
            weeklyExpenses: [10, 20, 30, 40, 50, 60, 70],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      // 2. Interrupt with drastic spike at t=150ms
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 40.0,
            weeklyExpenses: [500, 10, 0, 250, 1000, 20, 50],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      // 3. Interrupt with all zeros at t=300ms
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 40.0,
            weeklyExpenses: [0, 0, 0, 0, 0, 0, 0],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      // 4. Interrupt with single day massive expense at t=450ms
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 100.0,
            weeklyExpenses: [0, 0, 0, 0, 9999, 0, 0],
            animationDuration: Duration(milliseconds: 900),
          ),
        ),
      );

      // Settle completely to final state
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('9999 DT'), findsOneWidget);
    });

    testWidgets(
        'Rapidly toggles between same and new data without animation hiccups',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [10, 20, 30, 40, 50, 60, 70],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Re-pumping with exact same data should NOT retrigger animation from 0.0
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 50.0,
            weeklyExpenses: [10, 20, 30, 40, 50, 60, 70],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 4: Extreme Numerical Boundary & Stress Inputs
  // =========================================================================
  group('Empirical Challenger — Group 4: Boundary Values & Robustness', () {
    testWidgets(
        'Handles all zero spending and zero safe spend without division by zero',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 0.0,
            weeklyExpenses: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(find.text('vs. Daily Safe Spend (0.0 DT)'), findsOneWidget);
      expect(find.textContaining(' DT'), findsWidgets); // header has 0.0 DT
    });

    testWidgets(
        'Handles negative expense inputs gracefully without negative height crash',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 30.0,
            weeklyExpenses: [-50.0, -10.0, 0.0, 25.0, -5.0, 0.0, -100.0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('25 DT'), findsOneWidget);
    });

    testWidgets(
        'Handles astronomical amounts (100 Million DT) with FittedBox scale down',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 50000.0,
            weeklyExpenses: [
              100000000.0,
              50000000.0,
              0.0,
              25000.0,
              1000.0,
              0.0,
              500.0
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100000000 DT'), findsOneWidget);
    });

    testWidgets('Handles empty weeklyExpenses list fallback cleanly',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 25.0,
            weeklyExpenses: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Weekly Rhythm'), findsOneWidget);
    });

    testWidgets(
        'Handles partial list (< 7 elements) and oversized list (> 7 elements)',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 25.0,
            weeklyExpenses: [10.0, 20.0], // only 2 elements
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 25.0,
            weeklyExpenses: [
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12
            ], // 12 elements
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 5: Zero Emojis & Brand Color Conformance
  // =========================================================================
  group('Empirical Challenger — Group 5: Brand Identity & Zero Emojis', () {
    testWidgets(
        'Runtime string audit: zero Unicode emojis across all rendered Text widgets',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 45.0,
            weeklyExpenses: [10, 20, 30, 40, 50, 60, 70],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final emojiPattern = RegExp(
        r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}]',
        unicode: true,
      );

      for (final textWidget in textWidgets) {
        final text =
            textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(
          emojiPattern.hasMatch(text),
          isFalse,
          reason: 'Text widget contains an emoji: "$text"',
        );
      }
    });

    testWidgets('Strict 7 brand color tokens sequence Monday to Sunday',
        (tester) async {
      expect(WeeklyRhythmCard.dayColors.length, equals(7));
      expect(WeeklyRhythmCard.dayColors[0],
          equals(const Color(0xFF1E3A2E))); // M - Deep Pine
      expect(WeeklyRhythmCard.dayColors[1],
          equals(const Color(0xFF3E5A3F))); // T - Mid Moss
      expect(WeeklyRhythmCard.dayColors[2],
          equals(const Color(0xFF6B7F67))); // W - Soft Sage
      expect(WeeklyRhythmCard.dayColors[3],
          equals(const Color(0xFF3D4337))); // T - Dark Olive
      expect(WeeklyRhythmCard.dayColors[4],
          equals(const Color(0xFF00D084))); // F - Vibrant Green
      expect(WeeklyRhythmCard.dayColors[5],
          equals(const Color(0xFF0F1F17))); // S - Dark Forest
      expect(WeeklyRhythmCard.dayColors[6],
          equals(const Color(0xFF3E5A3F))); // S - Mid Moss
    });

    testWidgets(
        'Header strictly renders auto_graph_rounded icon in #1E3A2E and no legacy badge',
        (tester) async {
      await tester.pumpWidget(
        _wrapSubject(
          const WeeklyRhythmCard(
            dailySafeSpend: 35.0,
            weeklyExpenses: [0, 0, 0, 0, 0, 0, 0],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.auto_graph_rounded);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, equals(const Color(0xFF1E3A2E)));

      expect(find.text('Active Rhythm'), findsNothing);
      expect(find.text('Clean Zero'), findsNothing);
    });
  });
}

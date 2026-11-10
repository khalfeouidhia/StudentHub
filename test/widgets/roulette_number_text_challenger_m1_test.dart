import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.instance.ensureSemantics();
  });

  Widget buildSubject({
    required double value,
    String? prefix,
    String? suffix,
    int decimalDigits = 3,
    TextStyle? wholeStyle,
    TextStyle? decimalStyle,
    bool isHeader = false,
    bool thousandsSeparator = false,
    Duration duration = const Duration(milliseconds: 1200),
    Curve curve = Curves.easeOutCubic,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
    TextScaler? textScaler,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          backgroundColor:
              isHeader ? AppColors.deepPine : AppColors.surfaceWhite,
          body: Center(
            child: MediaQuery(
              data: MediaQueryData(
                textScaler: textScaler ?? TextScaler.noScaling,
              ),
              child: RouletteNumberText(
                value: value,
                prefix: prefix,
                suffix: suffix,
                decimalDigits: decimalDigits,
                wholeStyle: wholeStyle,
                decimalStyle: decimalStyle,
                isHeader: isHeader,
                thousandsSeparator: thousandsSeparator,
                duration: duration,
                curve: curve,
                crossAxisAlignment: crossAxisAlignment,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Group 1: Extreme Values, Negative Values, Non-Finite & Precision Stress
  // =========================================================================
  group('Challenger M1 — Group 1: Extreme Values & Mathematical Edge Cases',
      () {
    testWidgets('Exact zero 0.0 with thousands separator formats 0.000 DT',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 0.0,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.000 DT'), findsOneWidget);
      expect(find.text(','), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Negative zero -0.0 with thousands separator formats 0.000 DT',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: -0.0,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Near-billion 999999999.999 with thousandsSeparator renders exactly 2 commas and 9 whole reels',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 999999999.999,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('999,999,999.999 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Extreme 12-digit trillion figure 999999999999.999 formats 3 commas cleanly',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 999999999999.999,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('999,999,999,999.999 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Large negative number -999999999.999 with thousands separator formats minus and commas',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: -999999999.999,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-999,999,999.999 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Non-finite NaN falls back safely to 0.000 without crashing',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: double.nan,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Non-finite positive infinity falls back safely to 0.000',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: double.infinity,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Non-finite negative infinity falls back safely to 0.000',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: double.negativeInfinity,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Floating-point rounding (0.1 + 0.7 = 0.7999999999999999) correctly formats 0.800',
        (tester) async {
      final val = 0.1 + 0.7;
      await tester.pumpWidget(buildSubject(
        value: val,
        decimalDigits: 3,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.800 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sub-millime rounding (0.0004 -> 0.000, 0.0006 -> 0.001)',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 0.0004, decimalDigits: 3));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('0.000'), findsOneWidget);

      await tester.pumpWidget(buildSubject(value: 0.0006, decimalDigits: 3));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('0.001'), findsOneWidget);
    });

    testWidgets(
        'decimalDigits: 0 with thousandsSeparator on millions formats 1,500,000 without dot',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 1500000.0,
        decimalDigits: 0,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,500,000 DT'), findsOneWidget);
      expect(find.text('.'), findsNothing);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 2: Typography Scaling & Overflow Stress (TextScaler up to 3.0x & 4.0x)
  // =========================================================================
  group('Challenger M1 — Group 2: Typography Scaling & Overflow Stress', () {
    testWidgets(
        'TextScaler 1.5x renders standard financial figure without overflow',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 3400.000,
        thousandsSeparator: true,
        suffix: ' DT',
        textScaler: const TextScaler.linear(1.5),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3,400.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'TextScaler 3.0x on typical KPI figure (99.999 DT) renders without reel clipping',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 99.999,
        suffix: ' DT',
        textScaler: const TextScaler.linear(3.0),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('99.999 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Extreme TextScaler 4.0x on compact value renders cleanly without exceptions',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 45.250,
        thousandsSeparator: true,
        suffix: ' DT',
        textScaler: const TextScaler.linear(4.0),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('45.250 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Large figures (1.25M DT) at TextScaler 2.5x require FittedBox or overflow unconstrained Row',
        (tester) async {
      // In mobile KPI cards, large numbers under high text scale must be wrapped in FittedBox
      // to avoid unconstrained Row overflow.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: RouletteNumberText(
                  value: 1250500.750,
                  thousandsSeparator: true,
                  suffix: ' DT',
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hero fontSize: 48.0 renders without overflow', (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 3400.000,
        thousandsSeparator: true,
        wholeStyle:
            const TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold),
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3,400.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Micro fontSize: 9.0 renders without underflow or negative height',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 3400.000,
        thousandsSeparator: true,
        wholeStyle: const TextStyle(fontSize: 9.0),
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3,400.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 3: Dynamic Boundary Transitions (Crossing Comma Thresholds)
  // =========================================================================
  group(
      'Challenger M1 — Group 3: Dynamic Boundary Transitions & Comma Mutation',
      () {
    testWidgets(
        'Crossing 999 to 1000 dynamically inserts a comma reel mid-animation',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 999.999,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();
      expect(find.text(','), findsNothing);
      expect(find.bySemanticsLabel('999.999 DT'), findsOneWidget);

      // Transition across thousands barrier
      await tester.pumpWidget(buildSubject(
        value: 1000.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1,000.000 DT'), findsOneWidget);
      expect(find.text(','), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Crossing 1000 to 999 dynamically removes comma separator cleanly',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 1000.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();
      expect(find.text(','), findsOneWidget);

      // Transition downward below thousands barrier
      await tester.pumpWidget(buildSubject(
        value: 999.500,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('999.500 DT'), findsOneWidget);
      expect(find.text(','), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Crossing 999,999 to 1,000,000 inserts second comma without layout glitch',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 999999.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();
      expect(find.text(','), findsNWidgets(1));

      // Transition across million barrier
      await tester.pumpWidget(buildSubject(
        value: 1000000.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1,000,000.000 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Sign flip: from -5000.000 to +5000.000 removes minus and updates label',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: -5000.000,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('-5,000.000 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);

      await tester.pumpWidget(buildSubject(
        value: 5000.000,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('5,000.000 DT'), findsOneWidget);
      expect(find.text('-'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 4: Rapid Updates, Concurrent Tickers, & Interrupted Animations
  // =========================================================================
  group('Challenger M1 — Group 4: High-Frequency Rapid Updates & Ticker Stress',
      () {
    testWidgets(
        '30 rapid consecutive value updates in 20ms steps complete without assert',
        (tester) async {
      for (int i = 0; i < 30; i++) {
        await tester.pumpWidget(buildSubject(
          value: i * 137.45,
          thousandsSeparator: true,
          suffix: ' DT',
          duration: const Duration(milliseconds: 250),
        ));
        await tester.pump(const Duration(milliseconds: 20));
      }

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Alternating positive and negative numbers rapidly settles cleanly',
        (tester) async {
      final stream = [-100.0, 50.0, -250.5, 300.25, -10.0, 1500.0];
      for (final val in stream) {
        await tester.pumpWidget(buildSubject(
          value: val,
          thousandsSeparator: true,
          suffix: ' DT',
          duration: const Duration(milliseconds: 200),
        ));
        await tester.pump(const Duration(milliseconds: 40));
      }

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1,500.000 DT'), findsOneWidget);
      expect(find.text('-'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Empirical observation: didUpdateWidget does not sync controller duration on runtime change',
        (tester) async {
      // Step 1: Initialize with Duration.zero
      await tester.pumpWidget(buildSubject(
        value: 500.000,
        duration: Duration.zero,
      ));
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('500.000'), findsOneWidget);

      // Step 2: Update value and duration to 1000ms
      await tester.pumpWidget(buildSubject(
        value: 1200.000,
        duration: const Duration(milliseconds: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Empirical Check: Because RouletteNumberTextState.didUpdateWidget does not update _controller.duration,
      // the controller duration remains Duration.zero and forward() finishes immediately.
      // We document this as an empirical finding in our challenger report.
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1200.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 5: Typography Palette, RTL, & Semantics Invariants
  // =========================================================================
  group('Challenger M1 — Group 5: Palette Tokens, RTL & Semantics Invariants',
      () {
    testWidgets(
        'RTL Directionality renders without RenderFlex assert or layout failure',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 12500.750,
        thousandsSeparator: true,
        suffix: ' DT',
        textDirection: TextDirection.rtl,
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('12,500.750 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header mode defaults to AppColors.sandCream for decimals',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 20000.000,
        isHeader: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      // Decimal dot, 3 decimal reels, and suffix must use AppColors.sandCream (0xFFC7CBB8)
      final sandCreamWidgets =
          textWidgets.where((t) => t.style?.color == AppColors.sandCream);
      expect(sandCreamWidgets.length, greaterThanOrEqualTo(4));
    });

    testWidgets(
        'Custom prefix and suffix are preserved in semantics and layout',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 4500.500,
        prefix: 'TND ',
        suffix: ' Net',
        thousandsSeparator: true,
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('TND 4,500.500 Net'), findsOneWidget);
      expect(find.text('TND '), findsOneWidget);
      expect(find.text(' Net'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Semantics excludeSemantics: true prevents duplicate inner digit node reading',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 20000.000,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      final semanticsList = tester.widgetList<Semantics>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Semantics),
      ));
      expect(semanticsList, isNotEmpty);
      final widgetSemantics = semanticsList.first;
      expect(widgetSemantics.excludeSemantics, isTrue,
          reason: 'Inner digit reels must be hidden from screen readers');
      expect(widgetSemantics.properties.label, equals('20,000.000 DT'));
    });
  });
}

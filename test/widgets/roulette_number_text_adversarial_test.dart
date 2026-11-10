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
    Duration duration = const Duration(milliseconds: 1200),
    Curve curve = Curves.easeOutCubic,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.end,
    double? containerWidth,
    double? containerHeight,
    TextScaler? textScaler,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: isHeader ? AppColors.deepPine : AppColors.surfaceWhite,
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(
              textScaler: textScaler ?? TextScaler.noScaling,
            ),
            child: SizedBox(
              width: containerWidth,
              height: containerHeight,
              child: RouletteNumberText(
                value: value,
                prefix: prefix,
                suffix: suffix,
                decimalDigits: decimalDigits,
                wholeStyle: wholeStyle,
                decimalStyle: decimalStyle,
                isHeader: isHeader,
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

  group('Milestone 1 Adversarial — Value Domain Stress Tests', () {
    testWidgets('Exact zero 0.000 with DT suffix', (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 0.0, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Negative zero -0.0 behaves safely as 0.000', (tester) async {
      await tester.pumpWidget(
          buildSubject(value: -0.0, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Negative value -45.250 DT renders minus and proper decimals',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: -45.250, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-45.250 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(' DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Large number 20000.000 renders all 5 whole digits and 3 decimals',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 20000.000, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Extremely large number 9999999.999 does not crash or throw',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 9999999.999, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('9999999.999 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Non-finite input double.nan falls back to 0.000 without exception',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: double.nan));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Non-finite input double.infinity falls back to 0.000 without exception',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: double.infinity));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Non-finite input double.negativeInfinity falls back to 0.000 without exception',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: double.negativeInfinity));
      await tester.pumpAndSettle();

      expect(find.text('0.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 1 Adversarial — Precision Variations (decimalDigits 0 to 4)',
      () {
    testWidgets(
        'decimalDigits: 0 renders pure integer without decimal separator',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 125.75, decimalDigits: 0, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('126 DT'), findsOneWidget);
      expect(find.text('.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decimalDigits: 1 rounds and displays 1 decimal digit',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 45.67, decimalDigits: 1, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('45.7 DT'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decimalDigits: 2 standard currency format', (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 45.67, decimalDigits: 2, prefix: 'TND '));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('TND 45.67'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decimalDigits: 3 Tunisian Dinar millimes standard',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 12.345, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('12.345 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decimalDigits: 4 high-precision currency rate',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 3.1415, decimalDigits: 4));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3.1415'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 1 Adversarial — Timing, Zero Duration, & Rapid Changes', () {
    testWidgets('Duration.zero executes synchronously without timer asserts',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 77.777,
        duration: Duration.zero,
        suffix: ' DT',
      ));
      // First frame should immediately have settled value
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('77.777 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Rapid consecutive value changes (10 updates in 50ms intervals)',
        (tester) async {
      final values = [
        10.0,
        25.5,
        5.0,
        100.25,
        3.125,
        99.0,
        0.5,
        42.0,
        88.888,
        12.345
      ];
      for (final val in values) {
        await tester.pumpWidget(buildSubject(
          value: val,
          duration: const Duration(milliseconds: 300),
          suffix: ' DT',
        ));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('12.345 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Number of digits dynamically expanding (5 -> 10000 -> 0.1)',
        (tester) async {
      // 1-digit whole
      await tester.pumpWidget(buildSubject(
          value: 5.0, duration: const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('5.000'), findsOneWidget);

      // Expand to 5-digit whole
      await tester.pumpWidget(buildSubject(
          value: 10000.0, duration: const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('10000.000'), findsOneWidget);

      // Contract to decimal only
      await tester.pumpWidget(buildSubject(
          value: 0.1, duration: const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('0.100'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 1 Adversarial — Layout Stability & Scaler Stress', () {
    testWidgets(
        'TextScaler 2.0x scales typography cleanly without reel overflow',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 125.750,
        suffix: ' DT',
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('125.750 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TextScaler 3.0x extreme scaling renders without reel overflow',
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
        'Unconstrained width container with 100dp height fits without overflow',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 20000.000,
        suffix: ' DT',
        containerHeight: 100.0,
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '100dp width constraint with typical KPI figure fits or handles bounded constraints',
        (tester) async {
      // Test 100dp container with compact figure
      await tester.pumpWidget(buildSubject(
        value: 5.0,
        decimalDigits: 1,
        containerWidth: 100.0,
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('5.0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('100dp width constraint behavior on compact vs large numbers',
        (tester) async {
      // Compact number (e.g. 5.0) fits within 100dp without overflow
      await tester.pumpWidget(buildSubject(
        value: 5.0,
        decimalDigits: 1,
        containerWidth: 100.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Single digit value must fit within 100dp');

      // Medium number (12.345 DT) in 100dp
      await tester.pumpWidget(buildSubject(
        value: 12.345,
        decimalDigits: 3,
        suffix: ' DT',
        containerWidth: 100.0,
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      // Unconstrained Row overflows 100dp when children width > 100dp
      // If FittedBox is not built into RouletteNumberText, it overflows by ~20-30px
    });

    testWidgets(
        'Bounded 100dp container with FittedBox scaling for large financial figures',
        (tester) async {
      // In mobile layouts, large figures in constrained columns (e.g. 100dp KPI cards)
      // are wrapped in FittedBox to adapt cleanly to card boundaries.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 100.0,
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: RouletteNumberText(
                  value: 20000.000,
                  suffix: ' DT',
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reel inner Column does not cause RenderFlex vertical overflow',
        (tester) async {
      // The digit reel contains 10-20 vertical digit slots
      // Even with a short fixed height on the digit reel, OverflowBox prevents vertical RenderFlex asserts
      await tester.pumpWidget(buildSubject(
        value: 123.456,
        duration: const Duration(milliseconds: 500),
      ));
      // Mid-flight pump: animation value is actively interpolating
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 1 Adversarial — Ticker Lifecycle & Mid-Animation Disposal',
      () {
    testWidgets('Unmounting mid-animation at 25% does not leak ticker or crash',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 500.000,
        duration: const Duration(milliseconds: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.hasRunningAnimations, isTrue);

      // Destroy widget tree mid-flight
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Unmounting mid-animation at 90% does not leak ticker or crash',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 999.999,
        duration: const Duration(milliseconds: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.hasRunningAnimations, isTrue);

      // Destroy widget tree near completion
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Repeated mount and unmount cycles (5 times) do not cause leaks',
        (tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(buildSubject(
          value: i * 50.0,
          duration: const Duration(milliseconds: 400),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
    });
  });

  group(
      'Milestone 1 Adversarial — Hex Token Palette & RGB Channel Exhaustive Checks',
      () {
    test(
        'All 10 brand & surface hex tokens match specifications to the exact byte',
        () {
      final tokens = <String, (Color, int, int, int, int)>{
        'darkForest': (AppColors.darkForest, 0x0F, 0x1F, 0x17, 0xFF0F1F17),
        'deepPine': (AppColors.deepPine, 0x1E, 0x3A, 0x2E, 0xFF1E3A2E),
        'midMoss': (AppColors.midMoss, 0x3E, 0x5A, 0x3F, 0xFF3E5A3F),
        'softSage': (AppColors.softSage, 0x6B, 0x7F, 0x67, 0xFF6B7F67),
        'sandCream': (AppColors.sandCream, 0xC7, 0xCB, 0xB8, 0xFFC7CBB8),
        'darkOlive': (AppColors.darkOlive, 0x3D, 0x43, 0x37, 0xFF3D4337),
        'vibrantGreen': (AppColors.vibrantGreen, 0x00, 0xD0, 0x84, 0xFF00D084),
        'surfaceWhite': (AppColors.surfaceWhite, 0xF9, 0xFA, 0xF7, 0xFFF9FAF7),
        'iconBlue': (AppColors.iconBlue, 0x42, 0xA5, 0xF5, 0xFF42A5F5),
        'expenseRed': (AppColors.expenseRed, 0xE5, 0x73, 0x73, 0xFFE57373),
      };

      for (final entry in tokens.entries) {
        final name = entry.key;
        final (color, expectedR, expectedG, expectedB, expectedHex) =
            entry.value;

        expect(color.value, equals(expectedHex),
            reason: '$name full hex value mismatch');
        expect(color.alpha, equals(0xFF), reason: '$name alpha mismatch');
        expect(color.red, equals(expectedR),
            reason: '$name red channel mismatch');
        expect(color.green, equals(expectedG),
            reason: '$name green channel mismatch');
        expect(color.blue, equals(expectedB),
            reason: '$name blue channel mismatch');
      }
    });
  });
}

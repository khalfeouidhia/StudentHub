import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    bool wrapFittedBox = true,
  }) {
    final rouletteWidget = RouletteNumberText(
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
    );

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
              child: wrapFittedBox
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: rouletteWidget,
                    )
                  : rouletteWidget,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Group 1: 100-Iteration Mid-Animation Removal & Ticker Leak Stress Test
  // =========================================================================
  group(
      'Challenger 2 — Group 1: 100-Iteration Mid-Animation Removal & Ticker Leak Stress',
      () {
    testWidgets(
        '100 mid-animation removals across varied percentages and values leak zero tickers',
        (tester) async {
      // Test 100 distinct mount-interruption-unmount cycles
      for (int i = 0; i < 100; i++) {
        // Vary values and durations deterministically
        final testValue = (i * 12505.007) % 1250500.750 + 1.0;
        final totalDurationMs = 200 + (i * 17) % 800; // 200ms to 1000ms
        // Interrupt between 5% and 95% of duration
        final interruptRatio = 0.05 + ((i * 31) % 90) / 100.0;
        final interruptMs = (totalDurationMs * interruptRatio)
            .round()
            .clamp(10, totalDurationMs - 10);

        // Mount widget
        await tester.pumpWidget(
          buildSubject(
            value: testValue,
            thousandsSeparator: true,
            suffix: ' DT',
            duration: Duration(milliseconds: totalDurationMs),
          ),
        );

        // Advance to mid-animation point
        await tester.pump(Duration(milliseconds: interruptMs));
        expect(
          tester.hasRunningAnimations,
          isTrue,
          reason:
              'Animation must be actively running at iteration $i before unmount',
        );

        // Unmount widget mid-flight by replacing tree with empty SizedBox
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        );

        // Pump frame to process disposal and verify ticker cancelled
        await tester.pump(const Duration(milliseconds: 50));

        // Verify zero uncaught exceptions and no running animations
        expect(tester.takeException(), isNull,
            reason: 'Disposal at iteration $i must not throw');
        expect(
          tester.hasRunningAnimations,
          isFalse,
          reason:
              'Tickers must be completely cancelled after disposal at iteration $i',
        );
      }
    });

    testWidgets(
        '100 mid-flight didUpdateWidget value change unmounts dispose cleanly',
        (tester) async {
      for (int i = 0; i < 100; i++) {
        // Initial mount and settle
        await tester.pumpWidget(
          buildSubject(
            value: 100.0,
            thousandsSeparator: true,
            suffix: ' DT',
            duration: const Duration(milliseconds: 300),
          ),
        );
        await tester.pumpAndSettle();

        // Update value to trigger didUpdateWidget reel animation
        final updatedValue = 1000.0 + (i * 12500.0);
        await tester.pumpWidget(
          buildSubject(
            value: updatedValue,
            thousandsSeparator: true,
            suffix: ' DT',
            duration: const Duration(milliseconds: 400),
          ),
        );

        // Advance mid-roll (100ms into 400ms)
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.hasRunningAnimations, isTrue);

        // Unmount mid-roll
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        expect(tester.hasRunningAnimations, isFalse);
      }
    });

    testWidgets(
        '50 immediate frame-0 unmounts without pump execute without ticker leaks',
        (tester) async {
      for (int i = 0; i < 50; i++) {
        // Mount widget
        await tester.pumpWidget(
          buildSubject(
            value: 50000.000,
            thousandsSeparator: true,
            suffix: ' DT',
            duration: const Duration(milliseconds: 1000),
          ),
        );
        // Immediate unmount without any time advancement
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
        expect(tester.hasRunningAnimations, isFalse);
      }
    });

    testWidgets(
        'Rapid key recycling (50 iterations) creates and disposes controllers cleanly',
        (tester) async {
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RouletteNumberText(
                key: ValueKey('roulette_$i'),
                value: 1250500.750,
                thousandsSeparator: true,
                suffix: ' DT',
                duration: const Duration(milliseconds: 500),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 75));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 2: Micro-Viewport (320x568 & 280x653) Layout & RenderFlex Overflow Tests
  // =========================================================================
  group(
      'Challenger 2 — Group 2: Micro-Viewport Layout Assertions & RenderFlex Overflows',
      () {
    testWidgets(
        'Micro-viewport 320x568 renders comma-formatted 1,250,500.750 DT with FittedBox without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
          isHeader: true,
          wrapFittedBox: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull,
          reason: 'Zero layout assertions or RenderFlex overflows on 320x568');
    });

    testWidgets(
        'Micro-viewport 280x653 (Galaxy Fold cover) renders 1,250,500.750 DT with FittedBox without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
          isHeader: true,
          wrapFittedBox: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull,
          reason: 'Zero layout assertions or RenderFlex overflows on 280x653');
    });

    testWidgets(
        'Micro-viewport 320x568 with standard body size (fontSize: 16) renders unconstrained without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 14 characters at 16px font fits comfortably in 320px screen even without FittedBox
      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
          wholeStyle: const TextStyle(fontSize: 16.0),
          wrapFittedBox: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Micro-viewport 320x568: 2-column KPI card layout with 1,250,500.750 DT has zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Matches HomeView KPI card layout structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.deepPine,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkForest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL BALANCE',
                              style: TextStyle(
                                  color: AppColors.softSage, fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RouletteNumberText(
                                value: 1250500.750,
                                thousandsSeparator: true,
                                suffix: ' DT',
                                isHeader: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.darkForest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL EXPENSE',
                              style: TextStyle(
                                  color: AppColors.softSage, fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RouletteNumberText(
                                value: 1250500.750,
                                thousandsSeparator: true,
                                suffix: ' DT',
                                isHeader: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsNWidgets(2));
      expect(find.text(','), findsNWidgets(4)); // 2 commas per card = 4 total
      expect(tester.takeException(), isNull,
          reason: 'Zero RenderFlex overflow in 2-column KPI on 320x568');
    });

    testWidgets(
        'Micro-viewport 280x653: 2-column KPI card layout with 1,250,500.750 DT has zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Ultra-narrow 280px Samsung Galaxy Fold cover screen
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.deepPine,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkForest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL BALANCE',
                              style: TextStyle(
                                  color: AppColors.softSage, fontSize: 9),
                            ),
                            const SizedBox(height: 4),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RouletteNumberText(
                                value: 1250500.750,
                                thousandsSeparator: true,
                                suffix: ' DT',
                                isHeader: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.darkForest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL EXPENSE',
                              style: TextStyle(
                                  color: AppColors.softSage, fontSize: 9),
                            ),
                            const SizedBox(height: 4),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RouletteNumberText(
                                value: 1250500.750,
                                thousandsSeparator: true,
                                suffix: ' DT',
                                isHeader: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsNWidgets(2));
      expect(find.text(','), findsNWidgets(4));
      expect(tester.takeException(), isNull,
          reason:
              'Zero RenderFlex overflow in 280x653 ultra-narrow 2-column KPI');
    });

    testWidgets(
        'Micro-viewport 280x653 with TextScaler 1.5x in KPI card scales cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.5),
                ),
                child: SizedBox(
                  width: 120,
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RouletteNumberText(
                      value: 1250500.750,
                      thousandsSeparator: true,
                      suffix: ' DT',
                      isHeader: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Empirical boundary: unconstrained 22px header Row overflows unscaled viewports < 339px',
        (tester) async {
      // Documenting exact mathematical boundary where unconstrained Row exceeds viewport width:
      // 14 glyphs * ~22px = 338.8px. When unconstrained, 280px viewport triggers a RenderFlex overflow,
      // confirming why production screens (HomeView, ExpensesView) use FittedBox(fit: BoxFit.scaleDown).
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
          isHeader: true,
          wrapFittedBox: false,
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isA<FlutterError>());
      expect(
        (exception as FlutterError).toString(),
        contains('A RenderFlex overflowed by'),
        reason:
            'Unconstrained Row without FittedBox is mathematically expected to overflow 280px',
      );
    });
  });

  // =========================================================================
  // Group 3: Large Numbers & Comma Formatting Structural Invariants
  // =========================================================================
  group(
      'Challenger 2 — Group 3: Large Number Comma Structuring & Digit Reel Geometry',
      () {
    testWidgets(
        '1,250,500.750 DT renders exact digit sequence, commas, dot, and suffix',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
        ),
      );
      await tester.pumpAndSettle();

      // Semantics
      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);

      // Comma counts
      final commas = tester.widgetList<Text>(find.text(','));
      expect(commas.length, equals(2),
          reason: 'Exactly 2 commas must be present for 1,250,500.750');

      // Decimal dot
      expect(find.text('.'), findsOneWidget);

      // Suffix
      expect(find.text(' DT'), findsOneWidget);

      // Verify comma height matches whole digit height
      final commaSizedBoxes = tester.widgetList<SizedBox>(find.ancestor(
        of: find.text(','),
        matching: find.byType(SizedBox),
      ));
      expect(commaSizedBoxes, isNotEmpty);
      for (final box in commaSizedBoxes) {
        expect(box.height, greaterThanOrEqualTo(20.0),
            reason:
                'Comma container height must match whole digit reel height');
      }
    });

    testWidgets(
        'Comma formatting across all orders of magnitude (1 to 1,000,000,000)',
        (tester) async {
      final testCases = <(double, String, int)>{
        (1.0, '1.000 DT', 0),
        (10.0, '10.000 DT', 0),
        (100.0, '100.000 DT', 0),
        (1000.0, '1,000.000 DT', 1),
        (10000.0, '10,000.000 DT', 1),
        (100000.0, '100,000.000 DT', 1),
        (1000000.0, '1,000,000.000 DT', 2),
        (1250500.750, '1,250,500.750 DT', 2),
        (10000000.0, '10,000,000.000 DT', 2),
        (100000000.0, '100,000,000.000 DT', 2),
        (1000000000.0, '1,000,000,000.000 DT', 3),
      };

      for (final (val, expectedLabel, expectedCommas) in testCases) {
        await tester.pumpWidget(
          buildSubject(
            value: val,
            thousandsSeparator: true,
            suffix: ' DT',
            duration: Duration.zero,
          ),
        );
        await tester.pump(Duration.zero);

        expect(find.bySemanticsLabel(expectedLabel), findsOneWidget,
            reason: 'Failed label for $val');
        if (expectedCommas > 0) {
          expect(find.text(','), findsNWidgets(expectedCommas),
              reason: 'Failed comma count for $val');
        } else {
          expect(find.text(','), findsNothing,
              reason: 'Expected 0 commas for $val');
        }
      }
    });

    testWidgets(
        'Negative large number -1,250,500.750 DT formats minus sign before first digit',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: -1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-1,250,500.750 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Group 4: Asset Bundle Loading & Dual-Tone Palette Verification
  // =========================================================================
  group('Challenger 2 — Group 4: Asset Bundle & Dual-Tone Brand Tokens', () {
    test(
        'assets/images/header_avatar.png exists and is readable as a valid PNG image',
        () {
      final file = File('assets/images/header_avatar.png');
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(10000));
      // PNG header bytes
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50));
      expect(bytes[2], equals(0x4E));
      expect(bytes[3], equals(0x47));
    });

    testWidgets(
        'rootBundle loads assets/images/header_avatar.png without asset manifest error',
        (tester) async {
      final data = await rootBundle.load('assets/images/header_avatar.png');
      expect(data.lengthInBytes, greaterThan(0));
    });

    testWidgets(
        'Dual-tone header typography: whole numbers #F9FAF7 / white and decimals #C7CBB8 (sandCream)',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: 1250500.750,
          thousandsSeparator: true,
          suffix: ' DT',
          isHeader: true,
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      // Decimals must use AppColors.sandCream (0xFFC7CBB8)
      final decimalTexts =
          textWidgets.where((t) => t.style?.color == AppColors.sandCream);
      expect(
        decimalTexts.length,
        greaterThanOrEqualTo(4), // dot, 3 decimals, suffix
        reason:
            'Decimals, dot, and suffix must use #C7CBB8 (AppColors.sandCream) in header mode',
      );

      // Whole numbers must use AppColors.surfaceWhite or Colors.white with w700
      final wholeTexts = textWidgets.where((t) =>
          (t.style?.color == AppColors.surfaceWhite ||
              t.style?.color == Colors.white) &&
          t.style?.fontWeight == FontWeight.w700);
      expect(
        wholeTexts,
        isNotEmpty,
        reason:
            'Whole digits and commas must use bold surfaceWhite in header mode',
      );
    });
  });
}

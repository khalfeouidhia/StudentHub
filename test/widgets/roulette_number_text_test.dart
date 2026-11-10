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
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: isHeader ? AppColors.deepPine : AppColors.surfaceWhite,
        body: Center(
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
          ),
        ),
      ),
    );
  }

  group('Milestone 1 — RouletteNumberText Mount & Dual-Tone Rendering', () {
    testWidgets('renders whole and decimal parts in standard body mode',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 125.750, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('125.750 DT'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      expect(find.text(' DT'), findsOneWidget);

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      final wholeStyles =
          textWidgets.where((t) => t.style?.color == AppColors.darkForest);
      final decimalStyles =
          textWidgets.where((t) => t.style?.color == AppColors.softSage);

      expect(wholeStyles, isNotEmpty,
          reason: 'Whole digits must use darkForest');
      expect(decimalStyles, isNotEmpty, reason: 'Decimals must use softSage');
    });

    testWidgets('renders white whole digits in header mode (isHeader: true)',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 3400.000, isHeader: true, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3400.000 DT'), findsOneWidget);

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      final whiteStyles = textWidgets.where((t) =>
          t.style?.color == AppColors.surfaceWhite ||
          t.style?.color == Colors.white);
      final sageStyles = textWidgets.where((t) =>
          t.style?.color == AppColors.sandCream ||
          t.style?.color == AppColors.softSage);

      expect(whiteStyles, isNotEmpty,
          reason: 'Header whole digits must use surfaceWhite/white');
      expect(sageStyles, isNotEmpty,
          reason: 'Header decimal digits must use sandCream or softSage');
    });

    testWidgets('custom wholeStyle and decimalStyle override defaults',
        (tester) async {
      const customWhole = TextStyle(color: Colors.purple, fontSize: 30.0);
      const customDecimal = TextStyle(color: Colors.amber, fontSize: 18.0);

      await tester.pumpWidget(buildSubject(
        value: 88.888,
        wholeStyle: customWhole,
        decimalStyle: customDecimal,
      ));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      final purpleStyles =
          textWidgets.where((t) => t.style?.color == Colors.purple);
      final amberStyles =
          textWidgets.where((t) => t.style?.color == Colors.amber);

      expect(purpleStyles, isNotEmpty);
      expect(amberStyles, isNotEmpty);
    });
  });

  group('Milestone 1 — Decimal Dot Splitting & Precision Variations', () {
    testWidgets('decimalDigits: 0 omits decimal point and fractional reels',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 42.0, decimalDigits: 0, suffix: ' tasks'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('42 tasks'), findsOneWidget);
      expect(find.text('.'), findsNothing,
          reason: 'Dot must not render when decimalDigits is 0');
      expect(find.text(' tasks'), findsOneWidget);
    });

    testWidgets('decimalDigits: 2 formats currency to 2 decimal places',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 19.99, decimalDigits: 2, prefix: '\$'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('\$19.99'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
      expect(find.text('\$'), findsOneWidget);
    });

    testWidgets(
        'decimalDigits: 3 formats Tunisian Dinar millimes with 3 decimal places',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 12.345, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('12.345 DT'), findsOneWidget);
    });

    testWidgets('includes tabular figures font feature on all styles',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 100.500));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      for (final t in textWidgets) {
        if (t.style != null && t.style!.fontFeatures != null) {
          expect(
            t.style!.fontFeatures!.any((f) => f.feature == 'tnum'),
            isTrue,
            reason: 'All digits must use tabular figures to prevent jitter',
          );
        }
      }
    });
  });

  group('Milestone 1 — Roulette Animation Execution & Value Changes', () {
    testWidgets('animation runs on mount and settles completely',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 50.000,
        duration: const Duration(milliseconds: 600),
      ));

      // At start (0ms)
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isTrue);

      // Mid-flight (300ms)
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      // Settled (600ms+)
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('50.000'), findsOneWidget);
    });

    testWidgets('updating value triggers smooth roll to new target',
        (tester) async {
      await tester.pumpWidget(buildSubject(
          value: 10.000, duration: const Duration(milliseconds: 400)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('10.000'), findsOneWidget);

      // Update value
      await tester.pumpWidget(buildSubject(
          value: 85.250, duration: const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('85.250'), findsOneWidget);
    });

    testWidgets(
        'unmounting widget mid-animation disposes ticker safely without leaks',
        (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 99.999, duration: const Duration(seconds: 5)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      // Unmount immediately
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Ticker must dispose cleanly');
    });

    testWidgets('rapid value updates do not crash or throw exceptions',
        (tester) async {
      await tester.pumpWidget(buildSubject(
          value: 1.0, duration: const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(buildSubject(
          value: 2.0, duration: const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 30));

      await tester.pumpWidget(buildSubject(
          value: 3.0, duration: const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('3.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Milestone 1 — Edge Cases & Adversarial Inputs', () {
    testWidgets('exact zero renders 0.000 without crashing', (tester) async {
      await tester.pumpWidget(
          buildSubject(value: 0.0, decimalDigits: 3, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.000 DT'), findsOneWidget);
    });

    testWidgets('integer double input without decimals renders padded zeroes',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 500.0, decimalDigits: 3));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('500.000'), findsOneWidget);
    });

    testWidgets(
        'negative amount renders prefix minus sign and correct decimals',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: -45.250, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-45.250 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(' DT'), findsOneWidget);
    });

    testWidgets('large number renders correctly without clipping',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 20000.000, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'non-finite numbers (NaN, Infinity) fall back gracefully to 0.000',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: double.nan));
      await tester.pumpAndSettle();
      expect(find.text('0.000'), findsOneWidget);

      await tester.pumpWidget(buildSubject(value: double.infinity));
      await tester.pumpAndSettle();
      expect(find.text('0.000'), findsOneWidget);
    });

    testWidgets('binary floating-point drift (0.1 + 0.2) renders clean 0.300',
        (tester) async {
      final floatDrift = 0.1 + 0.2;
      await tester
          .pumpWidget(buildSubject(value: floatDrift, decimalDigits: 3));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.300'), findsOneWidget);
    });
  });
}

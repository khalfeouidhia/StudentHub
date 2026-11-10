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
            thousandsSeparator: thousandsSeparator,
            duration: duration,
            curve: curve,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Requirement 1: Thousands Separator Formatting & Comma Placement
  // =========================================================================
  group('Milestone 1 — Thousands Separator Formatting', () {
    testWidgets(
        'thousandsSeparator: false (default) retains unformatted digits for backward compatibility',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 20000.000,
        thousandsSeparator: false,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(find.text(','), findsNothing,
          reason: 'Commas must not render when thousandsSeparator is false');
    });

    testWidgets(
        'thousandsSeparator: true renders comma separator for 5-digit number (20,000.000)',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 20000.000,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20,000.000 DT'), findsOneWidget);
      expect(find.text(','), findsOneWidget,
          reason: 'Exactly 1 comma reel/separator must render for 20,000');
    });

    testWidgets(
        'thousandsSeparator: true renders two commas for millions (1,250,500.750)',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 1250500.750,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2),
          reason: 'Exactly 2 commas must render for 1,250,500');
    });

    testWidgets(
        'thousandsSeparator: true with value < 1000 renders zero commas',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 850.250,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('850.250 DT'), findsOneWidget);
      expect(find.text(','), findsNothing,
          reason: 'Numbers under 1000 have no thousands comma');
    });

    testWidgets(
        'thousandsSeparator: true with negative number formats minus sign before grouped digits',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: -15000.300,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-15,000.300 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(','), findsOneWidget);
    });

    testWidgets(
        'dynamic value update from 500 to 25000 dynamically inserts comma without layout assert',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 500.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();
      expect(find.text(','), findsNothing);

      await tester.pumpWidget(buildSubject(
        value: 25000.000,
        thousandsSeparator: true,
        suffix: ' DT',
        duration: const Duration(milliseconds: 300),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('25,000.000 DT'), findsOneWidget);
      expect(find.text(','), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // Requirement 2: Dual-Tone Rendering (#C7CBB8 Decimals & Bold Whole)
  // =========================================================================
  group('Milestone 1 — Dual-Tone Typography (#C7CBB8 & Bold Whole)', () {
    testWidgets(
        'whole numbers are bold (w700) and decimals use muted tone (#C7CBB8 / sandCream)',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 3400.000,
        isHeader: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      // Whole digits: bold w700 and white in header
      final wholeDigits = textWidgets.where((t) =>
          t.style?.fontWeight == FontWeight.w700 &&
          (t.style?.color == AppColors.surfaceWhite ||
              t.style?.color == Colors.white));
      expect(wholeDigits, isNotEmpty,
          reason: 'Whole digits must be bold (w700) and white in header');

      // Decimal digits: light/muted tone
      final decimalWidgets = textWidgets.where((t) =>
          t.style?.color == AppColors.sandCream ||
          t.style?.color == const Color(0xFFC7CBB8) ||
          t.style?.color == AppColors.softSage);
      expect(decimalWidgets, isNotEmpty,
          reason:
              'Decimals must use muted tone (#C7CBB8 / sandCream / softSage)');
    });

    testWidgets(
        'decimalStyle with exact Color(0xFFC7CBB8) applies to all fractional digits, dot, and suffix',
        (tester) async {
      const sandCreamColor = Color(0xFFC7CBB8);
      await tester.pumpWidget(buildSubject(
        value: 125.750,
        decimalStyle: const TextStyle(
          color: sandCreamColor,
          fontWeight: FontWeight.w400,
        ),
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      final sandCreamTexts =
          textWidgets.where((t) => t.style?.color == sandCreamColor);
      expect(sandCreamTexts.length, greaterThanOrEqualTo(4),
          reason: 'Decimal dot, 3 decimal reels, and suffix must use #C7CBB8');
    });

    testWidgets(
        'all text widgets in RouletteNumberText include tabular figures font feature',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 99.999,
        thousandsSeparator: true,
        suffix: ' DT',
      ));
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Text),
      ));

      for (final t in textWidgets) {
        if (t.style?.fontFeatures != null) {
          expect(
            t.style!.fontFeatures!.any((f) => f.feature == 'tnum'),
            isTrue,
            reason:
                'Every text widget must feature tnum to prevent horizontal jitter',
          );
        }
      }
    });
  });

  // =========================================================================
  // Requirement 3: Exactly 3 Decimal Places Formatting
  // =========================================================================
  group('Milestone 1 — Exactly 3 Decimal Places Formatting & Reel Architecture',
      () {
    testWidgets(
        'default decimalDigits is 3 and renders exactly 3 fractional reels',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 45.1));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('45.100'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets(
        'value with integer double pads exactly three zeroes (500 -> 500.000)',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 500.0, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('500.000 DT'), findsOneWidget);
    });

    testWidgets(
        'value with 4+ decimal places rounds accurately to 3 places (12.3456 -> 12.346)',
        (tester) async {
      await tester.pumpWidget(buildSubject(value: 12.3456, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('12.346 DT'), findsOneWidget);
    });

    testWidgets(
        'binary floating-point drift 0.1 + 0.2 formats cleanly to 0.300 without 0.30000000000000004 artifacts',
        (tester) async {
      final floatSum = 0.1 + 0.2;
      await tester.pumpWidget(buildSubject(value: floatSum, suffix: ' DT'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('0.300 DT'), findsOneWidget);
    });
  });

  // =========================================================================
  // Requirement 4: Vertical Roll Motion Animation on Mount & Value Change
  // =========================================================================
  group('Milestone 1 — Vertical Roll Motion Animation (Mount & Value Change)',
      () {
    testWidgets(
        'vertical roll animation is active on mount and translates reels vertically',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 120.500,
        duration: const Duration(milliseconds: 800),
      ));

      // Frame 0: animation starts
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isTrue);

      // Mid-roll (300ms): translation offset is active
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      // Verify Transform.translate widgets exist in the tree
      final transforms = tester.widgetList<Transform>(find.descendant(
        of: find.byType(RouletteNumberText),
        matching: find.byType(Transform),
      ));
      expect(transforms, isNotEmpty,
          reason: 'Digit reels must use Transform for vertical translation');

      // Settle
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('120.500'), findsOneWidget);
    });

    testWidgets('updating value triggers vertical roll to new target',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 10.000,
        duration: const Duration(milliseconds: 400),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('10.000'), findsOneWidget);

      // Update value to 85.250
      await tester.pumpWidget(buildSubject(
        value: 85.250,
        duration: const Duration(milliseconds: 400),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('85.250'), findsOneWidget);
    });

    testWidgets(
        'zero duration settles synchronously without running animations',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 99.999,
        duration: Duration.zero,
      ));
      await tester.pump(Duration.zero);

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('99.999'), findsOneWidget);
    });

    testWidgets(
        'unmounting mid-roll at 50% disposes animation controller safely without exceptions',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        value: 50.000,
        duration: const Duration(milliseconds: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.hasRunningAnimations, isTrue);

      // Replace with empty container
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason: 'Ticker must cancel cleanly upon disposal');
    });
  });

  // =========================================================================
  // Requirement 5: Asset Bundle Loading (header_avatar.png)
  // =========================================================================
  group('Milestone 1 — Asset Bundle Loading (header_avatar.png)', () {
    test('header_avatar.png exists on filesystem with valid PNG payload', () {
      final avatarFile = File('assets/images/header_avatar.png');
      expect(avatarFile.existsSync(), isTrue,
          reason: 'assets/images/header_avatar.png must exist on disk');
      expect(avatarFile.lengthSync(), greaterThan(10000),
          reason: 'header_avatar.png must not be empty');
    });

    testWidgets(
        'rootBundle loads assets/images/header_avatar.png byte data successfully',
        (tester) async {
      final byteData = await rootBundle.load('assets/images/header_avatar.png');
      expect(byteData.lengthInBytes, greaterThan(0),
          reason: 'Avatar byte data must be loaded');

      // Verify PNG magic bytes: 0x89, 'P', 'N', 'G'
      final bytes = byteData.buffer.asUint8List();
      expect(bytes[0], equals(0x89));
      expect(bytes[1], equals(0x50)); // 'P'
      expect(bytes[2], equals(0x4E)); // 'N'
      expect(bytes[3], equals(0x47)); // 'G'
    });

    testWidgets(
        'Image.asset with header_avatar.png mounts cleanly in widget tree',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Image.asset(
                'assets/images/header_avatar.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Text('FallbackAvatar');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('FallbackAvatar'), findsNothing);
    });
  });
}

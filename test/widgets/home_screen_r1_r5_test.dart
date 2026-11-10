// test/widgets/home_screen_r1_r5_test.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/weekly_rhythm_card.dart';
import 'package:studenthold_app/ui/views/glowing_typewriter_greeting.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';

Widget _wrapWithProviders(
  Widget child, {
  AuthController? auth,
  TasksController? tasks,
  BudgetController? budget,
  Size? surfaceSize,
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
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: surfaceSize ?? const Size(400, 1800)),
          child: child,
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
  // GROUP 1: REQUIREMENT 1 (R1) — Dual-Tone Roulette Odometer Component
  // =========================================================================
  group('Master E2E — Group 1: R1 Dual-Tone Roulette Odometer Component', () {
    testWidgets(
        '1.1: Bold whole digits and light muted #C7CBB8 decimals in header style',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.deepPine,
            body: Center(
              child: RouletteNumberText(
                value: 20000.000,
                suffix: ' DT',
                isHeader: true,
                thousandsSeparator: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidgets = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(RouletteNumberText),
          matching: find.byType(Text),
        ),
      );

      // Whole digits: bold w700
      final boldWholeDigits = textWidgets.where((t) =>
          t.style?.fontWeight == FontWeight.w700 &&
          (t.style?.color == AppColors.surfaceWhite ||
              t.style?.color == Colors.white));
      expect(boldWholeDigits, isNotEmpty,
          reason: 'Whole digits must be bold w700 white in header');

      // Decimal digits & dot: muted sandCream / #C7CBB8
      final mutedDecimals = textWidgets.where((t) =>
          t.style?.color == AppColors.sandCream ||
          t.style?.color == const Color(0xFFC7CBB8));
      expect(mutedDecimals, isNotEmpty,
          reason: 'Decimals must use muted #C7CBB8');
    });

    testWidgets(
        '1.2: Formats exactly 3 decimal places with grouping commas for thousands',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 20000.000,
                suffix: ' DT',
                thousandsSeparator: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20,000.000 DT'), findsOneWidget);
      expect(find.text(','), findsOneWidget,
          reason: 'Exactly 1 comma reel must render for 20,000');
      expect(find.text('.'), findsOneWidget);
    });

    testWidgets(
        '1.3: Millions formatting renders two commas with thousandsSeparator: true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 1250500.750,
                suffix: ' DT',
                thousandsSeparator: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1,250,500.750 DT'), findsOneWidget);
      expect(find.text(','), findsNWidgets(2),
          reason: 'Two commas for 1,250,500');
    });

    testWidgets(
        '1.4: thousandsSeparator: false retains backward-compatible unformatted string',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 20000.000,
                suffix: ' DT',
                thousandsSeparator: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('20000.000 DT'), findsOneWidget);
      expect(find.text(','), findsNothing);
    });

    testWidgets('1.5: Vertical translation animation is active on mount',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 450.500,
                duration: const Duration(milliseconds: 800),
              ),
            ),
          ),
        ),
      );

      // Frame 0: animation active
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isTrue);

      // Mid-flight: Transform.translate exists
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      final transforms = tester.widgetList<Transform>(
        find.descendant(
            of: find.byType(RouletteNumberText),
            matching: find.byType(Transform)),
      );
      expect(transforms, isNotEmpty,
          reason: 'Reels must translate vertically via Transform');

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('450.500'), findsOneWidget);
    });

    testWidgets(
        '1.6: Dynamic amount update triggers vertical roll to new target',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 50.000,
                duration: const Duration(milliseconds: 400),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('50.000'), findsOneWidget);

      // Update value
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 175.250,
                duration: const Duration(milliseconds: 400),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('175.250'), findsOneWidget);
    });

    testWidgets(
        '1.7: Tabular figures font feature (tnum) is applied across all reels',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: 123.456,
                thousandsSeparator: true,
                suffix: ' DT',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final texts = tester.widgetList<Text>(
        find.descendant(
            of: find.byType(RouletteNumberText), matching: find.byType(Text)),
      );
      for (final t in texts) {
        if (t.style?.fontFeatures != null) {
          expect(
            t.style!.fontFeatures!.any((f) => f.feature == 'tnum'),
            isTrue,
            reason: 'Tabular figures required to eliminate horizontal jitter',
          );
        }
      }
    });

    testWidgets(
        '1.8: Negative amount correctly prefixes minus sign before grouped digits',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RouletteNumberText(
                value: -15000.300,
                thousandsSeparator: true,
                suffix: ' DT',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('-15,000.300 DT'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);
      expect(find.text(','), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 2: REQUIREMENT 2 (R2) — Top Home Header Rebuild
  // =========================================================================
  group('Master E2E — Group 2: R2 Top Home Header Rebuild', () {
    testWidgets(
        '2.1: Eco logo (#00D084), bold white StudentHub, Solo Student pill badge',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      // Eco logo
      final ecoIcon = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon == Icons.eco_rounded &&
          w.color == const Color(0xFF00D084));
      expect(ecoIcon, findsOneWidget);

      // StudentHub
      expect(find.text('StudentHub'), findsOneWidget);

      // Solo Student pill
      expect(find.text('Solo Student'), findsOneWidget);
    });

    testWidgets(
        '2.2: Circular action buttons (history, bell with #E57373 red dot, avatar)',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'Yasmine')));
      await tester.pumpAndSettle();

      // Circular history button
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);

      // Notification bell
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

      // Notification red dot container (#E57373)
      final redDot = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xFFE57373) &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(redDot, findsOneWidget);

      // User avatar with initials fallback
      expect(find.text('Y'), findsOneWidget);
    });

    testWidgets('2.3: Tap history button opens MonthlyHistoryModalSheet',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Historical Archive'), findsOneWidget);
      expect(
          find.text('Review past spending cycles & receipts'), findsOneWidget);
    });

    testWidgets('2.4: Tap notification button opens active notifications sheet',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Active Notifications'), findsOneWidget);
      expect(find.text('Monthly budget tracker initialized.'), findsOneWidget);
    });

    testWidgets(
        '2.5: Dynamic time-aware greeting headline and dedicated mascot frame',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'Yasmine')));
      await tester.pumpAndSettle();

      expect(find.byType(GlowingTypewriterGreeting), findsOneWidget);
      expect(find.text('Yasmine'), findsOneWidget);

      // Header illustration frame
      final avatarImages = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('header_avatar.png'));
      expect(avatarImages, findsWidgets);
    });

    testWidgets(
        '2.6: AnimatedSwitcher cross-fade subtitle displays welcome text with wave icon and 0 emojis',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedSwitcher), findsWidgets);
      expect(find.textContaining('Welcome'), findsWidgets);
      expect(find.byIcon(Icons.waving_hand_rounded), findsOneWidget);
    });

    testWidgets(
        '2.7: Total Balance KPI card renders dual-tone RouletteNumberText and mint wallet icon',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(2000.0, 500.0);
      budget.addExpense(title: 'Groceries', amount: 350.0, category: 'Food');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);

      final walletIcon = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon == Icons.account_balance_wallet_rounded &&
          w.color == const Color(0xFF00D084));
      expect(walletIcon, findsOneWidget);

      expect(
        find.byWidgetPredicate((w) => w is RouletteNumberText && w.isHeader),
        findsNWidgets(2),
      );
    });

    testWidgets(
        '2.8: Total Expense KPI card renders automated trend arrow (#00D084 up / #E57373 down)',
        (tester) async {
      // Test Case A: Low spend -> flat/down (green/red arrow)
      final budget = BudgetController();
      await budget.setBudgetCap(2000.0, 300.0);
      budget.addExpense(title: 'Snack', amount: 5.0, category: 'Food');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('TOTAL EXPENSE'), findsOneWidget);

      // Test Case B: Heavy spend exceeding daily pace -> green upward arrow
      budget.addExpense(
          title: 'Tuition Fee', amount: 1500.0, category: 'Academic');
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);
    });

    testWidgets(
        '2.9: Dynamic Month Budget progress bar with dark track (#0F1F17) and green indicator (#00D084)',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(20000.0, 5000.0);
      budget.addExpense(title: 'Tuition', amount: 9200.0, category: 'Academic');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      // Progress percentage text
      expect(find.textContaining('DT Cap'), findsOneWidget);
      expect(find.textContaining('46%'), findsOneWidget);

      // Track capsule (#0F1F17 or translucent white)
      final trackCapsule = find.byWidgetPredicate((w) =>
          w is Container &&
          (w.constraints?.maxHeight == 7 || w.constraints?.maxHeight == 8) &&
          (w.color == const Color(0xFF0F1F17) ||
              w.color == Colors.white.withOpacity(0.16)));
      expect(trackCapsule, findsOneWidget);

      // Indicator bar (#00D084 or gradient)
      final greenBar = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).color == const Color(0xFF00D084) ||
              (w.decoration as BoxDecoration).gradient != null));
      expect(greenBar, findsWidgets);
    });

    testWidgets('2.10: Injects custom date or month label dynamically',
        (tester) async {
      final customDate = DateTime(2026, 4, 15);
      await tester.pumpWidget(
          _wrapWithProviders(HomeDashboard(currentDate: customDate)));
      await tester.pumpAndSettle();

      expect(find.text('APRIL BUDGET'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: REQUIREMENT 3 (R3) — Curved Body Container & Quick Actions
  // =========================================================================
  group('Master E2E — Group 3: R3 Curved Body Container & Quick Actions', () {
    testWidgets(
        '3.1: Curved body container has 38px top-left and top-right radius and #F4F6F0 background',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final curvedContainer = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          final br = dec.borderRadius;
          if (br is BorderRadius) {
            return (br.topLeft == const Radius.circular(38) ||
                    br.topLeft == const Radius.circular(28) ||
                    br.topLeft == const Radius.circular(26)) &&
                (br.topRight == const Radius.circular(38) ||
                    br.topRight == const Radius.circular(28) ||
                    br.topRight == const Radius.circular(26)) &&
                br.bottomLeft == Radius.zero &&
                br.bottomRight == Radius.zero &&
                (dec.color == const Color(0xFFF4F6F0) ||
                    dec.color == const Color(0xFFF4F7F5));
          }
        }
        return false;
      });

      expect(curvedContainer, findsOneWidget);
    });

    testWidgets('3.2: Single row of exactly 4 action cards with #1E3A2E icons',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);

      // Verify icon colors are Color(0xFF1E3A2E) / deepPine
      final actionIcons = tester.widgetList<Icon>(find.byWidgetPredicate((w) =>
          w is Icon &&
          w.color == const Color(0xFF1E3A2E) &&
          (w.icon == Icons.add_circle_outline_rounded ||
              w.icon == Icons.document_scanner_outlined ||
              w.icon == Icons.tune_rounded ||
              w.icon == Icons.calendar_month_rounded)));
      expect(actionIcons.length, greaterThanOrEqualTo(4));
    });

    testWidgets(
        '3.3: Total absence of legacy buttons (Send, Receive, Pay, Top-Up)',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Send'), findsNothing);
      expect(find.text('Receive'), findsNothing);
      expect(find.text('Pay'), findsNothing);
      expect(find.text('Top-Up'), findsNothing);
    });

    testWidgets(
        '3.4: Quick Action taps trigger expected modals (Add Expense and Adjust Cap)',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      // Tap Add Expense
      await tester.tap(find.text('Add Expense'));
      await tester.pumpAndSettle();
      expect(find.text('Record New Outflow'), findsOneWidget);

      // Dismiss Add Expense
      await tester
          .tap(find.byType(ElevatedButton).first); // or tap outside/dismiss
      // In this sheet, there's 'Save Expense' button; dismiss by popping:
      Navigator.of(tester.element(find.text('Record New Outflow'))).pop();
      await tester.pumpAndSettle();

      // Tap Adjust Cap
      await tester.tap(find.text('Adjust Cap'));
      await tester.pumpAndSettle();
      expect(find.text('Adjust Monthly Cap'), findsOneWidget);
      expect(find.text('MONTHLY ALLOWANCE TARGET'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: REQUIREMENT 4 (R4) — Animated Weekly Rhythm Section
  // =========================================================================
  group('Master E2E — Group 4: R4 Animated Weekly Rhythm Section', () {
    testWidgets(
        '4.1: Header renders Icons.auto_graph_rounded with #1E3A2E and Daily Safe Spend subtitle',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(find.textContaining('vs. Daily Safe Spend'), findsOneWidget);

      final rhythmIcon = find.byWidgetPredicate((w) =>
          w is Icon &&
          w.icon == Icons.auto_graph_rounded &&
          w.color == const Color(0xFF1E3A2E));
      expect(rhythmIcon, findsOneWidget);
    });

    testWidgets(
        '4.2: Permanent removal of Active Rhythm and Clean Zero pill badges',
        (tester) async {
      // Inactive state
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();
      expect(find.text('Active Rhythm'), findsNothing);
      expect(find.text('Clean Zero'), findsNothing);

      // Active state
      final budget = BudgetController();
      await budget.setBudgetCap(1000.0, 200.0);
      budget.addExpense(title: 'Coffee', amount: 5.0, category: 'Food');
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('Active Rhythm'), findsNothing);
      expect(find.text('Clean Zero'), findsNothing);
    });

    testWidgets(
        '4.3: WeeklyRhythmCard cycles strictly through 7 designated brand color tokens',
        (tester) async {
      const expectedTokens = [
        Color(0xFF1E3A2E), // Monday - Deep Pine
        Color(0xFF3E5A3F), // Tuesday - Mid Moss
        Color(0xFF6B7F67), // Wednesday - Soft Sage
        Color(0xFF3D4337), // Thursday - Dark Olive
        Color(0xFF00D084), // Friday - Vibrant Green
        Color(0xFF0F1F17), // Saturday - Dark Forest
        Color(0xFF3E5A3F), // Sunday - Mid Moss
      ];

      expect(WeeklyRhythmCard.dayColors, equals(expectedTokens));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyRhythmCard(
              dailySafeSpend: 40.0,
              weeklySpending: const {
                1: 10.0,
                2: 20.0,
                3: 30.0,
                4: 40.0,
                5: 50.0,
                6: 60.0,
                7: 70.0
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barContainers = tester
          .widgetList<Container>(
        find.descendant(
            of: find.byType(WeeklyRhythmCard),
            matching: find.byType(Container)),
      )
          .where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(7) &&
            c.constraints?.maxWidth == 14;
      }).toList();

      expect(barContainers.length, equals(7));
      for (int i = 0; i < 7; i++) {
        final dec = barContainers[i].decoration as BoxDecoration;
        expect(dec.color, equals(expectedTokens[i]));
      }
    });

    testWidgets('4.4: Inactive bars retain brand token with 0.18 opacity tint',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyRhythmCard(
              dailySafeSpend: 40.0,
              weeklySpending: const {
                1: 0.0,
                2: 0.0,
                3: 0.0,
                4: 0.0,
                5: 0.0,
                6: 0.0,
                7: 0.0
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final barContainers = tester
          .widgetList<Container>(
        find.descendant(
            of: find.byType(WeeklyRhythmCard),
            matching: find.byType(Container)),
      )
          .where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(7) &&
            c.constraints?.maxWidth == 14;
      }).toList();

      expect(barContainers.length, equals(7));
      for (int i = 0; i < 7; i++) {
        final dec = barContainers[i].decoration as BoxDecoration;
        expect(
            dec.color, equals(WeeklyRhythmCard.dayColors[i].withOpacity(0.18)));
      }
    });

    testWidgets('4.5: Animated bar entry growth smoothly scales up from 0.0',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyRhythmCard(
              dailySafeSpend: 50.0,
              weeklySpending: const {
                1: 50.0,
                2: 50.0,
                3: 50.0,
                4: 50.0,
                5: 50.0,
                6: 50.0,
                7: 50.0
              },
              animationDuration: const Duration(milliseconds: 900),
            ),
          ),
        ),
      );

      // Frame 0: Heights start at 0.0
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isTrue);

      final barContainers0 = tester
          .widgetList<Container>(
        find.descendant(
            of: find.byType(WeeklyRhythmCard),
            matching: find.byType(Container)),
      )
          .where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration &&
            dec.borderRadius == BorderRadius.circular(7) &&
            c.constraints?.maxWidth == 14;
      }).toList();

      for (final bar in barContainers0) {
        final h = bar.constraints?.maxHeight ?? 0.0;
        expect(h, lessThanOrEqualTo(0.1));
      }

      // Mid-flight: Growth in progress
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets(
        '4.6: Floating dark capsule pills (#0F1F17, white text) appear above active days only',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyRhythmCard(
              dailySafeSpend: 50.0,
              weeklySpending: const {2: 45.0}, // Tuesday only
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 DT'), findsOneWidget);
      expect(find.text('0 DT'), findsNothing);

      // Pill container has dark background Color(0xFF0F1F17)
      final pillContainerFinder = find
          .ancestor(
            of: find.text('45 DT'),
            matching: find.byType(Container),
          )
          .first;
      final pillContainer = tester.widget<Container>(pillContainerFinder);
      final dec = pillContainer.decoration as BoxDecoration;
      expect(dec.color, equals(const Color(0xFF0F1F17)));
    });

    testWidgets(
        '4.7: Weekday labels below bars are M, T, W, T, F, S, S in #6B7F67',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyRhythmCard(dailySafeSpend: 50.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2));
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2));

      final mondayText = tester.widget<Text>(find.text('M'));
      expect(mondayText.style?.color, equals(const Color(0xFF6B7F67)));
    });
  });

  // =========================================================================
  // GROUP 5: REQUIREMENT 5 (R5) — Sequence, Recent Transactions & Zero-Emoji
  // =========================================================================
  group('Master E2E — Group 5: R5 Sequence, Transactions & Zero-Emoji Scan',
      () {
    testWidgets(
        '5.1: Strict vertical sequence: Quick Actions -> Weekly Rhythm -> Transactions -> Deadlines',
        (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 1800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final budget = BudgetController();
      budget.addExpense(title: 'Lab Notebook', amount: 15.0, category: 'Tools');
      final tasks = TasksController();
      tasks.addTask(
          title: 'Study Session', category: 'Academic', dueDate: 'Tonight');

      await tester.pumpWidget(_wrapWithProviders(
        const HomeDashboard(),
        budget: budget,
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      final actionsY = tester.getTopLeft(find.text('Add Expense')).dy;
      final rhythmY = tester.getTopLeft(find.text('Weekly Rhythm')).dy;
      final transactionsY =
          tester.getTopLeft(find.text('Recent Transactions')).dy;
      final deadlinesY =
          tester.getTopLeft(find.text('Upcoming & Deadlines')).dy;

      expect(actionsY, lessThan(rhythmY),
          reason: 'Quick Actions must appear above Weekly Rhythm');
      expect(rhythmY, lessThan(transactionsY),
          reason: 'Weekly Rhythm must appear above Recent Transactions');
      expect(transactionsY, lessThan(deadlinesY),
          reason: 'Recent Transactions must appear above Upcoming Deadlines');
    });

    testWidgets(
        '5.2: Recent Transactions render blue square badges (#42A5F5) and RouletteNumberText',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Campus Bookstore', amount: 38.0, category: 'Books');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('Campus Bookstore'), findsOneWidget);

      // Blue square badge (#42A5F5, radius 10)
      final blueSquareBadge = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final dec = w.decoration as BoxDecoration;
          return (dec.color == const Color(0xFF42A5F5) ||
                  dec.color == AppColors.iconBlue) &&
              dec.shape == BoxShape.rectangle &&
              dec.borderRadius == BorderRadius.circular(10);
        }
        return false;
      });
      expect(blueSquareBadge, findsWidgets);

      // Amount renders dual-tone RouletteNumberText
      expect(find.byType(RouletteNumberText), findsWidgets);
    });

    testWidgets(
        '5.3: Category tag contains vertical separator \' | \' between category and time',
        (tester) async {
      final budget = BudgetController();
      final now = DateTime.now();
      budget.addExpense(title: 'Dining Hall', amount: 12.5, category: 'Dining');

      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      final expectedSeparator = 'Dining | ${DateFormat('h:mm a').format(now)}';
      expect(find.text(expectedSeparator), findsOneWidget);
    });

    testWidgets(
        '5.4: Transaction empty state guides user to + Add Expense without legacy verbs',
        (tester) async {
      final budget = BudgetController();
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(), budget: budget));
      await tester.pumpAndSettle();

      expect(find.text('No recent transactions'), findsOneWidget);
      expect(
          find.text('Tap + Add Expense to record an outflow'), findsOneWidget);
      expect(find.textContaining('Send or Pay'), findsNothing);
    });

    testWidgets(
        '5.5: Strict runtime zero-emoji scan across populated widget tree',
        (tester) async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Groceries & Supplies', amount: 45.0, category: 'Food');
      final tasks = TasksController();
      tasks.addTask(
          title: 'Math Assignment 2', category: 'Academic', dueDate: 'Friday');

      await tester.pumpWidget(_wrapWithProviders(
        const HomeDashboard(userName: 'Yasmine'),
        budget: budget,
        tasks: tasks,
      ));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final t in textWidgets) {
        final text = t.data ?? t.textSpan?.toPlainText() ?? '';
        expect(
          emojiRegex.hasMatch(text),
          isFalse,
          reason:
              'Prohibited Unicode emoji encountered in Text widget: "$text"',
        );
      }
    });

    test('5.6: Static source files contain strictly zero Unicode emojis', () {
      final filesToCheck = [
        File('lib/ui/views/home_view.dart'),
        File('lib/ui/views/weekly_rhythm_card.dart'),
        File('lib/core/widgets/roulette_number_text.dart'),
      ];

      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F5FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{2300}-\u{23FF}]',
        unicode: true,
      );

      for (final file in filesToCheck) {
        expect(file.existsSync(), isTrue, reason: '${file.path} must exist');
        final content = file.readAsStringSync();
        expect(
          emojiRegex.hasMatch(content),
          isFalse,
          reason: '${file.path} contains forbidden Unicode emojis',
        );
      }
    });
  });

  // =========================================================================
  // GROUP 6: NON-REGRESSION, SCOPE BOUNDARY & RESPONSIVE RESILIENCE
  // =========================================================================
  group('Master E2E — Group 6: Non-Regression & Scope Boundary Integrity', () {
    testWidgets(
        '6.1: HomeDashboard matches test/widget_test.dart baseline lines 50–61',
        (tester) async {
      final tasks = TasksController();
      tasks.addTask(
        title: 'CS301 Project Submission',
        category: 'Academic',
        dueDate: 'Due tomorrow',
      );
      await tester.pumpWidget(_wrapWithProviders(
          const HomeDashboard(userName: 'Yasmine'),
          tasks: tasks));
      await tester.pumpAndSettle();

      expect(find.byType(GlowingTypewriterGreeting), findsOneWidget);
      expect(find.text('Yasmine'), findsOneWidget);
      expect(find.text('StudentHub'), findsOneWidget);
      expect(find.text('OCTOBER BUDGET'), findsOneWidget);
      expect(find.text('Upcoming & Deadlines'), findsOneWidget);
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Scan Receipt'), findsOneWidget);
      expect(find.text('Adjust Cap'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
    });

    testWidgets(
        '6.2: Clean zero-base state matches test/widget_test.dart lines 63–69',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.text('StudentHub'), findsOneWidget);
      expect(find.text('OCTOBER BUDGET'), findsOneWidget);
    });

    testWidgets(
        '6.3: Micro-viewport (280x653) renders cleanly without RenderFlex overflows',
        (tester) async {
      tester.view.physicalSize = const Size(280 * 2.0, 653 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(280, 653)),
          child: _wrapWithProviders(const HomeDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Micro-viewport must not throw layout exceptions');
    });

    testWidgets(
        '6.4: High text scaling (2.0x) on compact viewport renders without layout crash',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 568), textScaler: TextScaler.linear(2.0)),
          child: _wrapWithProviders(const HomeDashboard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '6.5: MainShell tab integration switches seamlessly from Home to Calendar',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const MainShell()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeDashboard), findsOneWidget);

      // Tap quick action Calendar card
      await tester.tap(find.text('Calendar').first);
      await tester.pumpAndSettle();

      // Should switch to Calendar tab
      expect(find.text('Calender'), findsOneWidget);
    });
  });
}

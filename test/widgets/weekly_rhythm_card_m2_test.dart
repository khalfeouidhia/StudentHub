// test/widgets/weekly_rhythm_card_m2_test.dart
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
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapWithProviders(
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
      home: Scaffold(
        backgroundColor: AppColors.sandCream,
        body: Center(child: child),
      ),
    ),
  );
}

Widget buildSubject({
  BudgetController? budget,
  double spentSoFar = 0.0,
  Map<int, double>? weeklySpending,
  List<double>? weeklyExpenses,
  double? dailySafeSpend,
  Duration animationDuration = const Duration(milliseconds: 900),
}) {
  return _wrapWithProviders(
    WeeklyRhythmCard(
      budget: budget,
      spentSoFar: spentSoFar,
      weeklySpending: weeklySpending,
      weeklyExpenses: weeklyExpenses,
      dailySafeSpend: dailySafeSpend,
      animationDuration: animationDuration,
    ),
    budget: budget,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.instance.ensureSemantics();
  });

  // =========================================================================
  // Group 1: Baseline Compatibility & widget_test.dart Non-Regression (Lines 357–362)
  // =========================================================================
  group('Milestone 2 — Group 1: Baseline Compatibility & Non-Regression', () {
    testWidgets(
        'HomeDashboard renders dynamic Weekly Rhythm tooltip pill badge with DT format',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(1500.0, 300.0);
      budget.addExpense(
        title: 'Course Textbook',
        amount: 45.000,
        category: 'Books & Study',
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const HomeDashboard(),
          budget: budget,
        ),
      );
      await tester.pumpAndSettle();

      // Exact assertions from test/widget_test.dart lines 357–362
      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(find.textContaining('vs. Daily Safe Spend'), findsOneWidget);
      expect(find.textContaining('DT'), findsWidgets);
      expect(find.text('45 DT'), findsOneWidget);
    });

    testWidgets(
        'WeeklyRhythmCard standalone renders Weekly Rhythm title and safe spend subtitle',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 42.5,
        weeklySpending: {
          1: 15.0,
          2: 30.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(find.textContaining('vs. Daily Safe Spend (42.5 DT)'),
          findsOneWidget);
    });

    testWidgets(
        'Header icon uses Icons.auto_graph_rounded with Color(0xFF1E3A2E)',
        (tester) async {
      await tester.pumpWidget(buildSubject(dailySafeSpend: 35.0));
      await tester.pumpAndSettle();

      final iconFinder = find.byIcon(Icons.auto_graph_rounded);
      expect(iconFinder, findsOneWidget,
          reason: 'Header must render Icons.auto_graph_rounded');

      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, equals(const Color(0xFF1E3A2E)),
          reason: 'Header icon must use brand Color(0xFF1E3A2E) / deepPine');

      // Verify legacy icon is absent
      expect(find.byIcon(Icons.insights), findsNothing,
          reason: 'Legacy Icons.insights must be removed');
    });
  });

  // =========================================================================
  // Group 2: Permanent Removal of "Active Rhythm" and "Clean Zero" Badges
  // =========================================================================
  group('Milestone 2 — Group 2: Permanent Removal of Active Rhythm Badge', () {
    testWidgets(
        'Clean zero state (spentSoFar = 0.0) renders neither Active Rhythm nor Clean Zero badge',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        spentSoFar: 0.0,
        weeklySpending: {
          1: 0.0,
          2: 0.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Rhythm'), findsNothing,
          reason: 'Active Rhythm badge must be permanently removed');
      expect(find.text('Clean Zero'), findsNothing,
          reason: 'Clean Zero badge must be permanently removed');
    });

    testWidgets(
        'Active spending state (spentSoFar = 120.0) permanently omits Active Rhythm badge',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        spentSoFar: 120.0,
        weeklySpending: {
          1: 45.0,
          2: 75.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Rhythm'), findsNothing,
          reason: 'Active Rhythm badge must be permanently removed');
      expect(find.text('Clean Zero'), findsNothing,
          reason: 'Clean Zero badge must be permanently removed');
    });

    testWidgets(
        'Header row contains no badge container next to Weekly Rhythm title',
        (tester) async {
      await tester.pumpWidget(buildSubject(spentSoFar: 50.0));
      await tester.pumpAndSettle();

      // Ensure no pill badge text widgets exist in the header area
      expect(find.text('Active Rhythm'), findsNothing);
      expect(find.text('Clean Zero'), findsNothing);
      expect(find.text('Active'), findsNothing);
    });
  });

  // =========================================================================
  // Group 3: Strict 7 Brand Color Tokens Cycle
  // =========================================================================
  group('Milestone 2 — Group 3: Strict 7 Brand Color Tokens Cycle', () {
    test(
        'WeeklyRhythmCard.brandBarColors contains exactly the 7 designated brand tokens',
        () {
      const expectedTokens = [
        Color(0xFF1E3A2E), // Monday - Deep Pine
        Color(0xFF3E5A3F), // Tuesday - Mid Moss
        Color(0xFF6B7F67), // Wednesday - Soft Sage
        Color(0xFF3D4337), // Thursday - Dark Olive
        Color(0xFF00D084), // Friday - Vibrant Green
        Color(0xFF0F1F17), // Saturday - Dark Forest
        Color(0xFF3E5A3F), // Sunday - Mid Moss
      ];

      expect(WeeklyRhythmCard.dayColors, equals(expectedTokens),
          reason:
              'WeeklyRhythmCard.dayColors must cycle strictly through the 7 brand color tokens');
      expect(WeeklyRhythmCard.brandBarColors, equals(expectedTokens));
    });

    testWidgets(
        'Rendered bars exhibit strictly the 7 brand color tokens for Monday through Sunday',
        (tester) async {
      const testSpending = {
        1: 20.0,
        2: 30.0,
        3: 40.0,
        4: 50.0,
        5: 60.0,
        6: 70.0,
        7: 80.0
      };
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: testSpending,
      ));
      await tester.pumpAndSettle();

      const expectedTokens = [
        Color(0xFF1E3A2E),
        Color(0xFF3E5A3F),
        Color(0xFF6B7F67),
        Color(0xFF3D4337),
        Color(0xFF00D084),
        Color(0xFF0F1F17),
        Color(0xFF3E5A3F),
      ];

      // Find all bar animated containers with width 14 and rounded corners
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

      expect(barContainers.length, equals(7),
          reason: 'There must be exactly 7 weekday bars');

      for (int i = 0; i < 7; i++) {
        final dec = barContainers[i].decoration as BoxDecoration;
        expect(dec.color, equals(expectedTokens[i]),
            reason:
                'Bar ${i + 1} must match brand color token ${expectedTokens[i]}');
      }
    });

    testWidgets(
        'Zero-spending bars retain brand color token with subtle opacity tint',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 0.0,
          2: 0.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

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

      for (int i = 0; i < 7; i++) {
        final dec = barContainers[i].decoration as BoxDecoration;
        final baseColor = WeeklyRhythmCard.dayColors[i];
        expect(dec.color, equals(baseColor.withOpacity(0.18)),
            reason:
                'Inactive bar ${i + 1} must use base brand token with 0.18 opacity');
      }
    });
  });

  // =========================================================================
  // Group 4: Entry Growth Animation with CurvedAnimation(curve: Curves.easeOutBack)
  // =========================================================================
  group('Milestone 2 — Group 4: Entry Growth Animation (Curves.easeOutBack)',
      () {
    testWidgets(
        'Entry animation initializes at 0.0 bar height on mount (frame 0)',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 50.0,
          2: 50.0,
          3: 50.0,
          4: 50.0,
          5: 50.0,
          6: 50.0,
          7: 50.0
        },
        animationDuration: const Duration(milliseconds: 900),
      ));

      // Frame 0: Animation has started but no time elapsed
      await tester.pump(Duration.zero);
      expect(tester.hasRunningAnimations, isTrue,
          reason: 'Entry animation must run on mount');

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

      for (final bar in barContainers) {
        final height = bar.constraints?.maxHeight ?? 0.0;
        expect(height, lessThanOrEqualTo(0.1),
            reason: 'Bar height must start smoothly from 0.0 on entry');
      }
    });

    testWidgets(
        'Bar heights grow smoothly mid-flight at t=350ms with running animations',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 50.0,
          2: 50.0,
          3: 50.0,
          4: 50.0,
          5: 50.0,
          6: 50.0,
          7: 50.0
        },
        animationDuration: const Duration(milliseconds: 900),
      ));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.hasRunningAnimations, isTrue,
          reason: 'Animation must be actively running mid-flight');

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

      for (final bar in barContainers) {
        final height = bar.constraints?.maxHeight ?? 0.0;
        expect(height, greaterThan(0.0),
            reason: 'Bar height must grow past 0.0 mid-flight');
      }
    });

    testWidgets('Bar heights settle completely after pumpAndSettle',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 75.0,
          2: 0.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
        animationDuration: const Duration(milliseconds: 900),
      ));
      await tester.pumpAndSettle();

      expect(tester.hasRunningAnimations, isFalse,
          reason: 'Animation must complete after pumpAndSettle');

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

      // Monday has spend 75.0 (which equals benchmark 75.0), so it reaches maxBarHeight 84.0
      final mondayBarHeight = barContainers[0].constraints?.maxHeight ?? 0.0;
      expect(mondayBarHeight, closeTo(84.0, 1.0),
          reason: 'Full spend bar must settle at maxBarHeight (84.0)');
    });

    testWidgets(
        'Zero animationDuration settles synchronously without running animations',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {1: 50.0},
        animationDuration: Duration.zero,
      ));
      await tester.pump(Duration.zero);

      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Disposing WeeklyRhythmCard mid-flight disposes AnimationController cleanly without exceptions',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {1: 50.0},
        animationDuration: const Duration(milliseconds: 1000),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.hasRunningAnimations, isTrue);

      // Unmount
      await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull,
          reason:
              'AnimationController must dispose cleanly without ticker leaks');
    });
  });

  // =========================================================================
  // Group 5: Floating Dark Capsule Amount Pills & Weekday Labels
  // =========================================================================
  group(
      'Milestone 2 — Group 5: Floating Dark Capsule Amount Pills & Weekday Labels',
      () {
    testWidgets(
        'Active day displays floating dark capsule with Color(0xFF0F1F17) and amount text',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {2: 45.0}, // Tuesday spend = 45 DT
      ));
      await tester.pumpAndSettle();

      final pillTextFinder = find.text('45 DT');
      expect(pillTextFinder, findsOneWidget,
          reason: 'Pill text must format as 45 DT');

      // Find enclosing pill Container
      final pillContainerFinder = find
          .ancestor(
            of: pillTextFinder,
            matching: find.byType(Container),
          )
          .first;
      final pillContainer = tester.widget<Container>(pillContainerFinder);
      final dec = pillContainer.decoration as BoxDecoration;

      expect(dec.color, equals(const Color(0xFF0F1F17)),
          reason:
              'Amount pill background must be dark forest capsule Color(0xFF0F1F17)');

      // Verify text style color is white
      final textWidget = tester.widget<Text>(pillTextFinder);
      expect(textWidget.style?.color, equals(Colors.white));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w700));
    });

    testWidgets(
        'Inactive days (dailyTotal == 0) do not render amount pill text',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 0.0,
          2: 45.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('0 DT'), findsNothing,
          reason: 'Zero-spend days must not render amount pill text');
      expect(find.text('45 DT'), findsOneWidget);
    });

    testWidgets('Weekday labels below bars are exactly M, T, W, T, F, S, S',
        (tester) async {
      await tester.pumpWidget(buildSubject(dailySafeSpend: 50.0));
      await tester.pumpAndSettle();

      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2)); // Tuesday & Thursday
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2)); // Saturday & Sunday
    });

    testWidgets(
        'Weekday labels use designated brand token Color(0xFF6B7F67) (softSage)',
        (tester) async {
      await tester.pumpWidget(buildSubject(dailySafeSpend: 50.0));
      await tester.pumpAndSettle();

      const softSage = Color(0xFF6B7F67);
      final mondayText = tester.widget<Text>(find.text('M'));
      expect(mondayText.style?.color, equals(softSage),
          reason: 'Weekday labels must use Color(0xFF6B7F67) / softSage');

      final wednesdayText = tester.widget<Text>(find.text('W'));
      expect(wednesdayText.style?.color, equals(softSage));
    });
  });

  // =========================================================================
  // Group 6: Strict Zero-Emoji Policy
  // =========================================================================
  group('Milestone 2 — Group 6: Strict Zero-Emoji Policy', () {
    testWidgets('WeeklyRhythmCard widget tree contains zero Unicode emojis',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        spentSoFar: 150.0,
        dailySafeSpend: 50.0,
        weeklySpending: {
          1: 25.0,
          2: 45.0,
          3: 60.0,
          4: 10.0,
          5: 0.0,
          6: 0.0,
          7: 10.0
        },
      ));
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{1F700}-\u{1F77F}|\u{1F780}-\u{1F7FF}|\u{1F800}-\u{1F8FF}|\u{1F900}-\u{1F9FF}|\u{1FA00}-\u{1FA6F}|\u{1FA70}-\u{1FAFF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}|\u{2300}-\u{23FF}]',
        unicode: true,
      );

      final textWidgets = tester.widgetList<Text>(
        find.descendant(
            of: find.byType(WeeklyRhythmCard), matching: find.byType(Text)),
      );

      for (final t in textWidgets) {
        final text = t.data ?? '';
        expect(emojiRegex.hasMatch(text), isFalse,
            reason: 'Widget text "$text" must not contain any Unicode emojis');
      }
    });

    test(
        'Static source file lib/ui/views/weekly_rhythm_card.dart contains zero Unicode emojis',
        () {
      final file = File('lib/ui/views/weekly_rhythm_card.dart');
      expect(file.existsSync(), isTrue);

      final contents = file.readAsStringSync();
      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}|\u{1F300}-\u{1F5FF}|\u{1F680}-\u{1F6FF}|\u{1F700}-\u{1F77F}|\u{1F780}-\u{1F7FF}|\u{1F800}-\u{1F8FF}|\u{1F900}-\u{1F9FF}|\u{1FA00}-\u{1FA6F}|\u{1FA70}-\u{1FAFF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}|\u{2300}-\u{23FF}]',
        unicode: true,
      );

      expect(emojiRegex.hasMatch(contents), isFalse,
          reason:
              'weekly_rhythm_card.dart must contain 0 Unicode emojis in source code and comments');
    });
  });

  // =========================================================================
  // Group 7: Dynamic Data Updates & Edge Case Resilience
  // =========================================================================
  group('Milestone 2 — Group 7: Dynamic Data Updates & Edge Case Resilience',
      () {
    testWidgets(
        'Clean zero-base week (all 7 days = 0.0 DT) renders safely without layout exceptions',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 0.0,
        weeklySpending: {
          1: 0.0,
          2: 0.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Rhythm'), findsOneWidget);
      expect(
          find.textContaining('vs. Daily Safe Spend (0.0 DT)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'High-spending day (500 DT) clamps cleanly within maxBarHeight without RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 30.0,
        weeklySpending: {
          1: 500.0,
          2: 10.0,
          3: 0.0,
          4: 0.0,
          5: 0.0,
          6: 0.0,
          7: 0.0
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('500 DT'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason:
              'RenderFlex overflow must not occur on large expense figures');
    });

    testWidgets(
        'Dynamically updating spending data triggers smooth bar rebuild without ticker conflicts',
        (tester) async {
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {1: 20.0},
        animationDuration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();
      expect(find.text('20 DT'), findsOneWidget);
      expect(find.text('60 DT'), findsNothing);

      // Rebuild with updated weekly spend
      await tester.pumpWidget(buildSubject(
        dailySafeSpend: 50.0,
        weeklySpending: {1: 20.0, 2: 60.0},
        animationDuration: const Duration(milliseconds: 300),
      ));
      await tester.pumpAndSettle();

      expect(find.text('20 DT'), findsOneWidget);
      expect(find.text('60 DT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

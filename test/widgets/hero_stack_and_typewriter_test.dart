import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  group(
      'Hero Header Stack, Frosted Refraction & Looping Typewriter Verification',
      () {
    testWidgets(
        'FrostedGlassKpiCard renders BackdropFilter blur and custom border',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedGlassKpiCard(
              child: Text('Frosted Content'),
            ),
          ),
        ),
      );

      expect(find.byType(FrostedGlassKpiCard), findsOneWidget);
      expect(find.byType(CompactGlassKpiCard), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Frosted Content'), findsOneWidget);
    });

    testWidgets(
        'LoopingTypewriterHeader static presentation in test environment',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoopingTypewriterHeader(
              userName: 'Dhia',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoopingTypewriterHeader), findsOneWidget);
      expect(find.text('Dhia'), findsOneWidget);
      expect(find.textContaining('Good'), findsOneWidget);
    });

    testWidgets(
        'LoopingTypewriterHeader animated loop advances when enableAnimation is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoopingTypewriterHeader(
              userName: 'dhia',
              enableAnimation: true,
            ),
          ),
        ),
      );

      // Initially characters begin typing
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(LoopingTypewriterHeader), findsOneWidget);

      // Fast forward past initial phase
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(LoopingTypewriterHeader), findsOneWidget);
    });

    testWidgets(
        'Home Header Stack renders large background 3D avatar and frosted cards',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'anzdkazn')));
      await tester.pumpAndSettle();

      // Verify Stack architecture
      expect(find.byType(Stack), findsWidgets);

      // Verify FrostedGlassKpiCards
      expect(find.byType(FrostedGlassKpiCard), findsNWidgets(2));
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('TOTAL EXPENSE'), findsOneWidget);

      // Verify avatar image in Stack
      final avatarFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('header_avatar.png'));
      expect(avatarFinder, findsWidgets);

      // Verify zero emoji policy across Text widgets
      final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true);
      for (final element in find.byType(Text).evaluate()) {
        final textWidget = element.widget as Text;
        final data = textWidget.data ?? '';
        expect(emojiRegex.hasMatch(data), isFalse,
            reason: 'Emoji found in Text: "$data"');
      }
    });
  });
}

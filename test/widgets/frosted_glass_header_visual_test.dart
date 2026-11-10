import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/core/widgets/frosted_glass_card.dart';
import 'package:studenthold_app/ui/views/home_view.dart';
import 'package:studenthold_app/ui/views/glowing_typewriter_greeting.dart';

Widget _wrapWithProviders(Widget child, {String userName = 'anzdkazn'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: HomeDashboard(userName: userName),
      ),
    ),
  );
}

void main() {
  group('Frosted Glass Header Visual & Proportions Verification', () {
    testWidgets(
        'FrostedGlassCard renders BackdropFilter blur and subtle border',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FrostedGlassCard(
              child: Text('Test Glass'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Test Glass'), findsOneWidget);

      final backdrop =
          tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(backdrop.filter, isNotNull);
    });

    testWidgets(
        'Home Header renders 3 FrostedGlassCards (Balance, Expense, Month Budget)',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      expect(find.byType(FrostedGlassCard), findsNWidgets(3));
      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('TOTAL EXPENSE'), findsOneWidget);
    });

    testWidgets('Header renders large prominent 3D avatar at 215px height',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders(const HomeDashboard()));
      await tester.pumpAndSettle();

      final avatarFinder = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('header_avatar.png') &&
          w.height == 215.0);
      expect(avatarFinder, findsOneWidget);
    });

    testWidgets(
        'Glowing username renders without text collision or emoji leakage',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithProviders(const HomeDashboard(userName: 'anzdkazn')));
      await tester.pumpAndSettle();

      expect(find.byType(GlowingTypewriterGreeting), findsOneWidget);
      expect(find.text('anzdkazn'), findsOneWidget);
      expect(find.textContaining('Good'), findsOneWidget);

      // Verify zero Unicode emojis across all rendered Text widgets in header
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

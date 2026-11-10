import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/views/home_view.dart';

Widget _wrapHome({double width = 390.0, double height = 844.0}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: const Scaffold(
          body: HomeDashboard(userName: 'anzdkazn'),
        ),
      ),
    ),
  );
}

void main() {
  group('Compact KPI & 3D Avatar 1:1 Layout Verification', () {
    testWidgets(
        'Cards constrained to 48% usable width and not stretched full-width',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrapHome());
      await tester.pumpAndSettle();

      final cardFinders = find.byType(CompactGlassKpiCard);
      expect(cardFinders, findsNWidgets(2));

      // Usable width: 390 - 32 = 358. Left column: 358 * 0.48 = 171.84
      for (final card in cardFinders.evaluate()) {
        final renderBox = card.findRenderObject() as RenderBox;
        expect(renderBox.size.width, lessThanOrEqualTo(190.0));
      }
    });

    testWidgets('Avatar occupies right 54% of hero stage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_wrapHome());
      await tester.pumpAndSettle();

      final heroAvatar = find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('header_avatar.png') &&
          w.fit == BoxFit.contain);

      expect(heroAvatar, findsOneWidget);
      final renderBox = tester.renderObject(heroAvatar) as RenderBox;
      // 358 * 0.56 = ~200.5px
      expect(renderBox.size.width, greaterThan(180.0));
    });

    testWidgets(
        'Avatar is positioned at top: 38.0, right: -6.0 with alignment.bottomRight',
        (tester) async {
      await tester.pumpWidget(_wrapHome());
      await tester.pumpAndSettle();

      final positionedAvatarFinder = find.byWidgetPredicate((w) =>
          w is Positioned &&
          (w.bottom == 0.0 || w.top == 38.0) &&
          (w.right == -6.0 || w.right == -8.0 || w.right == -12.0) &&
          (w.child is Image || w.child is Stack || w.child is ShaderMask));
      expect(positionedAvatarFinder, findsWidgets);

      final imageWidget = tester.widget<Image>(find
          .descendant(
            of: positionedAvatarFinder,
            matching: find.byType(Image),
          )
          .first);
      expect(imageWidget.alignment, Alignment.bottomRight);
      expect(imageWidget.fit, BoxFit.contain);
    });

    testWidgets('Zero Unicode emojis across entire home screen',
        (tester) async {
      await tester.pumpWidget(_wrapHome());
      await tester.pumpAndSettle();

      final emojiRegex = RegExp(
          r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
          unicode: true);
      for (final element in find.byType(Text).evaluate()) {
        final text = (element.widget as Text).data ?? '';
        expect(emojiRegex.hasMatch(text), isFalse,
            reason: 'Emoji found: "$text"');
      }
    });
  });
}

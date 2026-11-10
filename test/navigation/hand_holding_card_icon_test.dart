import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/home_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';
import 'package:studenthold_app/ui/navigation/main_shell.dart';

Widget _wrapShell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
      ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController()),
      ChangeNotifierProvider<TasksController>(create: (_) => TasksController()),
      ChangeNotifierProvider<HomeController>(create: (_) => HomeController()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'isOnboarded': true,
      'userName': 'Alex Student',
      'userBudgetCap': 350.0,
    });
  });

  group('HandHoldingCardPainter & HandHoldingCardIcon Tests', () {
    test('HandHoldingCardPainter paints without throwing exceptions', () {
      const painter =
          HandHoldingCardPainter(color: Colors.white, strokeWidth: 1.5);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(24.0, 24.0);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('HandHoldingCardPainter shouldRepaint triggers on color/stroke change',
        () {
      const p1 = HandHoldingCardPainter(color: Colors.white, strokeWidth: 1.5);
      const p2 = HandHoldingCardPainter(color: Colors.green, strokeWidth: 1.5);
      const p3 = HandHoldingCardPainter(color: Colors.white, strokeWidth: 2.0);
      const p4 = HandHoldingCardPainter(color: Colors.white, strokeWidth: 1.5);

      expect(p1.shouldRepaint(p2), isTrue);
      expect(p1.shouldRepaint(p3), isTrue);
      expect(p1.shouldRepaint(p4), isFalse);
    });

    testWidgets(
        'HandHoldingCardIcon renders with 24x24 dimension and custom color',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HandHoldingCardIcon(
              color: Colors.amber,
              size: 24.0,
            ),
          ),
        ),
      );

      final iconFinder = find.byType(HandHoldingCardIcon);
      expect(iconFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(iconFinder);
      expect(renderBox.size.width, equals(24.0));
      expect(renderBox.size.height, equals(24.0));

      final customPaintFinder = find.descendant(
        of: iconFinder,
        matching: find.byType(CustomPaint),
      );
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as HandHoldingCardPainter;
      expect(painter.color, equals(Colors.amber));
    });

    testWidgets(
        'HandHoldingCardIcon dynamically inherits IconTheme selected and unselected colors',
        (tester) async {
      const selectedColor = Color(0xFF00E5BE);
      const unselectedColor = Color(0xFF7A9B93);

      // 1. Selected state test
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconTheme(
              data: IconThemeData(color: selectedColor, size: 24.0),
              child: HandHoldingCardIcon(),
            ),
          ),
        ),
      );

      var customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(HandHoldingCardIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      var painter = customPaint.painter as HandHoldingCardPainter;
      expect(painter.color, equals(selectedColor));

      // 2. Unselected state test
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IconTheme(
              data: IconThemeData(color: unselectedColor, size: 24.0),
              child: HandHoldingCardIcon(),
            ),
          ),
        ),
      );

      customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(HandHoldingCardIcon),
          matching: find.byType(CustomPaint),
        ),
      );
      painter = customPaint.painter as HandHoldingCardPainter;
      expect(painter.color, equals(unselectedColor));
    });

    testWidgets(
        'StudentBottomNavigationBar renders with BottomNavigationBar and HandHoldingCardIcon',
        (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StudentBottomNavigationBar(
              currentIndex: 1,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.grey,
              onTap: (idx) => tappedIndex = idx,
            ),
          ),
        ),
      );

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(HandHoldingCardIcon), findsWidgets);
      expect(find.text('Expenses'), findsOneWidget);

      await tester.tap(find.text('Expenses'));
      await tester.pump();
      expect(tappedIndex, equals(1));
    });

    testWidgets(
        'MainShell renders LiquidGlassBottomNavBar with HandHoldingCardIcon on Expenses tab',
        (tester) async {
      await tester.pumpWidget(_wrapShell(const MainShell(initialIndex: 0)));
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlassBottomNavBar), findsOneWidget);
      expect(find.byType(HandHoldingCardIcon), findsOneWidget);

      // Tap on Expenses tab
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(find.text('Expenses & Outflows'), findsOneWidget);
      expect(find.byType(HandHoldingCardIcon), findsOneWidget);
    });
  });
}

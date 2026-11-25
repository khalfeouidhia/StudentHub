import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/services/receipt_ocr_service.dart';
import 'package:studenthold_app/widgets/receipt_review_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required BudgetController budget,
    required ParsedReceipt receipt,
  }) {
    return ChangeNotifierProvider<BudgetController>.value(
      value: budget,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ReceiptReviewSheet.show(
                  context,
                  budget,
                  parsedReceipt: receipt,
                );
              },
              child: const Text('Open Review Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('ReceiptReviewSheet Widget Tests', () {
    testWidgets('renders pre-filled merchant, total, items and category chips',
        (tester) async {
      final budget = BudgetController();
      final sampleReceipt = ParsedReceipt(
        merchant: 'Carrefour Market',
        items: [
          ReceiptItem(name: 'PAIN BAGUETTE', price: 0.850),
          ReceiptItem(name: 'LAIT DELICE', price: 1.450),
        ],
        total: 2.300,
        imagePath: '/mock/carrefour.jpg',
      );

      await tester.pumpWidget(
        createTestWidget(budget: budget, receipt: sampleReceipt),
      );

      // Open sheet
      await tester.tap(find.text('Open Review Sheet'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Receipt Review'), findsOneWidget);
      expect(find.text('View Photo'), findsOneWidget);

      // Verify Pre-filled Fields
      expect(find.text('Carrefour Market'), findsOneWidget);
      expect(find.text('2.300'), findsOneWidget);
      expect(find.text('PAIN BAGUETTE'), findsOneWidget);
      expect(find.text('0.850'), findsOneWidget);
      expect(find.text('LAIT DELICE'), findsOneWidget);
      expect(find.text('1.450'), findsOneWidget);

      // Verify Category Chips
      expect(find.text('Food & Groceries'), findsOneWidget);
      expect(find.text('Resto / Café'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Supplies'), findsOneWidget);
    });

    testWidgets('deleting an item recalculates grand total automatically',
        (tester) async {
      final budget = BudgetController();
      final sampleReceipt = ParsedReceipt(
        merchant: 'Monoprix',
        items: [
          ReceiptItem(name: 'SANDWICH THON', price: 4.000),
          ReceiptItem(name: 'EAU', price: 1.000),
        ],
        total: 5.000,
      );

      await tester.pumpWidget(
        createTestWidget(budget: budget, receipt: sampleReceipt),
      );

      await tester.tap(find.text('Open Review Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('5.000'), findsOneWidget);

      // Delete the second item ('EAU', 1.000)
      final deleteIcons = find.byIcon(Icons.close_rounded);
      expect(deleteIcons, findsNWidgets(3));

      // Tap delete on the second item
      await tester.tap(deleteIcons.at(2));
      await tester.pumpAndSettle();

      // Item 'EAU' deleted, remaining item 'SANDWICH THON' is 4.000, total is 4.000
      expect(find.text('EAU'), findsNothing);
      expect(find.text('SANDWICH THON'), findsOneWidget);
      expect(find.text('4.000'), findsNWidgets(2));
    });

    testWidgets('tapping Add Item inserts a blank row and updates total',
        (tester) async {
      final budget = BudgetController();
      const sampleReceipt = ParsedReceipt(
        merchant: 'Aziza',
        items: [],
        total: 0.0,
      );

      await tester.pumpWidget(
        createTestWidget(budget: budget, receipt: sampleReceipt),
      );

      await tester.tap(find.text('Open Review Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('DETECTED ITEMS (0)'), findsOneWidget);

      // Tap + Add Item
      await tester.tap(find.byKey(const ValueKey('receipt_add_item_btn')));
      await tester.pumpAndSettle();

      expect(find.text('DETECTED ITEMS (1)'), findsOneWidget);

      // Enter price for new item
      await tester.enterText(
          find.byKey(const ValueKey('item_price_0')), '3.250');
      await tester.pumpAndSettle();

      // Grand total should now display 3.250
      expect(find.text('3.250'), findsWidgets);
    });

    testWidgets('saving expense persists to BudgetController and updates balance',
        (tester) async {
      final budget = BudgetController();
      await budget.setBudgetCap(200.0, 20.0);

      final sampleReceipt = ParsedReceipt(
        merchant: 'Monoprix',
        items: [
          ReceiptItem(name: 'PIZZA', price: 6.500),
        ],
        total: 6.500,
        imagePath: '/mock/mono.jpg',
      );

      await tester.pumpWidget(
        createTestWidget(budget: budget, receipt: sampleReceipt),
      );

      await tester.tap(find.text('Open Review Sheet'));
      await tester.pumpAndSettle();

      // Select Resto / Café category chip
      await tester.tap(find.text('Resto / Café'));
      await tester.pumpAndSettle();

      // Tap Save Expense button
      await tester.ensureVisible(find.byKey(const ValueKey('receipt_save_btn')));
      await tester.tap(find.byKey(const ValueKey('receipt_save_btn')));
      await tester.pumpAndSettle();

      // Sheet should be dismissed
      expect(find.text('Receipt Review'), findsNothing);

      // Verify BudgetController was updated
      expect(budget.transactions.length, 1);
      expect(budget.transactions.first.title, 'Monoprix');
      expect(budget.transactions.first.amount, 6.500);
      expect(budget.spentSoFar, 6.500);
      expect(budget.remainingBudget, 193.500);
      expect(budget.transactions.first.imagePath, '/mock/mono.jpg');
    });

    testWidgets('PC test mode loads real MG Proxi Kelibia receipt with all 6 items and total',
        (tester) async {
      final budget = BudgetController();
      final mgReceipt = ReceiptOcrService.instance.getSampleMgReceipt();

      await tester.pumpWidget(
        createTestWidget(budget: budget, receipt: mgReceipt),
      );

      await tester.tap(find.text('Open Review Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('MG PROXI KELIBIA'), findsOneWidget);
      expect(find.text('9.970'), findsOneWidget);
      expect(find.text('DETECTED ITEMS (6)'), findsOneWidget);

      expect(find.text('1x POPCORN CAR'), findsOneWidget);
      expect(find.text('3.410'), findsOneWidget);

      expect(find.text('2x NOUILLE MIGO'), findsOneWidget);
      expect(find.text('2.360'), findsOneWidget);

      expect(find.text('1x TIMBRE 100 M'), findsOneWidget);
      expect(find.text('0.100'), findsOneWidget);

      // Verify category chip is pre-selected as Food & Groceries
      expect(find.text('Food & Groceries'), findsOneWidget);

      // Save expense
      await tester.ensureVisible(find.byKey(const ValueKey('receipt_save_btn')));
      await tester.tap(find.byKey(const ValueKey('receipt_save_btn')));
      await tester.pumpAndSettle();

      expect(budget.transactions.length, 1);
      expect(budget.transactions.first.title, 'MG PROXI KELIBIA');
      expect(budget.transactions.first.amount, 9.970);
      expect(budget.spentSoFar, 9.970);
    });
  });
}

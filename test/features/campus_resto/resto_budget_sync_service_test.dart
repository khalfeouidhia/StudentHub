import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_budget_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BudgetController budgetController;
  late RestoBudgetSyncService syncService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    budgetController = BudgetController();
    syncService = const RestoBudgetSyncService();
  });

  final testCheckIns = [
    RestoCheckIn(
      id: 'c1',
      timestamp: DateTime(2026, 11, 6, 12, 45, 12),
      quantity: 1,
      cin: '09876543',
      mealType: MealType.dejeuner,
    ),
    RestoCheckIn(
      id: 'c2',
      timestamp: DateTime(2026, 11, 5, 19, 15, 30),
      quantity: 1,
      cin: '09876543',
      mealType: MealType.diner,
    ),
    RestoCheckIn(
      id: 'c3',
      timestamp: DateTime(2026, 11, 5, 12, 30, 0),
      quantity: 1,
      cin: '09876543',
      mealType: MealType.dejeuner,
    ),
  ];

  final testTopUps = [
    RestoTopUp(
      id: 't1',
      timestamp: DateTime(2026, 11, 1, 9, 14, 22),
      mealCount: 20,
      cin: '09876543',
    ),
  ];

  group('RestoBudgetSyncService — Idempotency & Expense Integration', () {
    test('syncs check-ins into BudgetController with Campus Dining category',
        () async {
      final addedCount = await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );

      expect(addedCount, 3);
      expect(budgetController.transactions.length, 3);

      final firstTx = budgetController.transactions.first;
      expect(firstTx.category, 'Campus Dining');
      expect(firstTx.amount, 0.200);
      expect(firstTx.title, contains('Resto U: Déjeuner'));
    });

    test('guarantees idempotency by producing zero duplicates on repeated runs',
        () async {
      // First sync
      final firstRun = await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );
      expect(firstRun, 3);
      expect(budgetController.transactions.length, 3);

      // Second sync with identical check-ins
      final secondRun = await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );
      expect(secondRun, 0);
      expect(budgetController.transactions.length, 3); // No duplicates!
    });

    test('syncs top-ups when mode is RestoSyncMode.topUps', () async {
      final added = await syncService.syncTransactions(
        topUps: testTopUps,
        checkIns: [],
        budgetController: budgetController,
        mode: RestoSyncMode.topUps,
      );

      expect(added, 1);
      expect(budgetController.transactions.length, 1);
      expect(budgetController.transactions.first.amount, 4.000);
      expect(budgetController.transactions.first.title, contains('20 repas'));
      expect(budgetController.transactions.first.category, 'Campus Dining');
    });

    test('syncs both check-ins and top-ups when mode is RestoSyncMode.both',
        () async {
      final added = await syncService.syncTransactions(
        topUps: testTopUps,
        checkIns: testCheckIns,
        budgetController: budgetController,
        mode: RestoSyncMode.both,
      );

      expect(added, 4);
      expect(budgetController.transactions.length, 4);
      expect(await syncService.getSyncedHashesCount(), 4);
    });

    test('handles incremental syncing when new check-in arrives', () async {
      await syncService.syncTransactions(
        topUps: [],
        checkIns: [testCheckIns[0], testCheckIns[1]],
        budgetController: budgetController,
      );
      expect(budgetController.transactions.length, 2);

      // Sync with full list (adds the 3rd one)
      final incremental = await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );
      expect(incremental, 1);
      expect(budgetController.transactions.length, 3);
    });

    test('clearSyncedHashes resets stored hashes', () async {
      await syncService.syncTransactions(
        topUps: [],
        checkIns: testCheckIns,
        budgetController: budgetController,
      );
      expect(await syncService.getSyncedHashesCount(), 3);

      await syncService.clearSyncedHashes();
      expect(await syncService.getSyncedHashesCount(), 0);
    });
  });
}

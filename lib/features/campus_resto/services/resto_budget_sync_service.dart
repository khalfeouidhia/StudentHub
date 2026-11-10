import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import '../models/models.dart';

/// Synchronization modes supported by RestoBudgetSyncService.
enum RestoSyncMode {
  /// Syncs restaurant check-in events (meals consumed at 0.200 DT). Default.
  checkIns,

  /// Syncs balance recharge top-ups (ticket packs bought).
  topUps,

  /// Syncs both check-ins and top-ups with distinct titles.
  both,
}

/// Idempotently synchronizes Resto U meal consumption and ticket top-ups
/// into the student's personal budget transactions.
class RestoBudgetSyncService {
  static const String storageKey = 'resto_synced_transaction_hashes_v1';
  static const double mealUnitPriceDT = 0.200;
  static const String diningCategory = 'Campus Dining';

  final SharedPreferences? _prefs;

  const RestoBudgetSyncService({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> _resolvePrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Generates a deterministic hash for a restaurant turnstile check-in.
  String generateCheckInHash(RestoCheckIn checkIn) {
    final iso = checkIn.timestamp.toIso8601String();
    final meal = checkIn.mealType.name;
    return 'resto_checkin_${checkIn.cin}_${iso}_${checkIn.quantity}_$meal';
  }

  /// Generates a deterministic hash for a ticket balance top-up.
  String generateTopUpHash(RestoTopUp topUp) {
    final iso = topUp.timestamp.toIso8601String();
    return 'resto_topup_${topUp.cin}_${iso}_${topUp.mealCount}';
  }

  /// Idempotently synchronizes transaction records into [BudgetController].
  ///
  /// Returns the number of newly added expense records.
  Future<int> syncTransactions({
    required List<RestoTopUp> topUps,
    required List<RestoCheckIn> checkIns,
    required BudgetController budgetController,
    RestoSyncMode mode = RestoSyncMode.checkIns,
  }) async {
    final prefs = await _resolvePrefs();
    final existingList = prefs.getStringList(storageKey) ?? [];
    final syncedHashes = existingList.toSet();
    int addedCount = 0;

    if (mode == RestoSyncMode.checkIns || mode == RestoSyncMode.both) {
      for (final checkIn in checkIns) {
        final hash = generateCheckInHash(checkIn);
        if (!syncedHashes.contains(hash)) {
          final cost = checkIn.quantity * mealUnitPriceDT;
          budgetController.addExpense(
            title:
                'Resto U: ${checkIn.mealType.label} (${checkIn.quantity} repas)',
            amount: cost,
            category: diningCategory,
            date: checkIn.timestamp,
          );
          syncedHashes.add(hash);
          addedCount++;
        }
      }
    }

    if (mode == RestoSyncMode.topUps || mode == RestoSyncMode.both) {
      for (final topUp in topUps) {
        final hash = generateTopUpHash(topUp);
        if (!syncedHashes.contains(hash)) {
          budgetController.addExpense(
            title: 'Recharge Resto U (${topUp.mealCount} repas)',
            amount: topUp.computedAmount,
            category: diningCategory,
            date: topUp.timestamp,
          );
          syncedHashes.add(hash);
          addedCount++;
        }
      }
    }

    if (addedCount > 0) {
      await prefs.setStringList(storageKey, syncedHashes.toList());
    }

    return addedCount;
  }

  /// Returns the total count of synced transaction hashes in storage.
  Future<int> getSyncedHashesCount() async {
    final prefs = await _resolvePrefs();
    return (prefs.getStringList(storageKey) ?? []).length;
  }

  /// Clears stored sync history hashes (useful for tests and full state resets).
  Future<void> clearSyncedHashes() async {
    final prefs = await _resolvePrefs();
    await prefs.remove(storageKey);
  }
}

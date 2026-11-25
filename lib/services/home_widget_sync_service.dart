import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../controllers/budget_controller.dart';
import '../features/campus_resto/controllers/campus_resto_controller.dart';
import '../features/campus_resto/ui/widgets/resto_u_meal_strip.dart';

/// Synchronizes app data with native Android Home Screen widgets via `home_widget`.
///
/// Manages:
/// 1. `RestoUMenuWidgetProvider`: Next upcoming meal, reservation status, and dish list.
/// 2. `BalanceExpensesWidgetProvider`: Remaining balance, spent amount, monthly cap progress, and daily safe spend.
class HomeWidgetSyncService {
  static const String restoWidgetProvider = 'RestoUMenuWidgetProvider';
  static const String budgetWidgetProvider = 'BalanceExpensesWidgetProvider';
  static const String restoWidgetQualifiedName =
      'com.example.studenthold_app.RestoUMenuWidgetProvider';
  static const String budgetWidgetQualifiedName =
      'com.example.studenthold_app.BalanceExpensesWidgetProvider';

  const HomeWidgetSyncService._();

  /// Pushes the latest meal schedule and reservation status to the Resto U home widget.
  static Future<bool> syncRestoUMenuWidget({
    required CampusRestoController controller,
    DateTime? now,
  }) async {
    try {
      final current = now ?? DateTime.now();
      final slot = MealTimeSlotResolver.resolveNextAvailable(
        now: current,
        controller: controller,
      );

      final isReserved = controller.isMealReserved(slot);
      final badgeText = isReserved ? 'Réservé' : 'Non réservé';

      String dayLabel;
      if (slot.daysAhead == 0) {
        dayLabel = "Aujourd'hui";
      } else if (slot.daysAhead == 1) {
        dayLabel = 'Demain';
      } else {
        dayLabel = slot.badge ?? slot.weekdayName ?? "Bientôt";
      }

      final meal = controller.findMealForSlot(slot);
      String mainDish = 'Plat du jour';
      String entreeDish = 'Entrée';
      String dessertDish = 'Dessert / Fruit';

      if (meal != null) {
        final details = controller.cachedMealDetails(meal.id);
        if (details != null && details.dishes.isNotEmpty) {
          final dishes = details.prioritizedDishes;
          final main = dishes.firstWhere(
            (d) => d.isMainCourseStrict,
            orElse: () => dishes.first,
          );
          mainDish = main.name;

          final otherDishes = dishes.where((d) => d != main).toList();
          if (otherDishes.isNotEmpty) {
            entreeDish = otherDishes.first.name;
          }
          if (otherDishes.length > 1) {
            dessertDish = otherDishes.last.name;
          }
        }
      }

      await HomeWidget.saveWidgetData<String>('resto_title', slot.title);
      await HomeWidget.saveWidgetData<String>('resto_day_label', dayLabel);
      await HomeWidget.saveWidgetData<bool>('resto_is_reserved', isReserved);
      await HomeWidget.saveWidgetData<String>('resto_badge_text', badgeText);
      await HomeWidget.saveWidgetData<String>('resto_main', mainDish);
      await HomeWidget.saveWidgetData<String>('resto_entree', entreeDish);
      await HomeWidget.saveWidgetData<String>('resto_dessert', dessertDish);

      await HomeWidget.updateWidget(
        name: restoWidgetProvider,
        androidName: restoWidgetProvider,
        qualifiedAndroidName: restoWidgetQualifiedName,
      );
      return true;
    } catch (e) {
      debugPrint('HomeWidgetSyncService: syncRestoUMenuWidget failed - $e');
      return false;
    }
  }

  /// Pushes current budget KPIs to the Balance & Expenses home widget.
  static Future<bool> syncBalanceExpensesWidget({
    required BudgetController budget,
  }) async {
    try {
      final balanceStr = '${budget.remainingBudget.toStringAsFixed(3)} DT';
      final spentStr = '${budget.spentSoFar.toStringAsFixed(3)} DT';
      final percent = budget.totalCap > 0
          ? ((budget.spentSoFar / budget.totalCap) * 100).toInt().clamp(0, 100)
          : 0;
      final progressText = '$percent% / ${budget.totalCap.toStringAsFixed(0)} DT Cap';
      final dailySafeStr = '${budget.dailySafeSpend.toStringAsFixed(3)} DT/day';
      final capStr = '${budget.totalCap.toStringAsFixed(0)} DT';

      await HomeWidget.saveWidgetData<String>('budget_balance', balanceStr);
      await HomeWidget.saveWidgetData<String>('budget_spent', spentStr);
      await HomeWidget.saveWidgetData<String>('budget_progress_text', progressText);
      await HomeWidget.saveWidgetData<int>('budget_progress_percent', percent);
      await HomeWidget.saveWidgetData<String>('budget_daily_safe', dailySafeStr);
      await HomeWidget.saveWidgetData<String>('budget_cap', capStr);

      await HomeWidget.updateWidget(
        name: budgetWidgetProvider,
        androidName: budgetWidgetProvider,
        qualifiedAndroidName: budgetWidgetQualifiedName,
      );
      return true;
    } catch (e) {
      debugPrint('HomeWidgetSyncService: syncBalanceExpensesWidget failed - $e');
      return false;
    }
  }

  /// Configures deep linking callbacks for when the user taps on a Home Screen widget.
  static void registerDeepLinkHandler({
    required void Function(Uri? uri) onDeepLink,
  }) {
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(onDeepLink);
      HomeWidget.widgetClicked.listen(onDeepLink);
    } catch (e) {
      debugPrint('HomeWidgetSyncService: registerDeepLinkHandler failed - $e');
    }
  }
}

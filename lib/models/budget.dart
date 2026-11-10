// lib/models/budget.dart
class BudgetModel {
  final double monthlyAllowance;
  final double spentSoFar;
  final double houseKittyPool;
  final String currency; // 'DT'

  const BudgetModel({
    required this.monthlyAllowance,
    required this.spentSoFar,
    required this.houseKittyPool,
    this.currency = 'DT',
  });
}

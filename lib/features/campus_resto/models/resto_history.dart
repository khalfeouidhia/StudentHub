import 'package:studenthold_app/models/expense_item.dart';
import 'campus_meal_item.dart';

/// Represents a physical restaurant turnstile check-in event.
class RestoCheckIn {
  final String id;
  final DateTime timestamp;
  final int quantity;
  final String cin;
  final MealType mealType;

  const RestoCheckIn({
    required this.id,
    required this.timestamp,
    required this.quantity,
    required this.cin,
    required this.mealType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'quantity': quantity,
        'cin': cin,
        'mealType': mealType.name,
      };

  factory RestoCheckIn.fromJson(Map<String, dynamic> json) => RestoCheckIn(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        cin: json['cin'] as String? ?? '',
        mealType: MealType.values.firstWhere(
          (e) => e.name == json['mealType'],
          orElse: () => MealType.unknown,
        ),
      );

  RestoCheckIn copyWith({
    String? id,
    DateTime? timestamp,
    int? quantity,
    String? cin,
    MealType? mealType,
  }) {
    return RestoCheckIn(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      quantity: quantity ?? this.quantity,
      cin: cin ?? this.cin,
      mealType: mealType ?? this.mealType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoCheckIn &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a meal balance top-up / recharge transaction.
class RestoTopUp {
  final String id;
  final DateTime timestamp;
  final int mealCount;
  final String cin;
  final double costPerMeal;
  final double? explicitAmount;

  const RestoTopUp({
    required this.id,
    required this.timestamp,
    required this.mealCount,
    required this.cin,
    this.costPerMeal = 0.200,
    this.explicitAmount,
  });

  double get computedAmount => explicitAmount ?? (mealCount * costPerMeal);

  String get formattedAmount => '${computedAmount.toStringAsFixed(3)} DT';

  /// Converts top-up to an app-level ExpenseItem for budget synchronization.
  ExpenseItem toExpenseItem({String category = 'Campus Dining'}) {
    return ExpenseItem(
      id: 'resto-topup-$id',
      title: 'Recharge Resto U ($mealCount repas)',
      amount: computedAmount,
      category: category,
      date: timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'mealCount': mealCount,
        'cin': cin,
        'costPerMeal': costPerMeal,
        if (explicitAmount != null) 'explicitAmount': explicitAmount,
      };

  factory RestoTopUp.fromJson(Map<String, dynamic> json) => RestoTopUp(
        id: json['id'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        mealCount: (json['mealCount'] as num?)?.toInt() ?? 0,
        cin: json['cin'] as String? ?? '',
        costPerMeal: (json['costPerMeal'] as num?)?.toDouble() ?? 0.200,
        explicitAmount: (json['explicitAmount'] as num?)?.toDouble(),
      );

  RestoTopUp copyWith({
    String? id,
    DateTime? timestamp,
    int? mealCount,
    String? cin,
    double? costPerMeal,
    double? explicitAmount,
  }) {
    return RestoTopUp(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      mealCount: mealCount ?? this.mealCount,
      cin: cin ?? this.cin,
      costPerMeal: costPerMeal ?? this.costPerMeal,
      explicitAmount: explicitAmount ?? this.explicitAmount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestoTopUp && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

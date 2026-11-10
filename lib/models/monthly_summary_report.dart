import 'expense_item.dart';

/// Data model representing an archived monthly spending cycle report.
class MonthlySummaryReport {
  final String id;
  final String monthLabel; // e.g., "October 2026"
  final double budgetCap;
  final double totalSpent;
  final double totalSaved;
  final int transactionCount;
  final Map<String, double> categoryBreakdown; // dining, social, housing, books
  final List<ExpenseItem> archivedExpenses;

  MonthlySummaryReport({
    required this.id,
    required this.monthLabel,
    required this.budgetCap,
    required this.totalSpent,
    required this.totalSaved,
    required this.transactionCount,
    required this.categoryBreakdown,
    required this.archivedExpenses,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'monthLabel': monthLabel,
        'budgetCap': budgetCap,
        'totalSpent': totalSpent,
        'totalSaved': totalSaved,
        'transactionCount': transactionCount,
        'categoryBreakdown': categoryBreakdown,
        'archivedExpenses': archivedExpenses.map((e) => e.toJson()).toList(),
      };

  factory MonthlySummaryReport.fromJson(Map<String, dynamic> json) =>
      MonthlySummaryReport(
        id: json['id'] as String? ?? '',
        monthLabel: json['monthLabel'] as String? ?? '',
        budgetCap: (json['budgetCap'] as num?)?.toDouble() ?? 0.0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
        totalSaved: (json['totalSaved'] as num?)?.toDouble() ?? 0.0,
        transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
        categoryBreakdown:
            (json['categoryBreakdown'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, (v as num).toDouble()),
                ) ??
                {},
        archivedExpenses: (json['archivedExpenses'] as List<dynamic>?)
                ?.map((e) => ExpenseItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

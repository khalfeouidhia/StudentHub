/// Represents a student personal expense record with optional attached receipt photo.
class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? imagePath;

  const ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.imagePath,
  });

  bool get hasReceipt => imagePath != null && imagePath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String,
        date: DateTime.parse(json['date'] as String),
        imagePath: json['imagePath'] as String?,
      );

  ExpenseItem copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? imagePath,
    bool clearImage = false,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
    );
  }
}

/// Backwards-compatibility alias
typedef TransactionRecord = ExpenseItem;

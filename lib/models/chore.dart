// lib/models/chore.dart
class ChoreItem {
  final String id;
  final String title;
  final String assignedTo;
  final String dueDate;
  final bool isCompleted;
  final String category;

  const ChoreItem({
    required this.id,
    required this.title,
    required this.assignedTo,
    required this.dueDate,
    required this.isCompleted,
    this.category = 'Chores',
  });

  ChoreItem copyWith({
    String? id,
    String? title,
    String? assignedTo,
    String? dueDate,
    bool? isCompleted,
    String? category,
  }) {
    return ChoreItem(
      id: id ?? this.id,
      title: title ?? this.title,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'assignedTo': assignedTo,
        'dueDate': dueDate,
        'isCompleted': isCompleted,
        'category': category,
      };

  factory ChoreItem.fromJson(Map<String, dynamic> json) => ChoreItem(
        id: json['id'] as String,
        title: json['title'] as String,
        assignedTo: json['assignedTo'] as String,
        dueDate: json['dueDate'] as String,
        isCompleted: json['isCompleted'] as bool,
        category: (json['category'] as String?) ?? 'Chores',
      );
}

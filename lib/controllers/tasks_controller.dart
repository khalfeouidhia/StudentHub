import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chore.dart';

enum TaskCategoryFilter { all, academic, personal }

/// Manages solo student tasks and academic deadlines with reactive state and persistence.
class TasksController extends ChangeNotifier {
  static const _storageKey = 'tasks_items_v2';

  TaskCategoryFilter _filter = TaskCategoryFilter.all;
  bool _isLoaded = false;

  final List<ChoreItem> _tasks = [];

  TasksController() {
    _initFromStorage();
  }

  TaskCategoryFilter get filter => _filter;
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _tasks.isEmpty;

  List<ChoreItem> get allTasks => List.unmodifiable(_tasks);

  List<ChoreItem> get filteredTasks {
    switch (_filter) {
      case TaskCategoryFilter.all:
        return List.unmodifiable(_tasks);
      case TaskCategoryFilter.academic:
        return List.unmodifiable(
            _tasks.where((t) => t.category.toLowerCase().contains('acad')));
      case TaskCategoryFilter.personal:
        return List.unmodifiable(_tasks.where((t) =>
            t.category.toLowerCase().contains('person') ||
            t.category.toLowerCase().contains('chore')));
    }
  }

  int get allCount => _tasks.length;
  int get academicCount =>
      _tasks.where((t) => t.category.toLowerCase().contains('acad')).length;
  int get personalCount => _tasks
      .where((t) =>
          t.category.toLowerCase().contains('person') ||
          t.category.toLowerCase().contains('chore'))
      .length;

  // Compatibility getter
  int get choresCount => personalCount;

  /// Calculate completion rate (percentage). If empty, returns 0%.
  int get completionPercentage {
    if (_tasks.isEmpty) return 0;
    final done = _tasks.where((t) => t.isCompleted).length;
    return ((done / _tasks.length) * 100).round();
  }

  Future<void> _initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ??
        prefs.getStringList('tasks_items_v1');
    if (rawList != null) {
      _tasks.clear();
      for (final item in rawList) {
        try {
          _tasks.add(
              ChoreItem.fromJson(jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _tasks.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  /// Sets the active category filter tab.
  void setFilter(TaskCategoryFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  /// Toggles task completion state.
  void toggleTask(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      notifyListeners();
      _saveToStorage();
    }
  }

  /// Adds a new academic deadline or personal task.
  void addTask({
    required String title,
    required String category,
    required String dueDate,
    String assignedTo = 'Me',
  }) {
    _tasks.insert(
      0,
      ChoreItem(
        id: 'task-${DateTime.now().microsecondsSinceEpoch}-${_tasks.length}',
        title: title.trim(),
        assignedTo: assignedTo.trim().isEmpty ? 'Me' : assignedTo.trim(),
        dueDate: dueDate.trim().isEmpty ? 'Due soon' : dueDate.trim(),
        isCompleted: false,
        category: category,
      ),
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Updates an existing task by id.
  void updateTask({
    required String id,
    required String title,
    required String category,
    required String dueDate,
    String? assignedTo,
  }) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        title: title.trim(),
        category: category.trim(),
        dueDate: dueDate.trim().isEmpty ? 'Due soon' : dueDate.trim(),
        assignedTo: (assignedTo != null && assignedTo.trim().isNotEmpty)
            ? assignedTo.trim()
            : null,
      );
      notifyListeners();
      _saveToStorage();
    }
  }

  /// Deletes a task by id.
  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _saveToStorage();
  }

  /// Compatibility stub for legacy swap
  void swapAssignee(String taskId, String newAssignee) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(assignedTo: newAssignee);
      notifyListeners();
      _saveToStorage();
    }
  }

  /// Compatibility stub for legacy nudge
  String nudgeRoommate(String taskId) {
    return 'Task reminder set!';
  }

  /// Clears tasks to zero base.
  void clearAllTasks() {
    _tasks.clear();
    notifyListeners();
    _saveToStorage();
  }
}

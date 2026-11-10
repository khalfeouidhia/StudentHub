import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/auth_controller.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/controllers/tasks_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthController Solo Student Flow', () {
    test('initializes with clean zero-base defaults', () async {
      final auth = AuthController();
      await auth.init();

      expect(auth.isOnboarded, isFalse);
      expect(auth.userName, isEmpty);
      expect(auth.university, isEmpty);
      expect(auth.monthlyBudgetCap, equals(0.0));
      expect(auth.safeBufferTarget, equals(0.0));
      expect(auth.isInitialized, isTrue);
    });

    test('completes onboarding and persists data', () async {
      final auth = AuthController();
      await auth.init();

      await auth.completeOnboarding(
        name: 'Sami Ben Ali',
        university: 'ESPRIT - Software Engineering',
        email: 'sami@esprit.tn',
        pin: '1234',
        budgetCap: 500.0,
        safeBuffer: 100.0,
      );

      expect(auth.isOnboarded, isTrue);
      expect(auth.userName, equals('Sami Ben Ali'));
      expect(auth.university, equals('ESPRIT - Software Engineering'));
      expect(auth.monthlyBudgetCap, equals(500.0));
      expect(auth.safeBufferTarget, equals(100.0));
      expect(auth.verifyPin('1234'), isTrue);
      expect(auth.verifyPin('9999'), isFalse);
    });

    test('resetOnboarding resets state back to clean zero', () async {
      final auth = AuthController();
      await auth.init();
      await auth.completeOnboarding(
        name: 'Test Student',
        university: 'University of Tunis',
        pin: '0000',
        budgetCap: 300.0,
      );
      expect(auth.isOnboarded, isTrue);

      await auth.resetOnboarding();
      expect(auth.isOnboarded, isFalse);
      expect(auth.userName, isEmpty);
      expect(auth.monthlyBudgetCap, equals(0.0));
    });
  });

  group('BudgetController Zero-Base & Reactive Metrics', () {
    test('initializes at 0.000 DT and empty logs', () async {
      final budget = BudgetController();
      expect(budget.spentSoFar, equals(0.0));
      expect(budget.isEmpty, isTrue);
      expect(budget.transactions, isEmpty);
      expect(budget.progressFraction, equals(0.0));
      expect(budget.usagePercentage, equals(0));

      for (final cat in budget.categories) {
        expect(cat.amount, equals(0.0));
      }
    });

    test('adding expenses updates totals and categories dynamically', () async {
      final budget = BudgetController();
      await budget.setBudgetCap(400.0, 50.0);

      budget.addExpense(
        title: 'Supermarket Groceries',
        amount: 45.500,
        category: 'Food & Dining',
      );
      budget.addExpense(
        title: 'Algorithms Book',
        amount: 30.000,
        category: 'Books & Study',
      );

      expect(budget.spentSoFar, closeTo(75.500, 0.001));
      expect(budget.isEmpty, isFalse);
      expect(budget.transactions.length, equals(2));
      expect(budget.remainingBudget, closeTo(324.500, 0.001));

      final foodCat =
          budget.categories.firstWhere((c) => c.name == 'Food & Dining');
      expect(foodCat.amount, closeTo(45.500, 0.001));

      final bookCat =
          budget.categories.firstWhere((c) => c.name == 'Books & Study');
      expect(bookCat.amount, closeTo(30.000, 0.001));
    });

    test('clearAllExpenses resets transactions back to zero-base', () async {
      final budget = BudgetController();
      budget.addExpense(
          title: 'Coffee', amount: 3.500, category: 'Leisure & Coffee');
      expect(budget.transactions.length, equals(1));

      budget.clearAllExpenses();
      expect(budget.transactions, isEmpty);
      expect(budget.spentSoFar, equals(0.0));
      expect(budget.isEmpty, isTrue);
    });

    test('setBudgetCap sanitizes negative and non-finite cap and buffer values',
        () async {
      final budget = BudgetController();
      await budget.setBudgetCap(-100.0, -50.0);
      expect(budget.totalCap, equals(0.0));
      expect(budget.safeBufferTarget, equals(0.0));

      await budget.setBudgetCap(350.0, 75.0);
      expect(budget.totalCap, equals(350.0));
      expect(budget.safeBufferTarget, equals(75.0));
    });
  });

  group('TasksController Academic & Personal Deadlines', () {
    test('starts at 0% complete with empty logs', () {
      final tasks = TasksController();
      expect(tasks.allCount, equals(0));
      expect(tasks.completionPercentage, equals(0));
      expect(tasks.isEmpty, isTrue);
    });

    test('categorizes tasks correctly and calculates completion rate', () {
      final tasks = TasksController();

      tasks.addTask(
        title: 'Operating Systems Homework',
        category: 'Academic',
        dueDate: 'Tomorrow',
      );
      tasks.addTask(
        title: 'Grocery shopping',
        category: 'Personal',
        dueDate: 'Saturday',
      );

      expect(tasks.allCount, equals(2));
      expect(tasks.academicCount, equals(1));
      expect(tasks.personalCount, equals(1));
      expect(tasks.completionPercentage, equals(0));

      // Toggle first task done
      final firstId = tasks.allTasks.first.id;
      tasks.toggleTask(firstId);
      expect(tasks.completionPercentage, equals(50));

      // Toggle second task done
      final secondId = tasks.allTasks[1].id;
      tasks.toggleTask(secondId);
      expect(tasks.completionPercentage, equals(100));
    });

    test('filtering returns proper subset', () {
      final tasks = TasksController();
      tasks.addTask(title: 'Exam 1', category: 'Academic', dueDate: 'Soon');
      tasks.addTask(
          title: 'Room Cleaning', category: 'Personal', dueDate: 'Sunday');

      tasks.setFilter(TaskCategoryFilter.academic);
      expect(tasks.filteredTasks.length, equals(1));
      expect(tasks.filteredTasks.first.title, equals('Exam 1'));

      tasks.setFilter(TaskCategoryFilter.personal);
      expect(tasks.filteredTasks.length, equals(1));
      expect(tasks.filteredTasks.first.title, equals('Room Cleaning'));

      tasks.setFilter(TaskCategoryFilter.all);
      expect(tasks.filteredTasks.length, equals(2));
    });
  });
}

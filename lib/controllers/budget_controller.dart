import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/expense_item.dart';
import '../models/monthly_summary_report.dart';
export '../models/expense_item.dart';
export '../models/monthly_summary_report.dart';

class SpendingCategory {
  final String name;
  final double amount;
  final Color color;
  final IconData icon;

  const SpendingCategory({
    required this.name,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

/// Compatibility alias
typedef ExpensesController = BudgetController;

/// Manages solo student personal expenses, category breakdowns, monthly budget allowance,
/// and automated multi-month archiving & rollover.
class BudgetController extends ChangeNotifier {
  static const _storageKey = 'budget_transactions_v2';
  static const _capKey = 'budget_total_cap_v1';
  static const _bufferKey = 'budget_safe_buffer_v1';
  static const _archiveStorageKey = 'budget_archived_transactions_v1';
  static const _archiveCapsKey = 'budget_archived_caps_v1';
  static const _activeMonthKey = 'budget_active_month_v1';
  static const _monthlyReportsKey = 'monthly_archives_json';

  double _totalCap = 0.000;
  double _safeBufferTarget = 0.000;
  final double _houseKittyPool = 0.000; // Compatibility
  final String _selectedMonth = 'Active Cycle';
  bool _isLoaded = false;

  final List<TransactionRecord> _transactions = [];
  final Map<String, List<TransactionRecord>> _monthlyArchive = {};
  final Map<String, double> _archivedCaps = {};
  final List<MonthlySummaryReport> _monthlyReports = [];
  String _currentActiveMonth = '';
  bool _pendingRollover = false;
  String? _rolloverPreviousMonth;
  String? _rolloverNewMonth;

  BudgetController() {
    _initFromStorage();
  }

  double get totalCap => _totalCap;
  double get activeBudgetCap => _totalCap;
  double get safeBufferTarget => _safeBufferTarget;
  double get houseKittyPool => _houseKittyPool;
  String get selectedMonth => _selectedMonth;
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _transactions.isEmpty;

  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  List<TransactionRecord> get allTransactions =>
      List.unmodifiable(_transactions);
  List<TransactionRecord> get activeExpenses =>
      List.unmodifiable(_transactions);

  Map<String, List<TransactionRecord>> get monthlyArchive =>
      Map.unmodifiable(_monthlyArchive);
  Map<String, double> get archivedCaps => Map.unmodifiable(_archivedCaps);
  List<MonthlySummaryReport> get monthlyReports =>
      List.unmodifiable(_monthlyReports);

  String get currentActiveMonth => _currentActiveMonth;
  String get activeMonthLabel => _currentActiveMonth.isNotEmpty
      ? formatMonthLabel(_currentActiveMonth)
      : formatMonthLabel(monthKeyFromDate(DateTime.now()));

  bool get pendingRollover => _pendingRollover;
  String? get rolloverPreviousMonth => _rolloverPreviousMonth;
  String? get rolloverNewMonth => _rolloverNewMonth;

  /// Returns sorted list of archived month keys in reverse chronological order (e.g. ['2026-09', '2026-08']).
  List<String> get availableArchivedMonths {
    final keys = _monthlyArchive.keys.toList();
    keys.sort((a, b) => b.compareTo(a));
    return keys;
  }

  double get spentSoFar =>
      _transactions.fold(0.0, (sum, tx) => sum + tx.amount);

  double get remainingBudget =>
      (_totalCap - spentSoFar).clamp(0.0, double.infinity);

  double get budgetLeftRatio =>
      _totalCap > 0 ? (remainingBudget / _totalCap).clamp(0.0, 1.0) : 0.0;

  int get budgetLeftPct => (budgetLeftRatio * 100).round();

  double get safeBuffer {
    if (_safeBufferTarget > 0.0) {
      return _safeBufferTarget;
    }
    return remainingBudget;
  }

  double get progressFraction =>
      (_totalCap > 0 ? (spentSoFar / _totalCap) : 0.0).clamp(0.0, 1.0);

  int get usagePercentage =>
      _totalCap > 0 ? ((spentSoFar / _totalCap) * 100).round() : 0;

  /// Total spending logged today
  double get todaySpent {
    final now = DateTime.now();
    return _transactions.fold(0.0, (sum, tx) {
      if (tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day) {
        return sum + tx.amount;
      }
      return sum;
    });
  }

  /// Dynamic daily safe spend based on remaining allowance and remaining days in month.
  double get dailySafeSpend {
    if (_totalCap <= 0.0) return 0.0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (daysInMonth - now.day + 1).clamp(1, 31);
    final remaining = (_totalCap - spentSoFar).clamp(0.0, double.infinity);
    return remaining / daysRemaining;
  }

  /// Weekly spending totals mapped by weekday (1 = Monday, 7 = Sunday).
  Map<int, double> get weeklySpending {
    final map = <int, double>{
      1: 0.0,
      2: 0.0,
      3: 0.0,
      4: 0.0,
      5: 0.0,
      6: 0.0,
      7: 0.0
    };
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    for (final tx in _transactions) {
      if (!tx.date.isBefore(monday) && tx.date.isBefore(nextMonday)) {
        map[tx.date.weekday] = (map[tx.date.weekday] ?? 0.0) + tx.amount;
      }
    }
    return map;
  }

  /// 4-Category Payly Ratios for Donut Chart
  double get diningRatio => spentSoFar > 0
      ? (getCategoryTotal('dining') / spentSoFar).clamp(0.0, 1.0)
      : 0.0;
  double get socialRatio => spentSoFar > 0
      ? (getCategoryTotal('social') / spentSoFar).clamp(0.0, 1.0)
      : 0.0;
  double get housingRatio => spentSoFar > 0
      ? (getCategoryTotal('housing') / spentSoFar).clamp(0.0, 1.0)
      : 0.0;
  double get booksRatio => spentSoFar > 0
      ? (getCategoryTotal('books') / spentSoFar).clamp(0.0, 1.0)
      : 0.0;

  /// Helper to get real total spent for a specific category name or alias.
  double getCategoryTotal(String name) {
    double total = 0.0;
    final target = name.toLowerCase().trim();
    for (final tx in _transactions) {
      final cat = tx.category.toLowerCase().trim();
      if (cat == target ||
          (target.contains('dining') &&
              (cat.contains('dining') ||
                  cat.contains('food') ||
                  cat.contains('caf'))) ||
          (target.contains('food') &&
              (cat.contains('dining') || cat.contains('food'))) ||
          (target.contains('housing') &&
              (cat.contains('housing') ||
                  cat.contains('rent') ||
                  cat.contains('util'))) ||
          (target.contains('books') &&
              (cat.contains('books') ||
                  cat.contains('study') ||
                  cat.contains('tech'))) ||
          (target.contains('study') &&
              (cat.contains('books') || cat.contains('study'))) ||
          (target.contains('social') &&
              (cat.contains('social') ||
                  cat.contains('transit') ||
                  cat.contains('leisure') ||
                  cat.contains('coffee'))) ||
          (target.contains('leisure') &&
              (cat.contains('social') ||
                  cat.contains('leisure') ||
                  cat.contains('coffee')))) {
        total += tx.amount;
      }
    }
    return total;
  }

  String get topCategoryName {
    final totals = {
      'Campus Dining': getCategoryTotal('dining'),
      'Social & Transit': getCategoryTotal('social'),
      'Housing & Util.': getCategoryTotal('housing'),
      'Books & Tech': getCategoryTotal('books'),
    };
    String top = 'Campus Dining';
    double maxVal = -1.0;
    totals.forEach((k, v) {
      if (v > maxVal) {
        maxVal = v;
        top = k;
      }
    });
    return top;
  }

  List<SpendingCategory> get categories {
    final diningVal = getCategoryTotal('dining');
    final booksVal = getCategoryTotal('books');
    final housingVal = getCategoryTotal('housing');
    final socialVal = getCategoryTotal('social');

    return [
      SpendingCategory(
        name: 'Food & Dining',
        amount: diningVal,
        color: AppColors.categoryDining,
        icon: Icons.restaurant_outlined,
      ),
      SpendingCategory(
        name: 'Books & Study',
        amount: booksVal,
        color: AppColors.categoryBooks,
        icon: Icons.menu_book_outlined,
      ),
      SpendingCategory(
        name: 'Housing',
        amount: housingVal,
        color: AppColors.categoryHousing,
        icon: Icons.home_outlined,
      ),
      SpendingCategory(
        name: 'Leisure & Coffee',
        amount: socialVal,
        color: AppColors.categorySocial,
        icon: Icons.local_cafe_outlined,
      ),
    ];
  }

  /// Converts DateTime to month key string format, e.g. "2026-10"
  static String monthKeyFromDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  /// Formats a month key (e.g. "2026-10") into compact display "Oct 2026"
  static String formatMonthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = parts[0];
    final monthInt = int.tryParse(parts[1]) ?? 1;
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (monthInt >= 1 && monthInt <= 12) {
      return '${monthNames[monthInt - 1]} $year';
    }
    return key;
  }

  /// Formats a month key into full month name (e.g. "October 2026")
  static String formatFullMonthName(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = parts[0];
    final monthInt = int.tryParse(parts[1]) ?? 1;
    const fullMonthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    if (monthInt >= 1 && monthInt <= 12) {
      return '${fullMonthNames[monthInt - 1]} $year';
    }
    return key;
  }

  Future<void> _initFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCap =
        prefs.getDouble(_capKey) ?? prefs.getDouble('userBudgetCap');
    if (savedCap != null && savedCap.isFinite && savedCap >= 0.0) {
      _totalCap = savedCap;
    }
    final savedBuffer =
        prefs.getDouble(_bufferKey) ?? prefs.getDouble('userSafeBuffer');
    if (savedBuffer != null && savedBuffer.isFinite && savedBuffer >= 0.0) {
      _safeBufferTarget = savedBuffer;
    }

    final rawList = prefs.getStringList(_storageKey) ??
        prefs.getStringList('budget_transactions_v1');
    if (rawList != null) {
      _transactions.clear();
      for (final item in rawList) {
        try {
          _transactions.add(TransactionRecord.fromJson(
              jsonDecode(item) as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    // Load monthly archives
    final rawArchive = prefs.getString(_archiveStorageKey);
    if (rawArchive != null) {
      try {
        final decoded = jsonDecode(rawArchive) as Map<String, dynamic>;
        _monthlyArchive.clear();
        decoded.forEach((k, v) {
          if (v is List) {
            _monthlyArchive[k] = v
                .map((item) =>
                    TransactionRecord.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        });
      } catch (_) {}
    }

    // Load archived caps
    final rawCaps = prefs.getString(_archiveCapsKey);
    if (rawCaps != null) {
      try {
        final decoded = jsonDecode(rawCaps) as Map<String, dynamic>;
        _archivedCaps.clear();
        decoded.forEach((k, v) {
          _archivedCaps[k] = (v as num).toDouble();
        });
      } catch (_) {}
    }

    // Load serialized MonthlySummaryReports
    final rawReports = prefs.getString(_monthlyReportsKey);
    if (rawReports != null) {
      try {
        final decoded = jsonDecode(rawReports) as List<dynamic>;
        _monthlyReports.clear();
        for (final item in decoded) {
          _monthlyReports
              .add(MonthlySummaryReport.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    // Detect month boundaries
    final currentKey = monthKeyFromDate(DateTime.now());
    final savedActiveMonth = prefs.getString(_activeMonthKey);

    if (savedActiveMonth == null || savedActiveMonth.isEmpty) {
      _currentActiveMonth = currentKey;
      await prefs.setString(_activeMonthKey, currentKey);
    } else if (savedActiveMonth != currentKey) {
      _currentActiveMonth = savedActiveMonth;
      _pendingRollover = true;
      _rolloverPreviousMonth = savedActiveMonth;
      _rolloverNewMonth = currentKey;
    } else {
      _currentActiveMonth = savedActiveMonth;
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Sets the student's personal budget cap and safe buffer target.
  Future<void> setBudgetCap(double cap, double buffer) async {
    final sanitizedCap = (cap.isFinite ? cap : 0.0).clamp(0.0, double.infinity);
    final sanitizedBuffer =
        (buffer.isFinite ? buffer : 0.0).clamp(0.0, double.infinity);
    _totalCap = sanitizedCap;
    _safeBufferTarget = sanitizedBuffer;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_capKey, sanitizedCap);
    await prefs.setDouble('userBudgetCap', sanitizedCap);
    await prefs.setDouble(_bufferKey, sanitizedBuffer);
    await prefs.setDouble('userSafeBuffer', sanitizedBuffer);
  }

  /// Adds extra money directly to the current active budget cap.
  Future<void> addMoney(double amount) async {
    if (amount <= 0 || !amount.isFinite) return;
    _totalCap += amount;
    notifyListeners();
    await _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _transactions.map((tx) => jsonEncode(tx.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
    await prefs.setDouble(_capKey, _totalCap);
    await prefs.setDouble(_bufferKey, _safeBufferTarget);
  }

  Future<void> _saveArchiveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encodedArchive = {};
    _monthlyArchive.forEach((k, v) {
      encodedArchive[k] = v.map((tx) => tx.toJson()).toList();
    });
    await prefs.setString(_archiveStorageKey, jsonEncode(encodedArchive));
    await prefs.setString(_archiveCapsKey, jsonEncode(_archivedCaps));
    await prefs.setString(_activeMonthKey, _currentActiveMonth);

    // Persist monthly reports
    final reportsJson =
        jsonEncode(_monthlyReports.map((r) => r.toJson()).toList());
    await prefs.setString(_monthlyReportsKey, reportsJson);
  }

  /// Adds a new personal expense record and recalculates budget metrics.
  void addExpense({
    required String title,
    required double amount,
    required String category,
    DateTime? date,
    String? imagePath,
  }) {
    final sanitizedAmount =
        (amount.isFinite ? amount : 0.0).clamp(0.0, double.infinity);
    _transactions.insert(
      0,
      TransactionRecord(
        id: 'tx-${DateTime.now().microsecondsSinceEpoch}-${_transactions.length}',
        title: title.trim(),
        amount: sanitizedAmount,
        category: category,
        date: date ?? DateTime.now(),
        imagePath: imagePath,
      ),
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Updates an existing transaction record by id and recalculates metrics.
  void updateExpense({
    required String id,
    required String title,
    required double amount,
    required String category,
    DateTime? date,
    String? imagePath,
    bool clearImage = false,
  }) {
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final sanitizedAmount =
        (amount.isFinite ? amount : 0.0).clamp(0.0, double.infinity);
    final existing = _transactions[index];
    _transactions[index] = existing.copyWith(
      title: title.trim(),
      amount: sanitizedAmount,
      category: category,
      date: date ?? existing.date,
      imagePath: imagePath,
      clearImage: clearImage,
    );
    notifyListeners();
    _saveToStorage();
  }

  /// Deletes a transaction by id.
  void deleteExpense(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
    _saveToStorage();
  }

  /// Starts a fresh new month with zero-reset: archives the closing month report,
  /// clears current expenses, establishes new budget cap, and saves state.
  Future<void> startNewMonth({
    required String nextMonthLabel,
    required double newBudgetCap,
  }) async {
    final pastMonthKey = _currentActiveMonth.isNotEmpty
        ? _currentActiveMonth
        : monthKeyFromDate(DateTime.now());

    // 1. Generate full monthly summary report
    final report = MonthlySummaryReport(
      id: 'rep-${DateTime.now().millisecondsSinceEpoch}',
      monthLabel: formatFullMonthName(pastMonthKey),
      budgetCap: _totalCap,
      totalSpent: spentSoFar,
      totalSaved: (remainingBudget > 0) ? remainingBudget : 0.0,
      transactionCount: _transactions.length,
      categoryBreakdown: {
        'dining': getCategoryTotal('dining'),
        'social': getCategoryTotal('social'),
        'housing': getCategoryTotal('housing'),
        'books': getCategoryTotal('books'),
      },
      archivedExpenses: List<ExpenseItem>.from(_transactions),
    );
    _monthlyReports.insert(0, report);

    // 2. Archive legacy maps
    _monthlyArchive[pastMonthKey] = List<TransactionRecord>.from(_transactions);
    _archivedCaps[pastMonthKey] = _totalCap;

    // 3. Zero-reset: clear current expenses and reset trackers
    _transactions.clear();
    _totalCap = (newBudgetCap.isFinite ? newBudgetCap : 0.0)
        .clamp(0.0, double.infinity);

    // Derive or set next month key
    _currentActiveMonth = nextMonthLabel.contains('-')
        ? nextMonthLabel
        : monthKeyFromDate(DateTime.now());
    _pendingRollover = false;
    _rolloverPreviousMonth = null;
    _rolloverNewMonth = null;

    notifyListeners();
    await _saveArchiveToStorage();
    await _saveToStorage();
  }

  /// Performs an automated or user-confirmed month rollover.
  Future<void> performMonthRollover(
      String newMonthKey, double newBudgetCap) async {
    await startNewMonth(
      nextMonthLabel: newMonthKey,
      newBudgetCap: newBudgetCap,
    );
  }

  /// Adds an archived month with its budget cap and transactions (used for migration, tests, and historical import).
  Future<void> addArchivedMonth({
    required String monthKey,
    required double cap,
    required List<TransactionRecord> transactions,
  }) async {
    _monthlyArchive[monthKey] = List<TransactionRecord>.from(transactions);
    _archivedCaps[monthKey] = cap;
    notifyListeners();
    await _saveArchiveToStorage();
  }

  /// Retrieves the total amount spent in a specific archived month.
  double getArchivedTotal(String monthKey) {
    final txs = _monthlyArchive[monthKey] ?? [];
    return txs.fold<double>(0.0, (acc, tx) => acc + tx.amount);
  }

  /// Retrieves the budget cap set for a specific archived month.
  double getArchivedCap(String monthKey) {
    return _archivedCaps[monthKey] ?? 0.0;
  }

  /// Retrieves all transaction records saved for an archived month.
  List<TransactionRecord> getArchivedTransactions(String monthKey) {
    return List.unmodifiable(_monthlyArchive[monthKey] ?? []);
  }

  /// Aggregates category spending totals for a given archived month.
  Map<String, double> getArchivedCategoryTotals(String monthKey) {
    final txs = _monthlyArchive[monthKey] ?? [];
    final Map<String, double> totals = {};
    for (final tx in txs) {
      final cat = tx.category;
      totals[cat] = (totals[cat] ?? 0.0) + tx.amount;
    }
    return totals;
  }

  /// Simulates month rollover for developer testing or interactive user preview.
  Future<void> simulateMonthRollover({double? nextCap}) async {
    final parts = _currentActiveMonth.split('-');
    int y = int.tryParse(parts.firstOrNull ?? '') ?? DateTime.now().year;
    int m = int.tryParse(parts.lastOrNull ?? '') ?? DateTime.now().month;
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
    final nextMonthKey = '$y-${m.toString().padLeft(2, '0')}';
    await startNewMonth(
      nextMonthLabel: nextMonthKey,
      newBudgetCap: nextCap ?? (_totalCap > 0 ? _totalCap : 250.0),
    );
  }

  /// Clears all active transactions to zero-base.
  void clearAllExpenses() {
    _transactions.clear();
    notifyListeners();
    _saveToStorage();
  }

  /// Loads sample realistic expenses for demo purposes if chosen by user.
  Future<void> loadSampleData() async {
    _transactions.clear();
    final now = DateTime.now();
    _transactions.addAll([
      TransactionRecord(
        id: 'tx-sample-1',
        title: 'Campus Cafeteria Lunch',
        amount: 8.500,
        category: 'Campus Dining',
        date: now,
      ),
      TransactionRecord(
        id: 'tx-sample-2',
        title: 'Monthly Transit Pass',
        amount: 22.000,
        category: 'Social & Transit',
        date: now.subtract(const Duration(days: 1)),
      ),
      TransactionRecord(
        id: 'tx-sample-3',
        title: 'Algorithms Textbook & Notebook',
        amount: 34.500,
        category: 'Books & Tech',
        date: now.subtract(const Duration(days: 2)),
      ),
      TransactionRecord(
        id: 'tx-sample-4',
        title: 'Studio Wi-Fi Share',
        amount: 15.000,
        category: 'Housing & Util.',
        date: now.subtract(const Duration(days: 3)),
      ),
    ]);
    if (_totalCap <= 0) {
      _totalCap = 250.0;
    }
    notifyListeners();
    await _saveToStorage();
  }
}

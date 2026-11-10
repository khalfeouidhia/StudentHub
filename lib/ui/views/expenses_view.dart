import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/roulette_number_text.dart';
import '../../controllers/budget_controller.dart';
import '../../features/campus_resto/controllers/campus_resto_controller.dart';
import '../../features/campus_resto/services/resto_budget_sync_service.dart';
import 'receipt_entry_sheet.dart';
import 'receipt_viewer_dialog.dart';

typedef ExpensesScreen = ExpensesView;

/// Screen 2: Expenses & Outflows ("Minty Nest" Google Stitch Design)
class ExpensesView extends StatefulWidget {
  const ExpensesView({super.key});

  @override
  State<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends State<ExpensesView> {
  String _selectedPeriod = 'Monthly';
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSyncing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddExpenseModal(BuildContext context, BudgetController budget) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Campus Dining & Groceries';
    final categories = [
      'Campus Dining & Groceries',
      'Housing & Shared Utilities',
      'Books, Course Tech & Tools',
      'Social, Club Dues & Commute',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx2).size.height * 0.85),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Record Outflow',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Expense Description',
                      hintText: 'e.g. Campus Coffee, Lab Manual, Groceries',
                      labelStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Amount (DT)',
                      hintText: 'e.g. 14.500',
                      labelStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Category',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                sel ? AppColors.primary : AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color:
                                  sel ? Colors.white : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final val =
                            double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                        if (title.isNotEmpty && val > 0) {
                          budget.addExpense(
                            title: title,
                            amount: val,
                            category: selectedCategory,
                          );
                          Navigator.pop(ctx2);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Logged ${val.toStringAsFixed(3)} DT for $title'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Save Expense',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Auto-Sync Resto U Recharges',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.deepPine,
                        side: const BorderSide(color: AppColors.deepPine),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx2);
                        CampusRestoController? resto;
                        try {
                          resto = context.read<CampusRestoController>();
                        } catch (_) {}
                        await _syncMealCardRecharges(context, budget, resto);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditExpenseModal(
    BuildContext context,
    BudgetController budget,
    TransactionRecord tx,
  ) {
    final titleCtrl = TextEditingController(text: tx.title);
    final amountCtrl =
        TextEditingController(text: tx.amount.toStringAsFixed(3));
    String selectedCategory = tx.category;
    DateTime selectedDate = tx.date;
    String? currentImage = tx.imagePath;
    bool clearImage = false;

    final categories = [
      'Campus Dining & Groceries',
      'Housing & Shared Utilities',
      'Books, Course Tech & Tools',
      'Social, Club Dues & Commute',
    ];
    if (!categories.contains(selectedCategory)) {
      categories.insert(0, selectedCategory);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx2).size.height * 0.9,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Edit Transaction',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                        tooltip: 'Delete Outflow',
                        onPressed: () {
                          budget.deleteExpense(tx.id);
                          Navigator.pop(ctx2);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Transaction deleted and metrics updated'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Expense Description',
                      hintText: 'e.g. Campus Coffee, Lab Manual',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount (DT)',
                      hintText: 'e.g. 14.500',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Category',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final sel = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                sel ? AppColors.primary : AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color:
                                  sel ? Colors.white : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  // Date Picker Row
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx2,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  color: AppColors.primary, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                'Transaction Date',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Receipt Photo Section
                  if (currentImage != null && !clearImage) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(currentImage!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: AppColors.surfaceHigh,
                                child: const Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Receipt Attached',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Physical proof saved',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined,
                                color: AppColors.primary, size: 20),
                            tooltip: 'View Receipt',
                            onPressed: () => ReceiptViewerDialog.show(
                              context,
                              TransactionRecord(
                                id: tx.id,
                                title: titleCtrl.text,
                                amount: double.tryParse(amountCtrl.text) ??
                                    tx.amount,
                                category: selectedCategory,
                                date: selectedDate,
                                imagePath: currentImage,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            tooltip: 'Remove Receipt',
                            onPressed: () {
                              setModalState(() {
                                clearImage = true;
                                currentImage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final photo = await picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                          );
                          if (photo != null) {
                            setModalState(() {
                              currentImage = photo.path;
                              clearImage = false;
                            });
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Attach Receipt Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx2),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final parsed = double.tryParse(
                                amountCtrl.text.replaceAll(',', '.'));
                            final desc = titleCtrl.text.trim();
                            if (desc.isEmpty || parsed == null || parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please enter valid description & amount')),
                              );
                              return;
                            }
                            budget.updateExpense(
                              id: tx.id,
                              title: desc,
                              amount: parsed,
                              category: selectedCategory,
                              date: selectedDate,
                              imagePath: currentImage,
                              clearImage: clearImage,
                            );
                            Navigator.pop(ctx2);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        budget.deleteExpense(tx.id);
                        Navigator.pop(ctx2);
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 18),
                      label: const Text(
                        'Delete Transaction',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    BudgetController? budget;
    CampusRestoController? restoController;
    try {
      budget = context.watch<BudgetController>();
    } catch (_) {}
    try {
      restoController = context.watch<CampusRestoController>();
    } catch (_) {}

    final totalSpent = budget?.spentSoFar ?? 0.0;
    final transactions = budget?.allTransactions ?? [];
    final now = DateTime.now();
    final daysElapsed = math.max(1, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAverage = totalSpent / daysElapsed;
    final projectedMonthEnd = (totalSpent / daysElapsed) * daysInMonth;

    // Filter transactions based on _selectedPeriod and _customDateRange
    List<TransactionRecord> periodFiltered = transactions;
    if (_customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year,
          _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year,
          _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      periodFiltered = transactions
          .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
          .toList();
    } else if (_selectedPeriod == 'Daily') {
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
      periodFiltered = transactions
          .where(
              (t) => !t.date.isBefore(todayStart) && !t.date.isAfter(todayEnd))
          .toList();
    } else if (_selectedPeriod == 'Weekly') {
      final weekAgo = now.subtract(const Duration(days: 7));
      periodFiltered =
          transactions.where((t) => t.date.isAfter(weekAgo)).toList();
    }

    final filteredTransactions = periodFiltered.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.deepPine,
      floatingActionButton: _buildThemedFab(context, budget),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDeepPineHeader(
                  context, budget, totalSpent, dailyAverage, projectedMonthEnd),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(38),
                    topRight: Radius.circular(38),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(38),
                    topRight: Radius.circular(38),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildPeriodSelectorPills(),
                        const SizedBox(height: 14),
                        _buildAutoSyncBanner(context, budget, restoController),
                        const SizedBox(height: 16),
                        _buildItemizedCategorySection(
                            totalSpent, filteredTransactions),
                        const SizedBox(height: 18),
                        _buildTransactionsSection(budget, filteredTransactions),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeepPineHeader(
    BuildContext context,
    BudgetController? budget,
    double totalSpent,
    double dailyAverage,
    double projectedMonthEnd,
  ) {
    return Container(
      color: AppColors.deepPine,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses & Outflows',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'StudentHub Outflows',
                      style: TextStyle(
                        color: AppColors.softSage,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final now = DateTime.now();
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(now.year - 1),
                            lastDate: DateTime(now.year + 1),
                            initialDateRange: _customDateRange ??
                                DateTimeRange(
                                  start: DateTime(now.year, now.month, 1),
                                  end: DateTime(now.year, now.month + 1, 0),
                                ),
                          );
                          if (picked != null) {
                            setState(() {
                              _customDateRange = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                _customDateRange != null
                                    ? '${_customDateRange!.start.day}/${_customDateRange!.start.month} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}'
                                    : 'Date Range',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (budget != null)
                            _showAddExpenseModal(context, budget);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.vibrantGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  color: AppColors.darkForest, size: 14),
                              SizedBox(width: 2),
                              Text(
                                'Add Expense',
                                style: TextStyle(
                                  color: AppColors.darkForest,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'OCTOBER TOTAL OUTFLOW',
            style: TextStyle(
              color: AppColors.softSage,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RouletteNumberText(
              value: totalSpent,
              suffix: ' DT',
              decimalDigits: 3,
              isHeader: true,
              wholeStyle: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              decimalStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.softSage,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF264A3B),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.midMoss.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.trending_up_rounded,
                              color: AppColors.vibrantGreen, size: 12),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'DAILY AVERAGE',
                              style: TextStyle(
                                color: AppColors.softSage,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RouletteNumberText(
                          value: dailyAverage,
                          suffix: ' DT',
                          decimalDigits: 3,
                          isHeader: true,
                          wholeStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          decimalStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.softSage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF264A3B),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.midMoss.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined,
                              color: AppColors.iconBlue, size: 12),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'PROJECTED END',
                              style: TextStyle(
                                color: AppColors.softSage,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RouletteNumberText(
                          value: projectedMonthEnd,
                          suffix: ' DT',
                          decimalDigits: 3,
                          isHeader: true,
                          wholeStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          decimalStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.softSage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelectorPills() {
    final periods = ['Daily', 'Weekly', 'Monthly'];
    return Row(
      children: periods.map((p) {
        final isSelected = (_selectedPeriod == p && _customDateRange == null);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPeriod = p;
                _customDateRange = null;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? AppColors.vibrantGreen : AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.vibrantGreen
                      : AppColors.sandCream.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: Text(
                  p,
                  style: GoogleFonts.plusJakartaSans(
                    color:
                        isSelected ? AppColors.darkForest : AppColors.darkOlive,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAutoSyncBanner(BuildContext context, BudgetController? budget,
      CampusRestoController? restoController) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.vibrantGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_rounded,
                color: AppColors.deepPine, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meal Card Recharges Auto-Sync',
                  style: TextStyle(
                    color: AppColors.darkForest,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Synchronize university cafeteria top-ups & recharges',
                  style: TextStyle(
                    color: AppColors.softSage,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ElevatedButton(
                onPressed: _isSyncing
                    ? null
                    : () async {
                        if (budget != null) {
                          await _syncMealCardRecharges(
                              context, budget, restoController);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPine,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(60, 30),
                ),
                child: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Sync',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedCategorySection(
      double totalSpent, List<TransactionRecord> transactions) {
    double dining = 0.0;
    double groceries = 0.0;
    double housing = 0.0;
    double transport = 0.0;

    for (final tx in transactions) {
      final text = '${tx.category.toLowerCase()} ${tx.title.toLowerCase()}';
      if (text.contains('grocer') ||
          text.contains('pantry') ||
          text.contains('market') ||
          text.contains('supermarket')) {
        groceries += tx.amount;
      } else if (text.contains('food') ||
          text.contains('dining') ||
          text.contains('resto') ||
          text.contains('meal') ||
          text.contains('recharge') ||
          text.contains('top-up') ||
          text.contains('ticket') ||
          text.contains('cafeteria')) {
        dining += tx.amount;
      } else if (text.contains('rent') ||
          text.contains('housing') ||
          text.contains('dorm') ||
          text.contains('room')) {
        housing += tx.amount;
      } else {
        transport += tx.amount;
      }
    }

    final categories = [
      (
        title: 'Food & Dining / Resto U',
        subtitle: 'Resto U meals, ticket recharges & dining',
        amount: dining,
        icon: Icons.restaurant_rounded,
        color: AppColors.deepPine,
        badge: 'Synced with Top-ups',
      ),
      (
        title: 'Groceries & Pantry',
        subtitle: 'Supermarkets, pantry & ingredients',
        amount: groceries,
        icon: Icons.shopping_cart_outlined,
        color: AppColors.vibrantGreen,
        badge: 'Essentials',
      ),
      (
        title: 'Rent & Housing',
        subtitle: 'Dorm rent, electricity & Wi-Fi',
        amount: housing,
        icon: Icons.home_outlined,
        color: AppColors.iconBlue,
        badge: 'Fixed',
      ),
      (
        title: 'Transport & Utilities',
        subtitle: 'Transit pass, bus, metro & phone',
        amount: transport,
        icon: Icons.directions_subway_outlined,
        color: const Color(0xFFD97706),
        badge: 'Commute',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORY BREAKDOWN',
          style: TextStyle(
            color: AppColors.softSage,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...categories.map((cat) {
          final progress =
              totalSpent > 0 ? (cat.amount / totalSpent).clamp(0.0, 1.0) : 0.0;
          final pct = (progress * 100).round();
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.title,
                            style: const TextStyle(
                              color: AppColors.darkForest,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            cat.subtitle,
                            style: const TextStyle(
                              color: AppColors.softSage,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: RouletteNumberText(
                          value: cat.amount,
                          suffix: ' DT',
                          decimalDigits: 3,
                          wholeStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkForest,
                          ),
                          decimalStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.softSage,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 5,
                          color: AppColors.surfaceLow,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress,
                            child: Container(color: cat.color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        color: AppColors.softSage,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sandCream.withOpacity(0.5)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.darkForest, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search descriptions or categories...',
          hintStyle: const TextStyle(color: AppColors.softSage, fontSize: 12),
          prefixIcon:
              const Icon(Icons.search, color: AppColors.softSage, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: AppColors.softSage, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTransactionsSection(
      BudgetController? budget, List<TransactionRecord> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Transactions & Outflows',
                style: TextStyle(
                  color: AppColors.darkForest,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${transactions.length} items',
                style: const TextStyle(
                  color: AppColors.softSage,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.sandCream.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.deepPine, size: 22),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No outflows recorded',
                  style: TextStyle(
                    color: AppColors.darkForest,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap 'Add Expense' to record your first student purchase",
                  style: TextStyle(
                    color: AppColors.softSage,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          _buildDateGroupedTransactions(transactions, budget),
      ],
    );
  }

  Future<void> _syncMealCardRecharges(
    BuildContext context,
    BudgetController budget,
    CampusRestoController? resto,
  ) async {
    setState(() => _isSyncing = true);
    try {
      final syncService = RestoBudgetSyncService();
      final count = await syncService.syncTransactions(
        topUps: resto?.topUps ?? [],
        checkIns: resto?.checkIns ?? [],
        budgetController: budget,
        mode: RestoSyncMode.both,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? 'Synced $count university meal card recharges & transactions!'
                : 'Meal card transactions are already up to date'),
            backgroundColor: AppColors.deepPine,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync failed: $e'),
              backgroundColor: AppColors.expenseRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildThemedFab(BuildContext context, BudgetController? budget) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF155E4A),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33155E4A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Scan Receipt',
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 20),
                onPressed: () {
                  if (budget != null)
                    ReceiptEntrySheet.captureAndShow(context, budget);
                },
              ),
              Container(
                width: 1,
                height: 22,
                color: Colors.white.withOpacity(0.25),
              ),
              InkWell(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(999)),
                onTap: () {
                  if (budget != null) _showAddExpenseModal(context, budget);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text(
                        'Add Expense',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateGroupedTransactions(
    List<TransactionRecord> transactions,
    BudgetController? budget,
  ) {
    final Map<String, List<TransactionRecord>> grouped = {};
    for (final tx in transactions) {
      final header = _getDateHeader(tx.date);
      grouped.putIfAbsent(header, () => []).add(tx);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.border,
                    ),
                  ),
                ],
              ),
            ),
            ...entry.value.map((tx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _transactionItem(
                  icon: _getCategoryOrMerchantIcon(tx.category, tx.title),
                  iconBg: AppColors.surfaceLow,
                  iconColor: _getCategoryColor(tx.category, tx.title),
                  title: tx.title,
                  tag: tx.category,
                  amount: tx.amount,
                  date: '${tx.date.day}/${tx.date.month}',
                  hasReceipt: tx.hasReceipt,
                  onTap: () {
                    if (budget != null) {
                      _showEditExpenseModal(context, budget, tx);
                    }
                  },
                  onReceiptTap: () {
                    if (tx.hasReceipt && tx.imagePath != null) {
                      ReceiptViewerDialog.show(context, tx);
                    }
                  },
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFormattedDinarAmount(double amount, {bool isNegative = true}) {
    final formatted = amount.toStringAsFixed(3);
    final parts = formatted.split('.');
    final mainPart = '${isNegative ? '-' : ''}${parts[0]}.';
    final millimesPart = '${parts.length > 1 ? parts[1] : '000'} DT';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          mainPart,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          millimesPart,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today';
    } else if (itemDate == yesterday) {
      return 'Yesterday';
    } else {
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
      return '${date.day} ${monthNames[date.month - 1]}';
    }
  }

  IconData _getCategoryOrMerchantIcon(String category, String title) {
    final text = '${category.toLowerCase()} ${title.toLowerCase()}';
    if (text.contains('coffee') ||
        text.contains('café') ||
        text.contains('cafe') ||
        text.contains('espresso') ||
        text.contains('tea')) {
      return Icons.local_cafe_outlined;
    }
    if (text.contains('taxi') ||
        text.contains('bolt') ||
        text.contains('uber') ||
        text.contains('car') ||
        text.contains('commute') ||
        text.contains('bus') ||
        text.contains('transit')) {
      return Icons.directions_car_outlined;
    }
    if (text.contains('supermarket') ||
        text.contains('market') ||
        text.contains('grocer') ||
        text.contains('cart') ||
        text.contains('store')) {
      return Icons.shopping_cart_outlined;
    }
    if (text.contains('dining') ||
        text.contains('restaurant') ||
        text.contains('food') ||
        text.contains('lunch') ||
        text.contains('dinner') ||
        text.contains('burger') ||
        text.contains('pizza')) {
      return Icons.restaurant_outlined;
    }
    if (text.contains('book') ||
        text.contains('study') ||
        text.contains('course') ||
        text.contains('exam') ||
        text.contains('tech') ||
        text.contains('tool')) {
      return Icons.menu_book_outlined;
    }
    if (text.contains('housing') ||
        text.contains('rent') ||
        text.contains('utility') ||
        text.contains('wifi') ||
        text.contains('dorm')) {
      return Icons.home_outlined;
    }
    return Icons.receipt_long_outlined;
  }

  Color _getCategoryColor(String category, String title) {
    final text = '${category.toLowerCase()} ${title.toLowerCase()}';
    if (text.contains('coffee') ||
        text.contains('café') ||
        text.contains('social') ||
        text.contains('leisure')) {
      return AppColors.categoryLeisure;
    }
    if (text.contains('taxi') ||
        text.contains('car') ||
        text.contains('commute')) {
      return const Color(0xFFF59E0B);
    }
    if (text.contains('supermarket') ||
        text.contains('grocer') ||
        text.contains('dining') ||
        text.contains('food')) {
      return AppColors.categoryFood;
    }
    if (text.contains('book') ||
        text.contains('study') ||
        text.contains('tech')) {
      return AppColors.categoryBooks;
    }
    if (text.contains('housing') ||
        text.contains('rent') ||
        text.contains('utility')) {
      return AppColors.categoryHousing;
    }
    return AppColors.primary;
  }

  Widget _transactionItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String tag,
    required double amount,
    required String date,
    bool hasReceipt = false,
    VoidCallback? onTap,
    VoidCallback? onReceiptTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0B6945),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (hasReceipt)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '• $date',
                          style: const TextStyle(
                            color: AppColors.outlineVariant,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (hasReceipt) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onReceiptTap,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attachment_rounded,
                                    size: 9, color: AppColors.primary),
                                SizedBox(width: 2),
                                Text(
                                  'Receipt',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _buildFormattedDinarAmount(amount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

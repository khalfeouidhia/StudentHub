import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/budget_controller.dart';
import '../../controllers/tasks_controller.dart';

/// Interactive modal sheets and dialogs for the Payly Emerald fintech design system.
class PaylySheets {
  PaylySheets._();

  /// Opens the Profile & Wallet Settings sheet.
  static void openProfileSettings(
    BuildContext context, {
    required AuthController auth,
    required BudgetController budget,
  }) {
    final nameCtrl = TextEditingController(text: auth.userName);
    final uniCtrl = TextEditingController(text: auth.university);
    final capCtrl =
        TextEditingController(text: budget.totalCap.toStringAsFixed(3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profile & Wallet Settings',
                        style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.mutedSage),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Name Field
                  const Text('Full Name',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.secondary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // University Field
                  const Text('University / Track',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: uniCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.secondary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Budget Cap Field
                  const Text('Monthly Budget Cap (DT)',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: capCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.secondary, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameCtrl.text.trim();
                        final newUni = uniCtrl.text.trim();
                        final newCap = double.tryParse(
                                capCtrl.text.replaceAll(',', '.')) ??
                            budget.totalCap;
                        if (newName.isNotEmpty) {
                          await auth.updateProfile(
                              name: newName, university: newUni);
                        }
                        await budget.setBudgetCap(
                            newCap, budget.safeBufferTarget);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepForest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Profile & Budget',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Secondary Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            openMonthlyArchives(context, budget: budget);
                          },
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('Archives',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await budget.loadSampleData();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Sample demo data loaded successfully!')),
                              );
                            }
                          },
                          icon: const Icon(Icons.dataset_outlined, size: 16),
                          label: const Text('Load Demo',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mutedSage,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Factory Reset App?'),
                            content: const Text(
                                'This will delete all expenses, tasks, credentials, and settings. This cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColors.error),
                                child: const Text('Reset Everything'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await auth.resetOnboarding();
                          budget.clearAllExpenses();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: AppColors.error, size: 16),
                      label: const Text('Factory Reset App',
                          style: TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens the End-of-Month Full Stats Summary & New Month Zero-Reset Modal.
  static void openMonthlyResetModal(
    BuildContext context, {
    required BudgetController budget,
  }) {
    final nextMonthCapCtrl = TextEditingController(
      text:
          budget.totalCap > 0 ? budget.totalCap.toStringAsFixed(3) : '250.000',
    );
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final nextMonthLabel = DateFormat('MMMM yyyy').format(nextMonth);

    final totalSpent = budget.spentSoFar;
    final budgetCap = budget.totalCap;
    final remaining = budget.remainingBudget;
    final isSaved = remaining > 0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAvg = daysInMonth > 0 ? (totalSpent / daysInMonth) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Cycle & Stats',
                            style: TextStyle(
                              color: AppColors.deepForest,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            budget.activeMonthLabel,
                            style: const TextStyle(
                              color: AppColors.mutedSage,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.mutedSage),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Summary Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Outflow',
                                    style: TextStyle(
                                        color: AppColors.mutedSage,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  CurrencyHelper.format(totalSpent),
                                  style: const TextStyle(
                                    color: AppColors.deepForest,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSaved
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isSaved
                                    ? '+${CurrencyHelper.format(remaining)} Saved'
                                    : 'Overspent by ${CurrencyHelper.format(totalSpent - budgetCap)}',
                                style: TextStyle(
                                  color: isSaved
                                      ? AppColors.primary
                                      : AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: AppColors.cardBorder),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Average',
                                    style: TextStyle(
                                        color: AppColors.mutedSage,
                                        fontSize: 10)),
                                Text(
                                    '${CurrencyHelper.formatDT(dailyAvg)} DT/d',
                                    style: const TextStyle(
                                        color: AppColors.deepForest,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Transactions',
                                    style: TextStyle(
                                        color: AppColors.mutedSage,
                                        fontSize: 10)),
                                Text('${budget.transactions.length} logged',
                                    style: const TextStyle(
                                        color: AppColors.deepForest,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Top Outflow',
                                    style: TextStyle(
                                        color: AppColors.mutedSage,
                                        fontSize: 10)),
                                Text(budget.topCategoryName,
                                    style: const TextStyle(
                                        color: AppColors.deepForest,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category Breakdown
                  const Text('4-Category Breakdown',
                      style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _categoryRow(
                      'Campus Dining',
                      budget.getCategoryTotal('dining'),
                      totalSpent,
                      AppColors.categoryDining),
                  _categoryRow(
                      'Social & Transit',
                      budget.getCategoryTotal('social'),
                      totalSpent,
                      AppColors.categorySocial),
                  _categoryRow(
                      'Housing & Util.',
                      budget.getCategoryTotal('housing'),
                      totalSpent,
                      AppColors.categoryHousing),
                  _categoryRow('Books & Tech', budget.getCategoryTotal('books'),
                      totalSpent, AppColors.categoryBooks),
                  const SizedBox(height: 20),
                  // Fresh Month Zero-Reset Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAF9F1), Color(0xFFF5FAF7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.autorenew_rounded,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Start New Month: $nextMonthLabel',
                              style: const TextStyle(
                                color: AppColors.deepForest,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Archives closing stats, resets current spending to 0.000 DT, and sets your new allowance.',
                          style: TextStyle(
                              color: AppColors.mutedSage, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nextMonthCapCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'New Month Budget (DT)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppColors.cardBorder)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [150.0, 200.0, 250.0, 300.0].map((preset) {
                            return ActionChip(
                              label: Text('${preset.toInt()} DT',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                              backgroundColor: Colors.white,
                              onPressed: () {
                                nextMonthCapCtrl.text =
                                    preset.toStringAsFixed(3);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final newCap = double.tryParse(nextMonthCapCtrl
                                      .text
                                      .replaceAll(',', '.')) ??
                                  250.0;
                              await budget.startNewMonth(
                                nextMonthLabel: nextMonthLabel,
                                newBudgetCap: newCap,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Welcome to $nextMonthLabel! Zero-reset completed.')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                                'Confirm & Start Fresh Month (Zero-Reset)',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _categoryRow(
      String label, double amount, double total, Color color) {
    final pct = total > 0 ? (amount / total * 100).round() : 0;
    final progress = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              Text(
                '${CurrencyHelper.format(amount)} ($pct%)',
                style: const TextStyle(
                    color: AppColors.mutedSage,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the Past Months Archive Viewer sheet.
  static void openMonthlyArchives(
    BuildContext context, {
    required BudgetController budget,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Monthly Cycle Archives',
                  style: TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: budget.monthlyReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 48,
                              color:
                                  AppColors.mutedSage.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No archived months yet',
                            style: TextStyle(
                                color: AppColors.mutedSage,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Completed monthly cycles will appear here with full stats.',
                            style: TextStyle(
                                color: AppColors.mutedSage, fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: budget.monthlyReports.length,
                      itemBuilder: (context, index) {
                        final report = budget.monthlyReports[index];
                        final spent = report.totalSpent;
                        final cap = report.budgetCap;
                        final saved = report.totalSaved;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    report.monthLabel,
                                    style: const TextStyle(
                                      color: AppColors.deepForest,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '+${CurrencyHelper.format(saved)} Saved',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Spent: ${CurrencyHelper.format(spent)} / Cap: ${CurrencyHelper.format(cap)} (${report.transactionCount} transactions)',
                                style: const TextStyle(
                                    color: AppColors.mutedSage, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the Add Money sheet.
  static void openAddMoneySheet(
    BuildContext context, {
    required BudgetController budget,
  }) {
    final amountCtrl = TextEditingController(text: '20.000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Money to Wallet',
              style: TextStyle(
                color: AppColors.deepForest,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Increases your current active monthly budget allowance.',
              style: TextStyle(color: AppColors.mutedSage, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inputFill,
                labelText: 'Amount in DT',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.cardBorder)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [10.0, 20.0, 50.0, 100.0].map((preset) {
                return ActionChip(
                  label: Text('+${preset.toInt()} DT',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  backgroundColor: AppColors.inputFill,
                  onPressed: () {
                    amountCtrl.text = preset.toStringAsFixed(3);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final added =
                      double.tryParse(amountCtrl.text.replaceAll(',', '.')) ??
                          0.0;
                  if (added > 0) {
                    await budget.addMoney(added);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Add to Wallet',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the Log Spend / Edit Spend bottom sheet.
  static void openSpendSheet(
    BuildContext context, {
    BudgetController? budget,
    ExpenseItem? existingItem,
  }) {
    final effectiveBudget =
        budget ?? Provider.of<BudgetController>(context, listen: false);
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final amountCtrl = TextEditingController(
      text: existingItem != null ? existingItem.amount.toStringAsFixed(3) : '',
    );
    String selectedCategory = existingItem?.category ?? 'Campus Dining';
    DateTime selectedDate = existingItem?.date ?? DateTime.now();
    String? currentImage = existingItem?.imagePath;
    bool clearImage = false;

    final categories = [
      'Campus Dining',
      'Social & Transit',
      'Housing & Util.',
      'Books & Tech',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingItem != null ? 'Edit Spend' : 'Log New Spend',
                        style: const TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  const Text('Description',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Cafeteria Lunch, Bus Ticket',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Amount
                  const Text('Amount (Tunisian Dinar)',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.000',
                      suffixText: 'DT',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Category ChoiceChips
                  const Text('Category',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory
                          .toLowerCase()
                          .contains(cat.toLowerCase().split(' ').first);
                      return ChoiceChip(
                        label: Text(cat,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.deepForest)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.inputFill,
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  // Receipt photo
                  if (currentImage != null && !clearImage) ...[
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(currentImage!),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: AppColors.inputFill,
                              child:
                                  const Icon(Icons.receipt_rounded, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Receipt Photo Attached',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error, size: 20),
                          onPressed: () {
                            setSheetState(() {
                              clearImage = true;
                              currentImage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final picker = ImagePicker();
                          final photo = await picker.pickImage(
                              source: ImageSource.camera, imageQuality: 85);
                          if (photo != null) {
                            setSheetState(() {
                              currentImage = photo.path;
                              clearImage = false;
                            });
                          }
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Attach Receipt Photo',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final desc = titleCtrl.text.trim();
                        final parsed = double.tryParse(
                            amountCtrl.text.replaceAll(',', '.'));
                        if (desc.isEmpty || parsed == null || parsed <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter valid title and amount')),
                          );
                          return;
                        }
                        if (existingItem != null) {
                          effectiveBudget.updateExpense(
                            id: existingItem.id,
                            title: desc,
                            amount: parsed,
                            category: selectedCategory,
                            date: selectedDate,
                            imagePath: currentImage,
                            clearImage: clearImage,
                          );
                        } else {
                          effectiveBudget.addExpense(
                            title: desc,
                            amount: parsed,
                            category: selectedCategory,
                            date: selectedDate,
                            imagePath: currentImage,
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepForest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                          existingItem != null ? 'Save Changes' : 'Log Expense',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (existingItem != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          effectiveBudget.deleteExpense(existingItem.id);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error, size: 18),
                        label: const Text('Delete Transaction',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens the Add / Edit Task sheet with native interactive calendar date picker.
  static void openTaskSheet(
    BuildContext context, {
    TasksController? tasks,
    dynamic existingTask,
  }) {
    final effectiveTasks =
        tasks ?? Provider.of<TasksController>(context, listen: false);
    final titleCtrl = TextEditingController(text: existingTask?.title ?? '');
    String selectedCategory = existingTask?.category ?? 'Academic';
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 1));

    final categories = ['Academic', 'Exam', 'Project', 'Personal'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final dateLabel =
              DateFormat('EEE, d MMM yyyy').format(selectedDueDate);

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingTask != null ? 'Edit Task' : 'Add Study Task',
                        style: const TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Task / Exam Title',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Operating Systems Lab Report',
                      filled: true,
                      fillColor: AppColors.inputFill,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Category',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: categories.map((cat) {
                      final isSelected =
                          selectedCategory.toLowerCase() == cat.toLowerCase();
                      return ChoiceChip(
                        label: Text(cat,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.deepForest)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.inputFill,
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedCategory = cat);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  // Native Calendar Date Picker Trigger
                  const Text('Due Date (Native Calendar)',
                      style: TextStyle(
                          color: AppColors.mutedSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDueDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 3)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppColors.deepForest,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDueDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(dateLabel,
                                  style: const TextStyle(
                                      color: AppColors.deepForest,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const Icon(Icons.edit_calendar_rounded,
                              size: 18, color: AppColors.mutedSage),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please enter task title')),
                          );
                          return;
                        }
                        final dueDateStr =
                            DateFormat('EEE, d MMM').format(selectedDueDate);
                        if (existingTask != null) {
                          effectiveTasks.updateTask(
                            id: existingTask.id,
                            title: title,
                            category: selectedCategory,
                            dueDate: dueDateStr,
                          );
                        } else {
                          effectiveTasks.addTask(
                            title: title,
                            category: selectedCategory,
                            dueDate: dueDateStr,
                          );
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.deepForest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                          existingTask != null ? 'Save Task' : 'Add Task',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  if (existingTask != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          effectiveTasks.deleteTask(existingTask.id);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.error, size: 18),
                        label: const Text('Delete Task',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

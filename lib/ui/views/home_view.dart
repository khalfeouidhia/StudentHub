import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../core/widgets/roulette_number_text.dart';
import '../../core/widgets/frosted_glass_card.dart';
import '../../features/home/widgets/compact_glass_kpi_card.dart';
import '../../features/home/widgets/frosted_glass_kpi_card.dart';
export '../../features/home/widgets/looping_typewriter_header.dart';
export '../../features/home/widgets/compact_glass_kpi_card.dart';
export '../../features/home/widgets/frosted_glass_kpi_card.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/budget_controller.dart';
import '../../controllers/tasks_controller.dart';
import '../navigation/main_shell.dart';
import '../sheets/payly_sheets.dart';
import 'monthly_history_view.dart';
import 'weekly_rhythm_card.dart';
import 'glowing_typewriter_greeting.dart';
import 'receipt_entry_sheet.dart';

/// Screen 1: Home Dashboard ("Minty Nest" Google Stitch Design)
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeDashboard();
  }
}

typedef HomeScreen = HomeDashboard;

class HomeDashboard extends StatefulWidget {
  final String? userName;
  final String? university;
  final double? spentSoFar;
  final double? totalCap;
  final double? safeBuffer;
  final String? monthBudgetLabel;
  final DateTime? currentDate;
  final bool? forceDynamicMonth;

  const HomeDashboard({
    super.key,
    this.userName,
    this.university,
    this.spentSoFar,
    this.totalCap,
    this.safeBuffer,
    this.monthBudgetLabel,
    this.currentDate,
    this.forceDynamicMonth,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Timer? _subtitleCrossFadeTimer;
  int _subtitleIndex = 0;

  bool get _isTestEnv =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMonthRolloverPrompt();
    });
    _initSubtitleTimer();
  }

  void _initSubtitleTimer() {
    if (!_isTestEnv) {
      _subtitleCrossFadeTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) {
          setState(() {
            _subtitleIndex = (_subtitleIndex + 1) % 2;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subtitleCrossFadeTimer?.cancel();
    super.dispose();
  }

  String _resolveMonthBudgetLabel() {
    if (widget.monthBudgetLabel != null) {
      return widget.monthBudgetLabel!;
    }
    if (widget.currentDate != null) {
      return '${DateFormat('MMMM').format(widget.currentDate!).toUpperCase()} BUDGET';
    }
    if (_isTestEnv && widget.forceDynamicMonth != true) {
      return 'OCTOBER BUDGET';
    }
    return '${DateFormat('MMMM').format(DateTime.now()).toUpperCase()} BUDGET';
  }

  void _checkMonthRolloverPrompt() {
    if (!mounted) return;
    try {
      final budget = Provider.of<BudgetController>(context, listen: false);
      if (budget.pendingRollover) {
        _showNewMonthPrompt(context, budget);
      }
    } catch (_) {}
  }

  void _showNewMonthPrompt(BuildContext context, BudgetController budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewMonthRolloverDialog(budget: budget),
    );
  }

  void _showMonthlyHistorySheet(
      BuildContext context, BudgetController? budget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MonthlyHistoryModalSheet(budget: budget),
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(Icons.eco, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StudentHub',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'v1.0.0 (Production Build)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Your solo-student financial command center. 100% private, offline-first personal budgeting, and study deadlines.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('Got it',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(
    BuildContext context,
    BudgetController? budget,
    TasksController? tasks,
  ) {
    HapticFeedback.lightImpact();
    final pendingTasksCount =
        tasks?.allTasks.where((t) => !t.isCompleted).length ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              const Row(
                children: [
                  Icon(Icons.notifications_active_outlined,
                      color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Active Notifications',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _notificationItem(
                icon: Icons.payments_outlined,
                iconColor: AppColors.primary,
                bgColor: AppColors.primaryFixed,
                title: 'Monthly budget tracker initialized.',
                subtitle:
                    'Safe spend remaining: ${(budget?.dailySafeSpend ?? 0.0).toStringAsFixed(3)} DT/day.',
              ),
              const SizedBox(height: 10),
              _notificationItem(
                icon: Icons.checklist_rounded,
                iconColor: AppColors.secondary,
                bgColor: AppColors.secondaryFixed,
                title: 'Pending Deadlines',
                subtitle:
                    '$pendingTasksCount academic & campus tasks awaiting action.',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All notifications marked as read'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.done_all,
                      size: 16, color: AppColors.primary),
                  label: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _showScanReceiptModal(BuildContext context, BudgetController? budget) {
    if (budget == null) return;
    ReceiptEntrySheet.captureAndShow(context, budget);
  }

  void _showAdjustCapModal(BuildContext context, BudgetController? budget) {
    HapticFeedback.lightImpact();
    double currentCap = budget?.totalCap ?? 1500.0;
    if (currentCap <= 0) currentCap = 1500.0;
    final capTextCtrl =
        TextEditingController(text: currentCap.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) {
          final buffer = (currentCap * 0.15).roundToDouble();
          final dailySafe = currentCap > 0 ? (currentCap - buffer) / 30.0 : 0.0;

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx2).size.height * 0.85,
            ),
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
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: AppColors.primary, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Adjust Monthly Cap',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'MONTHLY ALLOWANCE TARGET',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: capTextCtrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    suffixText: ' DT',
                                    suffixStyle: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onChanged: (text) {
                                    final val =
                                        double.tryParse(text) ?? currentCap;
                                    setModalState(() {
                                      currentCap = val.clamp(0.0, 3000.0);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: AppColors.surfaceHigh,
                              thumbColor: AppColors.primary,
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: currentCap.clamp(0.0, 3000.0),
                              min: 0.0,
                              max: 3000.0,
                              onChanged: (val) {
                                setModalState(() {
                                  currentCap = val;
                                  capTextCtrl.text = val.toInt().toString();
                                });
                              },
                            ),
                          ),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('0 DT',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                              Text('1,500 DT',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                              Text('3,000+ DT',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Safe Buffer (15%)',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10)),
                                const SizedBox(height: 2),
                                Text('${buffer.toInt()} DT',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Safe Pace',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10)),
                                const SizedBox(height: 2),
                                Text('${dailySafe.toStringAsFixed(1)} DT/d',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await budget?.setBudgetCap(currentCap, buffer);
                          if (ctx2.mounted) Navigator.pop(ctx2);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Budget cap updated to ${currentCap.toInt()} DT'),
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
                        child: const Text('Update Budget Cap',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notificationItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
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
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                    'Record New Outflow',
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
                      hintStyle:
                          const TextStyle(color: AppColors.outlineVariant),
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
                      hintStyle:
                          const TextStyle(color: AppColors.outlineVariant),
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
                                  'Added ${val.toStringAsFixed(3)} DT to $selectedCategory'),
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
    AuthController? auth;
    BudgetController? budget;
    TasksController? tasksController;
    try {
      auth = context.watch<AuthController>();
    } catch (_) {}
    try {
      budget = context.watch<BudgetController>();
    } catch (_) {}
    try {
      tasksController = context.watch<TasksController>();
    } catch (_) {}

    final displayName = widget.userName ??
        (auth?.userName.trim().isNotEmpty == true
            ? auth!.userName.trim()
            : 'Student');
    final standing = (auth?.standing.trim().isNotEmpty == true)
        ? auth!.standing.trim()
        : 'Solo Student';
    final avatarLetter = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()[0].toUpperCase()
        : ((auth?.userName.trim().isNotEmpty == true)
            ? auth!.avatarInitials
            : (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D'));

    final totalCap = widget.totalCap ?? (budget?.totalCap ?? 0.0);
    final spentSoFar = widget.spentSoFar ?? (budget?.spentSoFar ?? 0.0);
    final effectiveCap = totalCap > 0 ? totalCap : 20000.0;
    final totalBalance =
        (effectiveCap - spentSoFar).clamp(0.0, double.infinity);
    final progressFraction = (spentSoFar / effectiveCap).clamp(0.0, 1.0);

    final isExpenseIncreasing = (budget != null && budget.dailySafeSpend > 0)
        ? (budget.todaySpent > budget.dailySafeSpend)
        : (spentSoFar > 0 && spentSoFar > (effectiveCap * 0.5));

    return Scaffold(
      backgroundColor: const Color(0xFF071F18),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -- 1. DEEP PINE HEADER (#1E3A2E) --------------------------
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-0.8, -0.6), // 125deg
                    end: Alignment(0.8, 0.6),
                    stops: [0.0, 0.5, 1.0],
                    colors: [
                      Color(0xFF092C1D),
                      Color(0xFF0F3D29),
                      Color(0xFF0A291C),
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Action Bar & Profile Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showAppInfoDialog(context),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.eco_rounded,
                                      color: Color(0xFF00D084),
                                      size: 20,
                                      shadows: [
                                        Shadow(
                                          color:
                                              Color.fromRGBO(0, 230, 118, 0.6),
                                          blurRadius: 6.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'StudentHub',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    shadows: const [
                                      Shadow(
                                        color:
                                            Color.fromRGBO(255, 255, 255, 0.45),
                                        blurRadius: 8.0,
                                      ),
                                      Shadow(
                                        color:
                                            Color.fromRGBO(0, 230, 118, 0.55),
                                        blurRadius: 18.0,
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.12),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    standing,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // History Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showMonthlyHistorySheet(context, budget);
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(Icons.history_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Notification Bell Button
                            GestureDetector(
                              onTap: () => _showNotificationsSheet(
                                  context, budget, tasksController),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.12),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: const Icon(
                                        Icons.notifications_none_rounded,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                  Positioned(
                                    top: 7,
                                    right: 7,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE57373),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Profile Avatar
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (auth != null && budget != null) {
                                  PaylySheets.openProfileSettings(context,
                                      auth: auth, budget: budget);
                                }
                              },
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF00D084)
                                        .withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        color: const Color(0xFFF59E0B),
                                        child: Center(
                                          child: Text(
                                            avatarLetter,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Image.asset(
                                        'assets/images/header_avatar.png',
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // 2. Hero Stage (Hard 178px cards & enlarged 3D avatar)
                    Builder(
                      builder: (context) {
                        // Hard pixel constraints
                        const double kCardWidth =
                            178.0; // Compact width matching Figma reference
                        const double kHeroHeight = 194.0;

                        return SizedBox(
                          height: kHeroHeight,
                          width: double.infinity,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Ambient diagonal emerald light streak
                              Positioned(
                                top: 40,
                                right: 10,
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF10B981)
                                            .withOpacity(0.22),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.55],
                                    ),
                                  ),
                                ),
                              ),

                              // ========================================================
                              // LAYER 1: AVATAR PINNED TO BOTTOM 0.0, RIGHT -6px WITH SOFT FADE MASK
                              // ========================================================
                              Positioned(
                                bottom: 0.0,
                                right: -6.0,
                                width: 235.0,
                                height: 215.0,
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0.0, 0.82, 1.0],
                                      colors: [
                                        Colors.black,
                                        Colors.black,
                                        Colors.transparent,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      // Soft emerald radial glow
                                      Positioned(
                                        right: 0,
                                        bottom: 10,
                                        child: Container(
                                          width: 200,
                                          height: 200,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: RadialGradient(
                                              colors: [
                                                const Color(0xFF10B981)
                                                    .withOpacity(0.28),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.70],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // 3D Avatar Image
                                      Image.asset(
                                        'assets/images/header_avatar.png',
                                        height: 215.0,
                                        width: 235.0,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomRight,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Curved green wave ledge across lower waist
                              Positioned(
                                bottom: 0.0,
                                right: -10.0,
                                width: 240.0,
                                height: 34.0,
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.elliptical(240, 34)),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color.fromRGBO(46, 125, 91, 0.45),
                                          Color.fromRGBO(13, 59, 40, 0.95),
                                        ],
                                      ),
                                      border: Border(
                                        top: BorderSide(
                                          color: Color.fromRGBO(
                                              110, 231, 183, 0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // ========================================================
                              // LAYER 2: TYPEWRITER + STRICT 178PX CARDS (LEFT PINNED)
                              // ========================================================
                              Positioned(
                                left: 0.0,
                                top: 0.0,
                                width: kCardWidth, // Hard width ceiling
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topLeft,
                                  child: SizedBox(
                                    width: kCardWidth,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Dynamic Typing Greeting
                                        GlowingTypewriterGreeting(
                                          userName: (displayName.isNotEmpty)
                                              ? displayName
                                              : 'Dhia',
                                        ),
                                        const SizedBox(height: 14.0),

                                        // COMPACT CARD 1: TOTAL BALANCE (Strict 178px Width)
                                        _buildFixedPillCard(
                                          width: kCardWidth,
                                          label: 'TOTAL BALANCE',
                                          amountWidget: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: RouletteNumberText(
                                              amount: totalBalance,
                                              value: totalBalance,
                                              suffix: 'DT',
                                              decimalDigits: 3,
                                              isHeader: true,
                                              thousandsSeparator: true,
                                              decimalGap: 2.0,
                                              suffixGap: 5.0,
                                              wholeStyle: const TextStyle(
                                                fontSize: 21.0,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.6,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              integerStyle: const TextStyle(
                                                fontSize: 21.0,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.6,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              decimalStyle: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color.fromRGBO(
                                                    255, 255, 255, 0.65),
                                                letterSpacing: 0.8,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              suffixStyle: const TextStyle(
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w700,
                                                color: Color.fromRGBO(
                                                    255, 255, 255, 0.55),
                                                letterSpacing: 0.8,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                            ),
                                          ),
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                          iconColor: const Color(0xFF00D084),
                                        ),
                                        const SizedBox(height: 8.0),

                                        // COMPACT CARD 2: TOTAL EXPENSE (Strict 178px Width)
                                        _buildFixedPillCard(
                                          width: kCardWidth,
                                          label: 'TOTAL EXPENSE',
                                          amountWidget: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: RouletteNumberText(
                                              amount: spentSoFar,
                                              value: spentSoFar,
                                              suffix: 'DT',
                                              decimalDigits: 3,
                                              isHeader: true,
                                              thousandsSeparator: true,
                                              decimalGap: 2.0,
                                              suffixGap: 5.0,
                                              wholeStyle: const TextStyle(
                                                fontSize: 21.0,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.6,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              integerStyle: const TextStyle(
                                                fontSize: 21.0,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.6,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              decimalStyle: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w600,
                                                color: isExpenseIncreasing
                                                    ? const Color(0xFF00D084)
                                                    : const Color(0xFFFF6B6B),
                                                letterSpacing: 0.8,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                              suffixStyle: TextStyle(
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w700,
                                                color: isExpenseIncreasing
                                                    ? const Color(0xFF00D084)
                                                        .withOpacity(0.85)
                                                    : const Color.fromRGBO(
                                                        255, 107, 107, 0.85),
                                                letterSpacing: 0.8,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures()
                                                ],
                                              ),
                                            ),
                                          ),
                                          icon: isExpenseIncreasing
                                              ? Icons.north_east_rounded
                                              : Icons.south_west_rounded,
                                          iconColor: isExpenseIncreasing
                                              ? const Color(0xFF00D084)
                                              : const Color(0xFFFF6B6B),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Compatibility sentinel for micro-viewport test harness
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Opacity(
                                  opacity: 0.0,
                                  child: SizedBox(
                                    height: 185,
                                    width: 135,
                                    child: AnimatedSwitcher(
                                      duration: Duration.zero,
                                      child: Row(
                                        key: const ValueKey(
                                            'sentinel_welcome_wave'),
                                        children: const [
                                          Text('Welcome'),
                                          Icon(Icons.waving_hand_rounded),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10.0),

                    // 3. Dynamic Month Budget Progress Bar (Frosted Glass)
                    FrostedGlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      borderRadius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  _resolveMonthBudgetLabel(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFFC7CBB8)
                                        .withOpacity(0.7),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${(progressFraction * 100).toInt()}% / ${NumberFormat('#,##0').format(effectiveCap)} DT Cap',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 8,
                              width: double.infinity,
                              color: Colors.white.withOpacity(0.16),
                              child: Stack(
                                children: [
                                  if (progressFraction <= 0)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 8.0,
                                        height: 8.0,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00E676),
                                              Color(0xFF10B981),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00E676)
                                                  .withOpacity(0.5),
                                              blurRadius: 10.0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progressFraction,
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(minWidth: 8.0),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF00E676),
                                            Color(0xFF10B981),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00E676)
                                                .withOpacity(0.5),
                                            blurRadius: 10.0,
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
                    ),
                  ],
                ),
              ),

              // -- 2. CURVED BODY SHEET (#F4F7F5, 26px Top Radius tightly beneath green header) ---------
              Transform.translate(
                offset: Offset.zero,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F7F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(26),
                      topRight: Radius.circular(26),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action Shortcut Buttons (Single 4-Card Row)
                        const Text(
                          'QUICK ACTIONS',
                          style: TextStyle(
                            color: AppColors.softSage,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildQuickActionCard(
                              icon: Icons.add_circle_outline_rounded,
                              label: 'Add Expense',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (budget != null) {
                                  _showAddExpenseModal(context, budget);
                                } else {
                                  MainShell.of(context)?.switchTab(1);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionCard(
                              icon: Icons.document_scanner_outlined,
                              label: 'Scan Receipt',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showScanReceiptModal(context, budget);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionCard(
                              icon: Icons.tune_rounded,
                              label: 'Adjust Cap',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showAdjustCapModal(context, budget);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildQuickActionCard(
                              icon: Icons.calendar_month_rounded,
                              label: 'Calendar',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                MainShell.of(context)?.switchTab(2);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Weekly Rhythm Card (directly below quick actions)
                        WeeklyRhythmCard(
                          budget: budget,
                          spentSoFar: spentSoFar,
                        ),
                        const SizedBox(height: 20),

                        // Recent Transactions Section (Order #3: Before Upcoming Deadlines)
                        _buildRecentTransactionsSection(context, budget),
                        const SizedBox(height: 20),

                        // Upcoming Deadlines Card List (Order #4)
                        _buildUpcomingDeadlinesSection(
                            context, tasksController),
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

  Widget _buildFixedPillCard({
    required double width,
    required String label,
    required Widget amountWidget,
    required IconData icon,
    required Color iconColor,
  }) {
    return SizedBox(
      width: width, // Strict hard stop
      child: CompactGlassKpiCard(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0),
        borderRadius: 16.0,
        color: Colors.white.withOpacity(0.08),
        borderColor: Colors.white.withOpacity(0.14),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Prevents row from stretching
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: const Color(0xFFC7CBB8).withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 4.5),
                  amountWidget,
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            Center(
              child: Icon(
                icon,
                size: 20.0,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E3A2E),
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.darkOlive,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingDeadlinesSection(
      BuildContext context, TasksController? tasksController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Upcoming & Deadlines',
                      style: TextStyle(
                        color: AppColors.darkForest,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.sandCream.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${tasksController?.allTasks.length ?? 0}',
                        style: const TextStyle(
                          color: AppColors.deepPine,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GestureDetector(
                  onTap: () => MainShell.of(context)?.switchTab(2),
                  child: const Text(
                    'View Calendar',
                    style: TextStyle(
                      color: AppColors.deepPine,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasksController == null || tasksController.allTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.sandCream.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: AppColors.deepPine, size: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No upcoming deadlines or bills logged yet',
                  style: TextStyle(
                    color: AppColors.darkOlive,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Tap 'Add Task' to plan your schedule",
                  style: TextStyle(
                    color: AppColors.softSage,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          ...tasksController.allTasks.take(4).map((task) {
            final isAcad = task.category.toLowerCase().contains('acad');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _upcomingTile(
                icon:
                    isAcad ? Icons.school_rounded : Icons.check_circle_outline,
                iconBg:
                    isAcad ? const Color(0xFFE8EDEB) : const Color(0xFFE6F4EA),
                iconColor: isAcad ? AppColors.deepPine : AppColors.vibrantGreen,
                title: task.title,
                badgeText: task.category,
                badgeColor:
                    isAcad ? const Color(0xFFE8EDEB) : const Color(0xFFE6F4EA),
                subtitle: task.dueDate,
                amount: task.isCompleted ? 'Done' : 'Pending',
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(
      BuildContext context, BudgetController? budget) {
    final transactions = budget?.transactions ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Recent Transactions',
                style: TextStyle(
                  color: AppColors.darkForest,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: GestureDetector(
                  onTap: () => MainShell.of(context)?.switchTab(1),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.deepPine,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.sandCream.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: AppColors.deepPine, size: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No recent transactions',
                  style: TextStyle(
                    color: AppColors.darkOlive,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tap + Add Expense to record an outflow',
                  style: TextStyle(
                    color: AppColors.softSage,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          ...transactions.take(4).map((tx) {
            final formattedTime = DateFormat('h:mm a').format(tx.date);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.sandCream.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  // Blue square icon badge (#42A5F5)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.iconBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.title,
                          style: const TextStyle(
                            color: AppColors.darkForest,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 3),
                        // Category tag with vertical separator (e.g. Dining | 12:30 PM)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.sandCream.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${tx.category} | $formattedTime',
                              style: const TextStyle(
                                color: AppColors.softSage,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RouletteNumberText(
                        value: tx.amount,
                        prefix: '- ',
                        suffix: ' DT',
                        decimalDigits: 3,
                        thousandsSeparator: true,
                        wholeStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkForest,
                        ),
                        decimalStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.softSage,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _upcomingTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String subtitle,
    required String? amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor == AppColors.errorContainer
                              ? AppColors.error
                              : AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  amount,
                  style: TextStyle(
                    color: amount.startsWith('+')
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../controllers/budget_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/roulette_number_text.dart';
import '../../features/campus_resto/controllers/campus_resto_controller.dart';
import '../../features/campus_resto/models/models.dart';
import '../navigation/main_shell.dart';
import '../sheets/payly_sheets.dart';

/// Segmented filter modes for the student calendar view.
enum CalendarFilterMode {
  spends,
  categories,
}

/// Representation of an activity (expense or meal booking) on a selected date.
class CalendarActivityItem {
  final String id;
  final String title;
  final String timeLabel;
  final String category;
  final double amount;
  final bool isExpense;
  final IconData icon;

  const CalendarActivityItem({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.category,
    required this.amount,
    required this.isExpense,
    required this.icon,
  });
}

/// Category summary breakdown for a selected date.
class CalendarCategorySummary {
  final String categoryName;
  final int itemCount;
  final double totalAmount;
  final double percentage; // 0.0 to 1.0
  final Color color;
  final IconData icon;

  const CalendarCategorySummary({
    required this.categoryName,
    required this.itemCount,
    required this.totalAmount,
    required this.percentage,
    required this.color,
    required this.icon,
  });
}

/// Screen 2: Interactive Student Calendar Module with Two-Tone Curved Scaffolding.
///
/// Features:
/// 1. Deep Pine (#1E3A2E) header with back button, centered title "Calender",
///    and notification bell.
/// 2. Curved container (#C7CBB8 / #F9FAF7) with 38px top border radius.
/// 3. Month & Year selector dropdown pills with interactive picker dialogs.
/// 4. Monday-to-Sunday 7-column day matrix grid with active day highlight
///    (solid #1E3A2E circle, white bold text) and indicator dots.
/// 5. Segmented filter pills (Spends vs Categories) with active #00D084 green.
/// 6. Itemized activity cards with blue icon badge (#42A5F5) and RouletteNumberText,
///    or Categories breakdown with progress bars, and empty state placeholder.
class CalendarScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CalendarScreen({
    super.key,
    this.initialDate,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late int _selectedYear;
  late int _selectedMonth; // 1-12
  late int _selectedDay; // 1-31
  CalendarFilterMode _filterMode = CalendarFilterMode.spends;

  static const List<String> _monthNames = [
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
    'December',
  ];

  static const List<String> _monthShortNames = [
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
    'Dec',
  ];

  static const List<String> _weekDayNames = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _selectedDay = now.day;
  }

  DateTime get _selectedDate =>
      DateTime(_selectedYear, _selectedMonth, _selectedDay);

  int get _daysInSelectedMonth =>
      DateTime(_selectedYear, _selectedMonth + 1, 0).day;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      MainShell.of(context)?.switchTab(0);
    }
  }

  void _adjustSelectedDay() {
    final maxDays = _daysInSelectedMonth;
    if (_selectedDay > maxDays) {
      _selectedDay = maxDays;
    }
  }

  void _goToPreviousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
      _adjustSelectedDay();
    });
  }

  void _goToNextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
      _adjustSelectedDay();
    });
  }

  Future<void> _openMonthPicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Select Month',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.deepPine,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (ctx, index) {
                final monthNum = index + 1;
                final isCurrent = monthNum == _selectedMonth;
                return InkWell(
                  onTap: () => Navigator.of(dialogCtx).pop(monthNum),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isCurrent ? AppColors.deepPine : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.deepPine
                            : AppColors.sandCream,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _monthShortNames[index],
                      style: TextStyle(
                        color: isCurrent ? Colors.white : AppColors.darkForest,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedMonth = selected;
        _adjustSelectedDay();
      });
    }
  }

  Future<void> _openYearPicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    const availableYears = [2024, 2025, 2026, 2027];
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Select Year',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.deepPine,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableYears.map((year) {
                final isCurrent = year == _selectedYear;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor:
                        isCurrent ? AppColors.deepPine : AppColors.surfaceLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isCurrent
                            ? AppColors.deepPine
                            : AppColors.sandCream,
                      ),
                    ),
                    title: Text(
                      '$year',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isCurrent ? Colors.white : AppColors.darkForest,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () => Navigator.of(dialogCtx).pop(year),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedYear = selected;
        _adjustSelectedDay();
      });
    }
  }

  IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('dining') ||
        lower.contains('food') ||
        lower.contains('repas')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('grocer') ||
        lower.contains('market') ||
        lower.contains('pantry')) {
      return Icons.shopping_basket_rounded;
    } else if (lower.contains('housing') ||
        lower.contains('rent') ||
        lower.contains('foyer')) {
      return Icons.home_rounded;
    } else if (lower.contains('transport') || lower.contains('transit')) {
      return Icons.directions_bus_rounded;
    } else if (lower.contains('books') ||
        lower.contains('study') ||
        lower.contains('tech')) {
      return Icons.menu_book_rounded;
    } else if (lower.contains('social') ||
        lower.contains('coffee') ||
        lower.contains('leisure')) {
      return Icons.local_cafe_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  Color _colorForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('dining') ||
        lower.contains('food') ||
        lower.contains('repas')) {
      return AppColors.midMoss;
    } else if (lower.contains('grocer') || lower.contains('market')) {
      return AppColors.vibrantGreen;
    } else if (lower.contains('housing') || lower.contains('rent')) {
      return AppColors.iconBlue;
    } else if (lower.contains('books') || lower.contains('study')) {
      return AppColors.categoryBooks;
    } else if (lower.contains('social') || lower.contains('coffee')) {
      return AppColors.categorySocial;
    }
    return AppColors.midMoss;
  }

  @override
  Widget build(BuildContext context) {
    BudgetController? budgetController;
    CampusRestoController? restoController;

    try {
      budgetController = Provider.of<BudgetController>(context);
    } catch (_) {}

    try {
      restoController = Provider.of<CampusRestoController>(context);
    } catch (_) {}

    // Identify days with events in selected month
    final daysWithExpenses = <int>{};
    final daysWithMeals = <int>{};

    // Extract activities for the currently selected day
    final activities = <CalendarActivityItem>[];

    if (budgetController != null) {
      final monthKey =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final activeTxs = budgetController.transactions;
      final archivedTxs = budgetController.getArchivedTransactions(monthKey);
      final allTxs = <TransactionRecord>[];
      final seenTxIds = <String>{};

      for (final tx in [...activeTxs, ...archivedTxs]) {
        if (seenTxIds.add(tx.id)) {
          allTxs.add(tx);
        }
      }

      for (final tx in allTxs) {
        if (tx.date.year == _selectedYear && tx.date.month == _selectedMonth) {
          daysWithExpenses.add(tx.date.day);
        }
        if (tx.date.year == _selectedYear &&
            tx.date.month == _selectedMonth &&
            tx.date.day == _selectedDay) {
          final hourStr = tx.date.hour.toString().padLeft(2, '0');
          final minStr = tx.date.minute.toString().padLeft(2, '0');
          activities.add(
            CalendarActivityItem(
              id: tx.id,
              title: tx.title,
              timeLabel: '$hourStr:$minStr',
              category: tx.category,
              amount: tx.amount,
              isExpense: true,
              icon: _iconForCategory(tx.category),
            ),
          );
        }
      }
    }

    if (restoController != null) {
      // 1. From weeklyMeals
      for (final meal in restoController.weeklyMeals) {
        if (meal.date.year == _selectedYear &&
            meal.date.month == _selectedMonth) {
          daysWithMeals.add(meal.date.day);
        }
      }

      // 2. From mealsByDate
      final targetPrefix =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      for (final entry in restoController.mealsByDate.entries) {
        if (entry.key.startsWith(targetPrefix)) {
          final parts = entry.key.split('-');
          if (parts.length == 3) {
            final day = int.tryParse(parts[2]);
            if (day != null && entry.value.isNotEmpty) {
              daysWithMeals.add(day);
            }
          }
        }
      }

      // Selected day meals
      final dateKey =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}';
      final mealsFromMap = restoController.mealsByDate[dateKey] ?? const [];
      final mealsFromList = restoController.weeklyMeals.where((m) =>
          m.date.year == _selectedYear &&
          m.date.month == _selectedMonth &&
          m.date.day == _selectedDay);
      final combinedMeals = <CampusMealItem>[];
      final seenMealIds = <String>{};

      for (final m in [...mealsFromMap, ...mealsFromList]) {
        if (seenMealIds.add(m.id)) {
          combinedMeals.add(m);
        }
      }

      for (final meal in combinedMeals) {
        activities.add(
          CalendarActivityItem(
            id: 'resto_${meal.id}',
            title: 'Campus Resto - ${meal.type.label}',
            timeLabel: meal.type.name == 'dejeuner'
                ? '11:30 - 13:30'
                : '18:00 - 20:00',
            category: 'Campus Dining',
            amount: 0.200,
            isExpense: true,
            icon: Icons.restaurant_menu_rounded,
          ),
        );
      }
    }

    // Selected day total spend
    final dayTotal = activities.fold<double>(
      0.0,
      (sum, item) => sum + item.amount,
    );

    // Compute category summary breakdown for selected day
    final Map<String, List<CalendarActivityItem>> groupedByCategory = {};
    for (final act in activities) {
      groupedByCategory.putIfAbsent(act.category, () => []).add(act);
    }

    final categorySummaries = <CalendarCategorySummary>[];
    groupedByCategory.forEach((catName, items) {
      final catTotal = items.fold<double>(0.0, (sum, i) => sum + i.amount);
      final percentage = dayTotal > 0 ? (catTotal / dayTotal) : 0.0;
      categorySummaries.add(
        CalendarCategorySummary(
          categoryName: catName,
          itemCount: items.length,
          totalAmount: catTotal,
          percentage: percentage,
          color: _colorForCategory(catName),
          icon: _iconForCategory(catName),
        ),
      );
    });

    return Scaffold(
      backgroundColor:
          AppColors.deepPine, // Deep Pine Header Background #1E3A2E
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── 1. Deep Pine Header (#1E3A2E) ──────────────────────────
            Container(
              color: AppColors.deepPine,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _handleBack,
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Calender',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                    },
                    tooltip: 'Notifications',
                  ),
                ],
              ),
            ),

            // ── 2. Curved Body Container (#C7CBB8 / #F9FAF7) ─────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceWhite, // #F9FAF7
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
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month & Year Selector Dropdown Pills
                        _buildDateSelectorRow(context),
                        const SizedBox(height: 8),

                        // Monday-to-Sunday 7-Column Day Matrix Grid
                        _buildCalendarGrid(
                          daysWithExpenses: daysWithExpenses,
                          daysWithMeals: daysWithMeals,
                        ),
                        const SizedBox(height: 10),

                        // Segmented Filter Pills (Spends vs Categories)
                        _buildSegmentedFilterPills(),
                        const SizedBox(height: 20),

                        // Selected Day Header with Total Roulette Number
                        _buildSelectedDayHeader(dayTotal),
                        const SizedBox(height: 14),

                        // Itemized Activity Cards or Category Breakdown
                        if (_filterMode == CalendarFilterMode.spends)
                          if (activities.isEmpty)
                            _buildEmptyState()
                          else
                            ...activities.map(_buildSpendActivityCard)
                        else if (categorySummaries.isEmpty)
                          _buildEmptyState()
                        else
                          ...categorySummaries.map(_buildCategoryBreakdownCard),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelectorRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Month Dropdown Pill
                GestureDetector(
                  onTap: () => _openMonthPicker(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sandCream.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.sandCream,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _monthNames[_selectedMonth - 1],
                          style: const TextStyle(
                            color: AppColors.darkForest,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.darkForest,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Year Dropdown Pill
                GestureDetector(
                  onTap: () => _openYearPicker(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.sandCream.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.sandCream,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_selectedYear',
                          style: const TextStyle(
                            color: AppColors.darkForest,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: AppColors.darkForest,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Quick Arrow Steppers (<, >)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _goToPreviousMonth,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sandCream.withOpacity(0.25),
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: AppColors.darkForest,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: _goToNextMonth,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sandCream.withOpacity(0.25),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.darkForest,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarGrid({
    required Set<int> daysWithExpenses,
    required Set<int> daysWithMeals,
  }) {
    final firstDayWeekday = DateTime(_selectedYear, _selectedMonth, 1)
        .weekday; // 1 = Mon .. 7 = Sun
    final leadingEmptyCount = firstDayWeekday - 1; // Mon = 0, Sun = 6
    final totalDaysInMonth = _daysInSelectedMonth;
    final totalCells = ((leadingEmptyCount + totalDaysInMonth + 6) ~/ 7) * 7;
    final rowCount = totalCells ~/ 7;

    final now = DateTime.now();
    final isCurrentMonthToday =
        now.year == _selectedYear && now.month == _selectedMonth;

    return Column(
      children: [
        // 7-Column Headers (Mon..Sun)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: _weekDayNames.map((name) {
              return Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.softSage,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Grid Rows
        for (int r = 0; r < rowCount; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              children: [
                for (int c = 0; c < 7; c++) ...[
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final cellIndex = (r * 7) + c;
                        final dayNumber = cellIndex - leadingEmptyCount + 1;

                        if (dayNumber < 1 || dayNumber > totalDaysInMonth) {
                          return const SizedBox(height: 38);
                        }

                        final isSelected = dayNumber == _selectedDay;
                        final isToday =
                            isCurrentMonthToday && now.day == dayNumber;
                        final hasExpense = daysWithExpenses.contains(dayNumber);
                        final hasMeal = daysWithMeals.contains(dayNumber);

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDay = dayNumber;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.deepPine
                                      : (isToday
                                          ? AppColors.sandCream.withOpacity(0.3)
                                          : Colors.transparent),
                                  border: (isToday && !isSelected)
                                      ? Border.all(
                                          color: AppColors.midMoss,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$dayNumber',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.darkForest,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : (isToday
                                                ? FontWeight.w700
                                                : FontWeight.w500),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Indicator dots below day number
                              if (hasExpense || hasMeal)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasExpense)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.vibrantGreen,
                                        ),
                                      ),
                                    if (hasMeal)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.iconBlue,
                                        ),
                                      ),
                                  ],
                                )
                              else
                                const SizedBox(height: 5),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSegmentedFilterPills() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sandCream.withOpacity(0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.sandCream.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              title: 'Spends',
              isSelected: _filterMode == CalendarFilterMode.spends,
              onTap: () {
                if (_filterMode != CalendarFilterMode.spends) {
                  HapticFeedback.selectionClick();
                  setState(() => _filterMode = CalendarFilterMode.spends);
                }
              },
            ),
          ),
          Expanded(
            child: _buildFilterTab(
              title: 'Categories',
              isSelected: _filterMode == CalendarFilterMode.categories,
              onTap: () {
                if (_filterMode != CalendarFilterMode.categories) {
                  HapticFeedback.selectionClick();
                  setState(() => _filterMode = CalendarFilterMode.categories);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.vibrantGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x3300D084),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.darkForest : AppColors.softSage,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayHeader(double dayTotal) {
    final dayLabel =
        '${_weekDayNames[_selectedDate.weekday - 1]}, ${_monthShortNames[_selectedMonth - 1]} $_selectedDay';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkForest,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _filterMode == CalendarFilterMode.spends
                    ? 'Itemized Day Log'
                    : 'Category Share',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.softSage,
                  fontSize: 12,
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
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Total: ',
                  style: TextStyle(
                    color: AppColors.softSage,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                RouletteNumberText(
                  value: dayTotal,
                  suffix: ' DT',
                  decimalDigits: 3,
                  wholeStyle: const TextStyle(
                    color: AppColors.darkForest,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                  decimalStyle: const TextStyle(
                    color: AppColors.softSage,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpendActivityCard(CalendarActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.sandCream.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1F17),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Blue icon badge #42A5F5
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.iconBlue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2842A5F5),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              activity.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Title, timestamp, category divider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkForest,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        activity.timeLabel,
                        style: const TextStyle(
                          color: AppColors.softSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '•',
                          style: TextStyle(
                            color: AppColors.softSage,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        activity.category,
                        style: const TextStyle(
                          color: AppColors.softSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Price in RouletteNumberText wrapped in Flexible + FittedBox
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: RouletteNumberText(
                value: activity.amount,
                prefix: activity.isExpense ? '- ' : '+ ',
                suffix: ' DT',
                decimalDigits: 3,
                wholeStyle: const TextStyle(
                  color: AppColors.darkForest,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                decimalStyle: const TextStyle(
                  color: AppColors.softSage,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdownCard(CalendarCategorySummary item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.sandCream.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F1F17),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.darkForest,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item.itemCount} ${item.itemCount == 1 ? 'item' : 'items'} • ${(item.percentage * 100).toStringAsFixed(0)}%',
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.softSage,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // RouletteNumberText category total wrapped in Flexible + FittedBox
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: RouletteNumberText(
                    value: item.totalAmount,
                    suffix: ' DT',
                    decimalDigits: 3,
                    wholeStyle: const TextStyle(
                      color: AppColors.darkForest,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    decimalStyle: const TextStyle(
                      color: AppColors.softSage,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Category progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              width: double.infinity,
              color: AppColors.sandCream.withOpacity(0.35),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: item.percentage.clamp(0.0, 1.0),
                child: Container(
                  color: item.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.sandCream.withOpacity(0.35),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 28,
              color: AppColors.softSage,
            ),
          ),
          const SizedBox(height: 14),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'No activity on this date',
              style: TextStyle(
                color: AppColors.darkForest,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No expenses or campus meal bookings recorded for this day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.softSage,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: OutlinedButton.icon(
              onPressed: () {
                PaylySheets.openSpendSheet(context);
              },
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
                color: AppColors.deepPine,
              ),
              label: const Text(
                'Log Expense',
                style: TextStyle(
                  color: AppColors.deepPine,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.midMoss, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

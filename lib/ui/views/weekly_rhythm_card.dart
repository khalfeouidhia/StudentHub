import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../controllers/budget_controller.dart';

/// Screen Component: Animated Weekly Rhythm Chart Card ("StudentHub")
/// Milestone 2 (R4): 7-brand color token palette, CurvedAnimation(easeOutBack)
/// entry growth from 0.0, floating amount capsules, and strict zero-emoji styling.
class WeeklyRhythmCard extends StatefulWidget {
  final BudgetController? budget;
  final double spentSoFar;
  final double? dailySafeSpend;
  final Map<int, double>? weeklySpending;
  final List<double>? weeklyExpenses;
  final Duration animationDuration;

  const WeeklyRhythmCard({
    super.key,
    this.budget,
    this.spentSoFar = 0.0,
    this.dailySafeSpend,
    this.weeklySpending,
    this.weeklyExpenses,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// 7 designated brand color tokens cycling strictly Monday through Sunday:
  /// Day 0 (Monday):    #1E3A2E (Deep Pine)
  /// Day 1 (Tuesday):   #3E5A3F (Mid Moss)
  /// Day 2 (Wednesday): #6B7F67 (Soft Sage)
  /// Day 3 (Thursday):  #3D4337 (Dark Olive)
  /// Day 4 (Friday):    #00D084 (Vibrant Green)
  /// Day 5 (Saturday):  #0F1F17 (Dark Forest)
  /// Day 6 (Sunday):    #3E5A3F (Mid Moss)
  static const List<Color> dayColors = [
    Color(0xFF1E3A2E), // Monday - Deep Pine
    Color(0xFF3E5A3F), // Tuesday - Mid Moss
    Color(0xFF6B7F67), // Wednesday - Soft Sage
    Color(0xFF3D4337), // Thursday - Dark Olive
    Color(0xFF00D084), // Friday - Vibrant Green
    Color(0xFF0F1F17), // Saturday - Dark Forest
    Color(0xFF3E5A3F), // Sunday - Mid Moss
  ];

  static const List<Color> brandBarColors = dayColors;

  static const List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  State<WeeklyRhythmCard> createState() => _WeeklyRhythmCardState();
}

class _WeeklyRhythmCardState extends State<WeeklyRhythmCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _growthAnimation;

  static const double _maxBarHeight = 84.0;
  static const double _minBarHeight = 6.0;

  List<double> _previousHeights = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _targetHeights = const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _growthAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _targetHeights = _computeTargetHeights();
    if (widget.animationDuration == Duration.zero) {
      _animController.value = 1.0;
    } else {
      _animController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant WeeklyRhythmCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newTargetHeights = _computeTargetHeights();
    if (!_areListsEqual(_targetHeights, newTargetHeights)) {
      final progress = _growthAnimation.value;
      _previousHeights = List<double>.generate(7, (i) {
        return (lerpDouble(_previousHeights[i], _targetHeights[i], progress) ??
                0.0)
            .clamp(0.0, _maxBarHeight * 1.15);
      });
      _targetHeights = newTargetHeights;
      if (widget.animationDuration == Duration.zero) {
        _animController.value = 1.0;
      } else {
        _animController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _areListsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.001) return false;
    }
    return true;
  }

  double get _effectiveDailySafeSpend {
    if (widget.dailySafeSpend != null) return widget.dailySafeSpend!;
    return widget.budget?.dailySafeSpend ?? 0.0;
  }

  List<double> get _effectiveWeeklyExpenses {
    if (widget.weeklyExpenses != null && widget.weeklyExpenses!.isNotEmpty) {
      final list = widget.weeklyExpenses!;
      return List<double>.generate(7, (i) => i < list.length ? list[i] : 0.0);
    }
    if (widget.weeklySpending != null) {
      return List<double>.generate(
          7, (i) => widget.weeklySpending![i + 1] ?? 0.0);
    }
    final weeklyMap = widget.budget?.weeklySpending;
    if (weeklyMap != null) {
      return List<double>.generate(7, (i) => weeklyMap[i + 1] ?? 0.0);
    }
    return const [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  }

  List<double> _computeTargetHeights() {
    final expenses = _effectiveWeeklyExpenses;
    final dailySafeSpend = _effectiveDailySafeSpend;
    final highestDailySpendThisWeek = expenses.fold<double>(0.0, math.max);
    final benchmark = math.max(dailySafeSpend * 1.5, highestDailySpendThisWeek);
    final effectiveBenchmark = benchmark > 0.0 ? benchmark : 1.0;

    return List<double>.generate(7, (idx) {
      final dailyTotal = expenses[idx];
      if (dailyTotal <= 0.0) {
        return _minBarHeight;
      }
      return ((dailyTotal / effectiveBenchmark) * _maxBarHeight)
          .clamp(_minBarHeight, _maxBarHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dailySafeSpend = _effectiveDailySafeSpend;
    final weeklyExpenses = _effectiveWeeklyExpenses;
    final currentWeekday = DateTime.now().weekday; // 1 = Monday, 7 = Sunday

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E0B6945),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Weekly Rhythm with auto_graph_rounded icon and subtitle
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF1E3A2E),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Rhythm',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'vs. Daily Safe Spend (${dailySafeSpend.toStringAsFixed(1)} DT)',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Chart Section with animated bar entry from 0.0
          SizedBox(
            height: 140,
            child: AnimatedBuilder(
              animation: _growthAnimation,
              builder: (context, _) {
                final progress = _growthAnimation.value;
                final pillOpacity = _animController.value.clamp(0.0, 1.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (idx) {
                    final weekdayIndex = idx + 1;
                    final dailyTotal = weeklyExpenses[idx];
                    final isToday = weekdayIndex == currentWeekday;

                    final targetH = _targetHeights[idx];
                    final prevH = _previousHeights[idx];
                    final currentH =
                        (lerpDouble(prevH, targetH, progress) ?? 0.0)
                            .clamp(0.0, _maxBarHeight * 1.15);

                    return _buildWeeklyBar(
                      day: WeeklyRhythmCard.dayLabels[idx],
                      barHeight: currentH,
                      dailyTotal: dailyTotal,
                      isToday: isToday,
                      barColor: WeeklyRhythmCard.dayColors[idx],
                      pillOpacity: pillOpacity,
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBar({
    required String day,
    required double barHeight,
    required double dailyTotal,
    required bool isToday,
    required Color barColor,
    required double pillOpacity,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Floating dark capsule amount pill
          if (dailyTotal > 0)
            Opacity(
              opacity: pillOpacity,
              child: Container(
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1F17),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${dailyTotal.toInt()} DT',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 18),
          const SizedBox(height: 4),
          // Bar container with rounded capsule corners
          Container(
            width: 14,
            height: math.max(0.0, barHeight),
            decoration: BoxDecoration(
              color: dailyTotal > 0 ? barColor : barColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 6),
          // Weekday label
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                day,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6B7F67),
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

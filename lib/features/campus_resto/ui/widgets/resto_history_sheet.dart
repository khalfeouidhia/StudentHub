import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:studenthold_app/features/campus_resto/models/campus_meal_item.dart';
import 'package:studenthold_app/features/campus_resto/models/resto_history.dart';

/// Modal bottom sheet presenting turnstile check-in access history and recharge top-up history.
class RestoHistorySheet extends StatefulWidget {
  final List<RestoCheckIn> checkIns;
  final List<RestoTopUp> topUps;
  final int initialTabIndex;

  const RestoHistorySheet({
    super.key,
    required this.checkIns,
    required this.topUps,
    this.initialTabIndex = 0,
  });

  /// Displays the history bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<RestoCheckIn> checkIns,
    required List<RestoTopUp> topUps,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestoHistorySheet(
        checkIns: checkIns,
        topUps: topUps,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<RestoHistorySheet> createState() => _RestoHistorySheetState();
}

class _RestoHistorySheetState extends State<RestoHistorySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight =
        (mediaQuery.size.height * 0.90).clamp(480.0, mediaQuery.size.height);

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.history_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Historique Resto U',
                        style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Passages au tourniquet et recharges de solde',
                        style:
                            TextStyle(color: AppColors.mutedSage, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('resto_history_close_btn'),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.mutedSage),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Switcher Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: AppColors.deepForest,
                unselectedLabelColor: AppColors.mutedSage,
                labelStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Pointages (${widget.checkIns.length})'),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Recharges (${widget.topUps.length})'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCheckInsTab(),
                _buildTopUpsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Check-in Access History ────────────────────────────────────────

  Widget _buildCheckInsTab() {
    if (widget.checkIns.isEmpty) {
      return _buildEmptyState(
        icon: Icons.access_time_rounded,
        title: 'Aucun pointage enregistré',
        subtitle:
            'Vos passages validés au tourniquet du restaurant universitaire apparaîtront ici.',
      );
    }

    final totalMeals =
        widget.checkIns.fold<int>(0, (sum, item) => sum + item.quantity);

    return Column(
      children: [
        // KPI Summary Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Total Repas Consommés',
                    style: TextStyle(
                        color: AppColors.mutedSage,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$totalMeals repas',
                      style: const TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 14,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // List View
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: widget.checkIns.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final checkIn = widget.checkIns[index];
              return _buildCheckInTile(checkIn);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInTile(RestoCheckIn checkIn) {
    final isDejeuner = checkIn.mealType == MealType.dejeuner;
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(checkIn.timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDejeuner
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFEEF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDejeuner ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              size: 18,
              color: isDejeuner
                  ? const Color(0xFFD97706)
                  : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkIn.mealType.label,
                  style: const TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style:
                      const TextStyle(color: AppColors.mutedSage, fontSize: 11),
                ),
                if (checkIn.cin.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CIN: ${checkIn.cin}',
                    style: const TextStyle(
                        color: AppColors.mutedSageLight, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${checkIn.quantity} repas',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Top-Up Recharge History ────────────────────────────────────────

  Widget _buildTopUpsTab() {
    if (widget.topUps.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Aucune recharge enregistrée',
        subtitle:
            'Vos recharges de solde repas effectuées auprès de l\'administration apparaîtront ici.',
      );
    }

    final totalMeals =
        widget.topUps.fold<int>(0, (sum, item) => sum + item.mealCount);
    final totalSpent = widget.topUps
        .fold<double>(0.0, (sum, item) => sum + item.computedAmount);

    return Column(
      children: [
        // KPI Summary Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Rechargé',
                        style:
                            TextStyle(color: AppColors.mutedSage, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        '$totalMeals repas',
                        style: const TextStyle(
                            color: AppColors.deepForest,
                            fontSize: 14,
                            fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Montant Total',
                          style: TextStyle(
                              color: AppColors.mutedSage, fontSize: 11),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyHelper.format(totalSpent),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // List View
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            itemCount: widget.topUps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final topUp = widget.topUps[index];
              return _buildTopUpTile(topUp);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopUpTile(RestoTopUp topUp) {
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(topUp.timestamp);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_card_rounded,
                size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recharge ${topUp.mealCount} Repas',
                  style: const TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style:
                      const TextStyle(color: AppColors.mutedSage, fontSize: 11),
                ),
                if (topUp.cin.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CIN: ${topUp.cin}',
                    style: const TextStyle(
                        color: AppColors.mutedSageLight, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    topUp.formattedAmount,
                    style: const TextStyle(
                      color: AppColors.deepForest,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '0.200 DT / repas',
                    style: TextStyle(
                        color: AppColors.mutedSage,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48, color: AppColors.mutedSage.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  color: AppColors.deepForest,
                  fontSize: 15,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.mutedSage, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

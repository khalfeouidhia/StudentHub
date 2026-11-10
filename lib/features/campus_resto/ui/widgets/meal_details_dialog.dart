import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:studenthold_app/features/campus_resto/models/campus_meal_item.dart';
import 'package:studenthold_app/features/campus_resto/models/meal_details.dart';

/// Modal dialog presenting detailed menu dishes, courses, thumbnails, and main course badge.
class MealDetailsDialog extends StatelessWidget {
  final MealDetails details;
  final CampusMealItem? mealItem;
  final VoidCallback? onReserve;

  const MealDetailsDialog({
    super.key,
    required this.details,
    CampusMealItem? meal,
    CampusMealItem? mealItem,
    this.onReserve,
  }) : mealItem = mealItem ?? meal;

  /// Displays the meal details dialog.
  static Future<void> show(
    BuildContext context, {
    required MealDetails details,
    CampusMealItem? mealItem,
    VoidCallback? onReserve,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MealDetailsDialog(
        details: details,
        mealItem: mealItem,
        onReserve: onReserve,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final mainCourse = details.mainCourse;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(context),

              // Content Area
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subtitle Metadata Chips
                    if (mealItem != null) ...[
                      _buildMetadataRow(mealItem!),
                      const SizedBox(height: 14),
                    ],

                    // Empty state check
                    if (details.isEmpty)
                      _buildEmptyState()
                    else ...[
                      // Highlighted Main Course Banner
                      if (mainCourse != null) ...[
                        _buildMainCourseBanner(mainCourse),
                        const SizedBox(height: 16),
                      ],

                      // Dish Course Grid / List
                      const Text(
                        'Composition du Menu',
                        style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...details.prioritizedDishes
                          .map((dish) => _buildDishTile(dish)),
                    ],
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Row(
                  children: [
                    if (onReserve != null &&
                        mealItem?.status != MealStatus.reserved) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('meal_details_reserve_btn'),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReserve!();
                          },
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 16),
                          label: const Text('Réserver (1-Tap)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('meal_details_close_btn'),
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepForest,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Fermer',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.title,
                  style: const TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Menu officiel Restaurant Universitaire',
                  style: TextStyle(color: AppColors.mutedSage, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 20, color: AppColors.mutedSage),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(CampusMealItem item) {
    final isDejeuner = item.type == MealType.dejeuner;
    final dateFormatted = DateFormat('dd/MM/yyyy').format(item.date);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // Date Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 12, color: AppColors.mutedSage),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${item.dayLabel} $dateFormatted',
                  style: const TextStyle(
                      color: AppColors.deepForest,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Meal Type Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:
                isDejeuner ? const Color(0xFFFEF3C7) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDejeuner ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                size: 12,
                color: isDejeuner
                    ? const Color(0xFFD97706)
                    : const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  item.type.label,
                  style: TextStyle(
                    color: isDejeuner
                        ? const Color(0xFFB45309)
                        : const Color(0xFF4338CA),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Reservation Status Chip
        _buildStatusChip(item.status),
      ],
    );
  }

  Widget _buildStatusChip(MealStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case MealStatus.reserved:
        bg = const Color(0xFFDCFCE7);
        fg = AppColors.primary;
        icon = Icons.check_circle_rounded;
        break;
      case MealStatus.consumed:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        icon = Icons.task_alt_rounded;
        break;
      case MealStatus.notReserved:
      default:
        bg = AppColors.surfaceLow;
        fg = AppColors.mutedSage;
        icon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(status.label,
                style: TextStyle(
                    color: fg, fontSize: 11, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCourseBanner(MealDishItem mainCourse) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF9F1), Color(0xFFF5FAF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildThumbnail(mainCourse.fullImageUrl(), size: 70),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '★ PLAT PRINCIPAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mainCourse.name,
                  style: const TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  mainCourse.displayCategory,
                  style: const TextStyle(
                      color: AppColors.mutedSage,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishTile(MealDishItem dish) {
    final isMain = dish == details.mainCourse;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isMain
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _buildThumbnail(dish.fullImageUrl(), size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.displayCategory.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.mutedSageLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.name,
                  style: const TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isMain)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child:
                  Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String? url, {required double size}) {
    if (url == null || url.trim().isEmpty) {
      return _thumbnailPlaceholder(size);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbnailPlaceholder(size),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.inputFill,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _thumbnailPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_rounded,
            size: 20, color: AppColors.mutedSage),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.no_meals_rounded,
                size: 48, color: AppColors.mutedSage.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text(
              'Aucun plat renseigné',
              style: TextStyle(
                  color: AppColors.deepForest,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Les plats détaillés pour ce repas ne sont pas encore publiés.',
              style: TextStyle(color: AppColors.mutedSage, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../ui/navigation/main_shell.dart';
import '../../controllers/campus_resto_controller.dart';
import '../../models/campus_meal_item.dart';
import '../../models/meal_details.dart';

/// Represents the resolved time slot for the university restaurant.
class MealTimeSlot {
  final DateTime targetDate;
  final MealType mealType;
  final bool isTomorrow;
  final int daysAhead;
  final String title;
  final String? badge;
  final String? weekdayName;

  const MealTimeSlot({
    required this.targetDate,
    required this.mealType,
    required this.isTomorrow,
    required this.title,
    this.badge,
    this.daysAhead = 0,
    this.weekdayName,
  });

  /// Formatted title with optional weekday prefix for 2+ days ahead.
  String get displayTitle {
    if (daysAhead >= 2 && weekdayName != null && weekdayName!.isNotEmpty) {
      return '$weekdayName • $title';
    }
    return title;
  }

  /// ISO date key formatted as 'YYYY-MM-DD' matching CampusMealItem.dateKey.
  String get dateKey =>
      '${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealTimeSlot &&
          runtimeType == other.runtimeType &&
          targetDate.year == other.targetDate.year &&
          targetDate.month == other.targetDate.month &&
          targetDate.day == other.targetDate.day &&
          mealType == other.mealType &&
          isTomorrow == other.isTomorrow &&
          title == other.title;

  @override
  int get hashCode =>
      targetDate.year.hashCode ^
      targetDate.month.hashCode ^
      targetDate.day.hashCode ^
      mealType.hashCode ^
      isTomorrow.hashCode ^
      title.hashCode;

  @override
  String toString() =>
      'MealTimeSlot(dateKey: $dateKey, mealType: ${mealType.name}, isTomorrow: $isTomorrow, daysAhead: $daysAhead, title: "$title", badge: "$badge")';
}

/// Pure static resolver implementing time-based meal selection and smart fallback scanning.
class MealTimeSlotResolver {
  const MealTimeSlotResolver._();

  /// Capitalizes and formats the weekday name for [date] in French or English.
  static String formatWeekday(DateTime date, {bool english = false}) {
    try {
      final formatted =
          DateFormat('EEEE', english ? 'en_US' : 'fr_FR').format(date);
      if (formatted.isNotEmpty) {
        return formatted[0].toUpperCase() + formatted.substring(1);
      }
    } catch (_) {}

    if (english) {
      switch (date.weekday) {
        case DateTime.monday:
          return 'Monday';
        case DateTime.tuesday:
          return 'Tuesday';
        case DateTime.wednesday:
          return 'Wednesday';
        case DateTime.thursday:
          return 'Thursday';
        case DateTime.friday:
          return 'Friday';
        case DateTime.saturday:
          return 'Saturday';
        case DateTime.sunday:
          return 'Sunday';
        default:
          return '';
      }
    } else {
      switch (date.weekday) {
        case DateTime.monday:
          return 'Lundi';
        case DateTime.tuesday:
          return 'Mardi';
        case DateTime.wednesday:
          return 'Mercredi';
        case DateTime.thursday:
          return 'Jeudi';
        case DateTime.friday:
          return 'Vendredi';
        case DateTime.saturday:
          return 'Samedi';
        case DateTime.sunday:
          return 'Dimanche';
        default:
          return '';
      }
    }
  }

  /// Resolves the default [MealTimeSlot] based on [now] without data scanning.
  ///
  /// Cutoff rules:
  /// - 00:00–13:59: Today's Déjeuner (`MealType.dejeuner`, `isTomorrow: false`, title "Déjeuner")
  /// - 14:00–20:30: Today's Dîner (`MealType.diner`, `isTomorrow: false`, title "Dîner")
  /// - 20:31–23:59: Tomorrow's Déjeuner (`MealType.dejeuner`, `isTomorrow: true`, title "Déjeuner", badge "Demain")
  static MealTimeSlot resolve([DateTime? now, bool useEnglishLabels = false]) {
    final current = now ?? DateTime.now();
    final minuteOfDay = current.hour * 60 + current.minute;
    final today = DateTime(current.year, current.month, current.day);

    if (minuteOfDay < 14 * 60) {
      return MealTimeSlot(
        targetDate: today,
        mealType: MealType.dejeuner,
        isTomorrow: false,
        daysAhead: 0,
        title: 'Déjeuner',
        badge: null,
        weekdayName: formatWeekday(today, english: useEnglishLabels),
      );
    } else if (minuteOfDay <= 20 * 60 + 30) {
      return MealTimeSlot(
        targetDate: today,
        mealType: MealType.diner,
        isTomorrow: false,
        daysAhead: 0,
        title: 'Dîner',
        badge: null,
        weekdayName: formatWeekday(today, english: useEnglishLabels),
      );
    } else {
      final tomorrow = DateTime(current.year, current.month, current.day + 1);
      return MealTimeSlot(
        targetDate: tomorrow,
        mealType: MealType.dejeuner,
        isTomorrow: true,
        daysAhead: 1,
        title: 'Déjeuner',
        badge: useEnglishLabels ? 'Tomorrow' : 'Demain',
        weekdayName: formatWeekday(tomorrow, english: useEnglishLabels),
      );
    }
  }

  /// Scans forward up to [maxDaysAhead] (default 7 days) to find the first
  /// meal slot with an available, non-empty menu in [controller] or [hasMenu].
  static MealTimeSlot resolveNextAvailable({
    DateTime? now,
    CampusRestoController? controller,
    bool useEnglishLabels = false,
    bool Function(MealTimeSlot slot)? hasMenu,
    int maxDaysAhead = 7,
  }) {
    final current = now ?? DateTime.now();
    final initialSlot = resolve(current, useEnglishLabels);

    if (controller == null && hasMenu == null) {
      return initialSlot;
    }

    final today = DateTime(current.year, current.month, current.day);
    final minuteOfDay = current.hour * 60 + current.minute;

    int startDayOffset;
    MealType startMealType;
    if (minuteOfDay < 14 * 60) {
      startDayOffset = 0;
      startMealType = MealType.dejeuner;
    } else if (minuteOfDay <= 20 * 60 + 30) {
      startDayOffset = 0;
      startMealType = MealType.diner;
    } else {
      startDayOffset = 1;
      startMealType = MealType.dejeuner;
    }

    bool isSlotAvailable(MealTimeSlot candidate) {
      if (hasMenu != null) {
        return hasMenu(candidate);
      }
      if (controller != null) {
        return controller.hasMenuForSlot(candidate);
      }
      return false;
    }

    int currentDayOffset = startDayOffset;
    MealType currentMealType = startMealType;
    final maxOffset = startDayOffset + maxDaysAhead;

    while (currentDayOffset <= maxOffset) {
      final candidateDate =
          DateTime(today.year, today.month, today.day + currentDayOffset);
      final isTomorrow = currentDayOffset == 1;
      final weekday = formatWeekday(candidateDate, english: useEnglishLabels);

      String? badge;
      if (currentDayOffset == 0) {
        badge = null;
      } else if (currentDayOffset == 1) {
        badge = useEnglishLabels ? 'Tomorrow' : 'Demain';
      } else {
        badge = weekday;
      }

      final candidateSlot = MealTimeSlot(
        targetDate: candidateDate,
        mealType: currentMealType,
        isTomorrow: isTomorrow,
        daysAhead: currentDayOffset,
        title: currentMealType.label,
        badge: badge,
        weekdayName: weekday,
      );

      if (isSlotAvailable(candidateSlot)) {
        return candidateSlot;
      }

      if (currentMealType == MealType.dejeuner) {
        currentMealType = MealType.diner;
      } else {
        currentMealType = MealType.dejeuner;
        currentDayOffset++;
      }
    }

    return initialSlot;
  }
}

/// Query helpers for CampusRestoController and MealTimeSlot.
extension CampusRestoMealQuery on CampusRestoController {
  /// Finds the meal item matching the given [MealTimeSlot].
  CampusMealItem? findMealForSlot(MealTimeSlot slot) {
    final targetDateKey = slot.dateKey;
    for (final meal in weeklyMeals) {
      if (meal.dateKey == targetDateKey && meal.type == slot.mealType) {
        return meal;
      }
    }
    final mealsForDay = mealsByDate[targetDateKey];
    if (mealsForDay != null) {
      for (final meal in mealsForDay) {
        if (meal.type == slot.mealType) {
          return meal;
        }
      }
    }
    return null;
  }

  /// Checks whether a valid scheduled meal with available menu dishes exists for [slot].
  bool hasMenuForSlot(MealTimeSlot slot) {
    final meal = findMealForSlot(slot);
    if (meal == null) return false;
    final cached = cachedMealDetails(meal.id);
    if (cached != null && cached.dishes.isEmpty) {
      return false;
    }
    return true;
  }

  /// Checks if the meal for the given [MealTimeSlot] is reserved.
  bool isMealReserved(MealTimeSlot slot) {
    final meal = findMealForSlot(slot);
    return meal?.status == MealStatus.reserved;
  }

  /// Synchronously returns cached dish details for the given [slot] if present.
  MealDetails? cachedDetailsForSlot(MealTimeSlot slot) {
    final meal = findMealForSlot(slot);
    if (meal == null) return null;
    return cachedMealDetails(meal.id);
  }
}

/// Dynamic, time-based Resto U meal strip widget placed between Quick Actions
/// and Weekly Rhythm on the Home Screen.
class RestoUMealStrip extends StatelessWidget {
  final DateTime? currentTime;
  final VoidCallback? onNavigateToResto;
  final CampusRestoController? controller;
  final CampusMealItem? mealItemOverride;
  final MealDetails? mealDetailsOverride;
  final bool? isReservedOverride;
  final bool useEnglishLabels;
  final String? reservedBadgeLabel;
  final String? notReservedBadgeLabel;
  final String? tomorrowBadgeLabel;

  const RestoUMealStrip({
    super.key,
    this.currentTime,
    this.onNavigateToResto,
    this.controller,
    this.mealItemOverride,
    this.mealDetailsOverride,
    this.isReservedOverride,
    this.useEnglishLabels = false,
    this.reservedBadgeLabel,
    this.notReservedBadgeLabel,
    this.tomorrowBadgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    CampusRestoController? activeController = controller;
    try {
      final watchedController = context.watch<CampusRestoController>();
      activeController ??= watchedController;
    } catch (_) {}

    final now = currentTime ?? DateTime.now();
    final slot = mealItemOverride != null
        ? _slotFromOverride(mealItemOverride!, now)
        : MealTimeSlotResolver.resolveNextAvailable(
            now: now,
            controller: activeController,
            useEnglishLabels: useEnglishLabels,
          );

    final mealItem =
        mealItemOverride ?? activeController?.findMealForSlot(slot);
    final isReserved = isReservedOverride ?? (mealItem?.isReserved ?? false);

    return Container(
      key: const Key('resto_u_meal_strip'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(context, slot, isReserved, mealItem),
          const SizedBox(height: 10),
          _buildContentArea(context, activeController, mealItem),
        ],
      ),
    );
  }

  MealTimeSlot _slotFromOverride(CampusMealItem item, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
    final diffDays = itemDate.difference(today).inDays;
    final isTomorrow = diffDays == 1;
    final weekday =
        MealTimeSlotResolver.formatWeekday(itemDate, english: useEnglishLabels);
    String? badge;
    if (diffDays == 1) {
      badge = tomorrowBadgeLabel ?? (useEnglishLabels ? 'Tomorrow' : 'Demain');
    } else if (diffDays >= 2) {
      badge = weekday;
    }
    return MealTimeSlot(
      targetDate: itemDate,
      mealType: item.type,
      isTomorrow: isTomorrow,
      daysAhead: diffDays > 0 ? diffDays : 0,
      title: item.type.label,
      badge: badge,
      weekdayName: weekday,
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    MealTimeSlot slot,
    bool isReserved,
    CampusMealItem? mealItem,
  ) {
    final reservedText =
        reservedBadgeLabel ?? (useEnglishLabels ? 'Reserved' : 'Réservé');
    final notReservedText = notReservedBadgeLabel ??
        (useEnglishLabels ? 'Not Reserved' : 'Non réservé');
    final badgeLabel = isReserved ? reservedText : notReservedText;

    final tomorrowText =
        tomorrowBadgeLabel ?? (useEnglishLabels ? 'Tomorrow' : 'Demain');
    final dayBadgeLabel = slot.isTomorrow ? tomorrowText : (slot.badge ?? '');

    final badgeBgColor = isReserved
        ? const Color(0xFF1E3A2E) // Deep forest green
        : const Color(0xFFF08C4F); // Warm amber/coral

    return Row(
      key: const Key('resto_u_meal_header'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  size: 16,
                  color: Color(0xFF1E3A2E),
                ),
                const SizedBox(width: 6),
                Text(
                  slot.title,
                  key: const Key('resto_u_meal_title'),
                  style: const TextStyle(
                    color: Color(0xFF1E3A2E),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (slot.badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    key: const Key('resto_u_demain_badge'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F4EA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dayBadgeLabel,
                      key: const Key('resto_u_day_badge'),
                      style: const TextStyle(
                        color: Color(0xFF1E3A2E),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        Flexible(
          flex: 2,
          fit: FlexFit.loose,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('resto_u_reservation_badge'),
                borderRadius: BorderRadius.circular(20),
                onTap: () => _handleNavigation(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isReserved) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        badgeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentArea(
    BuildContext context,
    CampusRestoController? controller,
    CampusMealItem? mealItem,
  ) {
    if (controller != null &&
        controller.isLoading &&
        mealDetailsOverride == null) {
      return _buildLoadingState();
    }

    if (mealDetailsOverride != null) {
      if (mealDetailsOverride!.dishes.isEmpty) {
        return _buildEmptyState(context, controller);
      }
      return _buildDishStrip(
          context, mealDetailsOverride!.prioritizedDishes, mealItem);
    }

    if (mealItem == null || controller == null) {
      return _buildEmptyState(context, controller);
    }

    final cachedDetails = controller.cachedMealDetails(mealItem.id);
    if (cachedDetails != null && cachedDetails.isNotEmpty) {
      return _buildDishStrip(
          context, cachedDetails.prioritizedDishes, mealItem);
    }

    return FutureBuilder<MealDetails?>(
      future: controller.getMealDetails(mealItem.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        final details = snapshot.data;
        if (details == null || details.isEmpty) {
          return _buildEmptyState(context, controller);
        }
        return _buildDishStrip(
            context, details.prioritizedDishes, mealItem);
      },
    );
  }

  Widget _buildDishStrip(
    BuildContext context,
    List<MealDishItem> dishes,
    CampusMealItem? mealItem,
  ) {
    return SizedBox(
      key: const Key('resto_u_dish_list'),
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: dishes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dish = dishes[index];
          final isMain = dish.isMainCourseStrict;

          return Material(
            key: Key('resto_u_dish_chip_$index'),
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _handleDishTap(context, mealItem, dish),
              child: Container(
                width: 150,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFC7CBB8).withOpacity(0.40),
                    width: 1,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: _buildDishThumbnail(dish),
                        ),
                      ),
                      const SizedBox(width: 8),

                      SizedBox(
                        width: 82,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isMain) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 11,
                                    color: Color(0xFF1E3A2E),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Flexible(
                                  child: Text(
                                    dish.displayCategory.toUpperCase(),
                                    style: TextStyle(
                                      color: isMain
                                          ? const Color(0xFF1E3A2E)
                                          : const Color(0xFF6B7F67),
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dish.name,
                              style: const TextStyle(
                                color: Color(0xFF1E3A2E),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDishThumbnail(MealDishItem dish) {
    final url = dish.fullImageUrl();
    if (url == null || url.trim().isEmpty) {
      return _buildThumbnailPlaceholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const ColoredBox(
          color: Color(0xFFF4F6F4),
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFF1E3A2E),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return const ColoredBox(
      color: Color(0xFFF4F6F4),
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 20,
          color: Color(0xFF1E3A2E),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, CampusRestoController? controller) {
    return Material(
      key: const Key('resto_u_empty_state'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          if (controller != null) {
            controller.refreshDashboard();
          }
          _handleNavigation(context);
        },
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFC7CBB8).withOpacity(0.40),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 18,
                  color: Color(0xFF6B7F67),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Menu unavailable — Tap to sync',
                        style: TextStyle(
                          color: Color(0xFF1E3A2E),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Toucher pour actualiser le menu Resto U',
                        style: TextStyle(
                          color: Color(0xFF6B7F67),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.sync_rounded,
                size: 16,
                color: Color(0xFF1E3A2E),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      key: const Key('resto_u_loading_state'),
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => Container(
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFC7CBB8).withOpacity(0.35),
              width: 1,
            ),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1E3A2E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context) {
    HapticFeedback.lightImpact();
    if (onNavigateToResto != null) {
      onNavigateToResto!();
    } else {
      MainShell.of(context)?.switchTab(4);
    }
  }

  void _handleDishTap(
      BuildContext context, CampusMealItem? mealItem, MealDishItem dish) {
    HapticFeedback.lightImpact();
    _handleNavigation(context);
  }
}

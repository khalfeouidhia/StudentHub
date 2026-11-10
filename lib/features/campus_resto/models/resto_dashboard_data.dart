import 'student_profile.dart';
import 'wallet_kpis.dart';
import 'campus_meal_item.dart';
import 'resto_history.dart';

/// Aggregates all scraped data from the portal dashboard page.
class RestoDashboardData {
  final StudentProfile profile;
  final WalletKpis kpis;
  final List<CampusMealItem> weeklyMeals;
  final List<RestoCheckIn> checkIns;
  final List<RestoTopUp> topUps;
  final DateTime scrapedAt;

  const RestoDashboardData({
    required this.profile,
    required this.kpis,
    required this.weeklyMeals,
    required this.checkIns,
    required this.topUps,
    required this.scrapedAt,
  });

  RestoDashboardData.empty()
      : profile = const StudentProfile.empty(),
        kpis = const WalletKpis.empty(),
        weeklyMeals = const [],
        checkIns = const [],
        topUps = const [],
        scrapedAt = DateTime.now();

  /// Groups weekly meals by ISO date string (e.g. '2026-11-09').
  Map<String, List<CampusMealItem>> get mealsByDate {
    final map = <String, List<CampusMealItem>>{};
    for (final meal in weeklyMeals) {
      final key = meal.dateKey;
      map.putIfAbsent(key, () => []).add(meal);
    }
    return map;
  }

  /// Returns sorted unique date keys for calendar / day sections.
  List<String> get sortedDateKeys {
    final keys = mealsByDate.keys.toList();
    keys.sort();
    return keys;
  }

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'kpis': kpis.toJson(),
        'weeklyMeals': weeklyMeals.map((m) => m.toJson()).toList(),
        'checkIns': checkIns.map((c) => c.toJson()).toList(),
        'topUps': topUps.map((t) => t.toJson()).toList(),
        'scrapedAt': scrapedAt.toIso8601String(),
      };

  factory RestoDashboardData.fromJson(Map<String, dynamic> json) =>
      RestoDashboardData(
        profile: json['profile'] != null
            ? StudentProfile.fromJson(json['profile'] as Map<String, dynamic>)
            : const StudentProfile.empty(),
        kpis: json['kpis'] != null
            ? WalletKpis.fromJson(json['kpis'] as Map<String, dynamic>)
            : const WalletKpis.empty(),
        weeklyMeals: (json['weeklyMeals'] as List<dynamic>?)
                ?.map((m) => CampusMealItem.fromJson(m as Map<String, dynamic>))
                .toList() ??
            const [],
        checkIns: (json['checkIns'] as List<dynamic>?)
                ?.map((c) => RestoCheckIn.fromJson(c as Map<String, dynamic>))
                .toList() ??
            const [],
        topUps: (json['topUps'] as List<dynamic>?)
                ?.map((t) => RestoTopUp.fromJson(t as Map<String, dynamic>))
                .toList() ??
            const [],
        scrapedAt: DateTime.tryParse(json['scrapedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  RestoDashboardData copyWith({
    StudentProfile? profile,
    WalletKpis? kpis,
    List<CampusMealItem>? weeklyMeals,
    List<RestoCheckIn>? checkIns,
    List<RestoTopUp>? topUps,
    DateTime? scrapedAt,
  }) {
    return RestoDashboardData(
      profile: profile ?? this.profile,
      kpis: kpis ?? this.kpis,
      weeklyMeals: weeklyMeals ?? this.weeklyMeals,
      checkIns: checkIns ?? this.checkIns,
      topUps: topUps ?? this.topUps,
      scrapedAt: scrapedAt ?? this.scrapedAt,
    );
  }
}

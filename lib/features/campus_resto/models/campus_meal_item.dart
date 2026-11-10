/// Meal service types supported by the university restaurant.
enum MealType {
  dejeuner('Déjeuner'),
  diner('Dîner'),
  repasSec('Repas Sec'),
  unknown('Repas');

  final String label;
  const MealType(this.label);

  String get bilingualLabel {
    switch (this) {
      case MealType.dejeuner:
        return 'Déjeuner (طبق الغداء)';
      case MealType.diner:
        return 'Dîner (طبق العشاء)';
      case MealType.repasSec:
        return 'Repas Sec (الوجبة الجافّة)';
      case MealType.unknown:
        return 'Repas';
    }
  }

  static MealType fromString(String? value) {
    if (value == null) return MealType.unknown;
    final clean = value.trim();
    if (clean.contains('الغداء') ||
        clean.toLowerCase().contains('dejeuner') ||
        clean.toLowerCase().contains('déjeuner')) {
      return MealType.dejeuner;
    } else if (clean.contains('العشاء') ||
        clean.toLowerCase().contains('diner') ||
        clean.toLowerCase().contains('dîner')) {
      return MealType.diner;
    } else if (clean.contains('الجاف') ||
        clean.toLowerCase().contains('seche') ||
        clean.toLowerCase().contains('sèche')) {
      return MealType.repasSec;
    }
    return MealType.unknown;
  }
}

/// Student meal reservation and consumption status.
enum MealStatus {
  reserved('Réservé'),
  notReserved('Non réservé'),
  consumed('Consommé'),
  unknown('Inconnu');

  final String label;
  const MealStatus(this.label);

  static MealStatus fromString(String? value) {
    if (value == null) return MealStatus.unknown;
    final lower = value.toLowerCase().trim();
    // Normalize French vowel accents for robust substring matching
    final normalized =
        lower.replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e');

    // Check for negative indicator FIRST so "non réservé" is never mistaken for "réservé"
    if (normalized.contains('non') ||
        lower.contains('غير') ||
        lower.contains('لم')) {
      return MealStatus.notReserved;
    }
    if (normalized.contains('consomm') ||
        lower.contains('مستهلك') ||
        lower.contains('تم الاستهلاك')) {
      return MealStatus.consumed;
    }
    if (normalized.contains('reserv') ||
        lower.contains('محجوز') ||
        lower.contains('تم الحجز') ||
        lower.contains('حجز')) {
      return MealStatus.reserved;
    }
    return MealStatus.unknown;
  }
}

/// Represents a single meal entry in the weekly schedule.
class CampusMealItem {
  final String id;
  final MealType type;
  final DateTime date;
  final String dayLabel;
  final MealStatus status;
  final String rawStatusText;

  const CampusMealItem({
    required this.id,
    required this.type,
    required this.date,
    required this.dayLabel,
    required this.status,
    this.rawStatusText = '',
  });

  bool get isReserved => status == MealStatus.reserved;
  bool get isConsumed => status == MealStatus.consumed;
  bool get isAvailableToReserve => status == MealStatus.notReserved;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'date': date.toIso8601String(),
        'dayLabel': dayLabel,
        'status': status.name,
        'rawStatusText': rawStatusText,
      };

  factory CampusMealItem.fromJson(Map<String, dynamic> json) {
    return CampusMealItem(
      id: json['id'] as String? ?? '',
      type: MealType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MealType.unknown,
      ),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      dayLabel: json['dayLabel'] as String? ?? '',
      status: MealStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MealStatus.unknown,
      ),
      rawStatusText: json['rawStatusText'] as String? ?? '',
    );
  }

  CampusMealItem copyWith({
    String? id,
    MealType? type,
    DateTime? date,
    String? dayLabel,
    MealStatus? status,
    String? rawStatusText,
  }) {
    return CampusMealItem(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      dayLabel: dayLabel ?? this.dayLabel,
      status: status ?? this.status,
      rawStatusText: rawStatusText ?? this.rawStatusText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampusMealItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          date == other.date &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ type.hashCode ^ date.hashCode ^ status.hashCode;
}

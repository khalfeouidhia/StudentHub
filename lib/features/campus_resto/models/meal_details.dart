/// Represents a single course / dish in the meal details modal.
class MealDishItem {
  final String courseType;
  final String name;
  final String? imageRelativeUrl;

  const MealDishItem({
    required this.courseType,
    required this.name,
    this.imageRelativeUrl,
  });

  bool get hasImage =>
      imageRelativeUrl != null && imageRelativeUrl!.trim().isNotEmpty;

  String? fullImageUrl([String baseUrl = 'https://cukl.ooun.rnu.tn/']) {
    if (!hasImage) return null;
    final path = imageRelativeUrl!.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$cleanBase$cleanPath';
  }

  /// Normalizes Arabic diacritics, hamza forms, and letter variants.
  static String normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // remove tashkeel
  }

  /// Strictly determines if this dish is the Main Course (الطبق الرئيسي / Plat Principal).
  /// Handles all Arabic typography variations (الرئيسي, الرئسي, رئيس, etc.) and French forms.
  bool get isMainCourseStrict {
    final lower = courseType.toLowerCase().trim();
    final normalized = normalizeArabic(lower);
    return lower.contains('principal') ||
        lower.contains('plat chaud') ||
        normalized.contains('رئيس') ||
        normalized.contains('ريسي') ||
        normalized.contains('رءيس') ||
        lower.contains('الرئيسي') ||
        lower.contains('الرئسي') ||
        lower.contains('طبق رئيس');
  }

  /// Loose check for main course including generic 'plat'.
  bool get isMainCourseLoose {
    final lower = courseType.toLowerCase().trim();
    return isMainCourseStrict || lower.contains('plat');
  }

  bool get isMainCourse => isMainCourseLoose;

  /// Returns cleanly rendered display category, normalizing Arabic variants of الطبق الرئيسي.
  String get displayCategory {
    if (isMainCourseStrict) {
      return 'الطبق الرئيسي';
    }
    return courseType.trim();
  }

  Map<String, dynamic> toJson() => {
        'courseType': courseType,
        'name': name,
        if (imageRelativeUrl != null) 'imageRelativeUrl': imageRelativeUrl,
      };

  factory MealDishItem.fromJson(Map<String, dynamic> json) => MealDishItem(
        courseType: json['courseType'] as String? ?? '',
        name: json['name'] as String? ?? '',
        imageRelativeUrl: json['imageRelativeUrl'] as String?,
      );

  MealDishItem copyWith({
    String? courseType,
    String? name,
    String? imageRelativeUrl,
  }) {
    return MealDishItem(
      courseType: courseType ?? this.courseType,
      name: name ?? this.name,
      imageRelativeUrl: imageRelativeUrl ?? this.imageRelativeUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealDishItem &&
          runtimeType == other.runtimeType &&
          courseType == other.courseType &&
          name == other.name &&
          imageRelativeUrl == other.imageRelativeUrl;

  @override
  int get hashCode =>
      courseType.hashCode ^ name.hashCode ^ imageRelativeUrl.hashCode;
}

/// Represents the detailed menu for a meal returned from the details modal endpoint.
class MealDetails {
  final String repasId;
  final String title;
  final List<MealDishItem> dishes;

  const MealDetails({
    required this.repasId,
    required this.title,
    required this.dishes,
  });

  const MealDetails.empty(String repasId)
      : this(
          repasId: repasId,
          title: 'Détails du repas',
          dishes: const [],
        );

  bool get isEmpty => dishes.isEmpty;
  bool get isNotEmpty => dishes.isNotEmpty;

  MealDishItem? get mainCourse {
    for (final dish in dishes) {
      if (dish.isMainCourseStrict) return dish;
    }
    for (final dish in dishes) {
      if (dish.isMainCourseLoose) return dish;
    }
    return dishes.isNotEmpty ? dishes.first : null;
  }

  /// Returns the dishes sorted with Main Course first, followed by other courses.
  List<MealDishItem> get prioritizedDishes {
    if (dishes.isEmpty) return const [];
    final list = List<MealDishItem>.from(dishes);
    list.sort((a, b) {
      final aScore = a.isMainCourseStrict ? 0 : (a.isMainCourseLoose ? 1 : 2);
      final bScore = b.isMainCourseStrict ? 0 : (b.isMainCourseLoose ? 1 : 2);
      return aScore.compareTo(bScore);
    });
    return list;
  }

  Map<String, dynamic> toJson() => {
        'repasId': repasId,
        'title': title,
        'dishes': dishes.map((d) => d.toJson()).toList(),
      };

  factory MealDetails.fromJson(Map<String, dynamic> json) => MealDetails(
        repasId: json['repasId'] as String? ?? '',
        title: json['title'] as String? ?? 'Détails du repas',
        dishes: (json['dishes'] as List<dynamic>?)
                ?.map((d) => MealDishItem.fromJson(d as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  MealDetails copyWith({
    String? repasId,
    String? title,
    List<MealDishItem>? dishes,
  }) {
    return MealDetails(
      repasId: repasId ?? this.repasId,
      title: title ?? this.title,
      dishes: dishes ?? this.dishes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealDetails &&
          runtimeType == other.runtimeType &&
          repasId == other.repasId &&
          title == other.title;

  @override
  int get hashCode => repasId.hashCode ^ title.hashCode;
}

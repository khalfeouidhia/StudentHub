import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import '../models/models.dart';

/// Parses raw HTML responses from the university student portal (https://cukl.ooun.rnu.tn/).
class RestoScraperService {
  static const String defaultBaseUrl = 'https://cukl.ooun.rnu.tn/';

  /// Strict DOM Session Rule: ONLY declare session valid if `#repas-table` or `.infobox-container` is present.
  /// Never rely on string searching `'users.login'`.
  bool isSessionValid(String htmlContent) {
    if (htmlContent.trim().isEmpty) return false;
    final doc = html_parser.parse(htmlContent);
    return doc.querySelector('#repas-table') != null ||
        doc.querySelector('.infobox-container') != null;
  }

  /// Parses raw meal type string in strict Arabic/French priority order.
  String parseMealType(String rawText) {
    final clean = rawText.trim();
    if (clean.contains('الغداء') || clean.toLowerCase().contains('dejeuner')) {
      return 'Déjeuner (طبق الغداء)';
    } else if (clean.contains('العشاء') ||
        clean.toLowerCase().contains('diner')) {
      return 'Dîner (طبق العشاء)';
    } else if (clean.contains('الجاف') ||
        clean.toLowerCase().contains('seche')) {
      return 'Repas Sec (الوجبة الجافّة)';
    }
    return clean.isNotEmpty ? clean : 'Repas';
  }

  /// Parses the full student dashboard HTML into a structured [RestoDashboardData] model.
  RestoDashboardData parseDashboardHtml(String htmlContent) {
    if (htmlContent.trim().isEmpty) {
      return RestoDashboardData.empty();
    }

    final document = html_parser.parse(htmlContent);

    final profile = parseStudentProfile(document);
    final kpis = parseWalletKpis(document);
    final weeklyMeals = parseWeeklyMeals(document);
    final checkIns = parseCheckIns(document);
    final topUps = parseTopUps(document);

    return RestoDashboardData(
      profile: profile,
      kpis: kpis,
      weeklyMeals: weeklyMeals,
      checkIns: checkIns,
      topUps: topUps,
      scrapedAt: DateTime.now(),
    );
  }

  /// Parses student name and housing information.
  StudentProfile parseStudentProfile(dom.Document doc) {
    String fullName = 'Étudiant';
    final userInfoElem = doc.querySelector('.user-info');
    if (userInfoElem != null) {
      final rawText = userInfoElem.text;
      final cleaned = rawText
          .replaceAll(
              RegExp(r'^\s*Bienvenue\s*[,:]?\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        fullName = cleaned;
      }
    }

    final foyerElem = doc.querySelector('input#fu');
    final blocElem = doc.querySelector('input#bloc');
    final chambreElem = doc.querySelector('input#ch');

    final foyer = foyerElem?.attributes['value']?.trim() ?? '';
    final bloc = blocElem?.attributes['value']?.trim() ?? '';
    final chambre = chambreElem?.attributes['value']?.trim() ?? '';

    final dorm = DormInfo(
      foyer: foyer.isNotEmpty ? foyer : 'Non assigné',
      bloc: bloc.isNotEmpty ? bloc : '-',
      chambre: chambre.isNotEmpty ? chambre : '-',
    );

    // Extract CIN if present in first history row as fallback
    String cin = '';
    final firstCinTd =
        doc.querySelector('#h_access tbody tr td:nth-child(3)') ??
            doc.querySelector('#h_achat tbody tr td:nth-child(3)');
    if (firstCinTd != null) {
      cin = firstCinTd.text.trim();
    }

    return StudentProfile(
      fullName: fullName,
      dorm: dorm,
      cin: cin,
    );
  }

  /// Parses wallet KPIs from .infobox-container (.infobox cards).
  WalletKpis parseWalletKpis(dom.Document doc) {
    int soldeRepas = 0;
    int totalAchatMois = 0;
    double depensesMois = 0.0;

    final infoboxes = doc.querySelectorAll('.infobox-container .infobox');
    if (infoboxes.isEmpty) {
      return const WalletKpis.empty();
    }

    for (final box in infoboxes) {
      final contentText =
          box.querySelector('.infobox-content')?.text.toLowerCase() ??
              box.text.toLowerCase();
      final numberElem = box.querySelector('.infobox-data-number');
      final rawVal = (numberElem?.text ?? box.text).trim();

      if (contentText.contains('solde')) {
        soldeRepas = _extractInteger(rawVal);
      } else if (contentText.contains('achat')) {
        totalAchatMois = _extractInteger(rawVal);
      } else if (contentText.contains('dépense') ||
          contentText.contains('depense')) {
        depensesMois = _extractDouble(rawVal);
      }
    }

    // Fallback by position if content labels didn't match
    if (soldeRepas == 0 &&
        totalAchatMois == 0 &&
        depensesMois == 0.0 &&
        infoboxes.length >= 3) {
      soldeRepas = _extractInteger(
          infoboxes[0].querySelector('.infobox-data-number')?.text ?? '');
      totalAchatMois = _extractInteger(
          infoboxes[1].querySelector('.infobox-data-number')?.text ?? '');
      depensesMois = _extractDouble(
          infoboxes[2].querySelector('.infobox-data-number')?.text ?? '');
    }

    return WalletKpis(
      soldeRepas: soldeRepas,
      totalAchatMois: totalAchatMois,
      depensesMois: depensesMois,
    );
  }

  /// Parses weekly meal schedule table (#repas-table tbody tr).
  List<CampusMealItem> parseWeeklyMeals(dom.Document doc) {
    final List<CampusMealItem> meals = [];
    final rows = doc.querySelectorAll('#repas-table tbody tr');

    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length < 5) continue;

      final viewBtn = cols[0].querySelector(
          'input.view_data, button.view_data, .view_data, input, button, a');
      String repasId = viewBtn?.attributes['id']?.trim() ??
          viewBtn?.attributes['data-id']?.trim() ??
          viewBtn?.attributes['name']?.trim() ??
          '';

      if (repasId.isEmpty) {
        final val = viewBtn?.attributes['value']?.trim() ?? '';
        if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(val) &&
            !val.contains('Détails')) {
          repasId = val;
        }
      }

      if (repasId.isEmpty) {
        final match =
            RegExp(r'[A-Za-z]+_\d+|\b\d+\b').firstMatch(cols[0].innerHtml) ??
                RegExp(r'[A-Za-z]+_\d+|\b\d+\b').firstMatch(row.outerHtml);
        if (match != null) {
          repasId = match.group(0)!;
        } else {
          continue; // Skip informational or empty rows
        }
      }

      final rawType = cols[1].text.trim();
      final rawDate = cols[2].text.trim();
      final dayLabel = cols[3].text.trim();
      final statusCell = cols[4];
      final badgeSpan = statusCell.querySelector('span.label, .label');
      final badgeClass = badgeSpan?.className.toLowerCase() ?? '';
      final rawStatus = statusCell.text.trim();
      final lowerStatus = rawStatus.toLowerCase();

      final parsedDate = _parseDate(rawDate);
      final mealType = MealType.fromString(rawType);

      // Explicitly check negative indicators first so "non reservé" is never marked as reserved
      final bool hasNon = lowerStatus.contains('non') ||
          lowerStatus.contains('غير') ||
          lowerStatus.contains('لم');

      MealStatus mealStatus = MealStatus.unknown;
      if (hasNon ||
          badgeClass.contains('label-warning') ||
          badgeClass.contains('label-default')) {
        mealStatus = MealStatus.notReserved;
      } else if (badgeClass.contains('label-success') ||
          ((lowerStatus.contains('reserv') || lowerStatus.contains('محجوز')) &&
              !hasNon)) {
        mealStatus = MealStatus.reserved;
      } else if (badgeClass.contains('label-danger') ||
          lowerStatus.contains('consomm') ||
          lowerStatus.contains('مستهلك')) {
        mealStatus = MealStatus.consumed;
      }

      // Final fallback to string parser
      if (mealStatus == MealStatus.unknown) {
        mealStatus = MealStatus.fromString(rawStatus);
      }

      meals.add(
        CampusMealItem(
          id: repasId,
          type: mealType,
          date: parsedDate,
          dayLabel: dayLabel.isNotEmpty ? dayLabel : _getDayName(parsedDate),
          status: mealStatus,
          rawStatusText: rawStatus,
        ),
      );
    }

    // Sort chronologically by date, then Déjeuner before Dîner
    meals.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.type == MealType.dejeuner ? -1 : 1;
    });

    return meals;
  }

  /// Parses turnstile check-in access history (#h_access tbody tr).
  List<RestoCheckIn> parseCheckIns(dom.Document doc) {
    final List<RestoCheckIn> items = [];
    final rows = doc.querySelectorAll('#h_access tbody tr');

    int index = 0;
    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length < 4) continue;

      final rawDate = cols[0].text.trim();
      final rawQty = cols[1].text.trim();
      final cin = cols[2].text.trim();
      final rawType = cols[3].text.trim();

      if (rawDate.isEmpty) continue;

      final timestamp = _parseDateTime(rawDate);
      final id =
          'checkin_${cin}_${timestamp.millisecondsSinceEpoch}_${index++}';

      items.add(
        RestoCheckIn(
          id: id,
          timestamp: timestamp,
          quantity: int.tryParse(rawQty) ?? 1,
          cin: cin,
          mealType: MealType.fromString(rawType),
        ),
      );
    }

    return items;
  }

  /// Parses top-up recharge history (#h_achat tbody tr).
  List<RestoTopUp> parseTopUps(dom.Document doc) {
    final List<RestoTopUp> items = [];
    final rows = doc.querySelectorAll('#h_achat tbody tr');

    int index = 0;
    for (final row in rows) {
      final cols = row.querySelectorAll('td');
      if (cols.length < 3) continue;

      final rawDate = cols[0].text.trim();
      final rawCount = cols[1].text.trim();
      final cin = cols[2].text.trim();

      if (rawDate.isEmpty) continue;

      final timestamp = _parseDateTime(rawDate);
      final id = 'topup_${cin}_${timestamp.millisecondsSinceEpoch}_${index++}';

      items.add(
        RestoTopUp(
          id: id,
          timestamp: timestamp,
          mealCount: int.tryParse(rawCount) ?? 0,
          cin: cin,
        ),
      );
    }

    return items;
  }

  /// Parses the meal details modal HTML fragment (dishes, course types, pictures).
  /// Handles both modal grid cards (.thumbnail, .col-xs-6) and raw <tr> table fragments.
  MealDetails parseMealDetailsHtml(
    String htmlContent, {
    String repasId = '',
    String baseUrl = defaultBaseUrl,
  }) {
    if (htmlContent.trim().isEmpty) {
      return MealDetails.empty(repasId);
    }

    // CRITICAL: If the HTML fragment starts with <tr> tags or table markup without <table>,
    // Dart's package:html parser will discard <tr> elements as invalid body children!
    // Wrapping in <table><tbody> ensures full DOM preservation.
    final String sanitizedHtml;
    if (htmlContent.contains('<table')) {
      sanitizedHtml = htmlContent;
    } else {
      sanitizedHtml = '<table><tbody>$htmlContent</tbody></table>';
    }

    final doc = html_parser.parse(sanitizedHtml);

    final titleElem = doc.querySelector('.modal-title');
    final title = titleElem?.text.trim() ?? 'Menu du Jour';

    final List<MealDishItem> dishes = [];
    final seen = <String>{};

    // Strategy 1: Modal thumbnail cards (.thumbnail, .col-xs-6, .col-md-3)
    final thumbnails =
        doc.querySelectorAll('.thumbnail, .col-xs-6, .col-md-3, .dish-card');
    for (final card in thumbnails) {
      final h5Elem = card.querySelector('h5, h4, .dish-category');
      final nameElem = card.querySelector('strong, p strong, .dish-name, p');
      final imgElem = card.querySelector('img');

      final category = h5Elem?.text.trim() ?? 'Plat';
      String name = nameElem?.text.trim() ?? '';
      if (name.isEmpty && imgElem != null) {
        name = imgElem.attributes['alt']?.trim() ?? '';
      }

      if (name.isEmpty) continue;
      final key = '$category:$name';
      if (seen.contains(key)) continue;
      seen.add(key);

      String? relativeImg = imgElem?.attributes['src']?.trim();

      dishes.add(
        MealDishItem(
          courseType: category,
          name: name,
          imageRelativeUrl: relativeImg,
        ),
      );
    }

    // Strategy 2: Table rows (<tr>...<td>...</td>...</tr>) for raw table fragments
    if (dishes.isEmpty) {
      final rows = doc.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.isEmpty) continue; // Skip <th> headers

        String category = '';
        String name = '';
        String? relativeImg;

        final imgElem = row.querySelector('img');
        if (imgElem != null) {
          relativeImg = imgElem.attributes['src']?.trim();
          final alt = imgElem.attributes['alt']?.trim();
          if (alt != null && alt.isNotEmpty) {
            name = alt;
          }
        }

        if (cells.length == 1) {
          final text = cells[0].text.trim();
          if (text.contains(':')) {
            final parts = text.split(':');
            category = parts[0].trim();
            name = parts.sublist(1).join(':').trim();
          } else {
            name = text;
            category = 'Plat';
          }
        } else if (cells.length == 2) {
          final c0 = cells[0].text.trim();
          final c1 = cells[1].text.trim();
          if (_isCategoryWord(c0)) {
            category = c0;
            name = c1.isNotEmpty ? c1 : name;
          } else if (_isCategoryWord(c1)) {
            category = c1;
            name = c0.isNotEmpty ? c0 : name;
          } else {
            category = c0;
            name = c1.isNotEmpty ? c1 : name;
          }
        } else if (cells.length >= 3) {
          final c0 = cells[0].text.trim();
          final c1 = cells[1].text.trim();
          final c2 = cells[2].text.trim();

          if (_isCategoryWord(c0)) {
            category = c0;
            name = c1.isNotEmpty ? c1 : c2;
          } else if (_isCategoryWord(c1)) {
            category = c1;
            name = c2.isNotEmpty ? c2 : c0;
          } else {
            category = c0.isNotEmpty ? c0 : 'Plat';
            name = c1.isNotEmpty ? c1 : c2;
          }
        }

        if (name.isEmpty) {
          name = row.text.trim();
        }

        if (name.isNotEmpty &&
            !name.toLowerCase().contains('action') &&
            !name.toLowerCase().contains('statut') &&
            !name.toLowerCase().contains('date')) {
          final key = '$category:$name';
          if (!seen.contains(key)) {
            seen.add(key);
            dishes.add(
              MealDishItem(
                courseType: category.isNotEmpty ? category : 'Plat',
                name: name,
                imageRelativeUrl: relativeImg,
              ),
            );
          }
        }
      }
    }

    return MealDetails(
      repasId: repasId,
      title: title,
      dishes: dishes,
    );
  }

  bool _isCategoryWord(String text) {
    final lower = text.toLowerCase().trim();
    return lower.contains('entrée') ||
        lower.contains('entree') ||
        lower.contains('مقبلات') ||
        lower.contains('سلطة') ||
        lower.contains('principal') ||
        lower.contains('plat') ||
        lower.contains('الرئيسي') ||
        lower.contains('رئيس') ||
        lower.contains('رئسي') ||
        lower.contains('dessert') ||
        lower.contains('تحلية') ||
        lower.contains('غلال') ||
        lower.contains('فاكهة') ||
        lower.contains('complément') ||
        lower.contains('complement') ||
        lower.contains('pain') ||
        lower.contains('yaourt') ||
        lower.contains('خبز');
  }

  // --- Helper Methods ---

  int _extractInteger(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? (int.tryParse(match.group(0)!) ?? 0) : 0;
  }

  double _extractDouble(String text) {
    final cleaned = text.replaceAll(',', '.');
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleaned);
    return match != null ? (double.tryParse(match.group(0)!) ?? 0.0) : 0.0;
  }

  DateTime _parseDate(String dateStr) {
    final trimmed = dateStr.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final slashMatch =
        RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(trimmed);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final year = int.parse(slashMatch.group(3)!);
      return DateTime(year, month, day);
    }

    return DateTime.now();
  }

  DateTime _parseDateTime(String dateTimeStr) {
    final trimmed = dateTimeStr.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final isoMatch = RegExp(
            r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?')
        .firstMatch(trimmed);
    if (isoMatch != null) {
      return DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
        int.parse(isoMatch.group(4)!),
        int.parse(isoMatch.group(5)!),
        isoMatch.group(6) != null ? int.parse(isoMatch.group(6)!) : 0,
      );
    }

    final slashMatch = RegExp(
            r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?')
        .firstMatch(trimmed);
    if (slashMatch != null) {
      return DateTime(
        int.parse(slashMatch.group(3)!),
        int.parse(slashMatch.group(2)!),
        int.parse(slashMatch.group(1)!),
        int.parse(slashMatch.group(4)!),
        int.parse(slashMatch.group(5)!),
        slashMatch.group(6) != null ? int.parse(slashMatch.group(6)!) : 0,
      );
    }

    return DateTime.now();
  }

  String _getDayName(DateTime dt) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    return days[dt.weekday - 1];
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_scraper_service.dart';

void main() {
  late RestoScraperService scraper;

  setUp(() {
    scraper = RestoScraperService();
  });

  group('Adversarial Test Suite 1: Empty, Whitespace & Control Characters', () {
    test('handles completely empty string', () {
      final data = scraper.parseDashboardHtml('');
      expect(data.profile.fullName, 'Étudiant');
      expect(data.kpis.soldeRepas, 0);
      expect(data.weeklyMeals, isEmpty);
      expect(data.checkIns, isEmpty);
      expect(data.topUps, isEmpty);
    });

    test('handles whitespace and newlines only', () {
      final data = scraper.parseDashboardHtml('   \n\t\r\n   ');
      expect(data.profile.fullName, 'Étudiant');
      expect(data.weeklyMeals, isEmpty);
    });

    test('handles null bytes and binary garbage', () {
      final garbage =
          '\x00\x01\x02\x03<html\x00><body>\x00<div class="user-info">\x00Étudiant \x00Test</div></body></html>';
      final data = scraper.parseDashboardHtml(garbage);
      expect(data.profile.fullName, contains('Étudiant'));
      expect(data.weeklyMeals, isEmpty);
    });

    test('handles "null", "undefined", and JavaScript literals as HTML content',
        () {
      final data1 = scraper.parseDashboardHtml('null');
      expect(data1.profile.fullName, 'Étudiant');

      final data2 = scraper.parseDashboardHtml('undefined');
      expect(data2.profile.fullName, 'Étudiant');

      final data3 = scraper.parseDashboardHtml('NaN');
      expect(data3.profile.fullName, 'Étudiant');
    });
  });

  group('Adversarial Test Suite 2: Deeply Nested and Malformed Tags Soup', () {
    test('handles 500 levels of nested tags without stack overflow', () {
      final buffer = StringBuffer('<html><body>');
      for (int i = 0; i < 500; i++) {
        buffer.write('<div id="d_$i" class="infobox-container">');
      }
      buffer.write(
          '<div class="infobox"><span class="infobox-data-number">42</span><span class="infobox-content">Solde repas</span></div>');
      for (int i = 0; i < 500; i++) {
        buffer.write('</div>');
      }
      buffer.write('</body></html>');

      final data = scraper.parseDashboardHtml(buffer.toString());
      expect(data.kpis.soldeRepas, 42);
    });

    test('handles completely unclosed tags and broken DOM trees', () {
      const brokenHtml = '''
        <html><body>
        <div class="user-info"><b><i>Bienvenue Mohamed
        <input id="fu" value="Foyer A
        <table id="repas-table">
        <tbody>
        <tr><td><input class="view_data" id="999"><td>Déjeuner<td>09/11/2026<td>Lundi<td>Réservé
        <tr><td>broken row
      ''';

      final data = scraper.parseDashboardHtml(brokenHtml);
      expect(data.profile.fullName, isNotEmpty);
      expect(data.weeklyMeals.length, inInclusiveRange(0, 1));
    });

    test('handles random tag soup and misplaced elements', () {
      const soupHtml = '''
        <!DOCTYPE html>
        </td></tr></table>
        <div class="infobox-container">
          <div class="infobox"><div><div class="infobox-content">Total achat mois</div></div><span class="infobox-data-number">15</span></div>
        </div>
        <input id="ch" value="301" />
        <input id="bloc" value="C" />
        <span class="user-info">Bienvenue, Fatima Zahra</span>
      ''';

      final data = scraper.parseDashboardHtml(soupHtml);
      expect(data.profile.fullName, 'Fatima Zahra');
      expect(data.profile.dorm.bloc, 'C');
      expect(data.profile.dorm.chambre, '301');
      expect(data.kpis.totalAchatMois, 15);
    });
  });

  group('Adversarial Test Suite 3: Script, SVG, and Injection Attacks', () {
    test('neutralizes script tags, attributes, and svg injections in user-info',
        () {
      const xssHtml = '''
        <div class="user-info">
          Bienvenue <script>alert("XSS")</script><img src="x" onerror="alert(1)">Anis Ben Ali
        </div>
      ''';

      final data = scraper.parseDashboardHtml(xssHtml);
      expect(data.profile.fullName, contains('Anis Ben Ali'));
      expect(data.profile.fullName, isNot(contains('<script>')));
    });

    test('handles malicious attributes and HTML entities safely', () {
      const entityHtml = '''
        <div class="user-info">
          Bienvenue &lt;b&gt;Sami &amp; Youssef&lt;/b&gt;
        </div>
        <input id="fu" value="&quot;Residence&#39; &amp; Campus&quot;" />
      ''';

      final data = scraper.parseDashboardHtml(entityHtml);
      expect(data.profile.fullName, contains('Sami'));
      expect(data.profile.dorm.foyer, contains('Residence'));
    });
  });

  group('Adversarial Test Suite 4: Unicode, RTL Arabic & Zalgo Text', () {
    test('handles full Arabic student profile and housing information', () {
      const arabicHtml = '''
        <div class="user-info">
          مرحبا أحمد بن صالح
        </div>
        <input id="fu" value="المبيت الجامعي قليبية" />
        <input id="bloc" value="أ" />
        <input id="ch" value="١٠٤" />
      ''';

      final data = scraper.parseDashboardHtml(arabicHtml);
      expect(data.profile.fullName, 'مرحبا أحمد بن صالح');
      expect(data.profile.dorm.foyer, 'المبيت الجامعي قليبية');
      expect(data.profile.dorm.bloc, 'أ');
      expect(data.profile.dorm.chambre, '١٠٤');
    });

    test('handles mixed RTL/LTR and bidirectional formatting characters', () {
      const bidiHtml = '''
        <div class="user-info">
          Bienvenue \u202Eيلع نب دمحأ\u202C (Student #441) 🎓
        </div>
      ''';

      final data = scraper.parseDashboardHtml(bidiHtml);
      expect(data.profile.fullName, contains('Student #441'));
    });

    test('handles zalgo / combining unicode characters without crashing', () {
      const zalgo = 'B̵i̵e̵n̵v̵e̵n̵u̵e̵ ̵H̵a̵c̵k̵e̵r̵';
      final zalgoHtml = '<div class="user-info">$zalgo</div>';

      final data = scraper.parseDashboardHtml(zalgoHtml);
      expect(data.profile.fullName, isNotEmpty);
    });
  });

  group('Adversarial Test Suite 5: Extreme Numeric Boundaries in KPIs', () {
    test('handles 100-digit massive numbers in solde without overflow crash',
        () {
      const massiveNumber =
          '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999';
      final html = '''
        <div class="infobox-container">
          <div class="infobox">
            <div class="infobox-data-number">$massiveNumber</div>
            <div class="infobox-content">Solde repas</div>
          </div>
        </div>
      ''';

      final data = scraper.parseDashboardHtml(html);
      // Overflow should safely fall back to 0 without unhandled exception
      expect(data.kpis.soldeRepas, isA<int>());
    });

    test('handles negative values and strange currency formats in expenses',
        () {
      const strangeKpis = '''
        <div class="infobox-container">
          <div class="infobox">
            <div class="infobox-data-number">-12,500 DT</div>
            <div class="infobox-content">Dépenses du mois</div>
          </div>
          <div class="infobox">
            <div class="infobox-data-number">N/A</div>
            <div class="infobox-content">Total achat mois</div>
          </div>
          <div class="infobox">
            <div class="infobox-data-number">Gratuit / 0 repas</div>
            <div class="infobox-content">Solde actuel</div>
          </div>
        </div>
      ''';

      final data = scraper.parseDashboardHtml(strangeKpis);
      expect(data.kpis.depensesMois, isNonNegative);
      expect(data.kpis.totalAchatMois, 0);
      expect(data.kpis.soldeRepas, 0);
    });

    test(
        'handles KPI fallback by index when infobox-content text is completely missing',
        () {
      const positionOnlyHtml = '''
        <div class="infobox-container">
          <div class="infobox"><span class="infobox-data-number">10</span></div>
          <div class="infobox"><span class="infobox-data-number">20</span></div>
          <div class="infobox"><span class="infobox-data-number">4,500</span></div>
        </div>
      ''';

      final data = scraper.parseDashboardHtml(positionOnlyHtml);
      expect(data.kpis.soldeRepas, 10);
      expect(data.kpis.totalAchatMois, 20);
      expect(data.kpis.depensesMois, 4.5);
    });
  });

  group('Adversarial Test Suite 6: Date Parsing Anomalies & Corrupt Calendars',
      () {
    test('handles out-of-range dates like 31/02/2026 and 99/99/9999 safely',
        () {
      const corruptDatesHtml = '''
        <table id="repas-table">
          <tbody>
            <tr>
              <td><input class="view_data" id="101" /></td>
              <td>Déjeuner</td>
              <td>31/02/2026</td>
              <td>Lundi</td>
              <td>Réservé</td>
            </tr>
            <tr>
              <td><input class="view_data" id="102" /></td>
              <td>Dîner</td>
              <td>99/99/9999</td>
              <td>Mardi</td>
              <td>Non réservé</td>
            </tr>
            <tr>
              <td><input class="view_data" id="103" /></td>
              <td>Déjeuner</td>
              <td>not-a-date</td>
              <td>Mercredi</td>
              <td>Consommé</td>
            </tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(corruptDatesHtml);
      expect(data.weeklyMeals.length, 3);
      for (final meal in data.weeklyMeals) {
        expect(meal.date, isA<DateTime>());
        expect(meal.dateKey, isNotEmpty);
      }
    });

    test('handles empty dates and ISO format variations', () {
      const dateVariationsHtml = '''
        <table id="repas-table">
          <tbody>
            <tr>
              <td><input class="view_data" id="201" /></td>
              <td>Déjeuner</td>
              <td>2026-11-15</td>
              <td>Dimanche</td>
              <td>Réservé</td>
            </tr>
            <tr>
              <td><input class="view_data" id="202" /></td>
              <td>Dîner</td>
              <td>   </td>
              <td>Dimanche</td>
              <td>Non réservé</td>
            </tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(dateVariationsHtml);
      expect(data.weeklyMeals.length, 2);
      expect(
          data.weeklyMeals.any((m) =>
              m.date.year == 2026 && m.date.month == 11 && m.date.day == 15),
          isTrue);
    });
  });

  group(
      'Adversarial Test Suite 7: Table Row Truncation, Missing Columns & ID Extraction',
      () {
    test(
        'handles rows with 0, 1, 2, 3, 4 columns (less than 5) without index bounds error',
        () {
      const truncatedTable = '''
        <table id="repas-table">
          <tbody>
            <tr></tr>
            <tr><td>One cell only</td></tr>
            <tr><td>Cell 1</td><td>Cell 2</td></tr>
            <tr><td>Cell 1</td><td>Cell 2</td><td>Cell 3</td></tr>
            <tr><td>Cell 1</td><td>Cell 2</td><td>Cell 3</td><td>Cell 4</td></tr>
            <tr>
              <td><input class="view_data" id="valid_5" /></td>
              <td>Déjeuner</td>
              <td>09/11/2026</td>
              <td>Lundi</td>
              <td>Réservé</td>
            </tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(truncatedTable);
      expect(data.weeklyMeals.length, 1);
      expect(data.weeklyMeals.first.id, 'valid_5');
    });

    test('extracts ID from button value or data-id or regex fallback', () {
      const variedButtons = '''
        <table id="repas-table">
          <tbody>
            <tr>
              <td><button class="view_data" data-id="555"></button></td>
              <td>Déjeuner</td>
              <td>09/11/2026</td>
              <td>Lundi</td>
              <td>Réservé</td>
            </tr>
            <tr>
              <td><input class="view_data" value="777" /></td>
              <td>Dîner</td>
              <td>09/11/2026</td>
              <td>Lundi</td>
              <td>Non réservé</td>
            </tr>
            <tr data-repas-code="999">
              <td><span class="view_data">Détails 999</span></td>
              <td>Déjeuner</td>
              <td>10/11/2026</td>
              <td>Mardi</td>
              <td>Réservé</td>
            </tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(variedButtons);
      expect(data.weeklyMeals.length, 3);
      expect(data.weeklyMeals.map((m) => m.id), containsAll(['555', '777']));
    });
  });

  group(
      'Adversarial Test Suite 8: Comparator Stress Test (Identical Dates & Meal Types)',
      () {
    test(
        'sorts list of 50 meals with identical date and identical type without crashing',
        () {
      // Tests whether meals.sort() obeys anti-symmetry or crashes Dart SDK dual-pivot quicksort
      final buffer = StringBuffer('<table id="repas-table"><tbody>');
      for (int i = 0; i < 50; i++) {
        buffer.write('''
          <tr>
            <td><input class="view_data" id="diner_$i" /></td>
            <td>Dîner</td>
            <td>09/11/2026</td>
            <td>Lundi</td>
            <td>Non réservé</td>
          </tr>
        ''');
      }
      for (int i = 0; i < 50; i++) {
        buffer.write('''
          <tr>
            <td><input class="view_data" id="dej_$i" /></td>
            <td>Déjeuner</td>
            <td>09/11/2026</td>
            <td>Lundi</td>
            <td>Réservé</td>
          </tr>
        ''');
      }
      buffer.write('</tbody></table>');

      final data = scraper.parseDashboardHtml(buffer.toString());
      expect(data.weeklyMeals.length, 100);
      // All Déjeuner meals should be sorted before Dîner meals
      final firstDinerIndex =
          data.weeklyMeals.indexWhere((m) => m.type == MealType.diner);
      final lastDejeunerIndex =
          data.weeklyMeals.lastIndexWhere((m) => m.type == MealType.dejeuner);
      expect(lastDejeunerIndex, lessThan(firstDinerIndex));
    });

    test('sorts list with unknown meal types and conflicting timestamps safely',
        () {
      const unknownMeals = '''
        <table id="repas-table">
          <tbody>
            <tr>
              <td><input class="view_data" id="u1" /></td>
              <td>Collation</td>
              <td>10/11/2026</td>
              <td>Mardi</td>
              <td>Inconnu</td>
            </tr>
            <tr>
              <td><input class="view_data" id="u2" /></td>
              <td>Gouter</td>
              <td>10/11/2026</td>
              <td>Mardi</td>
              <td>Inconnu</td>
            </tr>
            <tr>
              <td><input class="view_data" id="u3" /></td>
              <td>Déjeuner</td>
              <td>10/11/2026</td>
              <td>Mardi</td>
              <td>Réservé</td>
            </tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(unknownMeals);
      expect(data.weeklyMeals.length, 3);
      expect(data.weeklyMeals.first.type, MealType.dejeuner);
    });
  });

  group(
      'Adversarial Test Suite 9: Turnstile Check-Ins and Top-Up History Stress',
      () {
    test(
        'handles check-in table with corrupted rows, missing CIN, and negative quantity',
        () {
      const corruptAccessHtml = '''
        <table id="h_access">
          <tbody>
            <tr><td>2026-11-09 12:30:00</td><td>-1</td><td></td><td>Déjeuner</td></tr>
            <tr><td>corrupt-date</td><td>abc</td><td>09876543</td><td>Dîner</td></tr>
            <tr><td></td><td>1</td><td>09876543</td><td>Déjeuner</td></tr>
            <tr><td>2026-11-09 19:45:00</td><td>2</td><td>09876543</td><td>UnknownType</td></tr>
          </tbody>
        </table>
      ''';

      final data = scraper.parseDashboardHtml(corruptAccessHtml);
      // Empty date row is skipped (line 193: if (rawDate.isEmpty) continue)
      expect(data.checkIns.length, 3);
      expect(data.checkIns[0].quantity, -1);
      expect(data.checkIns[1].quantity, 1); // fallback to 1 on 'abc'
      expect(data.checkIns[2].mealType, MealType.unknown);
    });

    test('handles 500 top-up rows without performance degradation', () {
      final buffer = StringBuffer('<table id="h_achat"><tbody>');
      for (int i = 0; i < 500; i++) {
        buffer.write(
            '<tr><td>2026-11-01 10:00:00</td><td>10</td><td>09876543</td></tr>');
      }
      buffer.write('</tbody></table>');

      final stopwatch = Stopwatch()..start();
      final data = scraper.parseDashboardHtml(buffer.toString());
      stopwatch.stop();

      expect(data.topUps.length, 500);
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    });
  });

  group(
      'Adversarial Test Suite 10: Meal Details Modal Fragility & Special Characters',
      () {
    test('handles empty, corrupted, and title-only modal fragments', () {
      final empty = scraper.parseMealDetailsHtml('');
      expect(empty.isEmpty, isTrue);

      final titleOnly = scraper
          .parseMealDetailsHtml('<div class="modal-title">Menu Unique</div>');
      expect(titleOnly.title, 'Menu Unique');
      expect(titleOnly.dishes, isEmpty);
      expect(titleOnly.isEmpty, isTrue);
    });

    test(
        'handles thumbnails with missing images, missing names, and duplicate categories',
        () {
      const brokenModal = '''
        <div class="modal-title">Menu du Jour</div>
        <div class="col-xs-6 thumbnail">
          <p><strong>Salade Mechouia</strong></p>
        </div>
        <div class="col-xs-6 thumbnail">
          <h5>Plat Principal</h5>
          <img src="" alt="Ojja Merguez" />
        </div>
        <div class="col-xs-6 thumbnail">
          <h5>Dessert</h5>
          <!-- completely empty card -->
        </div>
        <div class="col-xs-6 thumbnail">
          <!-- duplicate card -->
          <h5>Plat Principal</h5>
          <p><strong>Ojja Merguez</strong></p>
        </div>
      ''';

      final details = scraper.parseMealDetailsHtml(brokenModal, repasId: '888');
      expect(details.dishes.length, 2);
      expect(details.dishes[0].name, 'Salade Mechouia');
      expect(details.dishes[0].courseType, 'Plat');
      expect(details.dishes[1].name, 'Ojja Merguez');
      expect(details.dishes[1].courseType, 'Plat Principal');
    });

    test('resolves tricky and unusual image URLs safely', () {
      const trickyUrls = '''
        <div class="col-md-3">
          <h5>Plat</h5>
          <strong>Riz au Poulet</strong>
          <img src="images/plat/special%20dish.jpg" />
        </div>
        <div class="col-md-3">
          <h5>Fruit</h5>
          <strong>Pomme</strong>
          <img src="https://external-cdn.tn/apple.png" />
        </div>
      ''';

      final details = scraper.parseMealDetailsHtml(trickyUrls, repasId: '999');
      expect(details.dishes.length, 2);
      expect(details.dishes[0].fullImageUrl(),
          'https://cukl.ooun.rnu.tn/images/plat/special%20dish.jpg');
      expect(details.dishes[1].fullImageUrl(),
          'https://external-cdn.tn/apple.png');
    });
  });

  group('Adversarial Test Suite 11: Mega Payload & Stress Harness', () {
    test('handles 1MB combined adversarial payload in single parse call', () {
      final buffer = StringBuffer();
      buffer.write('<html><head><title>Mega Test</title></head><body>');
      buffer.write('<div class="user-info">Bienvenue Sabrine Dridi</div>');
      buffer.write(
          '<input id="fu" value="Foyer Jasmin" /><input id="bloc" value="F" /><input id="ch" value="999" />');
      buffer.write(
          '<div class="infobox-container"><div class="infobox"><span class="infobox-data-number">99</span><span class="infobox-content">Solde</span></div></div>');

      buffer.write('<table id="repas-table"><tbody>');
      for (int i = 0; i < 300; i++) {
        buffer.write(
            '<tr><td><input class="view_data" id="meal_$i" /></td><td>Déjeuner</td><td>0${(i % 28) + 1}/11/2026</td><td>Jour</td><td>Réservé</td></tr>');
      }
      buffer.write('</tbody></table>');

      buffer.write('<table id="h_access"><tbody>');
      for (int i = 0; i < 300; i++) {
        buffer.write(
            '<tr><td>2026-11-09 12:00:00</td><td>1</td><td>09876543</td><td>Déjeuner</td></tr>');
      }
      buffer.write('</tbody></table>');

      buffer.write('<table id="h_achat"><tbody>');
      for (int i = 0; i < 300; i++) {
        buffer.write(
            '<tr><td>2026-11-01 09:00:00</td><td>20</td><td>09876543</td></tr>');
      }
      buffer.write('</tbody></table>');
      buffer.write('</body></html>');

      final megaHtml = buffer.toString();
      expect(megaHtml.length, greaterThan(50000));

      final stopwatch = Stopwatch()..start();
      final data = scraper.parseDashboardHtml(megaHtml);
      stopwatch.stop();

      expect(data.weeklyMeals.length, 300);
      expect(data.checkIns.length, 300);
      expect(data.topUps.length, 300);
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });
  });
}

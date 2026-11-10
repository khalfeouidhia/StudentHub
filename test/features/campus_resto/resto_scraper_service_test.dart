import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/resto_scraper_service.dart';

void main() {
  late RestoScraperService scraper;

  setUp(() {
    scraper = RestoScraperService();
  });

  group('RestoScraperService — Full Dashboard Parsing', () {
    test('parses dashboard_full.html into complete RestoDashboardData',
        () async {
      final file = File('test/fixtures/campus_resto/dashboard_full.html');
      final html = await file.readAsString();

      final data = scraper.parseDashboardHtml(html);

      // Student Profile & Dorm
      expect(data.profile.fullName, 'Ahmed Ben Salah');
      expect(data.profile.dorm.foyer, 'Cité Universitaire Kélibia');
      expect(data.profile.dorm.bloc, 'B');
      expect(data.profile.dorm.chambre, '104');
      expect(data.profile.dorm.hasAssignment, isTrue);
      expect(data.profile.dorm.roomDisplay, 'Bloc B • Ch. 104');

      // KPIs
      expect(data.kpis.soldeRepas, 24);
      expect(data.kpis.totalAchatMois, 40);
      expect(data.kpis.depensesMois, 3.200);
      expect(data.kpis.formattedDepenses, '3.200 DT');

      // Weekly Meals (5 items)
      expect(data.weeklyMeals.length, 5);

      final meal1 = data.weeklyMeals[0];
      expect(meal1.id, '101');
      expect(meal1.type, MealType.dejeuner);
      expect(meal1.dayLabel, 'Lundi');
      expect(meal1.status, MealStatus.reserved);
      expect(meal1.isReserved, isTrue);

      final meal2 = data.weeklyMeals[1];
      expect(meal2.id, '102');
      expect(meal2.type, MealType.diner);
      expect(meal2.status, MealStatus.notReserved);
      expect(meal2.isAvailableToReserve, isTrue);

      final meal4 = data.weeklyMeals[3];
      expect(meal4.id, '104');
      expect(meal4.status, MealStatus.consumed);
      expect(meal4.isConsumed, isTrue);

      // Grouping by date
      final grouped = data.mealsByDate;
      expect(grouped.keys.length, 3);
      expect(grouped['2026-11-09']?.length, 2);
      expect(grouped['2026-11-10']?.length, 2);
      expect(grouped['2026-11-11']?.length, 1);

      // Check-ins (3 items)
      expect(data.checkIns.length, 3);
      expect(data.checkIns[0].quantity, 1);
      expect(data.checkIns[0].cin, '09876543');
      expect(data.checkIns[0].mealType, MealType.dejeuner);

      // Top-ups (2 items)
      expect(data.topUps.length, 2);
      expect(data.topUps[0].mealCount, 20);
      expect(data.topUps[0].cin, '09876543');
      expect(data.topUps[0].computedAmount, 4.000);
    });
  });

  group('RestoScraperService — Empty & Malformed Fixtures', () {
    test('parses dashboard_empty.html safely with default fallbacks', () async {
      final file = File('test/fixtures/campus_resto/dashboard_empty.html');
      final html = await file.readAsString();

      final data = scraper.parseDashboardHtml(html);

      expect(data.profile.fullName, 'Inconnu');
      expect(data.kpis.soldeRepas, 0);
      expect(data.kpis.totalAchatMois, 0);
      expect(data.kpis.depensesMois, 0.0);
      expect(data.weeklyMeals, isEmpty);
      expect(data.checkIns, isEmpty);
      expect(data.topUps, isEmpty);
    });

    test('parses dashboard_malformed.html safely without unhandled exceptions',
        () async {
      final file = File('test/fixtures/campus_resto/dashboard_malformed.html');
      final html = await file.readAsString();

      final data = scraper.parseDashboardHtml(html);

      expect(data.profile.fullName, 'Étudiant');
      expect(data.profile.dorm.hasAssignment, isFalse);
      expect(data.kpis.soldeRepas, 0);
      expect(data.kpis.totalAchatMois, 0);
      expect(data.kpis.depensesMois, 0.0);
      // Row with missing input.view_data or bad data should not crash
      expect(data.weeklyMeals.length, inInclusiveRange(0, 1));
    });

    test('handles empty or blank strings gracefully without throwing', () {
      final emptyData = scraper.parseDashboardHtml('');
      expect(emptyData.profile.fullName, 'Étudiant');
      expect(emptyData.weeklyMeals, isEmpty);

      final malformedData = scraper.parseDashboardHtml(
          '<html><body><div>Hello world</div></body></html>');
      expect(malformedData.profile.fullName, 'Étudiant');
      expect(malformedData.kpis.soldeRepas, 0);
      expect(malformedData.weeklyMeals, isEmpty);
    });
  });

  group('RestoScraperService — Meal Details Modal Parsing', () {
    test('parses meal_details_modal.html with resolved absolute image URLs',
        () async {
      final file = File('test/fixtures/campus_resto/meal_details_modal.html');
      final html = await file.readAsString();

      final details = scraper.parseMealDetailsHtml(html, repasId: '101');

      expect(details.repasId, '101');
      expect(details.title, 'Menu du Déjeuner - 09/11/2026');
      expect(details.dishes.length, 4);

      final dish1 = details.dishes[0];
      expect(dish1.courseType, 'Entrée');
      expect(dish1.name, 'Salade Tunisienne');
      expect(dish1.fullImageUrl(),
          'https://cukl.ooun.rnu.tn/images/plat/entree/CP_1.jpg');

      final dish2 = details.dishes[1];
      expect(dish2.courseType, 'Plat Principal');
      expect(dish2.name, 'Couscous au Poisson');

      final mainDish = details.mainCourse;
      expect(mainDish?.name, 'Couscous au Poisson');
    });

    test(
        'parses raw <tr> table fragment without <table> parent (production server format)',
        () {
      const rawTrHtml = '''
        <tr>
          <td><img src="images/plat/entree/salade.jpg" alt="Salade Mechouia"></td>
          <td>Entrée</td>
          <td>Salade Mechouia</td>
        </tr>
        <tr>
          <td><img src="images/plat/principale/tajine.jpg" alt="Tajine Tunisien"></td>
          <td>Plat Principal</td>
          <td>Tajine Tunisien</td>
        </tr>
        <tr>
          <td><img src="images/plat/dessert/orange.jpg" alt="Orange"></td>
          <td>Dessert</td>
          <td>Orange de saison</td>
        </tr>
      ''';

      final details =
          scraper.parseMealDetailsHtml(rawTrHtml, repasId: 'PJ_2638');

      expect(details.repasId, 'PJ_2638');
      expect(details.dishes.length, 3);
      expect(details.dishes[0].courseType, 'Entrée');
      expect(details.dishes[0].name, 'Salade Mechouia');
      expect(details.dishes[0].fullImageUrl(),
          'https://cukl.ooun.rnu.tn/images/plat/entree/salade.jpg');
      expect(details.dishes[1].courseType, 'Plat Principal');
      expect(details.dishes[1].name, 'Tajine Tunisien');
      expect(details.dishes[2].courseType, 'Dessert');
      expect(details.dishes[2].name, 'Orange de saison');
    });

    test(
        'parses production meal table rows with alphanumeric IDs like PJ_2638 and Arabic labels',
        () {
      const liveHtml = '''
      <table id="repas-table">
        <tbody>
          <tr>
            <td><input type="button" class="view_data btn btn-xs btn-primary" id="PJ_2638" value="Détails"></td>
            <td>طبق الغداء</td>
            <td>2026-11-09</td>
            <td>الاثنين</td>
            <td><span class="label label-success"><i class="ace-icon fa fa-check-square-o bigger-120"></i> reservé</span></td>
          </tr>
          <tr>
            <td><input type="button" class="view_data btn btn-xs btn-primary" id="PJ_2639" value="Détails"></td>
            <td>طبق العشاء</td>
            <td>2026-11-09</td>
            <td>الاثنين</td>
            <td><span class="label label-default">non réservé</span></td>
          </tr>
        </tbody>
      </table>
      ''';

      final meals = scraper.parseWeeklyMeals(html_parser.parse(liveHtml));

      expect(meals.length, 2);
      expect(meals[0].id, 'PJ_2638');
      expect(meals[0].type, MealType.dejeuner);
      expect(meals[0].status, MealStatus.reserved);
      expect(meals[0].isReserved, isTrue);

      expect(meals[1].id, 'PJ_2639');
      expect(meals[1].type, MealType.diner);
      expect(meals[1].status, MealStatus.notReserved);
      expect(meals[1].isAvailableToReserve, isTrue);
    });

    test('parses empty meal details fragment gracefully', () {
      final empty = scraper.parseMealDetailsHtml('', repasId: '999');
      expect(empty.repasId, '999');
      expect(empty.isEmpty, isTrue);
      expect(empty.dishes, isEmpty);
    });

    test(
        'strictly avoids false-positive reservation on non reservé with label-warning',
        () {
      const testHtml = '''
      <table id="repas-table">
        <tbody>
          <tr>
            <td><input type="button" class="view_data" id="PJ_3001" value="Détails"></td>
            <td>Déjeuner</td>
            <td>2026-11-12</td>
            <td>Jeudi</td>
            <td><span class="label label-warning"><i class="fa fa-exclamation"></i> non reservé</span></td>
          </tr>
          <tr>
            <td><input type="button" class="view_data" id="PJ_3002" value="Détails"></td>
            <td>Dîner</td>
            <td>2026-11-12</td>
            <td>Jeudi</td>
            <td><span class="label label-success"><i class="fa fa-check"></i> reservé</span></td>
          </tr>
          <tr>
            <td><input type="button" class="view_data" id="PJ_3003" value="Détails"></td>
            <td>Repas Sec</td>
            <td>2026-11-13</td>
            <td>Vendredi</td>
            <td><span class="label label-default">non réservé</span></td>
          </tr>
        </tbody>
      </table>
      ''';

      final meals = scraper.parseWeeklyMeals(html_parser.parse(testHtml));
      expect(meals.length, 3);

      expect(meals[0].id, 'PJ_3001');
      expect(meals[0].status, MealStatus.notReserved);
      expect(meals[0].isReserved, isFalse);
      expect(meals[0].isAvailableToReserve, isTrue);

      expect(meals[1].id, 'PJ_3002');
      expect(meals[1].status, MealStatus.reserved);
      expect(meals[1].isReserved, isTrue);

      expect(meals[2].id, 'PJ_3003');
      expect(meals[2].status, MealStatus.notReserved);
      expect(meals[2].isReserved, isFalse);
    });

    test(
        'normalizes Arabic hamza variations for mainCourse and displayCategory',
        () {
      const modalHtml = '''
      <div class="modal-dialog">
        <h4 class="modal-title">Menu du Jour</h4>
        <table>
          <tbody>
            <tr>
              <td>المقبلات</td>
              <td>Salade Méchouia</td>
            </tr>
            <tr>
              <td>الرئسي</td>
              <td>Kafteji Tunisien</td>
            </tr>
            <tr>
              <td>التحلية</td>
              <td>Orange de Tunisie</td>
            </tr>
          </tbody>
        </table>
      </div>
      ''';

      final details =
          scraper.parseMealDetailsHtml(modalHtml, repasId: 'PJ_3001');
      expect(details.dishes.length, 3);

      final main = details.mainCourse;
      expect(main, isNotNull);
      expect(main!.name, 'Kafteji Tunisien');
      expect(main.isMainCourseStrict, isTrue);
      expect(main.displayCategory, 'الطبق الرئيسي');

      // Prioritized dishes puts main course first
      expect(details.prioritizedDishes.first.name, 'Kafteji Tunisien');
    });
  });
}

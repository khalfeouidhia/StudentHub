import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/meal_details_dialog.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_history_sheet.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_kpi_card.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_login_sheet.dart';

Widget _wrapInTestApp(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  );
}

void main() {
  group('RestoKpiCard Tests', () {
    testWidgets('renders icon, value, label and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _wrapInTestApp(
          RestoKpiCard(
            icon: Icons.confirmation_number_outlined,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryContainer,
            value: '24',
            label: 'Solde Repas',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('24'), findsOneWidget);
      expect(find.text('Solde Repas'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsOneWidget);
      expect(find.text('Faible'), findsNothing);

      await tester.tap(find.byType(RestoKpiCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows warning badge when isLowWarning is true',
        (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          const RestoKpiCard(
            icon: Icons.confirmation_number_outlined,
            iconColor: AppColors.warning,
            iconBgColor: AppColors.tertiaryContainer,
            value: '2',
            label: 'Solde Repas',
            isLowWarning: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Faible'), findsOneWidget);
    });
  });

  group('RestoLoginSheet Tests', () {
    testWidgets('renders mock test mode UI and triggers onLoginSuccess',
        (tester) async {
      String? capturedCookies;

      await tester.pumpWidget(
        _wrapInTestApp(
          RestoLoginSheet(
            isTestMode: true,
            onLoginSuccess: (cookies) => capturedCookies = cookies,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
          find.byKey(const Key('resto_mock_login_container')), findsOneWidget);
      expect(find.text('Simulation Authentification Resto U'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mock_login_success_btn')));
      await tester.pumpAndSettle();

      expect(capturedCookies, contains('PHPSESSID=mock_session_12345'));
    });

    testWidgets('simulates login failure error banner in mock mode',
        (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          const RestoLoginSheet(isTestMode: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_login_failure_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Identifiants invalides'), findsOneWidget);
    });

    testWidgets('zero overflow on 320x568 at 2.0x font scaling',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? error;
      final original = FlutterError.onError;
      FlutterError.onError = (details) => error = details;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: _wrapInTestApp(
            const RestoLoginSheet(isTestMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = original;
      expect(error, isNull);
    });
  });

  group('MealDetailsDialog Tests', () {
    final testDetails = MealDetails(
      repasId: '42',
      title: 'Menu du Déjeuner - 09/11/2026',
      dishes: const [
        MealDishItem(courseType: 'Entrée', name: 'Salade Tunisienne'),
        MealDishItem(courseType: 'Plat Principal', name: 'Couscous au Poisson'),
        MealDishItem(courseType: 'Dessert', name: 'Pomme de saison'),
      ],
    );

    final testMealItem = CampusMealItem(
      id: '42',
      type: MealType.dejeuner,
      date: DateTime(2026, 11, 9),
      dayLabel: 'Lundi',
      status: MealStatus.reserved,
    );

    testWidgets('renders main course banner and all dish items',
        (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          MealDetailsDialog(
            details: testDetails,
            mealItem: testMealItem,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menu du Déjeuner - 09/11/2026'), findsOneWidget);
      expect(find.text('★ PLAT PRINCIPAL'), findsOneWidget);
      expect(find.text('Couscous au Poisson'), findsAtLeastNWidgets(1));
      expect(find.text('Salade Tunisienne'), findsOneWidget);
      expect(find.text('Pomme de saison'), findsOneWidget);
      expect(find.text('Réservé'), findsOneWidget);
    });

    testWidgets('renders empty state when dishes are empty', (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          const MealDetailsDialog(
            details: MealDetails.empty('42'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun plat renseigné'), findsOneWidget);
    });

    testWidgets('zero overflow on 320x568 at 2.0x font scaling',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? error;
      final original = FlutterError.onError;
      FlutterError.onError = (details) => error = details;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: _wrapInTestApp(
            MealDetailsDialog(
              details: testDetails,
              mealItem: testMealItem,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = original;
      expect(error, isNull);
    });
  });

  group('RestoHistorySheet Tests', () {
    final testCheckIns = [
      RestoCheckIn(
        id: 'c1',
        timestamp: DateTime(2026, 11, 9, 12, 30),
        quantity: 1,
        cin: '12345678',
        mealType: MealType.dejeuner,
      ),
      RestoCheckIn(
        id: 'c2',
        timestamp: DateTime(2026, 11, 8, 19, 15),
        quantity: 1,
        cin: '12345678',
        mealType: MealType.diner,
      ),
    ];

    final testTopUps = [
      RestoTopUp(
        id: 't1',
        timestamp: DateTime(2026, 11, 5, 10, 0),
        mealCount: 10,
        cin: '12345678',
      ),
    ];

    testWidgets('switches between check-ins and top-ups tabs', (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          RestoHistorySheet(
            checkIns: testCheckIns,
            topUps: testTopUps,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pointages (2)'), findsOneWidget);
      expect(find.text('Recharges (1)'), findsOneWidget);
      expect(find.text('Déjeuner'), findsOneWidget);
      expect(find.text('Dîner'), findsOneWidget);

      await tester.tap(find.text('Recharges (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Recharge 10 Repas'), findsOneWidget);
      expect(find.text('2.000 DT'), findsNWidgets(2));
    });

    testWidgets('renders empty state for both tabs when lists are empty',
        (tester) async {
      await tester.pumpWidget(
        _wrapInTestApp(
          const RestoHistorySheet(
            checkIns: [],
            topUps: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun pointage enregistré'), findsOneWidget);

      await tester.tap(find.text('Recharges (0)'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune recharge enregistrée'), findsOneWidget);
    });

    testWidgets('zero overflow on 320x568 at 2.0x font scaling',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? error;
      final original = FlutterError.onError;
      FlutterError.onError = (details) => error = details;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: _wrapInTestApp(
            RestoHistorySheet(
              checkIns: testCheckIns,
              topUps: testTopUps,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      FlutterError.onError = original;
      expect(error, isNull);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/meal_details_dialog.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_history_sheet.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_kpi_card.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_login_sheet.dart';

/// Test double simulating CampusRestoController state without live HTTP requests.
class MockRestoController extends ChangeNotifier
    implements CampusRestoController {
  @override
  RestoAuthStatus get authStatus => isAuthenticated
      ? RestoAuthStatus.authenticated
      : (isLoading ? RestoAuthStatus.loading : RestoAuthStatus.unauthenticated);

  @override
  bool isAuthenticated;

  @override
  bool isLoading;

  @override
  bool isOffline;

  @override
  String? errorMessage;

  @override
  StudentProfile? profile;

  @override
  DormInfo? dormInfo;

  @override
  WalletKpis? kpis;

  @override
  List<CampusMealItem> weeklyMeals;

  @override
  List<RestoCheckIn> checkIns;

  @override
  List<RestoTopUp> topUps;

  MockRestoController({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isOffline = false,
    this.errorMessage,
    this.profile,
    this.dormInfo,
    this.kpis,
    this.weeklyMeals = const [],
    this.checkIns = const [],
    this.topUps = const [],
  });

  @override
  Map<String, List<CampusMealItem>> get mealsByDate {
    final grouped = <String, List<CampusMealItem>>{};
    for (final meal in weeklyMeals) {
      grouped.putIfAbsent(meal.dateKey, () => []).add(meal);
    }
    return grouped;
  }

  @override
  List<String> get sortedDateKeys => mealsByDate.keys.toList()..sort();

  @override
  bool get hasData => profile != null || kpis != null || weeklyMeals.isNotEmpty;

  @override
  bool get isLowBalance => kpis?.isLowBalance ?? false;

  @override
  DateTime? get lastSyncTime => null;

  @override
  MealDetails? cachedMealDetails(String repasId) => null;

  @override
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  Future<void> init() async {}

  @override
  Future<bool> onLoginSuccess(String cookies) async => true;

  @override
  Future<bool> checkSession() async => true;

  @override
  Future<void> refreshDashboard() async {}

  @override
  Future<MealDetails?> getMealDetails(String repasId) async => null;

  @override
  Future<bool> reserveMeal(String refP) async => false;

  @override
  int get unreservedMealsCount =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).length;

  @override
  List<CampusMealItem> get unreservedMeals =>
      weeklyMeals.where((m) => m.status == MealStatus.notReserved).toList();

  @override
  Future<BatchReservationResult> reserveAllUnreservedMeals({
    void Function(int current, int total, CampusMealItem meal)? onProgress,
  }) async =>
      const BatchReservationResult(
        total: 0,
        succeeded: 0,
        failed: 0,
        reservedMeals: [],
      );

  @override
  Future<void> prefetchWeeklyMealDetails() async {}

  @override
  Future<void> parseAndLoadDashboard(String html) async {}

  @override
  void setAuthenticated(bool value) {
    isAuthenticated = value;
    notifyListeners();
  }

  @override
  Future<int> syncWithBudget(BudgetController budgetController) async => 0;

  @override
  Future<void> logout() async {
    isAuthenticated = false;
    notifyListeners();
  }
}

Widget _wrapTestWidget(
  Widget child, {
  required MockRestoController restoController,
  BudgetController? budgetController,
  required Size viewportSize,
  required double textScale,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: viewportSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<CampusRestoController>.value(
            value: restoController,
          ),
          ChangeNotifierProvider<BudgetController>(
            create: (_) => budgetController ?? BudgetController(),
          ),
        ],
        child: SizedBox(
          width: viewportSize.width,
          height: viewportSize.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Target viewports required by dispatch
  final viewports = <String, Size>{
    '320x480 (Legacy / Compact Phone)': const Size(320, 480),
    '280x653 (Ultra-Narrow Foldable)': const Size(280, 653),
    '412x915 (Modern Android Standard)': const Size(412, 915),
    '800x1280 (Tablet)': const Size(800, 1280),
  };

  // Text scales required by dispatch (0.8x - 3.0x)
  final textScales = <double>[0.8, 1.0, 1.5, 2.5, 3.0];

  // Huge adversarial test data
  final hugeProfile = StudentProfile(
    fullName:
        'Professeur Mohammed Al-Mansouri Bin Abdelaziz El-Idrissi Al-Hashemi Junior III De La Haute Université',
    cin: 'CIN-99999999-EXTRA-LONG-CIN-OVERFLOW-TESTING-SEQUENCE-VALUE-XYZ',
    dorm: const DormInfo(
      foyer:
          'Foyer Universitaire International El Ghazala Bâtiment Nord Résidence Étudiante 7',
      bloc: 'Bloc Central Bâtiment Principal B-9',
      chambre: 'Chambre 402 Bis Porte Gauche Deuxième Étage',
    ),
  );

  final hugeKpis = const WalletKpis(
    soldeRepas: 1, // triggers low warning
    totalAchatMois: 999999,
    depensesMois: 888888.800,
  );

  final hugeMeals = <CampusMealItem>[
    CampusMealItem(
      id: 'repas_999999',
      date: DateTime(2026, 11, 10),
      dayLabel: 'Mardi Exceptionnel Long Label',
      type: MealType.dejeuner,
      status: MealStatus.reserved,
    ),
    CampusMealItem(
      id: 'repas_999998',
      date: DateTime(2026, 11, 10),
      dayLabel: 'Mardi Exceptionnel Long Label',
      type: MealType.diner,
      status: MealStatus.consumed,
    ),
    CampusMealItem(
      id: 'repas_999997',
      date: DateTime(2026, 11, 11),
      dayLabel: 'Mercredi Spécial Cérémonie',
      type: MealType.dejeuner,
      status: MealStatus.notReserved,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 1: RestoUView — Unauthenticated Login Gate Layout Stress
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoUView — Unauthenticated Gate Stress Matrix', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            final controller = MockRestoController(isAuthenticated: false);

            await tester.pumpWidget(
              _wrapTestWidget(
                const RestoUView(),
                restoController: controller,
                viewportSize: vpEntry.value,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in Login Gate on ${vpEntry.key} at ${scale}x scale:\n${caughtOverflow?.exceptionAsString()}',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 2: RestoUView — Authenticated Dashboard with Huge Data Strings
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoUView — Authenticated Dashboard Huge Strings Stress Matrix', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in textScales) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale with huge strings',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            final controller = MockRestoController(
              isAuthenticated: true,
              profile: hugeProfile,
              dormInfo: hugeProfile.dorm,
              kpis: hugeKpis,
              weeklyMeals: hugeMeals,
            );

            await tester.pumpWidget(
              _wrapTestWidget(
                const RestoUView(),
                restoController: controller,
                viewportSize: vpEntry.value,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in Authenticated View on ${vpEntry.key} at ${scale}x scale:\n${caughtOverflow?.exceptionAsString()}',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 3: RestoUView — Error Banner & Loading State Stress
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoUView — Massive Error Message Banner Layout Stress', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in [1.0, 3.0]) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale with 300-char error',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            const massiveError =
                'ERREUR_SERVEUR_CUKL_504_GATEWAY_TIMEOUT: La passerelle du serveur des œuvres universitaires OOUN a mis trop de temps à répondre lors de la tentative de validation du jeton de session PHPSESSID. Veuillez vérifier votre connexion réseau ou réessayer plus tard.';

            final controller = MockRestoController(
              isAuthenticated: true,
              isLoading: true,
              errorMessage: massiveError,
              profile: hugeProfile,
              dormInfo: hugeProfile.dorm,
              kpis: hugeKpis,
              weeklyMeals: hugeMeals,
            );

            await tester.pumpWidget(
              _wrapTestWidget(
                const RestoUView(),
                restoController: controller,
                viewportSize: vpEntry.value,
                textScale: scale,
              ),
            );
            await tester.pump();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow with Error Banner on ${vpEntry.key} at ${scale}x scale',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 4: MealDetailsDialog Layout Stress Matrix
  // ═══════════════════════════════════════════════════════════════════════════
  group('MealDetailsDialog — Extreme Content & Viewport Stress Matrix', () {
    final hugeDetails = MealDetails(
      repasId: 'repas_999999',
      title:
          'Menu Gastronomique Impérial Complet du Restaurant Universitaire Central Avec Desserts et Boissons Rafraîchissantes',
      dishes: const [
        MealDishItem(
          courseType: 'Entrée Froide Spéciale Assortie',
          name:
              'Salade Mechouia Traditionnelle Pimentée Avec Œufs Durs et Thon Rouge de Méditerranée',
          imageRelativeUrl: 'img/salade.jpg',
        ),
        MealDishItem(
          courseType: 'Plat Principal Chaud',
          name:
              'Couscous Tunisien Royal à l\'Agneau Braisé et Légumes Vapeur Courgettes Pois Chiches',
          imageRelativeUrl: 'img/couscous.jpg',
        ),
        MealDishItem(
          courseType: 'Dessert Sucré',
          name:
              'Assiette de Pâtisserie Traditionnelle Baklawa aux Amandes et Miel d\'Oranger',
          imageRelativeUrl: 'img/dessert.jpg',
        ),
        MealDishItem(
          courseType: 'Pain & Condiments',
          name: 'Pain Tabouna Traditionnel Artisanal Chaud',
        ),
      ],
    );

    for (final vpEntry in viewports.entries) {
      for (final scale in [0.8, 1.0, 2.0, 3.0]) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale with huge meal details',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vpEntry.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: MealDetailsDialog(
                      details: hugeDetails,
                      mealItem: hugeMeals.first,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in MealDetailsDialog on ${vpEntry.key} at ${scale}x scale:\n${caughtOverflow?.exceptionAsString()}',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 5: RestoHistorySheet Layout Stress Matrix
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoHistorySheet — Extreme Content & Viewport Stress Matrix', () {
    final massiveCheckIns = List.generate(
      15,
      (i) => RestoCheckIn(
        id: 'access_$i',
        timestamp: DateTime(2026, 11, 6, 12, 30 + i),
        quantity: 1 + (i % 3),
        cin: '0987654321-LONG-CIN-$i',
        mealType: i.isEven ? MealType.dejeuner : MealType.diner,
      ),
    );

    final massiveTopUps = List.generate(
      15,
      (i) => RestoTopUp(
        id: 'topup_$i',
        timestamp: DateTime(2026, 11, 1, 9, i * 2),
        mealCount: 10 * (i + 1),
        cin: '0987654321-LONG-CIN-$i',
      ),
    );

    for (final vpEntry in viewports.entries) {
      for (final scale in [0.8, 1.0, 2.0, 3.0]) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale in RestoHistorySheet',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vpEntry.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: RestoHistorySheet(
                      checkIns: massiveCheckIns,
                      topUps: massiveTopUps,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Switch to tab 2 (TopUps)
            await tester.tap(find.textContaining('Recharges'));
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in RestoHistorySheet on ${vpEntry.key} at ${scale}x scale:\n${caughtOverflow?.exceptionAsString()}',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 6: RestoLoginSheet Layout Stress Matrix
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoLoginSheet — Mock Mode Layout Stress Matrix', () {
    for (final vpEntry in viewports.entries) {
      for (final scale in [0.8, 1.0, 2.0, 3.0]) {
        testWidgets(
          'Zero overflow on ${vpEntry.key} at ${scale}x text scale in RestoLoginSheet',
          (WidgetTester tester) async {
            tester.view.physicalSize = vpEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: vpEntry.value,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const Scaffold(
                    body: RestoLoginSheet(isTestMode: true),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Trigger failure error banner
            await tester.tap(find.byKey(const Key('mock_login_failure_btn')));
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in RestoLoginSheet on ${vpEntry.key} at ${scale}x scale',
            );
          },
        );
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SUITE 7: RestoKpiCard Micro-Width & Extreme Scale Stress
  // ═══════════════════════════════════════════════════════════════════════════
  group('RestoKpiCard — Micro-Width Stress', () {
    final microWidths = [60.0, 75.0, 90.0, 120.0];
    for (final width in microWidths) {
      for (final scale in [1.0, 2.0, 3.0]) {
        testWidgets(
          'Zero overflow at width $width px with warning at ${scale}x scale',
          (WidgetTester tester) async {
            FlutterErrorDetails? caughtOverflow;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtOverflow = details;
              }
              originalOnError?.call(details);
            };

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width + 40, 400),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Center(
                      child: SizedBox(
                        width: width,
                        child: const RestoKpiCard(
                          icon: Icons.confirmation_number_outlined,
                          iconColor: Colors.green,
                          iconBgColor: Colors.lightGreen,
                          value: '9999999',
                          label: 'Solde Repas Long',
                          isLowWarning: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            FlutterError.onError = originalOnError;
            expect(
              caughtOverflow,
              isNull,
              reason:
                  'RenderFlex overflow in RestoKpiCard at width $width with scale $scale:\n${caughtOverflow?.exceptionAsString()}',
            );
          },
        );
      }
    }
  });
}

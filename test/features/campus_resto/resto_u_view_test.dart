import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/ui/views/resto_u_view.dart';

/// Test double simulating CampusRestoController state without live HTTP requests.
class FakeCampusRestoController extends ChangeNotifier
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

  bool initCalled = false;
  bool refreshDashboardCalled = false;
  bool checkSessionCalled = false;
  bool logoutCalled = false;
  String? lastLoginCookies;
  String? lastRequestedRepasId;
  BudgetController? lastBudgetSynced;

  MealDetails? mockMealDetailsResponse;

  FakeCampusRestoController({
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
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<void> checkSession() async {
    checkSessionCalled = true;
  }

  @override
  Future<void> refreshDashboard() async {
    refreshDashboardCalled = true;
  }

  @override
  Future<void> onLoginSuccess(String cookies) async {
    lastLoginCookies = cookies;
    isAuthenticated = true;
    notifyListeners();
  }

  @override
  Future<MealDetails?> getMealDetails(String repasId) async {
    lastRequestedRepasId = repasId;
    return mockMealDetailsResponse ??
        MealDetails(
          repasId: repasId,
          title: 'Menu Complet',
          dishes: const [
            MealDishItem(
              courseType: 'Plat Principal',
              name: 'Couscous au poisson',
            ),
          ],
        );
  }

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
  Future<void> syncWithBudget(BudgetController budgetController) async {
    lastBudgetSynced = budgetController;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    isAuthenticated = false;
    notifyListeners();
  }
}

Widget _wrapWithRestoProviders(
  Widget child, {
  FakeCampusRestoController? restoController,
  BudgetController? budgetController,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CampusRestoController>.value(
        value: restoController ?? FakeCampusRestoController(),
      ),
      ChangeNotifierProvider<BudgetController>.value(
        value: budgetController ?? BudgetController(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testProfile = StudentProfile(
    fullName: 'Ahmed Ben Salah',
    cin: '12345678',
    dorm: DormInfo(
      foyer: 'Cité Universitaire Kélibia',
      bloc: 'B',
      chambre: '104',
    ),
  );

  const testKpis = WalletKpis(
    soldeRepas: 24,
    totalAchatMois: 40,
    depensesMois: 3.200,
  );

  final testMeals = [
    CampusMealItem(
      id: '101',
      type: MealType.dejeuner,
      date: DateTime(2026, 11, 9),
      dayLabel: 'Lundi',
      status: MealStatus.reserved,
    ),
    CampusMealItem(
      id: '102',
      type: MealType.diner,
      date: DateTime(2026, 11, 9),
      dayLabel: 'Lundi',
      status: MealStatus.notReserved,
    ),
    CampusMealItem(
      id: '103',
      type: MealType.dejeuner,
      date: DateTime(2026, 11, 10),
      dayLabel: 'Mardi',
      status: MealStatus.consumed,
    ),
  ];

  group('RestoUView — Unauthenticated State (Login Gate)', () {
    testWidgets('renders portal branding, benefits, and primary login button',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(isAuthenticated: false);

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Verify portal branding
      expect(find.text('Campus Resto U'), findsOneWidget);
      expect(find.text('CUKL'), findsOneWidget);
      expect(find.text('PORTAIL DES ŒUVRES UNIVERSITAIRES'), findsOneWidget);
      expect(find.text('Espace Resto U & Foyer'), findsOneWidget);

      // Verify 4 benefit feature pills
      expect(find.text('Solde de repas en temps réel'), findsOneWidget);
      expect(find.text('Menu de la semaine & détails'), findsOneWidget);
      expect(find.text('Affectation foyer & chambre'), findsOneWidget);
      expect(
          find.text('Synchronisation automatique du budget'), findsOneWidget);

      // Verify primary login CTA
      expect(find.byKey(const ValueKey('resto_login_button')), findsOneWidget);
      expect(find.text('Se connecter au portail'), findsOneWidget);

      // Verify security footnote
      expect(
        find.textContaining('cukl.ooun.rnu.tn'),
        findsOneWidget,
      );

      // Header action buttons must NOT be present when unauthenticated
      expect(find.byKey(const ValueKey('resto_history_button')), findsNothing);
      expect(find.byKey(const ValueKey('resto_sync_button')), findsNothing);
      expect(find.byKey(const ValueKey('resto_logout_button')), findsNothing);
    });

    testWidgets('tapping login button triggers login handler',
        (WidgetTester tester) async {
      bool loginSheetTriggered = false;
      final controller = FakeCampusRestoController(isAuthenticated: false);

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          RestoUView(
            onOpenLoginSheet: () {
              loginSheetTriggered = true;
            },
          ),
          restoController: controller,
        ),
      );
      await tester
          .ensureVisible(find.byKey(const ValueKey('resto_login_button')));
      await tester.tap(find.byKey(const ValueKey('resto_login_button')));
      await tester.pumpAndSettle();

      expect(loginSheetTriggered, isTrue);
    });
  });

  group('RestoUView — Authenticated Dashboard', () {
    testWidgets(
        'renders student profile banner with stripped name and dorm details',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
        weeklyMeals: testMeals,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Profile banner & initials
      expect(
          find.byKey(const ValueKey('resto_profile_banner')), findsOneWidget);
      expect(
          find.text(testProfile.initials), findsOneWidget); // Initials ('AS')
      expect(find.text('Ahmed Ben Salah'), findsOneWidget); // Full name
      expect(find.text('CIN: 12345678'), findsOneWidget);
      expect(find.text('Inscrit'), findsOneWidget);

      // Dorm room details
      expect(find.text('Cité Universitaire Kélibia'), findsOneWidget);
      expect(find.text('Bloc B • Ch. 104'), findsOneWidget);
    });

    testWidgets('handles unassigned dorm gracefully without layout crash',
        (WidgetTester tester) async {
      const unassignedProfile = StudentProfile(
        fullName: 'Nour Cherif',
        cin: '87654321',
        dorm: DormInfo.empty(),
      );

      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: unassignedProfile,
        dormInfo: const DormInfo.empty(),
        kpis: testKpis,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nour Cherif'), findsOneWidget);
      expect(find.text('Non assigné'), findsWidgets);
    });

    testWidgets('renders all 3 KPI cards with accurate scraped values',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
        weeklyMeals: testMeals,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Solde Repas
      expect(find.byKey(const ValueKey('kpi_solde_repas')), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Solde Repas'), findsOneWidget);

      // 2. Total Achats / Mois
      expect(find.byKey(const ValueKey('kpi_total_achats')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Achats / Mois'), findsOneWidget);

      // 3. Dépenses / Mois
      expect(find.byKey(const ValueKey('kpi_depenses_mois')), findsOneWidget);
      expect(find.text('3.200 DT'), findsOneWidget);
      expect(find.text('Dépenses / Mois'), findsOneWidget);

      // No low balance alert when solde > 3
      expect(find.text('Faible'), findsNothing);
    });

    testWidgets('renders low-balance warning badge when solde <= 3',
        (WidgetTester tester) async {
      const lowBalanceKpis = WalletKpis(
        soldeRepas: 2,
        totalAchatMois: 10,
        depensesMois: 1.600,
      );

      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: lowBalanceKpis,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Faible'), findsOneWidget);
    });

    testWidgets('groups meals by date and displays types and status badges',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
        weeklyMeals: testMeals,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Weekly schedule container
      expect(
          find.byKey(const ValueKey('resto_weekly_schedule')), findsOneWidget);
      expect(find.text('Menu de la Semaine'), findsOneWidget);
      expect(find.text('3 repas'), findsOneWidget);

      // Meal items
      expect(find.byKey(const ValueKey('meal_item_101')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal_item_102')), findsOneWidget);
      expect(find.byKey(const ValueKey('meal_item_103')), findsOneWidget);

      // Meal Types
      expect(find.text('Déjeuner'), findsNWidgets(2));
      expect(find.text('Dîner'), findsOneWidget);

      // Status badges
      expect(find.text('Réservé'), findsOneWidget);
      expect(find.text('Non réservé'), findsOneWidget);
      expect(find.text('Consommé'), findsOneWidget);
    });

    testWidgets('tapping a meal card invokes meal tap callback or controller',
        (WidgetTester tester) async {
      CampusMealItem? tappedMeal;
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
        weeklyMeals: testMeals,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          RestoUView(
            onMealTapped: (meal) {
              tappedMeal = meal;
            },
          ),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('meal_item_101')));
      await tester.pumpAndSettle();

      expect(tappedMeal, isNotNull);
      expect(tappedMeal!.id, equals('101'));
      expect(tappedMeal!.type, equals(MealType.dejeuner));
    });

    testWidgets('renders clean empty state when weeklyMeals is empty',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
        weeklyMeals: const [],
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun repas programmé pour cette semaine.'),
        findsOneWidget,
      );
    });
  });

  group('RestoUView — Header Actions & Session Management', () {
    testWidgets('tapping history button triggers history handler',
        (WidgetTester tester) async {
      bool historyOpened = false;
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          RestoUView(
            onOpenHistory: () {
              historyOpened = true;
            },
          ),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('resto_history_button')));
      await tester.pumpAndSettle();

      expect(historyOpened, isTrue);
    });

    testWidgets('tapping sync button triggers budget sync',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
      );
      final budget = BudgetController();

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
          budgetController: budget,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('resto_sync_button')));
      await tester.pumpAndSettle();

      expect(controller.lastBudgetSynced, equals(budget));
      expect(
        find.text('Synchronisation Resto U terminée avec succès'),
        findsOneWidget,
      );
    });

    testWidgets(
        'tapping logout button displays confirmation dialog and confirms',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        profile: testProfile,
        dormInfo: testProfile.dorm,
        kpis: testKpis,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      // Tap logout icon
      await tester.tap(find.byKey(const ValueKey('resto_logout_button')));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Déconnexion Resto U'), findsOneWidget);
      expect(
        find.textContaining(
            'Voulez-vous vous déconnecter du portail universitaire CUKL'),
        findsOneWidget,
      );

      // Confirm logout
      await tester.tap(find.widgetWithText(ElevatedButton, 'Déconnexion'));
      await tester.pumpAndSettle();

      expect(controller.logoutCalled, isTrue);
      expect(controller.isAuthenticated, isFalse);
    });
  });

  group('RestoUView — Error Banner & Loading State', () {
    testWidgets('displays error banner and retry button calls refreshDashboard',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        errorMessage: 'Échec de connexion au serveur CUKL',
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Échec de connexion au serveur CUKL'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(controller.refreshDashboardCalled, isTrue);
    });

    testWidgets('displays LinearProgressIndicator when isLoading is true',
        (WidgetTester tester) async {
      final controller = FakeCampusRestoController(
        isAuthenticated: true,
        isLoading: true,
      );

      await tester.pumpWidget(
        _wrapWithRestoProviders(
          const RestoUView(),
          restoController: controller,
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('RestoUView — Multi-Screen Responsive Layout Overflow Check', () {
    final testSizes = [
      const Size(320, 568), // iPhone SE / small viewport
      const Size(375, 667), // iPhone 8 / medium viewport
      const Size(412, 915), // Pixel 7 / large viewport
    ];

    for (final size in testSizes) {
      testWidgets(
          'zero RenderFlex overflow on ${size.width.toInt()}x${size.height.toInt()} viewport',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        FlutterErrorDetails? errorDetails;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) => errorDetails = details;

        final controller = FakeCampusRestoController(
          isAuthenticated: true,
          profile: testProfile,
          dormInfo: testProfile.dorm,
          kpis: testKpis,
          weeklyMeals: testMeals,
        );

        await tester.pumpWidget(
          _wrapWithRestoProviders(
            const RestoUView(),
            restoController: controller,
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = originalOnError;
        expect(errorDetails, isNull);
      });
    }
  });
}

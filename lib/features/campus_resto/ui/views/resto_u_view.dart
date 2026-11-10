import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studenthold_app/core/widgets/roulette_number_text.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:studenthold_app/controllers/budget_controller.dart';
import 'package:studenthold_app/features/campus_resto/controllers/campus_resto_controller.dart';
import 'package:studenthold_app/features/campus_resto/models/models.dart';
import 'package:studenthold_app/features/campus_resto/services/campus_resto_service.dart';
import 'package:studenthold_app/features/campus_resto/services/session_storage_service.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/meal_details_dialog.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_history_sheet.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_kpi_card.dart';
import 'package:studenthold_app/features/campus_resto/ui/widgets/resto_login_sheet.dart';

/// Screen 5: Resto U (Restaurant Universitaire) Native Feature View.
/// Integrates with the university portal (https://cukl.ooun.rnu.tn/).
/// Supports:
/// - Unauthenticated state: Hero card login gate with university branding and benefits.
/// - Authenticated state: Student profile & dorm banner, 3 KPI metric cards,
///   weekly meal schedule list grouped by date, history action buttons,
///   budget sync, and pull-to-refresh.
class RestoUView extends StatefulWidget {
  final VoidCallback? onOpenLoginSheet;
  final ValueChanged<CampusMealItem>? onMealTapped;
  final VoidCallback? onOpenHistory;

  const RestoUView({
    super.key,
    this.onOpenLoginSheet,
    this.onMealTapped,
    this.onOpenHistory,
  });

  @override
  State<RestoUView> createState() => _RestoUViewState();
}

class _RestoUViewState extends State<RestoUView> {
  bool _isInAppLoginOpen = false;
  WebViewController? _webViewController;
  int _loginProgress = 0;
  bool _isLoginLoading = false;
  String? _loginErrorMessage;
  String? _selectedDateFilter;

  void _handleBridgeMessageFromView(
    String rawMessage,
    CampusRestoController? controller,
  ) async {
    try {
      final dynamic decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        if (type == 'auth_success' || type == 'dashboard_ready') {
          final html = decoded['html']?.toString() ?? '';
          if (html.isNotEmpty) {
            await _completeLoginTransition(html, controller);
            return;
          }
        }
      }
    } catch (_) {}
    CampusRestoService.instance.handleBridgeMessage(rawMessage);
  }

  Future<void> _completeLoginTransition(
    String html,
    CampusRestoController? controller,
  ) async {
    // 1. Disable portal's auto-disconnect timer in webview
    try {
      await _webViewController?.runJavaScript('''
        if (typeof intervalId !== 'undefined') clearInterval(intervalId);
        window.checkSession = function() {};
      ''');
    } catch (_) {}

    // 2. Capture and persist 'resto_cookie' in secure storage
    try {
      if (_webViewController != null) {
        final cookies =
            await CampusRestoService.extractCookiesFromWebViewController(
          _webViewController!,
        );
        if (cookies.isNotEmpty) {
          await SessionStorageService().saveRestoCookie(cookies);
        }
      }
    } catch (_) {}

    // 3. Parse and load dashboard data into controller
    if (html.isNotEmpty) {
      await controller?.parseAndLoadDashboard(html);
    }
    controller?.setAuthenticated(true);

    // 4. Register active controller in service as invisible engine
    CampusRestoService.instance.registerWebViewController(_webViewController);

    // 5. Close the WebView and transition back to native view
    if (mounted) {
      setState(() {
        _isInAppLoginOpen = false;
      });
    }

    // 6. Trigger background refresh if meals or KPIs need hydration
    if (controller != null &&
        (controller.weeklyMeals.isEmpty || controller.kpis == null)) {
      controller.refreshDashboard();
    }
  }

  void _initWebViewController(CampusRestoController? controller) {
    if (_webViewController != null || !CampusRestoService.canCreateWebView)
      return;

    try {
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(true)
        ..setBackgroundColor(Colors.white)
        ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0')
        ..addJavaScriptChannel(
          'RestoBridge',
          onMessageReceived: (JavaScriptMessage msg) {
            _handleBridgeMessageFromView(msg.message, controller);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) setState(() => _loginProgress = progress);
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoginLoading = true;
                  _loginErrorMessage = null;
                });
              }
            },
            onPageFinished: (String url) async {
              if (mounted) {
                setState(() => _isLoginLoading = false);
              }

              // 1. Inject responsive viewport and scroll fix
              try {
                await _webViewController?.runJavaScript('''
                  (function() {
                    var meta = document.querySelector('meta[name="viewport"]');
                    if (!meta) {
                      meta = document.createElement('meta');
                      meta.name = 'viewport';
                      document.head.appendChild(meta);
                    }
                    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
                    document.body.style.overflow = 'auto';
                    document.documentElement.style.overflow = 'auto';
                  })();
                ''');
              } catch (_) {}

              // 2. Strict DOM Session Check
              final checkDashboardJs = '''
                (function() {
                  return document.querySelector('#repas-table') !== null || 
                         document.querySelector('.infobox-container') !== null;
                })();
              ''';

              try {
                final isDashboard = await _webViewController!
                    .runJavaScriptReturningResult(checkDashboardJs);
                final cleanIsDash = isDashboard.toString().toLowerCase();

                if (cleanIsDash == 'true') {
                  final cookies = await CampusRestoService
                      .extractCookiesFromWebViewController(
                    _webViewController!,
                  );
                  if (cookies.isNotEmpty) {
                    await SessionStorageService().saveRestoCookie(cookies);
                  }

                  final rawHtmlJs = await _webViewController!
                      .runJavaScriptReturningResult(
                          'document.documentElement.outerHTML');
                  final cleanHtml =
                      CampusRestoService.unescapeJsString(rawHtmlJs);

                  if (cleanHtml.isNotEmpty) {
                    await _completeLoginTransition(cleanHtml, controller);
                  }
                }
              } catch (e) {
                debugPrint('[RestoUView] Dashboard check caught: $e');
              }
            },
            onWebResourceError: (WebResourceError error) {
              // Log error but do not disrupt ongoing POST redirects
              debugPrint(
                  '[RestoUView] WebView resource error: ${error.errorCode} - ${error.description}');
            },
            onNavigationRequest: (NavigationRequest request) {
              // ALWAYS allow navigation so POST submits don't trigger ERR_CACHE_MISS
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse('https://cukl.ooun.rnu.tn/?p=users.login'));

      _webViewController = ctrl;
    } catch (e) {
      debugPrint('[RestoUView] WebViewController creation error: $e');
    }
  }

  Widget _buildInAppWebViewLogin(
    BuildContext context,
    CampusRestoController? controller,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceLow,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.deepForest),
                  tooltip: 'Annuler',
                  onPressed: () {
                    setState(() => _isInAppLoginOpen = false);
                  },
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connexion Portail Resto U',
                        style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'cukl.ooun.rnu.tn (reCAPTCHA officiel)',
                        style:
                            TextStyle(color: AppColors.mutedSage, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.deepForest),
                  tooltip: 'Actualiser',
                  onPressed: () {
                    _webViewController?.reload();
                  },
                ),
              ],
            ),
          ),

          // Loading Progress Bar
          if (_isLoginLoading)
            LinearProgressIndicator(
              value: _loginProgress > 0 ? _loginProgress / 100.0 : null,
              backgroundColor: AppColors.surfaceLow,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 2.5,
            ),

          if (_loginErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.errorContainer,
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.onErrorContainer, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loginErrorMessage!,
                      style: const TextStyle(
                          color: AppColors.onErrorContainer, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // In-App WebView
          Expanded(
            child: _webViewController != null
                ? WebViewWidget(
                    controller: _webViewController!,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSkeleton(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader(context, null, false),
          const SizedBox(height: 16),
          // Profile Skeleton Card
          Container(
            height: 94,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 90,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 3 KPI Cards Skeleton Row
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  height: 82,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 2 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Schedule Skeleton Header & Tiles
          Container(
            width: 130,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            return Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 60,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLow,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    CampusRestoController? controller;
    try {
      controller = context.watch<CampusRestoController>();
    } catch (_) {}

    final authStatus = controller?.authStatus ??
        (controller?.isAuthenticated == true
            ? RestoAuthStatus.authenticated
            : (controller?.isLoading == true
                ? RestoAuthStatus.loading
                : RestoAuthStatus.unauthenticated));
    final isAuth = controller?.isAuthenticated ?? false;
    final isLoading = controller?.isLoading ?? false;
    final errorMessage = controller?.errorMessage;
    final hasData = controller?.hasData ?? false;
    final isInitialBootLoading =
        authStatus == RestoAuthStatus.loading && !hasData && !isAuth;
    final showInAppLogin =
        !isAuth && _isInAppLoginOpen && CampusRestoService.canCreateWebView;

    return Scaffold(
      backgroundColor: AppColors.deepPine,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── 1. Deep Pine Header (#1E3A2E) ──────────────────────
                Container(
                  color: AppColors.deepPine,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: _buildTopHeader(context, controller, isAuth),
                ),

                // ── 2. Curved Body Sheet (#F9FAF7, 38px radius) ────────
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(38),
                        topRight: Radius.circular(38),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(38),
                        topRight: Radius.circular(38),
                      ),
                      child: isInitialBootLoading
                          ? _buildShimmerSkeleton(context)
                          : showInAppLogin
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 10,
                                    bottom:
                                        100, // clears bottom navigation dock
                                  ),
                                  child: _buildInAppWebViewLogin(
                                      context, controller),
                                )
                              : RefreshIndicator(
                                  color: AppColors.deepPine,
                                  backgroundColor: AppColors.surfaceWhite,
                                  onRefresh: () async {
                                    if (controller != null && isAuth) {
                                      await controller.refreshDashboard();
                                    }
                                  },
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.only(
                                      left: 16,
                                      right: 16,
                                      top: 10,
                                      bottom:
                                          120, // generous bottom padding prevents nav bar overlap
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── Error Banner (if any) ────────────────────────────────────
                                        if (errorMessage != null &&
                                            errorMessage.isNotEmpty) ...[
                                          _buildErrorBanner(context, controller,
                                              errorMessage),
                                          const SizedBox(height: 10),
                                        ],

                                        // ── Loading Bar Indicator (when refreshing in background) ───
                                        if (isLoading &&
                                            !isInitialBootLoading) ...[
                                          const LinearProgressIndicator(
                                            minHeight: 2.5,
                                            backgroundColor:
                                                AppColors.surfaceLow,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppColors.deepPine),
                                          ),
                                          const SizedBox(height: 10),
                                        ],

                                        // ── Main Body: Login Gate OR Authenticated Dashboard ──
                                        if (!isAuth)
                                          _buildLoginGate(context, controller)
                                        else ...[
                                          // Student Profile & Dorm Room Banner
                                          _buildProfileDormBanner(
                                            context,
                                            controller?.profile ??
                                                const StudentProfile.empty(),
                                            controller?.dormInfo ??
                                                controller?.profile?.dorm ??
                                                const DormInfo.empty(),
                                          ),
                                          const SizedBox(height: 8),

                                          // Top 3 Wallet & KPI Cards
                                          _buildKpiSection(
                                            context,
                                            controller?.kpis ??
                                                const WalletKpis.empty(),
                                          ),
                                          const SizedBox(height: 8),

                                          // Date Pill Scroller
                                          _buildDatePillScroller(
                                              context, controller),
                                          const SizedBox(height: 8),

                                          // Weekly Meal Schedule List (Grouped by Date)
                                          _buildWeeklyScheduleSection(
                                            context,
                                            controller,
                                            controller?.weeklyMeals ?? const [],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Invisible Persistent WebView Engine kept alive in memory for HttpOnly authenticated requests
          if (isAuth &&
              _webViewController != null &&
              CampusRestoService.canCreateWebView)
            Offstage(
              offstage: true,
              child: SizedBox(
                width: 1,
                height: 1,
                child: WebViewWidget(controller: _webViewController!),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top Header Bar
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopHeader(
    BuildContext context,
    CampusRestoController? controller,
    bool isAuthenticated,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Branding: Logo + Title + University Badge
        Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.vibrantGreen.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: AppColors.vibrantGreen,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          flex: 2,
                          child: Text(
                            'Campus Resto U',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 1,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.vibrantGreen.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: AppColors.vibrantGreen
                                        .withOpacity(0.4)),
                              ),
                              child: const Text(
                                'CUKL',
                                style: TextStyle(
                                  color: AppColors.vibrantGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Portail Universitaire OOUN',
                      style: TextStyle(
                        color: AppColors.softSage,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right Header Actions (only visible when authenticated)
        if (isAuthenticated && controller != null) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // History Action Icon
              _buildHeaderIconButton(
                key: const ValueKey('resto_history_button'),
                icon: Icons.history_rounded,
                tooltip: 'Historique des accès',
                onTap: () => _handleOpenHistory(context, controller),
              ),
              const SizedBox(width: 6),

              // Budget Sync Action Icon
              _buildHeaderIconButton(
                key: const ValueKey('resto_sync_button'),
                icon: Icons.sync_rounded,
                tooltip: 'Synchroniser Budget',
                onTap: () => _handleSyncBudget(context, controller),
              ),
              const SizedBox(width: 6),

              // Logout Action Icon
              _buildHeaderIconButton(
                key: const ValueKey('resto_logout_button'),
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFFF6B6B),
                tooltip: 'Déconnexion',
                onTap: () => _handleLogoutPrompt(context, controller),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderIconButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Center(
          child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Unauthenticated State: Login Gate Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLoginGate(
    BuildContext context,
    CampusRestoController? controller,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Portal Icon Badge
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderHighlight, width: 2),
            ),
            child: const Center(
              child: Icon(
                Icons.account_balance_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Portal Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Text(
              'PORTAIL DES ŒUVRES UNIVERSITAIRES',
              style: TextStyle(
                color: AppColors.mutedSage,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title & Description
          const Text(
            'Espace Resto U & Foyer',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connectez-vous pour consulter votre solde de repas, les menus de la semaine, votre affectation de chambre et synchroniser vos tickets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // 4 Feature Highlight Chips
          _buildFeaturePill(
            icon: Icons.confirmation_number_outlined,
            title: 'Solde de repas en temps réel',
            subtitle: 'Suivez vos tickets et recharges de cartes',
          ),
          const SizedBox(height: 8),
          _buildFeaturePill(
            icon: Icons.restaurant_menu_rounded,
            title: 'Menu de la semaine & détails',
            subtitle: 'Déjeuners, dîners et plats principaux',
          ),
          const SizedBox(height: 8),
          _buildFeaturePill(
            icon: Icons.apartment_rounded,
            title: 'Affectation foyer & chambre',
            subtitle: 'Détails du pavillon, bloc et numéro de chambre',
          ),
          const SizedBox(height: 8),
          _buildFeaturePill(
            icon: Icons.sync_rounded,
            title: 'Synchronisation automatique du budget',
            subtitle:
                'Intégration transparente dans la catégorie Campus Dining',
          ),
          const SizedBox(height: 24),

          // Primary Portal Login Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const ValueKey('resto_login_button'),
              onPressed: () => _handleOpenLogin(context, controller),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text(
                'Se connecter au portail',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Security Footnote
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 13, color: AppColors.textMuted),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Authentification sécurisée officielle via cukl.ooun.rnu.tn',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Authenticated Dashboard: Profile & Dorm Room Banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProfileDormBanner(
    BuildContext context,
    StudentProfile profile,
    DormInfo dorm,
  ) {
    return Container(
      key: const ValueKey('resto_profile_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sandCream.withOpacity(0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Profile Row
          Row(
            children: [
              // Avatar with Initials
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.vibrantGreen.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.vibrantGreen.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    profile.initials,
                    style: const TextStyle(
                      color: AppColors.deepPine,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Student Name & CIN
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.darkForest,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.cin.isNotEmpty
                          ? 'CIN: ${profile.cin}'
                          : 'Étudiant universitaire',
                      style: const TextStyle(
                        color: AppColors.softSage,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Enrolled Pill
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.vibrantGreen.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.vibrantGreen.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Inscrit',
                      style: TextStyle(
                        color: AppColors.darkForest,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dorm / Housing Assignment Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sandCream.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.vibrantGreen.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.apartment_rounded,
                      color: AppColors.deepPine,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dorm.foyer,
                        style: const TextStyle(
                          color: AppColors.darkForest,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        dorm.roomDisplay,
                        style: const TextStyle(
                          color: AppColors.softSage,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePillScroller(
    BuildContext context,
    CampusRestoController? controller,
  ) {
    final meals = controller?.weeklyMeals ?? [];
    if (meals.isEmpty) return const SizedBox.shrink();

    final dateKeys = <String>[];
    for (final meal in meals) {
      if (!dateKeys.contains(meal.dateKey)) {
        dateKeys.add(meal.dateKey);
      }
    }
    dateKeys.sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CALENDRIER DES REPAS',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _datePill(
                label: 'Toute la semaine',
                count: meals.length,
                isSelected: _selectedDateFilter == null,
                onTap: () => setState(() => _selectedDateFilter = null),
              ),
              const SizedBox(width: 6),
              ...dateKeys.map((k) {
                final count = meals.where((m) => m.dateKey == k).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _datePill(
                    label: k,
                    count: count,
                    isSelected: _selectedDateFilter == k,
                    onTap: () => setState(() => _selectedDateFilter = k),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _datePill({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.vibrantGreen : AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.vibrantGreen
                : AppColors.sandCream.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.darkForest : AppColors.darkOlive,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.darkForest
                    : AppColors.sandCream.withOpacity(0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color:
                      isSelected ? AppColors.vibrantGreen : AppColors.darkOlive,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Top 3 Wallet & KPI Cards
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildKpiSection(BuildContext context, WalletKpis kpis) {
    return Row(
      children: [
        // 1. Solde Repas
        Expanded(
          child: RestoKpiCard(
            key: const ValueKey('kpi_solde_repas'),
            icon: Icons.confirmation_number_outlined,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryContainer,
            value: '${kpis.soldeRepas}',
            label: 'Solde Repas',
            isLowWarning: kpis.isLowBalance,
          ),
        ),
        const SizedBox(width: 8),

        // 2. Total Achat / Mois
        Expanded(
          child: RestoKpiCard(
            key: const ValueKey('kpi_total_achats'),
            icon: Icons.shopping_bag_outlined,
            iconColor: AppColors.categoryHousing,
            iconBgColor: const Color(0xFFE0F2FE),
            value: '${kpis.totalAchatMois}',
            label: 'Achats / Mois',
          ),
        ),
        const SizedBox(width: 8),

        // 3. Dépenses / Mois
        Expanded(
          child: RestoKpiCard(
            key: const ValueKey('kpi_depenses_mois'),
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.categoryBooks,
            iconBgColor: AppColors.tertiaryContainer,
            value: kpis.formattedDepenses,
            label: 'Dépenses / Mois',
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Weekly Meal Schedule List (Grouped by Date)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWeeklyScheduleSection(
    BuildContext context,
    CampusRestoController? controller,
    List<CampusMealItem> meals,
  ) {
    if (meals.isEmpty) {
      return _buildEmptyMealsPlaceholder();
    }

    // Group meals chronologically by date
    final grouped = <String, List<CampusMealItem>>{};
    for (final meal in meals) {
      grouped.putIfAbsent(meal.dateKey, () => []).add(meal);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    final displayKeys = _selectedDateFilter != null
        ? sortedKeys.where((k) => k == _selectedDateFilter).toList()
        : sortedKeys;

    return Column(
      key: const ValueKey('resto_weekly_schedule'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Menu de la Semaine',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${meals.length} repas',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Magic Button ("Réserver toute la semaine")
        if (controller != null && controller.unreservedMealsCount > 0) ...[
          _buildReserveAllBanner(context, controller),
          const SizedBox(height: 14),
        ] else if (controller != null &&
            controller.weeklyMeals.isNotEmpty &&
            controller.unreservedMealsCount == 0) ...[
          _buildAllReservedBadge(),
          const SizedBox(height: 14),
        ],

        // Day Groups
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayKeys.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, idx) {
            final dateKey = displayKeys[idx];
            final dayMeals = grouped[dateKey] ?? [];
            return _buildDayGroup(context, controller, dateKey, dayMeals);
          },
        ),
      ],
    );
  }

  Widget _buildReserveAllBanner(
    BuildContext context,
    CampusRestoController controller,
  ) {
    final unreservedCount = controller.unreservedMealsCount;
    final solde = controller.kpis?.soldeRepas ?? 0;
    final textScale = MediaQuery.of(context).textScaler.scale(1.0);

    return Container(
      key: const ValueKey('resto_reserve_all_banner'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5A47), Color(0xFF1B7A5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5A47).withValues(alpha: 0.22),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleReserveAllWeek(context, controller),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final bool isCompact =
                    constraints.maxWidth < 320 || textScale > 1.3;

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Réserver la semaine',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '$unreservedCount repas en attente • Solde: ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: RouletteNumberText(
                                value: solde.toDouble(),
                                suffix: ' repas',
                                decimalDigits: 0,
                                isHeader: true,
                                duration: const Duration(milliseconds: 900),
                                wholeStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                decimalStyle: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey('resto_reserve_all_button'),
                          onPressed: () =>
                              _handleReserveAllWeek(context, controller),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F5A47),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '1-Tap Réserver',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Réserver toute la semaine',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '$unreservedCount repas en attente • Solde: ',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Flexible(
                                fit: FlexFit.loose,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: RouletteNumberText(
                                    value: solde.toDouble(),
                                    suffix: ' repas',
                                    decimalDigits: 0,
                                    isHeader: true,
                                    duration: const Duration(milliseconds: 900),
                                    wholeStyle: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    decimalStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ElevatedButton(
                        key: const ValueKey('resto_reserve_all_button'),
                        onPressed: () =>
                            _handleReserveAllWeek(context, controller),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F5A47),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '1-Tap',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllReservedBadge() {
    return Container(
      key: const ValueKey('resto_all_meals_reserved_badge'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF9F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Tous les repas de la semaine sont réservés !',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayGroup(
    BuildContext context,
    CampusRestoController? controller,
    String dateKey,
    List<CampusMealItem> meals,
  ) {
    final firstMeal = meals.isNotEmpty ? meals.first : null;
    final date = firstMeal?.date ?? DateTime.now();
    final dayTitle = _formatDayHeader(date, firstMeal?.dayLabel ?? '');
    final isToday = _isSameDay(date, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  dayTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isToday)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "Aujourd'hui",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Meal Items in this day
          ...meals.map((meal) => _buildMealItemCard(context, controller, meal)),
        ],
      ),
    );
  }

  Widget _buildMealItemCard(
    BuildContext context,
    CampusRestoController? controller,
    CampusMealItem meal,
  ) {
    final isLunch = meal.type == MealType.dejeuner;
    final isReserved = meal.status == MealStatus.reserved;
    final isConsumed = meal.status == MealStatus.consumed;

    return Container(
      key: ValueKey('meal_item_${meal.id}'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: () => _handleMealTap(context, controller, meal),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Meal Type Icon
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isLunch
                    ? const Color(0xFFFEF3C7) // Amber tint
                    : const Color(0xFFEEF2FF), // Lavender tint
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isLunch
                    ? Icons.wb_sunny_rounded
                    : Icons.nightlight_round_rounded,
                color:
                    isLunch ? const Color(0xFFD97706) : const Color(0xFF4F46E5),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Type & Date Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.type.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLunch
                        ? 'Service déjeuner • 11h30 - 14h00'
                        : 'Service dîner • 18h00 - 20h30',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Status Badge
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child:
                    _buildMealStatusBadge(meal.status, isReserved, isConsumed),
              ),
            ),
            const SizedBox(width: 4),

            // Chevron Arrow
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealStatusBadge(
    MealStatus status,
    bool isReserved,
    bool isConsumed,
  ) {
    if (isReserved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 12, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'Réservé',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (isConsumed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 12, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text(
              'Consommé',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Default: Not Reserved
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Non réservé',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyMealsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.restaurant_outlined,
              size: 38, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'Aucun repas programmé pour cette semaine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tirez vers le bas pour actualiser le menu du portail.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Error Banner Widget
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(
    BuildContext context,
    CampusRestoController? controller,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.onErrorContainer.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.onErrorContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (controller != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: TextButton(
                  onPressed: () => controller.refreshDashboard(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Réessayer',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Event & Modal Handlers
  // ─────────────────────────────────────────────────────────────────────────
  void _handleOpenLogin(
    BuildContext context,
    CampusRestoController? controller,
  ) {
    HapticFeedback.lightImpact();
    if (widget.onOpenLoginSheet != null) {
      widget.onOpenLoginSheet!();
      return;
    }

    if (CampusRestoService.canCreateWebView) {
      _initWebViewController(controller);
      setState(() {
        _isInAppLoginOpen = true;
      });
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => RestoLoginSheet(
          restoService: CampusRestoService.instance,
          onLoginSuccessWithHtml: (cookies, {html}) async {
            if (controller != null) {
              if (html != null && html.isNotEmpty) {
                await controller.parseAndLoadDashboard(html);
              }
              await controller.onLoginSuccess(cookies);
            }
          },
          onLoginSuccess: (cookies) async {
            if (controller != null) {
              await controller.onLoginSuccess(cookies);
            }
          },
        ),
      );
    }
  }

  void _handleMealTap(
    BuildContext context,
    CampusRestoController? controller,
    CampusMealItem meal,
  ) async {
    HapticFeedback.lightImpact();
    if (widget.onMealTapped != null) {
      widget.onMealTapped!(meal);
      return;
    }

    if (controller == null) return;

    // Fetch details asynchronously and display modal
    try {
      final details = await controller.getMealDetails(meal.id);
      if (!context.mounted) return;
      if (details != null) {
        showDialog(
          context: context,
          builder: (ctx) => MealDetailsDialog(
            meal: meal,
            details: details,
            onReserve: () async {
              final ok = await controller.reserveMeal(meal.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Repas réservé avec succès !'
                        : 'Échec de la réservation. Vérifiez votre solde.',
                  ),
                  backgroundColor: ok ? AppColors.primary : AppColors.error,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger le menu pour ce repas.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les détails: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleReserveAllWeek(
    BuildContext context,
    CampusRestoController controller,
  ) async {
    final unreservedCount = controller.unreservedMealsCount;
    if (unreservedCount == 0) return;

    final solde = controller.kpis?.soldeRepas ?? 0;
    final bool insufficient = solde < unreservedCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              insufficient
                  ? Icons.warning_amber_rounded
                  : Icons.auto_awesome_rounded,
              color: insufficient ? const Color(0xFFD97706) : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              insufficient ? 'Solde restreint' : 'Réserver la semaine',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Text(
          insufficient
              ? 'Vous avez $solde repas disponible(s) sur votre carte pour $unreservedCount repas non réservés cette semaine. Voulez-vous réserver jusqu’à épuisement de votre solde ?'
              : 'Confirmez-vous la réservation de $unreservedCount repas pour cette semaine ? Votre solde passera de $solde à ${solde - unreservedCount} repas.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            key: const ValueKey('confirm_reserve_all_btn'),
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(insufficient ? 'Continuer' : 'Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    int currentStep = 0;
    int totalSteps = unreservedCount;
    String currentMealLabel = 'Initialisation...';
    StateSetter? dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            dialogSetState = setDialogState;
            final progress = totalSteps > 0
                ? (currentStep / totalSteps).clamp(0.0, 1.0)
                : 0.0;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Réservation groupée en cours',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currentStep sur $totalSteps repas',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMealLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final result = await controller.reserveAllUnreservedMeals(
        onProgress: (current, total, meal) {
          currentStep = current;
          totalSteps = total;
          currentMealLabel = '${meal.dayLabel} • ${meal.type.label}';
          if (dialogSetState != null) {
            dialogSetState!(() {});
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog
      }

      if (!context.mounted) return;

      if (result.isFullSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Succès ! ${result.succeeded} repas réservés avec succès.',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result.succeeded > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.succeeded} repas réservés. (${result.failed} non réservés : solde insuffisant)',
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Impossible de réserver les repas. Solde insuffisant.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la réservation groupée: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleOpenHistory(
    BuildContext context,
    CampusRestoController controller,
  ) {
    if (widget.onOpenHistory != null) {
      widget.onOpenHistory!();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestoHistorySheet(
        checkIns: controller.checkIns,
        topUps: controller.topUps,
      ),
    );
  }

  void _handleSyncBudget(
    BuildContext context,
    CampusRestoController controller,
  ) async {
    BudgetController? budget;
    try {
      budget = Provider.of<BudgetController>(context, listen: false);
    } catch (_) {}

    if (budget == null) return;

    try {
      await controller.syncWithBudget(budget);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Synchronisation Resto U terminée avec succès'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la synchronisation: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleLogoutPrompt(
    BuildContext context,
    CampusRestoController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Déconnexion Resto U',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Voulez-vous vous déconnecter du portail universitaire CUKL ? Les données hors-ligne seront réinitialisées.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Annuler',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await controller.logout();
              _isInAppLoginOpen = false;
              _webViewController?.loadRequest(
                  Uri.parse('https://cukl.ooun.rnu.tn/?p=users.login'));
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Déconnexion',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper Date Utilities
  // ─────────────────────────────────────────────────────────────────────────
  String _formatDayHeader(DateTime date, String fallbackLabel) {
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    final dayIndex = (date.weekday - 1).clamp(0, 6);
    final monthIndex = (date.month - 1).clamp(0, 11);
    final dayName = days[dayIndex];
    final monthName = months[monthIndex];
    return '$dayName ${date.day} $monthName';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

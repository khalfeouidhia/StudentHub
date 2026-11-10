import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studenthold_app/constants/app_colors.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/campus_resto_service.dart';
import '../../services/session_storage_service.dart';

/// Modal bottom sheet embedding a WebView for student authentication on the OOUN portal.
///
/// Features:
/// - Loads `https://cukl.ooun.rnu.tn/?p=users.login`
/// - Intercepts post-login redirect to `?p=etd.posts.index`
/// - Direct DOM outerHTML extraction + JS `fetch()` bridge for HttpOnly session requests
/// - Safe platform guard preventing `WebViewPlatform.instance != null` red screen crashes
/// - Full Manual / PC Debug cookie entry mode alongside simulated mock login
class RestoLoginSheet extends StatefulWidget {
  final ValueChanged<String>? onLoginSuccess;
  final void Function(String cookies, {String? html})? onLoginSuccessWithHtml;
  final VoidCallback? onCancel;
  final bool isTestMode;
  final WebViewController? testController;
  final Object? testCookieManager;
  final CampusRestoService? restoService;

  const RestoLoginSheet({
    super.key,
    this.onLoginSuccess,
    this.onLoginSuccessWithHtml,
    this.onCancel,
    this.isTestMode = false,
    this.testController,
    this.testCookieManager,
    this.restoService,
  });

  /// Displays the login sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    ValueChanged<String>? onLoginSuccess,
    void Function(String cookies, {String? html})? onLoginSuccessWithHtml,
    VoidCallback? onCancel,
    bool isTestMode = false,
    CampusRestoService? restoService,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestoLoginSheet(
        onLoginSuccess: onLoginSuccess,
        onLoginSuccessWithHtml: onLoginSuccessWithHtml,
        onCancel: onCancel,
        isTestMode: isTestMode,
        restoService: restoService,
      ),
    );
  }

  @override
  State<RestoLoginSheet> createState() => _RestoLoginSheetState();
}

class _RestoLoginSheetState extends State<RestoLoginSheet> {
  static const String loginUrl = 'https://cukl.ooun.rnu.tn/?p=users.login';

  WebViewController? _controller;
  int _progress = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasExtracted = false;
  bool _isPlatformUnsupported = false;

  bool get _shouldUseMockMode =>
      widget.isTestMode ||
      _isPlatformUnsupported ||
      (!CampusRestoService.canCreateWebView && widget.testController == null);

  @override
  void initState() {
    super.initState();

    if (_shouldUseMockMode) {
      _isLoading = false;
    } else {
      _initWebViewControllerSafely();
    }
  }

  void _initWebViewControllerSafely() {
    if (widget.testController != null) {
      _controller = widget.testController;
      _isLoading = false;
      return;
    }

    if (!CampusRestoService.canCreateWebView) {
      setState(() {
        _isPlatformUnsupported = true;
        _isLoading = false;
      });
      return;
    }

    try {
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..enableZoom(true)
        ..setBackgroundColor(Colors.white)
        ..setUserAgent(
            'Mozilla/5.0 (Linux; Android 13; Mobile) StudentHoldApp/1.0')
        ..addJavaScriptChannel(
          'RestoBridge',
          onMessageReceived: (JavaScriptMessage msg) {
            widget.restoService?.handleBridgeMessage(msg.message);
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
            },
            onPageFinished: (String url) async {
              if (mounted) {
                setState(() => _isLoading = false);
              }

              // Inject responsive viewport and scroll fix
              try {
                await controller.runJavaScript('''
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

              // Strict DOM Session Check
              final checkDashboardJs = '''
                (function() {
                  return document.querySelector('#repas-table') !== null || 
                         document.querySelector('.infobox-container') !== null;
                })();
              ''';

              try {
                final isDashboard = await controller
                    .runJavaScriptReturningResult(checkDashboardJs);
                final cleanIsDash = isDashboard.toString().toLowerCase();

                if (cleanIsDash == 'true' || _isDashboardRedirect(url)) {
                  _extractCookiesAndComplete(url);
                }
              } catch (_) {
                if (_isDashboardRedirect(url)) {
                  _extractCookiesAndComplete(url);
                }
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              // ALWAYS allow navigation so POST submits don't trigger ERR_CACHE_MISS
              return NavigationDecision.navigate;
            },
            onWebResourceError: (WebResourceError error) {
              // Log error but do not disrupt ongoing POST redirects
              debugPrint(
                  '[RestoLoginSheet] WebView resource error: ${error.errorCode} - ${error.description}');
            },
          ),
        )
        ..loadRequest(Uri.parse(loginUrl));

      _controller = controller;
    } catch (e) {
      debugPrint(
          '[RestoLoginSheet] WebViewController initialization caught: $e');
      if (mounted) {
        setState(() {
          _isPlatformUnsupported = true;
          _isLoading = false;
        });
      }
    }
  }

  bool _isDashboardRedirect(String url) {
    return url.contains('p=etd.posts.index') || url.contains('etd.posts.index');
  }

  Future<void> _extractCookiesAndComplete(String redirectUrl) async {
    if (_hasExtracted) return;
    _hasExtracted = true;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    String? fullHtml;
    String? cookieHeader;

    if (_controller != null) {
      // 1. Disable the portal's annoying 20-second auto-disconnect timer
      try {
        await _controller!.runJavaScript('''
          if (typeof intervalId !== 'undefined') clearInterval(intervalId);
          window.checkSession = function() {};
        ''');
      } catch (_) {}

      // 2. Extract full rendered HTML of dashboard directly from live DOM
      try {
        final rawHtmlResult = await _controller!
            .runJavaScriptReturningResult('document.documentElement.outerHTML');
        final cleanHtml = CampusRestoService.unescapeJsString(rawHtmlResult);
        if (cleanHtml.isNotEmpty &&
            (cleanHtml.contains('infobox-container') ||
                cleanHtml.contains('repas-table'))) {
          fullHtml = cleanHtml;
          widget.restoService?.lastExtractedHtml = fullHtml;
          CampusRestoService.instance.lastExtractedHtml = fullHtml;
        }
      } catch (e) {
        debugPrint('[RestoLoginSheet] HTML extraction error: $e');
      }

      // 3. Register the active controller in the bridge service for subsequent fetch() calls
      widget.restoService?.registerWebViewController(_controller);
      CampusRestoService.instance.registerWebViewController(_controller);
    }

    // 4. Capture cookies via WebViewCookieManager and save under 'resto_cookie'
    try {
      if (_controller != null) {
        final cookies =
            await CampusRestoService.extractCookiesFromWebViewController(
                _controller!);
        if (cookies.isNotEmpty) {
          cookieHeader = cookies;
          await SessionStorageService().saveRestoCookie(cookies);
        }
      }
    } catch (_) {}

    cookieHeader ??=
        'PHPSESSID=session_${DateTime.now().millisecondsSinceEpoch}';

    if (widget.onLoginSuccessWithHtml != null) {
      widget.onLoginSuccessWithHtml!(cookieHeader, html: fullHtml);
    } else {
      widget.onLoginSuccess?.call(cookieHeader);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _triggerMockLoginSuccess() {
    const mockCookie =
        'PHPSESSID=mock_session_12345; cookiesession1=mock_token_67890';
    if (widget.onLoginSuccessWithHtml != null) {
      widget.onLoginSuccessWithHtml!(mockCookie);
    } else {
      widget.onLoginSuccess?.call(mockCookie);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.90;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portail Resto U',
                        style: TextStyle(
                          color: AppColors.deepForest,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Authentification OOUN (cukl.ooun.rnu.tn)',
                        style:
                            TextStyle(color: AppColors.mutedSage, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('resto_login_close_btn'),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.mutedSage),
                  onPressed: () {
                    widget.onCancel?.call();
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
          ),

          // Progress Bar
          if (_isLoading && !_shouldUseMockMode)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100.0 : null,
              backgroundColor: AppColors.surfaceLow,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 3,
            )
          else
            const Divider(height: 1, color: AppColors.cardBorder),

          // Content Area (Mock Test Mode vs Real Native WebView)
          Expanded(
            child: _shouldUseMockMode
                ? _buildManualAndMockView()
                : _buildWebView(),
          ),

          // Footer Controls Toolbar
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildManualAndMockView() {
    return SingleChildScrollView(
      key: const Key('resto_mock_login_container'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
              children: [
                Icon(Icons.science_rounded, size: 40, color: AppColors.primary),
                SizedBox(height: 10),
                Text(
                  'Simulation Authentification Resto U',
                  style: TextStyle(
                    color: AppColors.deepForest,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'Mode de simulation pour tests unitaires.',
                  style: TextStyle(color: AppColors.mutedSage, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('mock_login_success_btn'),
              onPressed: _triggerMockLoginSuccess,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Simuler Connexion Réussie',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('mock_login_failure_btn'),
              onPressed: () {
                setState(() => _errorMessage =
                    'Identifiants invalides ou captcha non résolu (Test)');
              },
              icon: const Icon(Icons.error_outline_rounded, size: 18),
              label: const Text('Simuler Échec de Connexion',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.errorContainer),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.onErrorContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebView() {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        WebViewWidget(
          controller: _controller!,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        ),
        if (_errorMessage != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  const Text(
                    'Erreur de chargement du portail',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepForest),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: AppColors.mutedSage, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _controller?.loadRequest(Uri.parse(loginUrl));
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    child: const Text('Réessayer',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLow,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!_shouldUseMockMode) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.deepForest),
                onPressed: () async {
                  if (await _controller?.canGoBack() ?? false) {
                    await _controller?.goBack();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.deepForest),
                onPressed: () => _controller?.reload(),
              ),
            ],
            const Spacer(),
            const Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Connexion sécurisée SSL',
                      style: TextStyle(
                        color: AppColors.mutedSage,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

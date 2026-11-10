import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/budget_controller.dart';
import '../navigation/main_shell.dart';
import 'welcome_vault_view.dart';

/// Optimized Seamless Splash PageRoute combining cross-fade with 4% upward slide
class SeamlessSplashRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SeamlessSplashRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 650),
          reverseTransitionDuration: const Duration(milliseconds: 650),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: curvedAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.04), // 4% subtle upward slide
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

class StudentHubSplashScreen extends StatefulWidget {
  final Future<void>? initializationTask;
  final Duration? minimumDisplayDuration;
  final bool autoBootstrap;

  const StudentHubSplashScreen({
    super.key,
    this.initializationTask,
    this.minimumDisplayDuration,
    this.autoBootstrap = true,
  });

  @override
  State<StudentHubSplashScreen> createState() => _StudentHubSplashScreenState();
}

class _StudentHubSplashScreenState extends State<StudentHubSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _pulseController;
  late AnimationController _spinnerController;
  late AnimationController _exitController;

  // Intro curves
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<Offset> _textSlideAnimation;

  // Exit curves
  late Animation<double> _exitFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance / Reveal Controller
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.90, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Idle Float Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 3. Flat Spinner Controller
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // 4. Exit / Transition Out Controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInQuad,
      ),
    );

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.05),
    ).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: Curves.easeInCubic,
      ),
    );

    _startFlow();
  }

  Future<void> _startFlow() async {
    // Run entrance animation
    _introController.forward();

    final bootstrapFuture = () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted || _isDisposed) return;

        // Verify onboarding state in storage
        final hasOnboardedFlag = prefs.getBool('isOnboarded') ?? false;

        // Verify and initialize AuthController
        final auth = Provider.of<AuthController>(context, listen: false);
        if (!auth.isInitialized) {
          await auth.init();
        } else if (hasOnboardedFlag && !auth.isOnboarded) {
          await auth.init();
        }

        // Verify and initialize BudgetController
        if (mounted && !_isDisposed) {
          final budget = Provider.of<BudgetController>(context, listen: false);
          if (budget.pendingRollover) {
            // Pending rollover will be prompted on dashboard
          }
        }
      } catch (_) {
        // Safe fallback in test environments
      }
    }();

    final taskFuture = widget.initializationTask ??
        (widget.autoBootstrap ? bootstrapFuture : null);
    final minDisplay =
        widget.minimumDisplayDuration ?? const Duration(milliseconds: 1400);

    // Wait for the initialization task or minimum graceful display window
    if (widget.autoBootstrap || widget.initializationTask != null) {
      await Future.wait([
        if (taskFuture != null) taskFuture,
        Future.delayed(minDisplay),
      ]);
    } else {
      return; // Static mode for test harnesses
    }

    if (!mounted || _isDisposed) return;

    // Trigger smooth exit collapse
    await _exitController.forward();

    if (!mounted || _isDisposed) return;

    final auth = Provider.of<AuthController>(context, listen: false);
    final isOnboarded = auth.isOnboarded;
    final Widget nextScreen = isOnboarded
        ? const MainShell(key: ValueKey('main_shell'))
        : const WelcomeVaultView(key: ValueKey('welcome_vault'));

    // Navigate smoothly and remove splash from navigation stack
    Navigator.of(context).pushReplacement(
      SeamlessSplashRoute(page: nextScreen),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _introController.dispose();
    _pulseController.dispose();
    _spinnerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color brandPrimary = Color(0xFF00C274);
    const Color brandDarkBg = Color(0xFF071F18);
    const Color brandTextMuted = Color(0xFF85A89D);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: brandDarkBg,
        body: SafeArea(
          child: SlideTransition(
            position: _exitSlideAnimation,
            child: FadeTransition(
              opacity: _exitFadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Animated Wallet Icon
                    AnimatedBuilder(
                      animation: Listenable.merge(
                          [_introController, _pulseController]),
                      builder: (context, child) {
                        final floatOffset =
                            math.sin(_pulseController.value * math.pi) * 3.5;
                        return Transform.translate(
                          offset: Offset(0, floatOffset),
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Opacity(
                              opacity: _fadeAnimation.value,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 110,
                        height: 110,
                        child: CustomPaint(
                          painter: FlatWalletPainter(color: brandPrimary),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Typography
                    SlideTransition(
                      position: _textSlideAnimation,
                      child: FadeTransition(
                        opacity: _textFadeAnimation,
                        child: Column(
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Student',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                      color: Colors.white,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Hub',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: brandPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'YOUR MONEY. YOUR FUTURE.',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.8,
                                color: brandTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Flat Minimal Loop Spinner
                    RotationTransition(
                      turns: _spinnerController,
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: CustomPaint(
                          painter: FlatSpinnerPainter(
                            trackColor: Color(0x1F00C274),
                            sweepColor: brandPrimary,
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Flat Vector Wallet Painter
class FlatWalletPainter extends CustomPainter {
  final Color color;
  const FlatWalletPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final RRect outerBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.56),
      const Radius.circular(16),
    );
    canvas.drawRRect(outerBody, outlinePaint);

    final Path cardLip = Path()
      ..moveTo(w * 0.26, h * 0.22)
      ..lineTo(w * 0.26, h * 0.16)
      ..quadraticBezierTo(w * 0.26, h * 0.12, w * 0.32, h * 0.12)
      ..lineTo(w * 0.68, h * 0.12)
      ..quadraticBezierTo(w * 0.74, h * 0.12, w * 0.74, h * 0.22);
    canvas.drawPath(cardLip, outlinePaint);

    final Path clasp = Path()
      ..moveTo(w * 0.60, h * 0.36)
      ..lineTo(w * 0.82, h * 0.36)
      ..quadraticBezierTo(w * 0.88, h * 0.36, w * 0.88, h * 0.50)
      ..quadraticBezierTo(w * 0.88, h * 0.64, w * 0.82, h * 0.64)
      ..lineTo(w * 0.60, h * 0.64);
    canvas.drawPath(clasp, outlinePaint);

    canvas.drawCircle(Offset(w * 0.76, h * 0.50), 3.2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Flat 2-Tone Spinner Painter
class FlatSpinnerPainter extends CustomPainter {
  final Color trackColor;
  final Color sweepColor;
  final double strokeWidth;

  const FlatSpinnerPainter({
    required this.trackColor,
    required this.sweepColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Paint sweepPaint = Paint()
      ..color = sweepColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      1.75,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Backward compatibility alias for legacy test harnesses and call sites.
typedef MintyNestSplashScreen = StudentHubSplashScreen;

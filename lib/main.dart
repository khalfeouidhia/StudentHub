import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_colors.dart';
import 'controllers/auth_controller.dart';
import 'controllers/tasks_controller.dart';
import 'controllers/budget_controller.dart';
import 'controllers/utilities_controller.dart';
import 'controllers/user_profile_controller.dart';
import 'features/campus_resto/controllers/campus_resto_controller.dart';
import 'services/storage_service.dart';
import 'ui/views/welcome_vault_view.dart';
import 'ui/navigation/main_shell.dart';
import 'ui/views/splash_screen.dart';

/// Permissive HTTP overrides for the university campus portal (cukl.ooun.rnu.tn)
/// which uses an incomplete intermediate SSL certificate chain.
class CampusHttpOverrides extends HttpOverrides {
  static bool verifyCertificate(X509Certificate? cert, String host, int port) {
    return host.contains('ooun.rnu.tn') || host.contains('rnu.tn');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return verifyCertificate(cert, host, port);
      };
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = CampusHttpOverrides();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const StudentHoldApp());
}

/// Root widget configuring state providers and the dark Stitch-inspired design theme.
class StudentHoldApp extends StatelessWidget {
  const StudentHoldApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController()..init(),
        ),
        ChangeNotifierProvider<TasksController>(
          create: (_) => TasksController(),
        ),
        ChangeNotifierProvider<BudgetController>(
          create: (_) => BudgetController(),
        ),
        ChangeNotifierProvider<CampusRestoController>(
          create: (_) => CampusRestoController()..init(),
        ),
        // Compatibility providers for legacy dependencies
        ChangeNotifierProvider<UtilitiesController>(
          create: (_) => UtilitiesController(),
        ),
        ChangeNotifierProvider<UserProfileController>(
          create: (_) => UserProfileController(storageService)..init(),
        ),
      ],
      child: MaterialApp(
        title: 'StudentHub',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.background,
          dialogBackgroundColor: AppColors.surface,
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            Theme.of(context).textTheme,
          ).apply(
            fontFamilyFallback: const [
              '-apple-system',
              'SF Pro Display',
              'SF Pro Text',
              'Helvetica Neue',
            ],
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: AppColors.surface,
          ),
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            error: AppColors.error,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        home: const StudentHubSplashScreen(),
        builder: (context, child) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: child ?? const SizedBox(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Asynchronous gate verifying onboarding status before routing.
class AppInitializationGate extends StatelessWidget {
  const AppInitializationGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (!auth.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.accent, size: 48),
              SizedBox(height: 16),
              CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        final curve =
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic);
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.05),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
      child: auth.isOnboarded
          ? const MainShell(key: ValueKey('main_shell'))
          : const WelcomeVaultView(key: ValueKey('welcome_vault')),
    );
  }
}

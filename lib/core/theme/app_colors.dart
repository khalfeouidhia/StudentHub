import 'package:flutter/material.dart';

/// Design tokens for the two-tone curved architecture.
class AppColors {
  AppColors._();

  // ==========================================
  // 6 Core Brand Tokens
  // ==========================================
  /// Deepest dark text & shadows (#0F1F17)
  static const Color darkForest = Color(0xFF0F1F17);

  /// Header primary green (#1E3A2E)
  static const Color deepPine = Color(0xFF1E3A2E);

  /// Secondary accents & borders (#3E5A3F)
  static const Color midMoss = Color(0xFF3E5A3F);

  /// Subtitles & decimal numbers (#6B7F67)
  static const Color softSage = Color(0xFF6B7F67);

  /// Curved body sheet / light tint (#C7CBB8)
  static const Color sandCream = Color(0xFFC7CBB8);

  /// Primary body typography (#3D4337)
  static const Color darkOlive = Color(0xFF3D4337);

  // ==========================================
  // Accents & Surfaces
  // ==========================================
  /// Bright active green pills (#00D084)
  static const Color vibrantGreen = Color(0xFF00D084);

  /// Inner card white surfaces (#F9FAF7)
  static const Color surfaceWhite = Color(0xFFF9FAF7);

  /// Icon badge background (#42A5F5)
  static const Color iconBlue = Color(0xFF42A5F5);

  /// Negative expense indicator (#E57373)
  static const Color expenseRed = Color(0xFFE57373);

  // ==========================================
  // Backward Compatibility & Legacy Aliases
  // ==========================================
  static const Color background = surfaceWhite;
  static const List<Color> backgroundGradient = [
    deepPine,
    midMoss,
    sandCream,
  ];
  static const Color backgroundGradientStart = deepPine;
  static const Color backgroundGradientEnd = sandCream;

  static const Color surface = surfaceWhite;
  static const Color surfaceLowest = surfaceWhite;
  static const Color surfaceLow = Color(0xFFF5FAF7);
  static const Color surfaceContainer = sandCream;
  static const Color surfaceHigh = Color(0xFFE2F4EA);
  static const Color surfaceHighest = sandCream;

  static const Color primary = deepPine;
  static const Color primaryEmerald = vibrantGreen;
  static const Color primaryDark = darkForest;
  static const Color primaryContainer = Color(0xFFDCFCE7);
  static const Color primaryFixed = sandCream;
  static const Color primaryFixedDim = softSage;
  static const Color onPrimary = surfaceWhite;
  static const Color onPrimaryFixed = darkForest;

  static const Color secondary = midMoss;
  static const Color mint = vibrantGreen;
  static const Color mintLight = Color(0xFF86EFAC);
  static const Color mintSage = Color(0xFF4ADE80);
  static const Color mintSubtle = Color(0x2600D084);
  static const Color secondaryContainer = Color(0xFFDCFCE7);
  static const Color secondaryFixed = Color(0xFFDCFCE7);

  static const Color deepForest = darkForest;
  static const Color textPrimary = darkForest;
  static const Color textOnSurface = darkForest;

  static const Color mutedSage = softSage;
  static const Color mutedSageLight = Color(0xFF6C8A79);
  static const Color textSecondary = softSage;
  static const Color textOnSurfaceVariant = softSage;
  static const Color textMuted = softSage;

  static const Color cardBorder = sandCream;
  static const Color border = sandCream;
  static const Color borderLight = Color(0xFFE2F4EA);
  static const Color borderHighlight = Color(0x3300D084);
  static const Color outline = midMoss;
  static const Color outlineVariant = softSage;
  static const Color inputFill = surfaceWhite;

  static const Color categoryDining = midMoss;
  static const Color categoryFood = midMoss;
  static const Color categorySocial = vibrantGreen;
  static const Color categoryLeisure = vibrantGreen;
  static const Color categoryHousing = iconBlue;
  static const Color categoryBooks = Color(0xFFD97706);
  static const Color academic = iconBlue;
  static const Color personal = vibrantGreen;
  static const Color exam = expenseRed;
  static const Color project = Color(0xFF7C3AED);

  static const Color error = expenseRed;
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);
  static const Color success = vibrantGreen;
  static const Color warning = Color(0xFFD97706);

  static const Color accent = vibrantGreen;
  static const Color accentSecondary = midMoss;
  static const Color accentSubtle = Color(0x2600D084);
  static const Color surfaceSecondary = sandCream;
  static const Color surfaceLight = Color(0xFFEBF7F0);
  static const Color borderMuted = sandCream;
  static const Color errorDark = Color(0xFFB91C1C);
  static const Color secondaryIndigo = Color(0xFF4F46E5);
  static const Color secondaryLavender = Color(0xFF818CF8);
  static const Color lavenderTint = Color(0xFFEEF2FF);
  static const Color tertiary = Color(0xFFD97706);
  static const Color tertiaryCaramel = Color(0xFFB45309);
  static const Color tertiaryPeach = Color(0xFFFB923C);
  static const Color tertiaryCoral = expenseRed;
  static const Color tertiaryFixed = Color(0xFFFFEDD5);
  static const Color tertiaryFixedDim = Color(0xFFFED7AA);
  static const Color tertiaryContainer = Color(0xFFFEF3C7);
  static const Color categoryEmergency = expenseRed;
}

/// Precision currency formatting helper strictly calculating and formatting in Tunisian Dinar (DT).
class CurrencyHelper {
  CurrencyHelper._();

  static String formatDT(double amount, {bool showSymbol = false}) {
    if (!amount.isFinite) return showSymbol ? '0.000 DT' : '0.000';
    final millimes = (amount * 1000).round();
    final sign = millimes < 0 ? '-' : '';
    final absMillimes = millimes.abs();
    final dinars = absMillimes ~/ 1000;
    final mPart = (absMillimes % 1000).toString().padLeft(3, '0');
    final val = '$sign$dinars.$mPart';
    return showSymbol ? '$val DT' : val;
  }

  static String format(double amount, {String symbol = 'DT'}) {
    return '${formatDT(amount)} $symbol';
  }

  static String formatCompact(double amount, {String symbol = 'DT'}) {
    return '${amount.toInt()} $symbol';
  }
}

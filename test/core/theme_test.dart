import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studenthold_app/core/theme/app_colors.dart';
import 'package:studenthold_app/constants/app_colors.dart' as legacy;

void main() {
  group('Milestone 1 — Core Brand Palette (6 tokens)', () {
    test('darkForest token matches exact hex #0F1F17', () {
      expect(AppColors.darkForest.value, equals(0xFF0F1F17));
      expect(AppColors.darkForest.alpha, equals(0xFF));
      expect(AppColors.darkForest.red, equals(0x0F));
      expect(AppColors.darkForest.green, equals(0x1F));
      expect(AppColors.darkForest.blue, equals(0x17));
    });

    test('deepPine token matches exact hex #1E3A2E', () {
      expect(AppColors.deepPine.value, equals(0xFF1E3A2E));
      expect(AppColors.deepPine.alpha, equals(0xFF));
      expect(AppColors.deepPine.red, equals(0x1E));
      expect(AppColors.deepPine.green, equals(0x3A));
      expect(AppColors.deepPine.blue, equals(0x2E));
    });

    test('midMoss token matches exact hex #3E5A3F', () {
      expect(AppColors.midMoss.value, equals(0xFF3E5A3F));
      expect(AppColors.midMoss.alpha, equals(0xFF));
      expect(AppColors.midMoss.red, equals(0x3E));
      expect(AppColors.midMoss.green, equals(0x5A));
      expect(AppColors.midMoss.blue, equals(0x3F));
    });

    test('softSage token matches exact hex #6B7F67', () {
      expect(AppColors.softSage.value, equals(0xFF6B7F67));
      expect(AppColors.softSage.alpha, equals(0xFF));
      expect(AppColors.softSage.red, equals(0x6B));
      expect(AppColors.softSage.green, equals(0x7F));
      expect(AppColors.softSage.blue, equals(0x67));
    });

    test('sandCream token matches exact hex #C7CBB8', () {
      expect(AppColors.sandCream.value, equals(0xFFC7CBB8));
      expect(AppColors.sandCream.alpha, equals(0xFF));
      expect(AppColors.sandCream.red, equals(0xC7));
      expect(AppColors.sandCream.green, equals(0xCB));
      expect(AppColors.sandCream.blue, equals(0xB8));
    });

    test('darkOlive token matches exact hex #3D4337', () {
      expect(AppColors.darkOlive.value, equals(0xFF3D4337));
      expect(AppColors.darkOlive.alpha, equals(0xFF));
      expect(AppColors.darkOlive.red, equals(0x3D));
      expect(AppColors.darkOlive.green, equals(0x43));
      expect(AppColors.darkOlive.blue, equals(0x37));
    });
  });

  group('Milestone 1 — Accents and Surfaces (4 tokens)', () {
    test('vibrantGreen token matches exact hex #00D084', () {
      expect(AppColors.vibrantGreen.value, equals(0xFF00D084));
      expect(AppColors.vibrantGreen.alpha, equals(0xFF));
      expect(AppColors.vibrantGreen.red, equals(0x00));
      expect(AppColors.vibrantGreen.green, equals(0xD0));
      expect(AppColors.vibrantGreen.blue, equals(0x84));
    });

    test('surfaceWhite token matches exact hex #F9FAF7', () {
      expect(AppColors.surfaceWhite.value, equals(0xFFF9FAF7));
      expect(AppColors.surfaceWhite.alpha, equals(0xFF));
      expect(AppColors.surfaceWhite.red, equals(0xF9));
      expect(AppColors.surfaceWhite.green, equals(0xFA));
      expect(AppColors.surfaceWhite.blue, equals(0xF7));
    });

    test('iconBlue token matches exact hex #42A5F5', () {
      expect(AppColors.iconBlue.value, equals(0xFF42A5F5));
      expect(AppColors.iconBlue.alpha, equals(0xFF));
      expect(AppColors.iconBlue.red, equals(0x42));
      expect(AppColors.iconBlue.green, equals(0xA5));
      expect(AppColors.iconBlue.blue, equals(0xF5));
    });

    test('expenseRed token matches exact hex #E57373', () {
      expect(AppColors.expenseRed.value, equals(0xFFE57373));
      expect(AppColors.expenseRed.alpha, equals(0xFF));
      expect(AppColors.expenseRed.red, equals(0xE5));
      expect(AppColors.expenseRed.green, equals(0x73));
      expect(AppColors.expenseRed.blue, equals(0x73));
    });
  });

  group('Milestone 1 — Backward Compatibility & Token Re-exports', () {
    test('legacy constants/app_colors exports all 10 tokens identically', () {
      expect(legacy.AppColors.darkForest, equals(AppColors.darkForest));
      expect(legacy.AppColors.deepPine, equals(AppColors.deepPine));
      expect(legacy.AppColors.midMoss, equals(AppColors.midMoss));
      expect(legacy.AppColors.softSage, equals(AppColors.softSage));
      expect(legacy.AppColors.sandCream, equals(AppColors.sandCream));
      expect(legacy.AppColors.darkOlive, equals(AppColors.darkOlive));
      expect(legacy.AppColors.vibrantGreen, equals(AppColors.vibrantGreen));
      expect(legacy.AppColors.surfaceWhite, equals(AppColors.surfaceWhite));
      expect(legacy.AppColors.iconBlue, equals(AppColors.iconBlue));
      expect(legacy.AppColors.expenseRed, equals(AppColors.expenseRed));
    });
  });

  group('Milestone 1 — Perceptual Contrast & Accessibility Verification', () {
    test('surfaceWhite and sandCream have light background luminance', () {
      expect(AppColors.surfaceWhite.computeLuminance(), greaterThan(0.90));
      expect(AppColors.sandCream.computeLuminance(), greaterThan(0.55));
    });

    test('darkForest and deepPine have dark foreground luminance', () {
      expect(AppColors.darkForest.computeLuminance(), lessThan(0.05));
      expect(AppColors.deepPine.computeLuminance(), lessThan(0.10));
    });

    test(
        'darkForest on surfaceWhite satisfies WCAG AAA contrast ratio (> 7.0:1)',
        () {
      final lumLight = AppColors.surfaceWhite.computeLuminance();
      final lumDark = AppColors.darkForest.computeLuminance();
      final contrast = (lumLight + 0.05) / (lumDark + 0.05);
      expect(contrast, greaterThan(7.0));
    });

    test(
        'white text on deepPine header satisfies WCAG AAA contrast ratio (> 7.0:1)',
        () {
      final lumWhite = Colors.white.computeLuminance();
      final lumDeepPine = AppColors.deepPine.computeLuminance();
      final contrast = (lumWhite + 0.05) / (lumDeepPine + 0.05);
      expect(contrast, greaterThan(7.0));
    });
  });
}

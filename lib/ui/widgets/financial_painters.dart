import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom financial sparkline showing rhythm insights and spending trend.
class FinancialSparklinePainter extends CustomPainter {
  const FinancialSparklinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(size.width * 0.16, size.height * 0.72, size.width * 0.22,
          size.height * 0.85, size.width * 0.34, size.height * 0.45)
      ..cubicTo(size.width * 0.48, size.height * 0.12, size.width * 0.56,
          size.height * 0.62, size.width * 0.70, size.height * 0.28)
      ..cubicTo(size.width * 0.84, size.height * 0.08, size.width * 0.90,
          size.height * 0.48, size.width, size.height * 0.18);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4ADE80).withValues(alpha: 0.38),
          const Color(0xFF4ADE80).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
    canvas.drawCircle(
      Offset(size.width, size.height * 0.18),
      3.5,
      Paint()..color = const Color(0xFF16A34A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circular radial gauge displaying budget remaining percentage.
class RadialGaugePainter extends CustomPainter {
  final double ratio;
  const RadialGaugePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;

    final trackPaint = Paint()
      ..color = const Color(0xFFE2F5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, trackPaint);

    if (ratio > 0) {
      final progressPaint = Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ratio.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadialGaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

/// 4-Category Donut Chart Painter for Campus Dining, Social, Housing, Books.
class CategoryDonutPainter extends CustomPainter {
  final double diningRatio;
  final double socialRatio;
  final double housingRatio;
  final double booksRatio;

  const CategoryDonutPainter({
    required this.diningRatio,
    required this.socialRatio,
    required this.housingRatio,
    required this.booksRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = const Color(0xFFEDF7F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(center, radius, trackPaint);

    final segments = [
      MapEntry(diningRatio, const Color(0xFF16A34A)),
      MapEntry(socialRatio, const Color(0xFF22C55E)),
      MapEntry(housingRatio, const Color(0xFF0284C7)),
      MapEntry(booksRatio, const Color(0xFFD97706)),
    ];

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.key > 0) {
        final sweep = 2 * math.pi * seg.key.clamp(0.0, 1.0);
        final paint = Paint()
          ..color = seg.value
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, startAngle, sweep, false, paint);
        startAngle += sweep;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CategoryDonutPainter oldDelegate) =>
      oldDelegate.diningRatio != diningRatio ||
      oldDelegate.socialRatio != socialRatio ||
      oldDelegate.housingRatio != housingRatio ||
      oldDelegate.booksRatio != booksRatio;
}

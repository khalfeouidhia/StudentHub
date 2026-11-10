import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight custom line-art painter rendering a tilted credit card with
/// a magnetic stripe and EMV chip, gripped and held by a hand.
class HandHoldingCardPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const HandHoldingCardPainter({
    required this.color,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Normalizes coordinate system to 24x24 logical pixels
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final finePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.82
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // --- 1. TILTED CREDIT CARD ---
    canvas.save();
    // Center card at (12.2, 8.2) tilted ~14° counter-clockwise
    canvas.translate(12.2, 8.2);
    canvas.rotate(-14.0 * math.pi / 180.0);

    // Card Body (15.5 x 9.6)
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 15.5, height: 9.6),
      const Radius.circular(1.6),
    );
    canvas.drawRRect(cardRect, strokePaint);

    // Magnetic Stripe across upper section
    canvas.drawLine(
      const Offset(-7.75, -2.0),
      const Offset(7.75, -2.0),
      finePaint,
    );

    // EMV Smart Chip on lower-left
    final chipRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6.0, 0.4, 3.2, 2.4),
      const Radius.circular(0.5),
    );
    canvas.drawRRect(chipRect, finePaint);

    // Chip contact divider line
    canvas.drawLine(
      const Offset(-4.4, 0.4),
      const Offset(-4.4, 2.8),
      finePaint,
    );

    canvas.restore();

    // --- 2. HAND HOLDING & GRIPPING THE CARD ---
    final handPath = Path();

    // Outer wrist / base of thumb on the left
    handPath.moveTo(3.2, 21.5);
    handPath.lineTo(4.0, 18.0);

    // Thumb: reaches up and curls over the front/bottom of the card
    handPath.cubicTo(4.2, 15.5, 5.0, 13.8, 6.8, 13.6);
    handPath.cubicTo(8.0, 13.5, 8.6, 14.4, 8.4, 15.8);

    // Knuckles / fingers curling under and gripping the bottom edge of the card
    handPath.lineTo(10.2, 15.2);
    // Finger ridge 1
    handPath.cubicTo(11.2, 14.8, 12.0, 14.6, 13.0, 14.2);
    // Finger ridge 2
    handPath.cubicTo(14.0, 13.8, 15.2, 13.4, 16.2, 13.0);

    // Palm outer edge dropping down to right wrist
    handPath.cubicTo(17.6, 14.2, 18.2, 16.5, 17.6, 18.8);
    handPath.lineTo(16.5, 21.5);

    canvas.drawPath(handPath, strokePaint);

    // Finger separation accents for depth
    final fingerLine1 = Path()
      ..moveTo(10.6, 15.8)
      ..lineTo(11.4, 17.8);
    canvas.drawPath(fingerLine1, finePaint);

    final fingerLine2 = Path()
      ..moveTo(13.6, 14.8)
      ..lineTo(14.4, 16.8);
    canvas.drawPath(fingerLine2, finePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HandHoldingCardPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Custom line-art vector icon displaying a hand holding a credit card.
/// Inherits dynamic [IconTheme] color (e.g., `selectedItemColor` and
/// `unselectedItemColor` in navigation bars) when [color] is not explicitly set.
class HandHoldingCardIcon extends StatelessWidget {
  final Color? color;
  final double size;
  final double strokeWidth;

  const HandHoldingCardIcon({
    super.key,
    this.color,
    this.size = 24.0,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveColor = color ?? iconTheme.color ?? Colors.white;
    final effectiveSize = size > 0 ? size : (iconTheme.size ?? 24.0);

    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: CustomPaint(
        size: Size(effectiveSize, effectiveSize),
        painter: HandHoldingCardPainter(
          color: effectiveColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';

/// Authentic frosted glassmorphism container with BackdropFilter blur,
/// translucent glass tint, subtle edge highlight border, and soft depth shadow.
class FrostedGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;

  const FrostedGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
    this.borderRadius = 16.0,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ??
                const Color(0xFF1E3A2E)
                    .withOpacity(0.40), // Glass tint over avatar
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ??
                  Colors.white.withOpacity(0.14), // Glass edge highlight
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1F17).withOpacity(0.25),
                blurRadius: 14.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/widgets/frosted_glass_card.dart';

class CompactGlassKpiCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;
  final Color? borderColor;

  const CompactGlassKpiCard({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
    this.borderRadius = 16.0,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: FrostedGlassCard(
        padding: padding,
        borderRadius: borderRadius,
        color: color ??
            Colors.white
                .withOpacity(0.07), // background: rgba(255, 255, 255, 0.07)
        borderColor: borderColor ??
            Colors.white.withOpacity(
                0.14), // border: 1px solid rgba(255, 255, 255, 0.14)
        child: child,
      ),
    );
  }
}

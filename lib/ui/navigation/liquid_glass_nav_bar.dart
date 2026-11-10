import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

export '../widgets/hand_holding_card_icon.dart';
export 'bottom_nav_bar.dart';

/// Navigation item model for the Liquid Glass Bottom Navigation Bar.
class GlassNavItem {
  final IconData? icon;
  final IconData? activeIcon;
  final Widget Function(BuildContext context, Color color, bool isActive)?
      customWidgetBuilder;
  final Widget? customWidget;
  final String label;

  const GlassNavItem({
    this.icon,
    this.activeIcon,
    this.customWidgetBuilder,
    this.customWidget,
    required this.label,
  });
}

/// Floating Liquid Glass Bottom Dock adapted to the two-tone curved palette (#C7CBB8 / #F9FAF7).
/// Features backdrop frosted glass blur (sigma 24), specular border,
/// circular active tab highlight (#1E3A2E), and white active icon.
///
/// In 5-tab mode ([items.length == 5]), the navigation bar renders 5 evenly-spaced
/// expanded tabs across the entire glass dock with zero RenderFlex overflow on
/// micro-viewports (down to 280dp) and extreme font scaling (up to 3.0x), and omits
/// the floating center orb so all 5 tabs remain 100% unobstructed.
/// When [items.length == 4] or null, it retains backward compatibility with
/// the 44px center gap and floating action orb.
class LiquidGlassBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem>? items;
  final VoidCallback? onCenterActionPressed;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;

  const LiquidGlassBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items,
    this.onCenterActionPressed,
    this.selectedItemColor,
    this.unselectedItemColor,
  });

  @override
  State<LiquidGlassBottomNavBar> createState() =>
      _LiquidGlassBottomNavBarState();
}

class _LiquidGlassBottomNavBarState extends State<LiquidGlassBottomNavBar> {
  Widget _navItemIcon(
    int index,
    IconData fallbackIcon,
    Color color,
    bool active, {
    required bool isCompact,
  }) {
    final list = widget.items;
    if (list != null && index < list.length) {
      final item = list[index];
      if (item.customWidgetBuilder != null) {
        return item.customWidgetBuilder!(context, color, active);
      }
      if (item.customWidget != null) {
        return item.customWidget!;
      }
    }
    return Icon(
      fallbackIcon,
      color: color,
      size: isCompact ? 19 : 21,
    );
  }

  Widget _animatedNavItem(
    int index,
    IconData icon,
    String label, {
    bool isCompact = false,
  }) {
    final active = widget.currentIndex == index;
    final activeColor = widget.selectedItemColor ?? AppColors.surfaceWhite;
    final inactiveColor = widget.unselectedItemColor ?? AppColors.softSage;
    final itemColor = active ? activeColor : inactiveColor;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  width: isCompact ? 36 : 40,
                  height: isCompact ? 36 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? AppColors.deepPine : Colors.transparent,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.deepPine.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedScale(
                      scale: active ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: IconTheme(
                        data: IconThemeData(
                          color: itemColor,
                          size: 24.0,
                        ),
                        child: _navItemIcon(
                          index,
                          icon,
                          itemColor,
                          active,
                          isCompact: isCompact,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: isCompact ? 9.5 : 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.darkForest : AppColors.softSage,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _navIcon(int index, IconData fallback) {
    final list = widget.items;
    if (list != null && index < list.length) {
      final item = list[index];
      if (widget.currentIndex == index && item.activeIcon != null) {
        return item.activeIcon!;
      }
      if (item.icon != null) {
        return item.icon!;
      }
    }
    return fallback;
  }

  String _navLabel(int index, String fallback) {
    final list = widget.items;
    if (list != null && index < list.length) {
      return list[index].label;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isFiveTabs = widget.items != null && widget.items!.length == 5;
    final horizontalMargin = isFiveTabs && screenWidth < 340 ? 8.0 : 14.0;
    final containerPadding = isFiveTabs && screenWidth < 340 ? 4.0 : 8.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset > 0 ? bottomInset : 8,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 12),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      height: 74,
                      padding:
                          EdgeInsets.symmetric(horizontal: containerPadding),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surfaceWhite.withValues(alpha: 0.90),
                            AppColors.sandCream.withValues(alpha: 0.78),
                            AppColors.surfaceWhite.withValues(alpha: 0.92),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkForest.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: -2,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: isFiveTabs
                            ? List.generate(
                                widget.items!.length,
                                (index) => Expanded(
                                  child: _animatedNavItem(
                                    index,
                                    _navIcon(index, Icons.circle_outlined),
                                    _navLabel(index, 'Tab ${index + 1}'),
                                    isCompact: true,
                                  ),
                                ),
                              )
                            : [
                                Expanded(
                                    child: _animatedNavItem(
                                        0,
                                        _navIcon(0, Icons.home_filled),
                                        _navLabel(0, 'Dashboard'))),
                                Expanded(
                                    child: _animatedNavItem(
                                        1,
                                        _navIcon(1, Icons.credit_card_outlined),
                                        _navLabel(1, 'Expenses'))),
                                const SizedBox(width: 44),
                                Expanded(
                                    child: _animatedNavItem(
                                        2,
                                        _navIcon(
                                            2, Icons.calendar_today_outlined),
                                        _navLabel(2, 'Study Tasks'))),
                                Expanded(
                                    child: _animatedNavItem(
                                        3,
                                        _navIcon(
                                            3, Icons.calendar_month_outlined),
                                        _navLabel(3, 'Calendar'))),
                              ],
                      ),
                    ),
                  ),
                ),
                if (!isFiveTabs)
                  Positioned(
                    top: -18,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onCenterActionPressed?.call();
                      },
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey<int>(widget.currentIndex),
                        tween: Tween(begin: 0.90, end: 1.0),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.2, -0.3),
                              colors: [Color(0xFF68F291), Color(0xFF16A34A)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.48),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.currentIndex == 2
                                ? Icons.add_task_rounded
                                : Icons.qr_code_scanner_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

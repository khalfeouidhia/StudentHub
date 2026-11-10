import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/hand_holding_card_icon.dart';

export '../widgets/hand_holding_card_icon.dart';

/// Standard Flutter [BottomNavigationBar] implementation for StudentHub,
/// featuring the custom line-art [HandHoldingCardIcon] for the Expenses tab.
class StudentBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color selectedItemColor;
  final Color unselectedItemColor;
  final Color backgroundColor;

  const StudentBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.selectedItemColor = AppColors.surfaceWhite,
    this.unselectedItemColor = AppColors.softSage,
    this.backgroundColor = const Color(0xFF071F18),
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: selectedItemColor,
      unselectedItemColor: unselectedItemColor,
      backgroundColor: backgroundColor,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 11,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined, size: 24),
          activeIcon: Icon(Icons.home_rounded, size: 24),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: HandHoldingCardIcon(size: 24),
          activeIcon: HandHoldingCardIcon(size: 24),
          label: 'Expenses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined, size: 24),
          activeIcon: Icon(Icons.calendar_month_rounded, size: 24),
          label: 'Calendar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.checklist_rtl_outlined, size: 24),
          activeIcon: Icon(Icons.checklist_rtl_rounded, size: 24),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_outlined, size: 24),
          activeIcon: Icon(Icons.restaurant_rounded, size: 24),
          label: 'Resto U',
        ),
      ],
    );
  }
}

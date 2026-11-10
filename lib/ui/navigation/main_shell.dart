import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/campus_resto/ui/views/resto_u_view.dart';
import '../views/home_view.dart';
import '../views/expenses_view.dart';
import '../views/calendar_view.dart';
import '../views/tasks_view.dart';
import 'liquid_glass_nav_bar.dart';

import '../sheets/payly_sheets.dart';

export 'liquid_glass_nav_bar.dart';

/// Navigation shell hosting 5 primary tabs for the student app:
/// [0: Home, 1: Expenses, 2: Calendar, 3: Tasks, 4: Resto U]
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  static MainShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _currentIndex;

  static final List<GlassNavItem> _navItems = [
    const GlassNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    GlassNavItem(
      icon: Icons.credit_card_outlined,
      activeIcon: Icons.credit_card,
      customWidgetBuilder: (context, color, isActive) => HandHoldingCardIcon(
        color: color,
        size: 24,
      ),
      label: 'Expenses',
    ),
    const GlassNavItem(
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
      label: 'Calendar',
    ),
    const GlassNavItem(
      icon: Icons.checklist_rtl_outlined,
      activeIcon: Icons.checklist_rtl_rounded,
      label: 'Tasks',
    ),
    const GlassNavItem(
      icon: Icons.restaurant_outlined,
      activeIcon: Icons.restaurant_rounded,
      label: 'Resto U',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    if (index >= 0 && index < _navItems.length) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onCenterAction() {
    HapticFeedback.mediumImpact();
    if (_currentIndex == 3) {
      PaylySheets.openTaskSheet(context);
    } else {
      PaylySheets.openSpendSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF071F18),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: const [
              HomeView(),
              ExpensesView(),
              CalendarScreen(),
              TasksView(),
              RestoUView(),
            ],
          ),
          LiquidGlassBottomNavBar(
            currentIndex: _currentIndex,
            onTap: switchTab,
            items: _navItems,
            onCenterActionPressed: _onCenterAction,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import '../widgets/floating_nav_bar.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';

/// Contenedor principal: barra flotante en móvil, riel lateral en pantallas anchas.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<NavItem> _items = [
    NavItem(label: AppStrings.navHome, icon: Icons.home_outlined, activeIcon: Icons.home),
    NavItem(
      label: AppStrings.navReport,
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle,
    ),
    NavItem(
      label: AppStrings.navAlerts,
      icon: Icons.notifications_none,
      activeIcon: Icons.notifications,
    ),
  ];

  int _index = 0;

  late final List<Widget> _pages = [
    HomeScreen(onReportTap: () => _go(1)),
    const ReportScreen(),
    const AlertsScreen(),
  ];

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // IndexedStack conserva el estado de cada pestaña (formulario, mapa).
    final body = IndexedStack(index: _index, children: _pages);

    if (Responsive.isExpanded(context)) {
      final palette = AppPalette.of(context);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _go,
              backgroundColor: palette.card,
              indicatorColor: palette.pale,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in _items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon, color: AppColors.blue),
                    label: Text(item.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: palette.line),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: body),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FloatingNavBar(
                  items: _items,
                  currentIndex: _index,
                  onTap: _go,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

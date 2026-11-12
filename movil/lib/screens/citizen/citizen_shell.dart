import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../widgets/floating_nav_bar.dart';
import '../shared/nav_shell.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';

/// Vista del ciudadano: Inicio (mapa), Reportar y Alertas.
class CitizenShell extends StatelessWidget {
  const CitizenShell({super.key});

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

  @override
  Widget build(BuildContext context) {
    return NavShell(
      items: _items,
      pagesBuilder: (goTo) => [
        HomeScreen(onReportTap: () => goTo(1)),
        const ReportScreen(),
        const AlertsScreen(),
      ],
    );
  }
}

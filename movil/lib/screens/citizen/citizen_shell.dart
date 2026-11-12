import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/di/app_dependencies.dart';
import '../../widgets/floating_nav_bar.dart';
import '../../services/push_service.dart';
import '../shared/nav_shell.dart';
import 'alerts_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';

/// Vista del ciudadano: Inicio (mapa), Reportar y Alertas.
class CitizenShell extends StatefulWidget {
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
  State<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends State<CitizenShell> {
  static const int _alertsTab = 2;

  StreamSubscription<PushTap>? _tapSub;
  StreamSubscription<void>? _incomingSub;
  ValueChanged<int>? _goTo;

  @override
  void initState() {
    super.initState();
    final push = AppDependencies.pushService;
    // Tocar una alerta abre la pestaña Alertas (ya recargada); un push con la
    // app abierta solo refresca las listas.
    _tapSub = push.taps.listen((_) {
      AppDependencies.dataRefresh.notifyChanged();
      _goTo?.call(_alertsTab);
    });
    _incomingSub = push.incoming.listen((_) => AppDependencies.dataRefresh.notifyChanged());
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      items: CitizenShell._items,
      pagesBuilder: (goTo) {
        _goTo = goTo;
        return [
          HomeScreen(onReportTap: () => goTo(1)),
          const ReportScreen(),
          const AlertsScreen(),
        ];
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/floating_nav_bar.dart';

/// Contenedor de navegación reutilizable: barra flotante en móvil y riel
/// lateral en pantallas anchas.
class NavShell extends StatefulWidget {
  const NavShell({super.key, required this.items, required this.pagesBuilder});

  final List<NavItem> items;

  /// Construye las pestañas. Recibe una función para saltar a otra pestaña.
  final List<Widget> Function(ValueChanged<int> goTo) pagesBuilder;

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell> {
  int _index = 0;

  late final List<Widget> _pages = widget.pagesBuilder(_go);

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // IndexedStack conserva el estado de cada pestaña.
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
                for (final item in widget.items)
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
                  items: widget.items,
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

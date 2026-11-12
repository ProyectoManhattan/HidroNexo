import 'package:flutter/material.dart';

import '../constants/app_config.dart';

/// Utilidades para adaptar la interfaz al tamaño de pantalla.
class Responsive {
  Responsive._();

  /// true en tablet horizontal / escritorio / web ancha.
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConfig.expandedBreakpoint;

  /// Espacio inferior para no tapar contenido con la barra flotante.
  static double bottomInset(BuildContext context) =>
      isExpanded(context) ? 24 : 104;

  /// Alto del mapa proporcional a la pantalla.
  static double mapHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return (height * 0.42).clamp(260.0, 520.0).toDouble();
  }
}

/// Centra el contenido y limita su ancho máximo en pantallas grandes.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = AppConfig.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

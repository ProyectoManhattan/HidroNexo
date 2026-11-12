import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';

/// Estructura común de pantalla: encabezado + contenido desplazable
/// centrado con ancho máximo.
class PageLayout extends StatelessWidget {
  const PageLayout({super.key, required this.header, required this.children});

  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          header,
          ResponsiveBody(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                Responsive.bottomInset(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

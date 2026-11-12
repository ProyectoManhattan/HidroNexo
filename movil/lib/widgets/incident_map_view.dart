import 'package:flutter/material.dart';

import '../core/di/app_dependencies.dart';
import '../models/incident_report.dart';

/// Contenedor del mapa: delega el dibujo al MapProvider registrado.
class IncidentMapView extends StatelessWidget {
  const IncidentMapView({
    super.key,
    required this.reports,
    required this.onReportTap,
    required this.height,
    this.overlay,
  });

  final List<IncidentReport> reports;
  final ValueChanged<IncidentReport> onReportTap;
  final double height;

  /// Widget opcional sobre el mapa (por ejemplo, el botón Reportar).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: AppDependencies.mapProvider.build(
                context,
                reports: reports,
                onReportTap: onReportTap,
              ),
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

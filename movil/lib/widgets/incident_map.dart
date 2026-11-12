import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/app_config.dart';
import '../models/incident_report.dart';

/// Mapa de Google Maps con un marcador por reporte.
class IncidentMap extends StatelessWidget {
  const IncidentMap({
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

  Set<Marker> _buildMarkers() {
    return reports
        .map(
          (report) => Marker(
            markerId: MarkerId(report.folio),
            position: report.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(report.type.markerHue),
            onTap: () => onReportTap(report),
          ),
        )
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: AppConfig.mapCenter,
                zoom: AppConfig.mapZoom,
              ),
              markers: _buildMarkers(),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              // Permite mover el mapa dentro de una lista desplazable.
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
            ),
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }
}

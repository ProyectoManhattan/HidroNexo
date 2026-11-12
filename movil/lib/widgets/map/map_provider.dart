import 'package:flutter/material.dart';

import '../../models/incident_report.dart';

/// Contrato del mapa. Implementaciones: [MaplibreMapProvider] (real, con el
/// riesgo por zona del backend) y [PlaceholderMapProvider] (demo sin red).
/// [riskZones] es el GeoJSON de `GET /zones/risk`, o null si aún no carga.
abstract class MapProvider {
  const MapProvider();

  Widget build(
    BuildContext context, {
    required List<IncidentReport> reports,
    required ValueChanged<IncidentReport> onReportTap,
    Map<String, dynamic>? riskZones,
  });
}

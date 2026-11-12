import 'package:flutter/material.dart';

import '../../models/incident_report.dart';

/// PUNTO DE INTEGRACIÓN DEL MAPA (BACKEND).
///
/// La app no depende de ningún paquete de mapas. Para poner el mapa real:
///   1. Crea una clase que extienda [MapProvider] y devuelva tu widget de mapa
///      (por ejemplo GoogleMap) en [build], pintando un marcador por reporte
///      y llamando a [onReportTap] al tocarlo.
///   2. Asígnala en AppDependencies.mapProvider.
/// Ninguna pantalla necesita cambios.
abstract class MapProvider {
  const MapProvider();

  Widget build(
    BuildContext context, {
    required List<IncidentReport> reports,
    required ValueChanged<IncidentReport> onReportTap,
  });
}

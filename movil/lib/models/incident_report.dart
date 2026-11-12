import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'report_status.dart';
import 'report_type.dart';

/// Reporte ciudadano que se muestra en el mapa.
class IncidentReport {
  const IncidentReport({
    required this.folio,
    required this.type,
    required this.place,
    required this.description,
    required this.dateLabel,
    required this.status,
    required this.position,
  });

  final String folio;
  final ReportType type;
  final String place;
  final String description;
  final String dateLabel;
  final ReportStatus status;
  final LatLng position;
}

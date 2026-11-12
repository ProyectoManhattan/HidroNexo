import 'coordinates.dart';
import 'report_status.dart';
import 'report_type.dart';

/// Reporte ciudadano que se muestra en el mapa y en las alertas.
class IncidentReport {
  const IncidentReport({
    required this.folio,
    required this.type,
    required this.neighborhood,
    required this.address,
    required this.description,
    required this.dateLabel,
    required this.status,
    required this.position,
    this.photoUrl,
  });

  final String folio;
  final ReportType type;
  final String neighborhood;
  final String address;
  final String description;
  final String dateLabel;
  final ReportStatus status;
  final Coordinates position;

  /// BACKEND: URL de la foto del reporte (opcional).
  final String? photoUrl;

}

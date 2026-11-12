import 'coordinates.dart';
import 'report_type.dart';

/// Datos capturados en el formulario antes de enviarse.
class NewReport {
  const NewReport({
    required this.type,
    required this.neighborhood,
    required this.address,
    required this.position,
    required this.description,
    required this.severity,
    this.photoUrl,
  });

  final ReportType type;
  final String neighborhood;
  final String address;
  final Coordinates position;
  final String description;

  /// 1 = baja, 2 = media, 3 = alta (lo que espera la API).
  final int severity;

  /// URL de la foto ya subida (`POST /reports/photo`), si hay.
  final String? photoUrl;
}

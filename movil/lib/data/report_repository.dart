import '../models/alert_item.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';

/// Falla al hablar con el backend (red, tiempo de espera o respuesta inválida).
/// [message] se puede mostrar al ciudadano.
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Contrato de acceso a datos. Todas las operaciones son asíncronas y
/// lanzan [RepositoryException] si fallan.
abstract class ReportRepository {
  /// Reportes visibles en el mapa.
  Future<List<IncidentReport>> getMapReports();

  /// Alertas oficiales vigentes (aprobadas por Protección Civil).
  Future<List<AlertItem>> getCurrentAlerts();

  /// Reportes ya atendidos.
  Future<List<AlertItem>> getAlertHistory();

  /// Busca un reporte por su folio (por ejemplo `AV-15`). Null si no existe.
  Future<IncidentReport?> findByFolio(String folio);

  /// Riesgo por zona en GeoJSON (`FeatureCollection`). Vacío si no hay datos.
  Future<Map<String, dynamic>> getRiskZones();

  /// Envía un reporte y devuelve su folio.
  Future<String> submit(NewReport report);

  /// Registra (o actualiza) el token de notificaciones push de este
  /// dispositivo junto con su ubicación aproximada.
  Future<void> registerDevice({
    required String token,
    required double lat,
    required double lon,
  });
}

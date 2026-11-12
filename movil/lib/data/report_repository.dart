import '../models/active_alert.dart';
import '../models/alert_item.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../services/photo_service.dart';

/// Falla al hablar con el backend (red, tiempo de espera o respuesta inválida).
/// [message] se puede mostrar al ciudadano.
class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.retryable = false});

  final String message;

  /// true si es un fallo de red, de tiempo de espera o un 5xx: reintentar más
  /// tarde puede funcionar. false para 4xx de validación y respuestas inválidas.
  final bool retryable;

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

  /// Alertas vigentes de la colonia que contiene el punto (`lat`, `lon`),
  /// con su guía de acción. Lista vacía si el punto no cae en ninguna colonia.
  Future<List<ActiveAlert>> getActiveAlertsAt({required double lat, required double lon});

  /// Reportes ya atendidos.
  Future<List<AlertItem>> getAlertHistory();

  /// Busca un reporte por su folio (por ejemplo `AV-15`). Null si no existe.
  Future<IncidentReport?> findByFolio(String folio);

  /// Riesgo por zona en GeoJSON (`FeatureCollection`). Vacío si no hay datos.
  Future<Map<String, dynamic>> getRiskZones();

  /// Sube una foto y devuelve su URL pública (para `NewReport.photoUrl`).
  Future<String> uploadPhoto(PickedPhoto photo);

  /// Envía un reporte y devuelve su folio.
  Future<String> submit(NewReport report);

  /// Petición ligera (`GET /health`) para saber si la API responde antes de
  /// subir una foto. Lanza [RepositoryException] si no responde.
  Future<void> checkHealth();

  /// Si los datos del mapa (reportes/zonas) salieron de la caché local, desde
  /// cuándo se guardaron; null si son recientes.
  DateTime? get mapStaleSince;

  /// Ídem para las alertas de [getCurrentAlerts].
  DateTime? get alertsStaleSince;

  /// Registra (o actualiza) el token de notificaciones push de este
  /// dispositivo junto con su ubicación aproximada.
  Future<void> registerDevice({
    required String token,
    required double lat,
    required double lon,
  });
}

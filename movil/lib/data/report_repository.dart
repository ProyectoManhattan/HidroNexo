import '../models/alert_item.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';

/// Contrato de acceso a datos. Implementa esta clase para conectar
/// una API o base de datos real.
abstract class ReportRepository {
  List<IncidentReport> getMapReports();
  List<AlertItem> getCurrentAlerts();
  List<AlertItem> getAlertHistory();
  IncidentReport? findByFolio(String folio);

  /// Envía un reporte y devuelve su folio.
  Future<String> submit(NewReport report);
}

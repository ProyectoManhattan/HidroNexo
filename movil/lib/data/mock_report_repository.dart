import '../core/constants/app_strings.dart';
import '../models/alert_item.dart';
import '../models/coordinates.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_status.dart';
import '../models/report_type.dart';
import 'report_repository.dart';

/// Datos de ejemplo en memoria. Las coordenadas son aproximadas.
class MockReportRepository implements ReportRepository {
  List<IncidentReport> _reports = const [
    IncidentReport(
      folio: 'AV-001',
      type: ReportType.leak,
      neighborhood: 'Col. Centro',
      address: 'Av. Independencia, esquina con Juárez',
      description: 'Fuga de agua visible en la vía pública. El agua corre hacia la calle.',
      dateLabel: '11 nov 2026',
      status: ReportStatus.pending,
      position: Coordinates(19.1925, -96.1385),
    ),
    IncidentReport(
      folio: 'AV-002',
      type: ReportType.flood,
      neighborhood: 'Col. Reforma',
      address: 'Calle 5 de Mayo #124',
      description: 'Acumulación de agua en la calle que dificulta el paso de vehículos.',
      dateLabel: '11 nov 2026',
      status: ReportStatus.pending,
      position: Coordinates(19.1898, -96.1318),
    ),
    IncidentReport(
      folio: 'AV-003',
      type: ReportType.drain,
      neighborhood: 'Col. Zaragoza',
      address: 'Calle Morelos, frente al parque',
      description: 'Alcantarilla obstruida por residuos y basura.',
      dateLabel: '10 nov 2026',
      status: ReportStatus.accepted,
      position: Coordinates(19.1872, -96.1352),
    ),
    IncidentReport(
      folio: 'AV-004',
      type: ReportType.leak,
      neighborhood: 'Col. Las Brisas',
      address: 'Calle del Mar #32',
      description: 'Se reporta humedad en la banqueta.',
      dateLabel: '10 nov 2026',
      status: ReportStatus.declined,
      position: Coordinates(19.1850, -96.1300),
    ),
    IncidentReport(
      folio: 'AV-005',
      type: ReportType.flood,
      neighborhood: 'Col. Flores Magón',
      address: 'Av. Xalapa, esquina con Abasolo',
      description: 'Encharcamiento considerable después de la lluvia.',
      dateLabel: '09 nov 2026',
      status: ReportStatus.pending,
      position: Coordinates(19.1940, -96.1300),
    ),
    IncidentReport(
      folio: 'AV-006',
      type: ReportType.drain,
      neighborhood: 'Col. Pocitos y Rivera',
      address: 'Calle 8, entre 3 y 5',
      description: 'Registro sin tapa en la vía pública.',
      dateLabel: '09 nov 2026',
      status: ReportStatus.attended,
      position: Coordinates(19.1850, -96.1400),
    ),
    IncidentReport(
      folio: 'AV-007',
      type: ReportType.leak,
      neighborhood: 'Col. Centro',
      address: 'Av. Díaz Mirón',
      description: 'Servicio restablecido tras reparar la tubería.',
      dateLabel: '08 nov 2026',
      status: ReportStatus.attended,
      position: Coordinates(19.1910, -96.1350),
    ),
    IncidentReport(
      folio: 'AV-008',
      type: ReportType.flood,
      neighborhood: 'Col. Centro',
      address: 'Calle Lerdo, esquina con Madero',
      description: 'Encharcamiento controlado después de la lluvia.',
      dateLabel: '07 nov 2026',
      status: ReportStatus.attended,
      position: Coordinates(19.1880, -96.1370),
    ),
  ];

  @override
  Future<List<IncidentReport>> getMapReports() async => List.unmodifiable(
        _reports.where((r) => r.status != ReportStatus.declined),
      );

  @override
  Future<Map<String, dynamic>> getRiskZones() async =>
      {'type': 'FeatureCollection', 'features': <dynamic>[]};

  @override
  Future<List<AlertItem>> getCurrentAlerts() async {
    return _reports
        .where((r) =>
            r.status == ReportStatus.pending || r.status == ReportStatus.accepted)
        .map(
          (r) => AlertItem(
            title: r.type.alertTitle,
            detail: '${r.address} · ${r.description}',
            meta: '${r.dateLabel} · ${r.folio}',
            type: r.type,
            status: r.status,
            recommendations: r.type.tips,
          ),
        )
        .toList();
  }

  @override
  Future<List<AlertItem>> getAlertHistory() async {
    return _reports
        .where((r) => r.status == ReportStatus.attended)
        .map(
          (r) => AlertItem(
            title: '${r.type.label} atendida',
            detail: '${r.address} · ${r.description}',
            meta: '${r.dateLabel} · ${r.folio}',
            type: r.type,
            status: r.status,
          ),
        )
        .toList();
  }

  @override
  Future<IncidentReport?> findByFolio(String folio) async {
    final normalized = folio.trim().toUpperCase();
    for (final report in _reports) {
      if (report.folio == normalized) return report;
    }
    return null;
  }

  @override
  Future<String> submit(NewReport report) async {
    final folio = 'AV-${(_reports.length + 1).toString().padLeft(3, '0')}';
    _reports = [
      IncidentReport(
        folio: folio,
        type: report.type,
        neighborhood: report.neighborhood,
        address: report.address,
        description: report.description,
        dateLabel: AppStrings.today,
        status: ReportStatus.pending,
        position: report.position,
      ),
      ..._reports,
    ];
    return folio;
  }
}

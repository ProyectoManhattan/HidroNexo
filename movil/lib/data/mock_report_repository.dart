import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/app_strings.dart';
import '../models/alert_item.dart';
import '../models/incident_report.dart';
import '../models/new_report.dart';
import '../models/report_status.dart';
import '../models/report_type.dart';
import 'report_repository.dart';

/// Datos de ejemplo en memoria. Las coordenadas son aproximadas.
class MockReportRepository implements ReportRepository {
  final List<IncidentReport> _reports = [
    const IncidentReport(
      folio: 'AV-0241',
      type: ReportType.flood,
      place: 'Av. Independencia',
      description: 'Agua acumulada en la vialidad.',
      dateLabel: 'Hace 18 min',
      status: ReportStatus.confirmed,
      position: LatLng(19.1925, -96.1385),
    ),
    const IncidentReport(
      folio: 'AV-0240',
      type: ReportType.leak,
      place: 'Calle 5 de Mayo',
      description: 'Salida constante de agua.',
      dateLabel: 'Hace 42 min',
      status: ReportStatus.received,
      position: LatLng(19.1898, -96.1318),
    ),
    const IncidentReport(
      folio: 'AV-0239',
      type: ReportType.drain,
      place: 'Callejón del Parque',
      description: 'Alcantarilla obstruida.',
      dateLabel: 'Hace 1 h',
      status: ReportStatus.inReview,
      position: LatLng(19.1872, -96.1352),
    ),
  ];

  final Random _random = Random();

  @override
  List<IncidentReport> getMapReports() => List.unmodifiable(_reports);

  @override
  List<AlertItem> getCurrentAlerts() => const [
        AlertItem(
          title: 'Posible inundación',
          detail: 'Av. Independencia · Agua acumulada.',
          meta: 'Hoy 09:23 · AV-0241',
          type: ReportType.flood,
          status: ReportStatus.confirmed,
          recommendations: [
            'Evita cruzar calles con agua acumulada.',
            'Sube documentos y objetos de valor a un lugar alto.',
            'Si el agua entra a tu casa, corta la luz desde el interruptor general.',
          ],
        ),
        AlertItem(
          title: 'Fuga de agua',
          detail: 'Calle 5 de Mayo · Salida de agua.',
          meta: 'Hoy 08:58 · AV-0240',
          type: ReportType.leak,
          status: ReportStatus.received,
          recommendations: [
            'Aléjate de cables y postes cercanos.',
            'Guarda agua para beber y cocinar por si se corta el servicio.',
            'Ya fue reportada: no necesitas reportarla de nuevo.',
          ],
        ),
      ];

  @override
  List<AlertItem> getAlertHistory() => const [
        AlertItem(
          title: 'Fuga atendida',
          detail: 'Av. Díaz Mirón · Servicio restablecido.',
          meta: 'Ayer · AV-0237',
          type: ReportType.leak,
          status: ReportStatus.attended,
        ),
        AlertItem(
          title: 'Alcantarilla obstruida',
          detail: 'Callejón del Parque · Se retiraron residuos.',
          meta: '10 nov · AV-0228',
          type: ReportType.drain,
          status: ReportStatus.attended,
        ),
        AlertItem(
          title: 'Encharcamiento',
          detail: 'Col. Centro · Reporte cerrado.',
          meta: '08 nov · AV-0219',
          type: ReportType.flood,
          status: ReportStatus.closed,
        ),
      ];

  @override
  IncidentReport? findByFolio(String folio) {
    final normalized = folio.trim().toUpperCase();
    for (final report in _reports) {
      if (report.folio == normalized) return report;
    }
    return null;
  }

  @override
  Future<String> submit(NewReport report) async {
    final folio = 'AV-${1000 + _random.nextInt(9000)}';
    _reports.add(
      IncidentReport(
        folio: folio,
        type: report.type,
        place: report.placeLabel,
        description: report.description,
        dateLabel: AppStrings.now,
        status: ReportStatus.received,
        position: report.position,
      ),
    );
    return folio;
  }
}

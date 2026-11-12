import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../data/report_repository.dart';
import '../models/incident_report.dart';
import '../models/report_type.dart';

/// Estado de la pantalla de inicio: filtro del mapa y zona.
class HomeController extends ChangeNotifier {
  HomeController(ReportRepository repository)
      : _reports = repository.getMapReports();

  final List<IncidentReport> _reports;

  ReportType? _filter;
  String _zoneLabel = AppConfig.zoneFull;

  ReportType? get filter => _filter;
  String get zoneLabel => _zoneLabel;

  List<IncidentReport> get visibleReports => _filter == null
      ? _reports
      : _reports.where((r) => r.type == _filter).toList();

  void setFilter(ReportType? type) {
    _filter = type;
    notifyListeners();
  }

  void updateZone(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _zoneLabel = text;
    notifyListeners();
  }
}

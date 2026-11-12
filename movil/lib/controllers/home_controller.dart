import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../data/report_repository.dart';
import '../models/incident_report.dart';
import '../models/report_type.dart';

/// Estado de la pantalla de inicio: reportes del mapa, filtro y zona.
class HomeController extends ChangeNotifier {
  HomeController(this._repository);

  final ReportRepository _repository;

  List<IncidentReport> _reports = const [];
  Map<String, dynamic>? _riskZones;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  ReportType? _filter;
  String _zoneLabel = AppConfig.zoneFull;

  /// GeoJSON de riesgo por zona (null si aún no carga o falló).
  Map<String, dynamic>? get riskZones => _riskZones;

  bool get loading => _loading;

  /// Mensaje de error de la última carga, o null si salió bien.
  String? get error => _error;
  ReportType? get filter => _filter;
  String get zoneLabel => _zoneLabel;

  List<IncidentReport> get visibleReports => _filter == null
      ? _reports
      : _reports.where((r) => r.type == _filter).toList();

  /// Carga (o recarga) los reportes. Conserva los anteriores si falla.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _repository.getMapReports(),
        // El riesgo es complementario: si falla, el mapa sigue con los reportes.
        _repository.getRiskZones().then<Object?>((z) => z).catchError((_) => _riskZones),
      ]);
      _reports = results[0] as List<IncidentReport>;
      _riskZones = results[1] as Map<String, dynamic>?;
    } on RepositoryException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

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

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

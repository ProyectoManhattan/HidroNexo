import 'package:flutter/foundation.dart';

import '../data/report_repository.dart';
import '../models/alert_item.dart';

/// Estado de la pantalla de alertas (pestaña Actuales / Historial).
class AlertsController extends ChangeNotifier {
  AlertsController(this._repository);

  final ReportRepository _repository;

  List<AlertItem> current = const [];
  List<AlertItem> history = const [];

  bool _showHistory = false;
  bool _loading = false;
  String? _error;
  bool _disposed = false;

  bool get showHistory => _showHistory;
  bool get loading => _loading;
  String? get error => _error;
  List<AlertItem> get visibleAlerts => _showHistory ? history : current;

  /// Carga (o recarga) alertas actuales e historial. Conserva lo anterior si falla.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getCurrentAlerts(),
        _repository.getAlertHistory(),
      ]);
      current = results[0];
      history = results[1];
    } on RepositoryException catch (e) {
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  void setShowHistory(bool value) {
    if (_showHistory == value) return;
    _showHistory = value;
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

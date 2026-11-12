import 'package:flutter/foundation.dart';

import '../data/report_repository.dart';
import '../models/alert_item.dart';

/// Estado de la pantalla de alertas (pestaña Actuales / Historial).
class AlertsController extends ChangeNotifier {
  AlertsController(ReportRepository repository)
      : current = repository.getCurrentAlerts(),
        history = repository.getAlertHistory();

  final List<AlertItem> current;
  final List<AlertItem> history;

  bool _showHistory = false;

  bool get showHistory => _showHistory;
  List<AlertItem> get visibleAlerts => _showHistory ? history : current;

  void setShowHistory(bool value) {
    if (_showHistory == value) return;
    _showHistory = value;
    notifyListeners();
  }
}

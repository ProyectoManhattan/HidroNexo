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

  /// Si las alertas vienen de la caché local, desde cuándo se guardaron.
  DateTime? get staleSince => _staleSince;
  DateTime? _staleSince;

  bool get showHistory => _showHistory;
  bool get loading => _loading;
  String? get error => _error;
  List<AlertItem> get visibleAlerts => _showHistory ? history : current;

  /// Carga (o recarga) alertas actuales e historial. Conserva lo anterior si falla.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    // Las actuales pueden salir de la caché local (sin conexión); el historial,
    // si falla, solo se omite mientras haya algo que mostrar.
    final results = await Future.wait<Object?>([
      _repository.getCurrentAlerts().then<Object?>((v) => v).catchError((Object e) => e),
      _repository.getAlertHistory().then<Object?>((v) => v).catchError((Object e) => e),
    ]);
    final cur = results[0], hist = results[1];
    if (cur is List<AlertItem>) {
      current = cur;
      _staleSince = _repository.alertsStaleSince;
      if (hist is List<AlertItem>) history = hist;
    } else if (cur is RepositoryException) {
      _error = cur.message;
    } else if (cur is Object) {
      _error = 'Respuesta inesperada del servidor.';
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

import 'report_status.dart';
import 'report_type.dart';

/// Aviso de la pestaña Alertas (actual o histórico).
class AlertItem {
  const AlertItem({
    required this.title,
    required this.detail,
    required this.meta,
    required this.type,
    required this.status,
    this.recommendations = const [],
  });

  final String title;
  final String detail;
  final String meta;
  final ReportType type;
  final ReportStatus status;

  /// Lista de "Qué hacer". Vacía en el historial.
  final List<String> recommendations;
}

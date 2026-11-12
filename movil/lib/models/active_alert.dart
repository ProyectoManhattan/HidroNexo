import 'report_type.dart';

/// Nivel de riesgo de una alerta oficial, de menor a mayor gravedad.
enum AlertLevel {
  bajo('bajo', 'Bajo', 0),
  medio('medio', 'Medio', 1),
  alto('alto', 'Alto', 2),
  critico('critico', 'Crítico', 3);

  const AlertLevel(this.apiKey, this.label, this.severity);

  final String apiKey;
  final String label;

  /// Mayor número = más grave.
  final int severity;

  /// Nivel desconocido se trata como medio (no se subestima ni se exagera).
  static AlertLevel fromApi(String? key) =>
      AlertLevel.values.firstWhere((l) => l.apiKey == key, orElse: () => AlertLevel.medio);
}

/// Alerta aprobada y vigente de la zona del usuario, con su guía de acción.
class ActiveAlert {
  const ActiveAlert({
    required this.id,
    required this.type,
    required this.level,
    required this.text,
    this.zoneName,
    this.motivo = '',
    this.simulated = false,
    this.approvedAt,
    this.guideTitle,
    this.steps = const [],
  });

  final int id;
  final ReportType type;
  final AlertLevel level;
  final String text;

  /// Nombre de la colonia, si se conoce.
  final String? zoneName;
  final String motivo;
  final bool simulated;
  final DateTime? approvedAt;

  /// Guía de acción (null/vacía si el backend no la envía).
  final String? guideTitle;
  final List<String> steps;

  /// Convierte un elemento de `GET /alerts/active`. Null si no trae `id`.
  static ActiveAlert? fromJson(Map<String, dynamic> row, {String? zoneName}) {
    final id = row['id'];
    if (id is! int) return null;
    final guide = row['guia'];
    final steps = guide is Map && guide['pasos'] is List
        ? (guide['pasos'] as List).map((p) => '$p'.trim()).where((p) => p.isNotEmpty).toList()
        : const <String>[];
    return ActiveAlert(
      id: id,
      type: ReportTypeApi.fromApi(row['tipo'] as String?),
      level: AlertLevel.fromApi(row['nivel'] as String?),
      text: '${row['texto'] ?? ''}',
      zoneName: zoneName,
      motivo: '${row['motivo'] ?? ''}',
      simulated: row['simulada'] == true,
      approvedAt: DateTime.tryParse('${row['aprobada_en'] ?? ''}'),
      guideTitle: guide is Map && guide['titulo'] != null ? '${guide['titulo']}' : null,
      steps: steps,
    );
  }

  /// Más grave primero; a igual gravedad, la más reciente primero.
  static int compareBySeverity(ActiveAlert a, ActiveAlert b) {
    final bySeverity = b.level.severity.compareTo(a.level.severity);
    if (bySeverity != 0) return bySeverity;
    final ta = a.approvedAt?.millisecondsSinceEpoch ?? 0;
    final tb = b.approvedAt?.millisecondsSinceEpoch ?? 0;
    final byTime = tb.compareTo(ta);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }
}

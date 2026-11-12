/// Estados posibles de un reporte.
enum ReportStatus {
  confirmed('Confirmado', isPending: false),
  received('Recibido', isPending: true),
  inReview('En revisión', isPending: true),
  attended('Atendido', isPending: false),
  closed('Cerrado', isPending: false);

  const ReportStatus(this.label, {required this.isPending});

  final String label;

  /// Los estados pendientes se muestran en color de advertencia.
  final bool isPending;
}

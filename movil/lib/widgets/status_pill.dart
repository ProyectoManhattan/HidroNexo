import 'package:flutter/material.dart';

import '../models/report_status.dart';

/// Etiqueta de color genérica.
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Etiqueta con el estado de un reporte.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) =>
      InfoPill(label: status.label, color: status.color);
}

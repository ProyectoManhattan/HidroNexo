import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/report_status.dart';

/// Etiqueta de estado (verde = resuelto, naranja = pendiente).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.isPending ? AppColors.warn : AppColors.ok;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

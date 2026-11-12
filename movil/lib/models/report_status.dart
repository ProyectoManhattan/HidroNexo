import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Estados de un reporte.
enum ReportStatus {
  pending('Pendiente', AppColors.warn),
  accepted('Aceptado', AppColors.ok),
  declined('Declinado', AppColors.danger),
  attended('Atendido', AppColors.blue);

  const ReportStatus(this.label, this.color);

  final String label;
  final Color color;
}

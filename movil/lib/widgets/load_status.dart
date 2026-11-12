import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_card.dart';

/// Aviso de carga o de error con botón para reintentar.
/// No ocupa espacio cuando todo está bien.
class LoadStatus extends StatelessWidget {
  const LoadStatus({super.key, required this.loading, required this.error, required this.onRetry});

  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.cloud_off, size: 20, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(error!, style: const TextStyle(fontSize: 12))),
            TextButton(onPressed: loading ? null : onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (loading) return const LinearProgressIndicator(minHeight: 3);
    return const SizedBox.shrink();
  }
}

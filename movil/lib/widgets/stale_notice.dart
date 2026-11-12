import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'app_card.dart';

/// Aviso discreto de que lo que se ve viene de la caché («Datos de hace 5 min»).
class StaleNotice extends StatelessWidget {
  const StaleNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.warn),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../models/alert_item.dart';
import 'status_pill.dart';

/// Fila de alerta con recomendaciones opcionales.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.item});

  final AlertItem item;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.pale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.type.icon, size: 19, color: item.type.color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(item.detail, style: TextStyle(fontSize: 11, color: palette.muted)),
                  const SizedBox(height: 3),
                  Text(item.meta, style: TextStyle(fontSize: 10, color: palette.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(status: item.status),
          ],
        ),
        if (item.recommendations.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: palette.pale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.whatToDo,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final tip in item.recommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5, right: 8),
                          child: Icon(Icons.circle, size: 5, color: AppColors.blue),
                        ),
                        Expanded(child: Text(tip, style: const TextStyle(fontSize: 12, height: 1.4))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/report_type.dart';

/// Leyenda de colores del mapa.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final type in ReportType.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  type.label,
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

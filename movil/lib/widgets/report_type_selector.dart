import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/report_type.dart';

/// Selector de tipo de incidente en el formulario.
class ReportTypeSelector extends StatelessWidget {
  const ReportTypeSelector({super.key, required this.selected, required this.onSelected});

  final ReportType selected;
  final ValueChanged<ReportType> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final types = ReportType.values;
    return Row(
      children: [
        for (var i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _TypeTile(
              type: types[i],
              selected: types[i] == selected,
              palette: palette,
              onTap: () => onSelected(types[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final ReportType type;
  final bool selected;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : palette.muted;
    return Material(
      color: selected ? AppColors.blue : palette.pale,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Column(
            children: [
              Icon(type.icon, size: 26, color: foreground),
              const SizedBox(height: 4),
              Text(
                type.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

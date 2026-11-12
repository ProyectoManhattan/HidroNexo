import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/theme/app_colors.dart';
import 'app_card.dart';

/// Estado del servicio de agua en la colonia.
class WaterServiceCard extends StatelessWidget {
  const WaterServiceCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.pale,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.water_drop, color: AppColors.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.waterNormal,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.waterNormalDetail,
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: AppColors.ok),
              SizedBox(width: 4),
              Text(
                AppStrings.upToDate,
                style: TextStyle(color: AppColors.ok, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

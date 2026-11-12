import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_colors.dart';

/// Tipos de incidente. Para agregar uno nuevo, añade un valor aquí.
enum ReportType {
  flood(
    label: 'Inundación',
    shortLabel: 'Inundación',
    filterLabel: 'Lluvia',
    icon: Icons.waves,
    color: AppColors.blue,
    markerHue: BitmapDescriptor.hueAzure,
  ),
  leak(
    label: 'Fuga de agua',
    shortLabel: 'Fuga',
    filterLabel: 'Fugas',
    icon: Icons.water_drop,
    color: AppColors.warn,
    markerHue: BitmapDescriptor.hueOrange,
  ),
  drain(
    label: 'Alcantarilla',
    shortLabel: 'Alcantarilla',
    filterLabel: 'Alcantarillas',
    icon: Icons.grid_view,
    color: AppColors.drain,
    markerHue: BitmapDescriptor.hueViolet,
  );

  const ReportType({
    required this.label,
    required this.shortLabel,
    required this.filterLabel,
    required this.icon,
    required this.color,
    required this.markerHue,
  });

  final String label;
  final String shortLabel;
  final String filterLabel;
  final IconData icon;
  final Color color;

  /// Tono del marcador de Google Maps.
  final double markerHue;
}

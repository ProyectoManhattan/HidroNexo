import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Tipos de incidente. Para agregar uno nuevo, añade un valor aquí.
enum ReportType {
  flood(
    label: 'Inundación',
    shortLabel: 'Inundación',
    filterLabel: 'Lluvia',
    alertTitle: 'Posible inundación',
    icon: Icons.waves,
    color: AppColors.blue,
    tips: [
      'Evita cruzar calles con agua acumulada.',
      'Sube documentos y objetos de valor a un lugar alto.',
      'Si el agua entra a tu casa, corta la luz desde el interruptor general.',
    ],
  ),
  leak(
    label: 'Fuga de agua',
    shortLabel: 'Fuga',
    filterLabel: 'Fugas',
    alertTitle: 'Fuga de agua',
    icon: Icons.water_drop,
    color: AppColors.warn,
    tips: [
      'Aléjate de cables y postes cercanos.',
      'Guarda agua para beber y cocinar por si se corta el servicio.',
      'Ya fue reportada: no necesitas reportarla de nuevo.',
    ],
  ),
  drain(
    label: 'Alcantarilla',
    shortLabel: 'Alcantarilla',
    filterLabel: 'Alcantarillas',
    alertTitle: 'Alcantarilla obstruida',
    icon: Icons.grid_view,
    color: AppColors.drain,
    tips: [
      'No camines ni manejes cerca de registros sin tapa.',
      'No arrojes basura a la calle.',
      'Avisa a quienes pasen por la zona.',
    ],
  );

  const ReportType({
    required this.label,
    required this.shortLabel,
    required this.filterLabel,
    required this.alertTitle,
    required this.icon,
    required this.color,
    required this.tips,
  });

  final String label;
  final String shortLabel;
  final String filterLabel;
  final String alertTitle;
  final IconData icon;
  final Color color;

  /// Recomendaciones "Qué hacer" para el ciudadano.
  final List<String> tips;
}

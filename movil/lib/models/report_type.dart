import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Tipos de incidente. Para agregar uno nuevo, añade un valor aquí.
enum ReportType {
  flood(
    apiKey: 'inundacion',
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
  pooling(
    apiKey: 'encharcamiento',
    label: 'Encharcamiento',
    shortLabel: 'Encharcamiento',
    filterLabel: 'Encharcamientos',
    alertTitle: 'Encharcamiento',
    icon: Icons.water,
    color: AppColors.sky,
    tips: [
      'Evita pasar por el agua acumulada: puede ocultar huecos o registros abiertos.',
      'No intentes cruzar en auto si no sabes qué tan profundo es.',
      'Cuida a niños y mascotas: no los dejes jugar en el agua.',
    ],
  ),
  leak(
    apiKey: 'fuga',
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
    apiKey: 'alcantarilla',
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
  ),
  noWater(
    apiKey: 'sin_agua',
    label: 'Sin agua',
    shortLabel: 'Sin agua',
    filterLabel: 'Sin agua',
    alertTitle: 'Falta de agua',
    icon: Icons.water_drop_outlined,
    color: AppColors.warn,
    tips: [
      'Almacena agua para beber y cocinar.',
      'Usa el agua con moderación mientras se restablece el servicio.',
      'Si la falta de agua se prolonga, repórtala de nuevo con más detalle.',
    ],
  );

  const ReportType({
    required this.apiKey,
    required this.label,
    required this.shortLabel,
    required this.filterLabel,
    required this.alertTitle,
    required this.icon,
    required this.color,
    required this.tips,
  });

  /// Clave que usa la API (`categoria`).
  final String apiKey;
  final String label;
  final String shortLabel;
  final String filterLabel;
  final String alertTitle;
  final IconData icon;
  final Color color;

  /// Recomendaciones "Qué hacer" para el ciudadano.
  final List<String> tips;
}

extension ReportTypeApi on ReportType {
  /// Convierte la `categoria` de la API; una categoría desconocida cae en inundación.
  static ReportType fromApi(String? key) =>
      ReportType.values.firstWhere((t) => t.apiKey == key, orElse: () => ReportType.flood);
}

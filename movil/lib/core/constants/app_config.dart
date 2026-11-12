import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Valores de configuración editables en un solo lugar.
class AppConfig {
  AppConfig._();

  static const String zoneFull = 'Centro, Veracruz';
  static const String zoneShort = 'Centro';
  static const String emergencyNumber = '911';

  // Mapa
  static const LatLng mapCenter = LatLng(19.1903, -96.1342);
  static const double mapZoom = 14.5;

  // Diseño responsivo
  static const double maxContentWidth = 720;
  static const double expandedBreakpoint = 900;
}

import '../../models/coordinates.dart';

/// Valores de configuración editables en un solo lugar.
class AppConfig {
  AppConfig._();

  static const String zoneFull = 'Centro, Veracruz';
  static const String zoneShort = 'Centro';
  static const String emergencyNumber = '911';

  // Mapa de demostración (el mapa real lo integra el backend)
  static const Coordinates mapCenter = Coordinates(19.1903, -96.1342);
  static const double mapSpanLat = 0.012;
  static const double mapSpanLng = 0.016;

  // Diseño responsivo
  static const double maxContentWidth = 720;
  static const double expandedBreakpoint = 900;
}

import '../../models/coordinates.dart';

/// Valores de configuración editables en un solo lugar.
class AppConfig {
  AppConfig._();

  static const String zoneFull = 'Centro, Veracruz';
  static const String zoneShort = 'Centro';
  static const String emergencyNumber = '911';

  /// Dirección del backend. Por defecto, el servicio desplegado en Railway.
  /// Para usar el backend local al compilar:
  ///   flutter run --dart-define=API_URL=http://10.0.2.2:8000          (emulador)
  ///   flutter run --dart-define=API_URL=http://192.168.1.10:8000      (celular físico)
  /// 10.0.2.2 es el localhost de la computadora visto desde el emulador de Android.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://proyectoagualluvia-production.up.railway.app',
  );

  /// `--dart-define=USE_MOCK=true` usa datos de ejemplo sin backend.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  /// Tiempo máximo de espera de cada petición a la API.
  static const Duration apiTimeout = Duration(seconds: 10);

  /// La subida de una foto (~1 MB) puede tardar más que una petición normal.
  static const Duration uploadTimeout = Duration(seconds: 25);

  // Mapa de demostración (el mapa real lo integra el backend)
  static const Coordinates mapCenter = Coordinates(19.1903, -96.1342);
  static const double mapSpanLat = 0.012;
  static const double mapSpanLng = 0.016;

  // Diseño responsivo
  static const double maxContentWidth = 720;
  static const double expandedBreakpoint = 900;
}

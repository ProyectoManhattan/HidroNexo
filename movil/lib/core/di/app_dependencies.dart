import '../../data/mock_report_repository.dart';
import '../../data/report_repository.dart';
import '../../services/location_service.dart';
import '../../services/phone_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/map/map_provider.dart';
import '../../widgets/map/placeholder_map_provider.dart';

/// Punto único para cambiar implementaciones. Todo es simulado, así que la
/// app corre en el emulador sin claves, permisos ni paquetes externos.
/// Cuando el backend esté listo, reemplaza aquí cada pieza.
class AppDependencies {
  AppDependencies._();

  static final ReportRepository reportRepository = MockReportRepository();
  static final LocationService locationService = SimulatedLocationService();
  static final PhotoService photoService = SimulatedPhotoService();
  static final PhoneService phoneService = SimulatedPhoneService();

  /// BACKEND: asigna aquí el mapa real (ver widgets/map/map_provider.dart).
  static MapProvider mapProvider = const PlaceholderMapProvider();
}

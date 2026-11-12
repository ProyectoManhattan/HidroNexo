import '../../data/api_report_repository.dart';
import '../../data/mock_report_repository.dart';
import '../../data/report_repository.dart';
import '../../services/location_service.dart';
import '../../services/phone_service.dart';
import '../../services/photo_service.dart';
import '../../widgets/map/map_provider.dart';
import '../../widgets/map/maplibre_map_provider.dart';
import '../../widgets/map/placeholder_map_provider.dart';
import '../constants/app_config.dart';
import 'data_refresh.dart';

/// Punto único para cambiar implementaciones.
///
/// Por defecto la app habla con el backend (`AppConfig.apiUrl`). Para trabajar
/// sin backend: `flutter run --dart-define=USE_MOCK=true`.
class AppDependencies {
  AppDependencies._();

  /// Se dispara al enviar un reporte; Inicio y Alertas escuchan y recargan.
  static final DataRefresh dataRefresh = DataRefresh();

  static final ReportRepository reportRepository =
      AppConfig.useMock ? MockReportRepository() : ApiReportRepository();
  static final LocationService locationService =
      AppConfig.useMock ? SimulatedLocationService() : DeviceLocationService();
  static final PhoneService phoneService =
      AppConfig.useMock ? SimulatedPhoneService() : DevicePhoneService();

  // PENDIENTE: la API todavía no recibe archivos (solo `foto_url`), así que
  // la foto sigue simulada y NO se envía con el reporte.
  static final PhotoService photoService = SimulatedPhotoService();

  /// Mapa real (MapLibre) con riesgo por zona; en modo mock, el de demostración.
  static MapProvider mapProvider = AppConfig.useMock
      ? const PlaceholderMapProvider()
      : const MaplibreMapProvider();
}

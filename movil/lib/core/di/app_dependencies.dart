import '../../data/api_report_repository.dart';
import '../../data/mock_report_repository.dart';
import '../../data/report_repository.dart';
import '../../services/active_alert_watcher.dart';
import '../../services/location_service.dart';
import '../../services/phone_service.dart';
import '../../services/push_service.dart';
import '../../services/photo_service.dart';
import '../../services/seen_alerts_store.dart';
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

  /// Push (FCM). En modo mock no hace nada.
  static final PushService pushService = AppConfig.useMock
      ? NoopPushService()
      : FirebasePushService(
          repository: reportRepository,
          locationService: locationService,
        );

  /// Vigila alertas de la zona del usuario (polling) para mostrarlas a pantalla
  /// completa. No depende de Firebase.
  static final ActiveAlertWatcher alertWatcher = ActiveAlertWatcher(
    repository: reportRepository,
    locationService: locationService,
    store: PrefsSeenAlertsStore(),
  );

  /// Fotos reales (cámara/galería). Se suben a `POST /reports/photo` antes de
  /// crear el reporte. En modo mock, simulada.
  static final PhotoService photoService =
      AppConfig.useMock ? SimulatedPhotoService() : DevicePhotoService();

  /// Mapa real (MapLibre) con riesgo por zona; en modo mock, el de demostración.
  static MapProvider mapProvider = AppConfig.useMock
      ? const PlaceholderMapProvider()
      : const MaplibreMapProvider();
}

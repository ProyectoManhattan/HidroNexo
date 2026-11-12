import '../../data/api_report_repository.dart';
import '../../data/local/local_database.dart';
import '../../data/local/offline_cache.dart';
import '../../data/local/pending_report_store.dart';
import '../../data/mock_report_repository.dart';
import '../../data/report_repository.dart';
import '../../services/active_alert_watcher.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';
import '../../services/pending_report_queue.dart';
import '../../services/pending_report_sender.dart';
import '../../services/phone_service.dart';
import '../../services/push_service.dart';
import '../../services/photo_service.dart';
import '../../services/mesh/in_memory_mesh.dart';
import '../../services/mesh/mesh_node.dart';
import '../../services/mesh/mesh_origins.dart';
import '../../services/mesh/mesh_store.dart';
import '../../services/mesh/mesh_transport.dart';
import '../../services/mesh/nearby_mesh_transport.dart';
import '../../services/mesh/postal_code_resolver.dart';
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

  /// SQLite local: cola de un reporte pendiente y caché de alertas/mapa.
  /// Si falla, la app sigue funcionando sin ella.
  static final LocalDatabase localDatabase = LocalDatabase();
  static final OfflineCache offlineCache = OfflineCache(localDatabase);

  static final ReportRepository reportRepository = AppConfig.useMock
      ? MockReportRepository()
      : ApiReportRepository(cache: offlineCache);

  /// Conectividad del dispositivo (banda «Sin conexión» y reenvío).
  static final ConnectivityService connectivity =
      AppConfig.useMock ? AlwaysOnlineConnectivity() : DeviceConnectivityService();

  /// Único reporte pendiente de envío (sin señal).
  static final PendingReportQueue pendingQueue =
      PendingReportQueue(store: PendingReportStore(localDatabase));

  /// Reenvía el pendiente con backoff, sin saturar la red.
  static final PendingReportSender pendingSender = PendingReportSender(
    queue: pendingQueue,
    repository: reportRepository,
    connectivity: connectivity,
    onSent: dataRefresh.notifyChanged,
  );
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

  // ---- Modo sin internet (malla Bluetooth, experimental) ----

  /// Código postal propio (el fijado a mano manda sobre el GPS).
  static final PostalCodeResolver cpResolver = PostalCodeResolver.fromApp(
    manualStore: PrefsManualCpStore(),
    cache: offlineCache,
    location: locationService,
  );

  /// Transporte: Nearby Connections; con USE_MOCK, red en memoria.
  static final MeshTransport meshTransport =
      AppConfig.useMock ? InMemoryMeshNetwork().node('demo') : NearbyMeshTransport();

  static final MeshNode meshNode = MeshNode(
    transport: meshTransport,
    store: SqlMeshStore(localDatabase),
    cpResolver: cpResolver,
    repository: reportRepository,
    connectivity: connectivity,
    onShowAlert: (a) => alertWatcher.showExternal(a),
  );

  static final MeshOrigins meshOrigins = MeshOrigins(
    node: meshNode,
    watcher: alertWatcher,
    queue: pendingQueue,
    connectivity: connectivity,
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

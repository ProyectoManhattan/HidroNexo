import '../../data/mock_report_repository.dart';
import '../../data/report_repository.dart';
import '../../services/location_service.dart';
import '../../services/phone_service.dart';
import '../../services/photo_service.dart';

/// Punto único para cambiar implementaciones (por ejemplo, pasar de datos
/// de prueba a una API real sin tocar pantallas ni controladores).
class AppDependencies {
  AppDependencies._();

  static final ReportRepository reportRepository = MockReportRepository();
  static final LocationService locationService = SimulatedLocationService();
  static final PhotoService photoService = GalleryPhotoService();
  static final PhoneService phoneService = PhoneService();
}

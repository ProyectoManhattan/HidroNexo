import '../core/constants/app_config.dart';
import '../models/coordinates.dart';

class UserLocation {
  const UserLocation({
    required this.neighborhood,
    required this.address,
    required this.position,
  });

  final String neighborhood;
  final String address;
  final Coordinates position;
}

/// Contrato para obtener la ubicación del usuario.
abstract class LocationService {
  Future<UserLocation> getCurrentLocation();
}

/// Ubicación simulada: no pide permisos, no falla en el emulador.
/// Para GPS real, implementa [LocationService] con `geolocator`.
class SimulatedLocationService implements LocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    return const UserLocation(
      neighborhood: 'Col. Centro',
      address: '${AppConfig.zoneFull} (simulada)',
      position: AppConfig.mapCenter,
    );
  }
}

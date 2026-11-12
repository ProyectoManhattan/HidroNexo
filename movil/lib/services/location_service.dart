import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/app_config.dart';

class UserLocation {
  const UserLocation({required this.label, required this.position});

  final String label;
  final LatLng position;
}

/// Contrato para obtener la ubicación del usuario.
abstract class LocationService {
  Future<UserLocation> getCurrentLocation();
}

/// Ubicación simulada (igual que el prototipo). Para GPS real, crea una
/// clase que implemente [LocationService] con el paquete `geolocator`
/// y cámbiala en AppDependencies.
class SimulatedLocationService implements LocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    return const UserLocation(
      label: '${AppConfig.zoneFull} (simulada)',
      position: AppConfig.mapCenter,
    );
  }
}

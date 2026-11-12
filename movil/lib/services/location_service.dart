import 'package:geolocator/geolocator.dart';

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

/// No se pudo obtener la ubicación; [message] se muestra al ciudadano.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
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

/// GPS real con `geolocator`. Pide el permiso la primera vez.
class DeviceLocationService implements LocationService {
  @override
  Future<UserLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Activa la ubicación (GPS) de tu celular.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Necesitamos el permiso de ubicación para ubicar tu reporte.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('El permiso de ubicación está bloqueado. Actívalo en los ajustes del celular.');
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final label =
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      return UserLocation(
        neighborhood: 'Mi ubicación',
        address: 'Mi ubicación ($label)',
        position: Coordinates(position.latitude, position.longitude),
      );
    } catch (_) {
      throw const LocationException('No pudimos obtener tu ubicación. Inténtalo de nuevo.');
    }
  }
}

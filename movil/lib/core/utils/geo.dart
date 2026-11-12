import 'dart:math' as math;

import '../../models/coordinates.dart';

/// Distancia en metros entre dos puntos (fórmula de Haversine).
double distanceMeters(Coordinates a, Coordinates b) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Decide si la ubicación enviada al backend debe actualizarse: la primera
/// vez, o si el usuario se movió más de [thresholdMeters] desde la última enviada.
bool shouldResendLocation(
  Coordinates? lastSent,
  Coordinates current, {
  double thresholdMeters = 300,
}) {
  if (lastSent == null) return true;
  return distanceMeters(lastSent, current) > thresholdMeters;
}
